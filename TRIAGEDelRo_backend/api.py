"""
API.PY - FastAPI Backend
Exposes your trained ML model as a REST API.
Your Node.js server calls this to get predictions.

Run with:
    uvicorn api:app --host 0.0.0.0 --port 8000 --reload
"""

import json
import re
import torch
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# ─── LOAD MODEL ON STARTUP ───────────────────────────────────────────────────
MODEL_PATH = "saved_model/"

print("⏳ Loading model...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, use_fast=False)
severity_model  = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)
severity_model.eval()

with open(f"{MODEL_PATH}/label_map_severity.json") as f:
    severity_map = json.load(f)

# Optional: load a separate category model if you trained one
# category_model = ...
# with open(f"{MODEL_PATH}/label_map_category.json") as f:
#     category_map = json.load(f)

print("✅ Model loaded and ready!")

# ─── APP SETUP ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Barangay Triage API",
    description="ML-powered severity classification of citizen disaster reports",
    version="1.0.0"
)

# Allow React frontend and Node.js to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict to your domain in production
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── REQUEST / RESPONSE MODELS ───────────────────────────────────────────────
class ReportRequest(BaseModel):
    report_text: str  # The raw citizen report text

class ClassificationResult(BaseModel):
    report_text: str
    severity: str
    severity_confidence: float
    severity_scores: dict
    # category: str  # Uncomment when category model is ready
    message: str

# ─── HELPER: CLEAN TEXT ──────────────────────────────────────────────────────
def clean_text(text: str) -> str:
    text = text.lower()
    text = re.sub(r"http\S+", "", text)
    text = re.sub(r"@\w+", "", text)
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text

# ─── HELPER: PREDICT ─────────────────────────────────────────────────────────
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
    confidence     = float(probs[pred_idx])
    all_scores     = {severity_map[str(i)]: float(p) for i, p in enumerate(probs)}
    
    return severity_label, confidence, all_scores

# ─── ROUTES ──────────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "Barangay Triage API is running ✅"}

@app.get("/health")
def health():
    return {"status": "ok", "model": "roberta-tagalog"}

@app.post("/classify", response_model=ClassificationResult)
def classify_report(payload: ReportRequest):
    """
    Main endpoint. Send a citizen report text, get back severity + category.
    
    Example request body:
    {
        "report_text": "Nagbaha na sa aming bahay, may nakulong na tao sa loob"
    }
    """
    if not payload.report_text.strip():
        raise HTTPException(status_code=400, detail="report_text must not be empty.")
    
    severity, confidence, scores = predict_severity(payload.report_text)
    
    # Map severity to a user-friendly message
    messages = {
        "Critical": "🔴 CRITICAL — Immediate response required!",
        "High":     "🟠 HIGH — Urgent attention needed.",
        "Medium":   "🟡 MEDIUM — Moderate priority.",
        "Low":      "🟢 LOW — Can be queued for later action.",
    }

    return ClassificationResult(
        report_text=payload.report_text,
        severity=severity,
        severity_confidence=round(confidence * 100, 2),
        severity_scores={k: round(v * 100, 2) for k, v in scores.items()},
        message=messages.get(severity, "Classified successfully.")
    )

@app.post("/classify/batch")
def classify_batch(reports: list[ReportRequest]):
    """Classify multiple reports at once."""
    results = []
    for r in reports:
        severity, confidence, scores = predict_severity(r.report_text)
        results.append({
            "report_text": r.report_text,
            "severity": severity,
            "confidence": round(confidence * 100, 2)
        })
    # Sort by severity (Critical first)
    order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    results.sort(key=lambda x: order.get(x["severity"], 99))
    return {"results": results, "total": len(results)}
