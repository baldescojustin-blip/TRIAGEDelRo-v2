"""
API.PY - FastAPI Backend
Exposes your trained ML model as a REST API.
Your Flutter app calls /classify to get ML predictions.
Reports are saved to Supabase from the Flutter app directly.

Run with:
    python -m uvicorn api:app --host 0.0.0.0 --port 8000 --reload
"""

import io
import json
import os
import re
import sys
import torch
import httpx
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image
from torch import nn
from torchvision import models, transforms
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# Loads RESEND_API_KEY / OPENWEATHER_API_KEY from a local .env file
# (gitignored — see .env.example for the template). Never commit real
# credentials to this file.
load_dotenv()

# Force UTF-8 stdout/stderr so the emoji in the log messages below don't crash
# the server on startup when launched from a terminal using a non-UTF-8
# codepage (common on plain Windows cmd.exe/PowerShell).
if sys.stdout.encoding is None or sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# ─── LOAD MODEL ON STARTUP ───────────────────────────────────────────────────
MODEL_PATH = "saved_model/"

print("⏳ Loading model...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, use_fast=False)
severity_model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)
severity_model.eval()

with open(f"{MODEL_PATH}/label_map_severity.json") as f:
    severity_map = json.load(f)

print("✅ Severity model loaded and ready!")

# ─── LOAD IMAGE MODELS (for /verify-image) ───────────────────────────────────
VISION_DEVICE = torch.device("cpu")
VALIDITY_MODEL_PATH = Path("vision_models/validity_best_model.pt")
PHASE2_MODEL_PATH = Path("vision_models/phase2_best_model.pt")
VISION_ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}

VISION_TRANSFORM = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
])

print("⏳ Loading image validity model (Stage 1)...")
if VALIDITY_MODEL_PATH.is_file():
    checkpoint = torch.load(VALIDITY_MODEL_PATH, map_location=VISION_DEVICE, weights_only=False)
    validity_model = models.mobilenet_v3_small(weights=None)
    validity_model.classifier[-1] = nn.Linear(validity_model.classifier[-1].in_features, 2)
    validity_model.load_state_dict(checkpoint["model_state_dict"])
    validity_model = validity_model.to(VISION_DEVICE).eval()
    print("✅ Validity model loaded!")
else:
    validity_model = None
    print(f"⚠️  Validity model not found at {VALIDITY_MODEL_PATH} — /verify-image will be disabled.")

print("⏳ Loading multi-class disaster model (Stage 2)...")
if PHASE2_MODEL_PATH.is_file():
    phase2_model = models.mobilenet_v3_small(weights=None)
    phase2_model.classifier[3] = nn.Linear(phase2_model.classifier[3].in_features, 4)
    phase2_model.load_state_dict(torch.load(PHASE2_MODEL_PATH, map_location=VISION_DEVICE, weights_only=True))
    phase2_model = phase2_model.to(VISION_DEVICE).eval()
    print("✅ Phase 2 (4-class) model loaded!")
else:
    phase2_model = None
    print(f"⚠️  Phase2 model not found at {PHASE2_MODEL_PATH} — classification will skip.")

PHASE2_TO_REPORT_CATEGORY = {
    "EARTHQUAKE": "Earthquake",
    "FIRE": "Fire",
    "FLOOD": "Flooding",
    "LANDSLIDE": "Landslide"
}

# ─── APP SETUP ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="My Laud Triage API",
    description="ML-powered severity classification of citizen disaster reports",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── NOTIFICATION CONFIGURATION ────────────────────────────────────────────────
# Email alerts go through Resend's HTTP API rather than raw SMTP. Some hosts
# (Hugging Face Spaces' free tier included) block outbound SMTP sockets
# entirely to prevent spam abuse — HTTPS-based email APIs like Resend aren't
# affected since they just look like a normal web request.
RESEND_API_KEY = os.getenv("RESEND_API_KEY")

# NOTE: until a custom sending domain is verified on Resend
# (resend.com/domains), their shared "onboarding@resend.dev" sender can only
# deliver to the email address the Resend account itself was signed up
# with — anything else gets a 403 from Resend's API. Real recipients are
# kept here for reference; TEMP_DEMO_RECIPIENT is what's actually used until
# a domain is verified, at which point swap OFFICIAL_ALERT_EMAILS back in.
OFFICIAL_ALERT_EMAILS = [
    "jubaldesco@gbox.ncf.edu.ph",
    "rksaycon@gbox.ncf.edu.ph",
    "jalauron@gbox.ncf.edu.ph"
]
TEMP_DEMO_RECIPIENT = ["baldescojustin@gmail.com"]

# ─── REQUEST / RESPONSE MODELS ───────────────────────────────────────────────

class ReportRequest(BaseModel):
    report_text: str                        
    category: Optional[str] = None          
    report_type: Optional[str] = None       
    location: Optional[str] = None          
    lat: Optional[float] = None             
    lng: Optional[float] = None             

class ClassificationResult(BaseModel):
    report_text: str
    severity: str
    severity_confidence: float
    severity_scores: dict
    message: str
    report_type: Optional[str] = None
    category: Optional[str] = None
    location: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    language_hint: Optional[str] = None
    classified_at: str = ""

class BatchReportRequest(BaseModel):
    reports: list[ReportRequest]

class EmergencyAlertRequest(BaseModel):
    category: str
    severity: str
    description: str
    location: str | None = None
    lat: float | None = None
    lng: float | None = None
    image_url: str | None = None

# ─── ALERT WORKERS ─────────────────────────────────────────────────────────────
def send_email_alert(data: EmergencyAlertRequest):
    if not RESEND_API_KEY:
        print("Email dispatch skipped: RESEND_API_KEY not configured.")
        return

    try:
        coords_str = f"{data.lat}, {data.lng}" if data.lat and data.lng else "N/A"
        evidence_html = f'<p><b>Evidence:</b> <a href="{data.image_url}">View Attached Photo</a></p>' if data.image_url else ""

        html_content = f"""
        <html>
          <body style="font-family: Arial, sans-serif; background-color: #0b0f19; color: #ffffff; padding: 20px;">
            <div style="max-width: 600px; margin: auto; background: #131926; border: 1px solid #ef4444; border-radius: 8px; padding: 24px;">
              <h2 style="color: #ef4444; margin-top: 0;">🚨 CRITICAL INCIDENT REPORT TRANSMITTED</h2>
              <p style="font-size: 14px; color: #94a3b8;">An emergency report with <b>HIGH SEVERITY</b> has been logged in Barangay Del Rosario.</p>
              <hr style="border: 0; border-top: 1px solid #243049; margin: 16px 0;" />
              
              <table style="width: 100%; font-size: 14px; line-height: 1.6;">
                <tr><td style="color: #94a3b8; width: 120px;"><b>Category:</b></td><td>{data.category}</td></tr>
                <tr><td style="color: #94a3b8;"><b>Severity:</b></td><td style="color: #ef4444; font-weight: bold;">HIGH</td></tr>
                <tr><td style="color: #94a3b8;"><b>Location:</b></td><td>{data.location or 'Not provided'}</td></tr>
                <tr><td style="color: #94a3b8;"><b>GPS:</b></td><td>{coords_str}</td></tr>
                <tr><td style="color: #94a3b8;"><b>Description:</b></td><td>{data.description}</td></tr>
              </table>
              
              {evidence_html}
              
              <div style="margin-top: 24px; padding: 12px; background: rgba(239, 68, 68, 0.1); border-left: 4px solid #ef4444;">
                <p style="margin: 0; font-size: 12px; color: #ef4444;">Please dispatch responders or review the incident via the Official Dashboard immediately.</p>
              </div>
            </div>
          </body>
        </html>
        """

        response = httpx.post(
            "https://api.resend.com/emails",
            headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
            json={
                "from": "My Laud Emergency Dispatch <onboarding@resend.dev>",
                "to": TEMP_DEMO_RECIPIENT,
                "subject": f"🚨 [MY LAUD HIGH ALERT] {data.category.upper()} Incident Reported",
                "html": html_content,
            },
            timeout=15.0,
        )

        if response.status_code in (200, 201):
            print(f"Resend dispatch email sent successfully (id={response.json().get('id')})")
        else:
            print(f"Resend dispatch failed: {response.status_code} {response.text}")
    except Exception as e:
        print(f"Resend dispatch failed: {e}")

# ─── HELPER FUNCTIONS ──────────────────────────────────────────────────────
def clean_text(text: str) -> str:
    text = text.lower()
    text = re.sub(r"http\S+", "", text)        
    text = re.sub(r"@\w+", "", text)           
    text = re.sub(r"[^\w\s]", " ", text)       
    text = re.sub(r"\s+", " ", text).strip()   
    return text

_TAGALOG_MARKERS = ["ang", "ng", "mga", "sa", "na", "ay", "po", "ako", "siya", "namin", "kami"]
_BIKOL_MARKERS = ["an", "kan", "asin", "sa", "na", "ako", "ika", "sinda", "digdi", "duman"]

def detect_language_hint(cleaned_text: str) -> str:
    """Rough heuristic: guesses FIL(Tagalog)/Bikol/English/mixed from function-word
    overlap. Not a substitute for a trained language-ID model, but enough to
    surface which language a report was likely written in (FIL-Eng, Bikol-Eng,
    or plain English)."""
    words = cleaned_text.split()
    total_words = max(len(words), 1)
    tagalog_ratio = sum(1 for w in words if w in _TAGALOG_MARKERS) / total_words
    bikol_ratio = sum(1 for w in words if w in _BIKOL_MARKERS) / total_words

    if bikol_ratio > 0.3 and bikol_ratio >= tagalog_ratio:
        return "bikol"
    elif bikol_ratio > 0.1 and bikol_ratio >= tagalog_ratio:
        return "bikol-english"
    elif tagalog_ratio > 0.3:
        return "tagalog"
    elif tagalog_ratio > 0.1:
        return "taglish"
    else:
        return "english"

def predict_severity(text: str):
    cleaned = clean_text(text)
    inputs = tokenizer(
        cleaned,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=128
    )
    with torch.no_grad():
        outputs = severity_model(**inputs)

    probs = torch.softmax(outputs.logits, dim=1).squeeze().numpy()
    pred_idx = int(np.argmax(probs))

    severity_label = severity_map[str(pred_idx)]
    confidence = float(probs[pred_idx])
    all_scores = {severity_map[str(i)]: float(p) for i, p in enumerate(probs)}

    return severity_label, confidence, all_scores

def run_image_verification(image_bytes: bytes) -> dict:
    if validity_model is None:
        raise HTTPException(
            status_code=503,
            detail=f"Validity model not found at {VALIDITY_MODEL_PATH}. Add the file and restart the server.",
        )

    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Could not open or process image: {error}")

    tensor = VISION_TRANSFORM(image).unsqueeze(0).to(VISION_DEVICE)

    with torch.no_grad():
        validity_probs = torch.softmax(validity_model(tensor), dim=1).squeeze(0)
    invalid_probability = float(validity_probs[0])
    valid_probability = float(validity_probs[1])
    is_valid = valid_probability > invalid_probability

    result = {
        "is_valid_report_photo": is_valid,
        "valid_probability": round(valid_probability * 100, 2),
        "invalid_probability": round(invalid_probability * 100, 2),
        "detected_disaster_category": None,
        "disaster_confidence": None,
    }

    if is_valid and phase2_model is not None:
        with torch.no_grad():
            disaster_probs = torch.softmax(phase2_model(tensor), dim=1).squeeze(0)
        
        disaster_index = int(disaster_probs.argmax())
        disaster_labels = {0: "EARTHQUAKE", 1: "FIRE", 2: "FLOOD", 3: "LANDSLIDE"}
        disaster_label = disaster_labels[disaster_index]
        
        result["detected_disaster_category"] = PHASE2_TO_REPORT_CATEGORY[disaster_label]
        result["disaster_confidence"] = round(float(disaster_probs[disaster_index]) * 100, 2)
        
        result["earthquake_probability"] = round(float(disaster_probs[0]) * 100, 2)
        result["fire_probability"] = round(float(disaster_probs[1]) * 100, 2)
        result["flood_probability"] = round(float(disaster_probs[2]) * 100, 2)
        result["landslide_probability"] = round(float(disaster_probs[3]) * 100, 2)

    return result

def image_matches_report(photo_category: Optional[str], reported_category: Optional[str]) -> Optional[bool]:
    if not photo_category or not reported_category:
        return None
    return photo_category.strip().lower() == reported_category.strip().lower()

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/forecast"
DEFAULT_LAT = 13.6218
DEFAULT_LNG = 123.1948

async def get_rain_forecast(lat: float, lng: float):
    if not OPENWEATHER_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="OPENWEATHER_API_KEY is not set. Get a free key at openweathermap.org/api",
        )

    params = {"lat": lat, "lon": lng, "appid": OPENWEATHER_API_KEY, "units": "metric"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(OPENWEATHER_URL, params=params)

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Weather provider error: {resp.text}")

    data = resp.json()
    next_blocks = data.get("list", [])[:4]

    total_rain_mm = 0.0
    for block in next_blocks:
        total_rain_mm += block.get("rain", {}).get("3h", 0.0)

    if total_rain_mm >= 50:
        risk = "Severe"
        evacuation_advisory = True
        recommended_action = (
            "Heavy rainfall expected — flooding is likely. Monitor official barangay "
            "announcements closely and be ready to evacuate if barangay officials instruct you to."
        )
    elif total_rain_mm >= 30:
        risk = "High"
        evacuation_advisory = False
        recommended_action = "Significant rain expected. Prepare an emergency kit and watch for barangay updates."
    elif total_rain_mm >= 10:
        risk = "Moderate"
        evacuation_advisory = False
        recommended_action = "Moderate rain expected. Stay alert, no action needed yet."
    else:
        risk = "Low"
        evacuation_advisory = False
        recommended_action = "No significant rain expected."

    return {
        "lat": lat,
        "lng": lng,
        "expected_rain_mm_next_12h": round(total_rain_mm, 1),
        "flood_risk": risk,
        "evacuation_advisory": evacuation_advisory,
        "recommended_action": recommended_action,
        "note": "Estimated from rain forecast, not a physical water-level sensor. This is an advisory only — official evacuation decisions come from barangay officials, not this system.",
        "checked_at": datetime.utcnow().isoformat(),
    }

def get_severity_message(severity: str, report_type: Optional[str] = None) -> str:
    if report_type == "Minor Concern":
        return "🟢 MINOR CONCERN — Logged for community review."

    messages = {
        "High":   "🟠 HIGH — Urgent attention needed.",
        "Medium": "🟡 MEDIUM — Moderate priority.",
        "Low":    "🟢 LOW — Can be queued for later action.",
    }
    return messages.get(severity, "Classified successfully.")

# ─── ROUTES ──────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "My Laud Triage API is running ✅", "version": "2.0.0"}

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": "roberta-tagalog",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/classify", response_model=ClassificationResult)
def classify_report(payload: ReportRequest):
    if not payload.report_text.strip():
        raise HTTPException(status_code=400, detail="report_text must not be empty.")

    language_hint = detect_language_hint(clean_text(payload.report_text))

    if payload.report_type == "Minor Concern":
        return ClassificationResult(
            report_text=payload.report_text,
            severity="Low",
            severity_confidence=100.0,
            severity_scores={"High": 0.0, "Medium": 0.0, "Low": 100.0},
            message=get_severity_message("Low", payload.report_type),
            report_type=payload.report_type,
            category=payload.category,
            location=payload.location,
            lat=payload.lat,
            lng=payload.lng,
            language_hint=language_hint,
            classified_at=datetime.utcnow().isoformat(),
        )

    severity, confidence, scores = predict_severity(payload.report_text)

    return ClassificationResult(
        report_text=payload.report_text,
        severity=severity,
        severity_confidence=round(confidence * 100, 2),
        severity_scores={k: round(v * 100, 2) for k, v in scores.items()},
        message=get_severity_message(severity, payload.report_type),
        report_type=payload.report_type,
        category=payload.category,
        location=payload.location,
        lat=payload.lat,
        lng=payload.lng,
        language_hint=language_hint,
        classified_at=datetime.utcnow().isoformat(),
    )

@app.post("/classify/batch")
def classify_batch(payload: BatchReportRequest):
    results = []
    for r in payload.reports:
        if not r.report_text.strip():
            continue

        if r.report_type == "Minor Concern":
            severity, confidence = "Low", 1.0
        else:
            severity, confidence, _ = predict_severity(r.report_text)

        results.append({
            "report_text": r.report_text,
            "category": r.category,
            "report_type": r.report_type,
            "location": r.location,
            "lat": r.lat,
            "lng": r.lng,
            "severity": severity,
            "confidence": round(confidence * 100, 2),
            "message": get_severity_message(severity, r.report_type),
            "classified_at": datetime.utcnow().isoformat(),
        })

    order = {"High": 0, "Medium": 1, "Low": 2}
    results.sort(key=lambda x: (
        0 if x.get("report_type") == "Emergency" else 1,
        order.get(x["severity"], 99)
    ))

    return {
        "results": results,
        "total": len(results),
        "breakdown": {
            "High": sum(1 for r in results if r["severity"] == "High"),
            "Medium": sum(1 for r in results if r["severity"] == "Medium"),
            "Low": sum(1 for r in results if r["severity"] == "Low"),
            "Emergency": sum(1 for r in results if r.get("report_type") == "Emergency"),
            "Minor Concern": sum(1 for r in results if r.get("report_type") == "Minor Concern"),
        }
    }

@app.post("/verify-image")
async def verify_image(
    file: UploadFile = File(...),
    reported_category: Optional[str] = Form(None),
):
    extension = (file.filename or "").rsplit(".", 1)[-1].lower()
    if extension not in VISION_ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Supported formats: JPG, JPEG, PNG, and WEBP.")

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image upload.")

    verification = run_image_verification(image_bytes)
    photo_category = verification["detected_disaster_category"]
    matches = image_matches_report(photo_category, reported_category)

    if not verification["is_valid_report_photo"]:
        verdict = "⚠️ Photo doesn't look like a disaster report photo. Needs manual review."
    elif photo_category is None:
        verdict = "Photo looks valid, but the classification model isn't loaded yet — nothing to compare."
    elif matches is None:
        verdict = "Photo looks valid. No reported category given — nothing to compare against."
    elif matches:
        verdict = "✅ Photo appears consistent with the reported category."
    else:
        verdict = (
            f"⚠️ Photo looks more like '{photo_category}' than the reported "
            f"'{reported_category}'. Needs manual review."
        )

    return {
        **verification,
        "reported_category": reported_category,
        "matches_report": matches,
        "verdict": verdict,
        "requires_human_review": (not verification["is_valid_report_photo"]) or (matches is False),
        "checked_at": datetime.utcnow().isoformat(),
    }

@app.get("/weather/rain-risk")
async def weather_rain_risk(lat: Optional[float] = None, lng: Optional[float] = None):
    return await get_rain_forecast(lat or DEFAULT_LAT, lng or DEFAULT_LNG)

@app.post("/classify/explain")
def classify_with_explanation(payload: ReportRequest):
    if not payload.report_text.strip():
        raise HTTPException(status_code=400, detail="report_text must not be empty.")

    cleaned = clean_text(payload.report_text)
    severity, confidence, scores = predict_severity(payload.report_text)

    category_keywords = {
        "Flooding":               ["baha", "bahang", "tubig", "flood", "bumabaha", "nagbaha", "baha na", "salog", "uran"],
        "Fire":                   ["sunog", "apoy", "nasusunog", "fire", "nagliliyab", "kalayo"],
        "Medical Emergency":      ["sugatan", "patay", "ospital", "ambulance", "dugo", "injured", "medical", "gadan", "helang"],
        "Infrastructure Damage":  ["tulay", "daan", "bahay", "gusali", "gumuho", "damage", "nasira", "harong", "tinapok"],
    }
    detected_category = payload.category  
    if not detected_category:
        for cat, keywords in category_keywords.items():
            if any(kw in cleaned for kw in keywords):
                detected_category = cat
                break

    language_hint = detect_language_hint(cleaned)

    return {
        "report_text": payload.report_text,
        "cleaned_text": cleaned,
        "severity": severity,
        "severity_confidence": round(confidence * 100, 2),
        "severity_scores": {k: round(v * 100, 2) for k, v in scores.items()},
        "message": get_severity_message(severity, payload.report_type),
        "detected_category": detected_category,
        "language_hint": language_hint,
        "report_type": payload.report_type,
        "location": payload.location,
        "lat": payload.lat,
        "lng": payload.lng,
        "classified_at": datetime.utcnow().isoformat(),
    }

# NEW ROUTE: Triggers Email alerts for HIGH severity incidents.
# TODO (future work): also dispatch SMS here (e.g. via Semaphore/Twilio) once
# an SMS provider account is set up. Currently email-only.
@app.post("/notify-high")
async def notify_high_incident(report: EmergencyAlertRequest, background_tasks: BackgroundTasks):
    background_tasks.add_task(send_email_alert, report)
    return {"status": "alerts_queued", "message": "Email dispatch initiated."}