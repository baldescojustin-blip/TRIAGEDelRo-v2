"""
TRAIN.PY - Full ML Pipeline
Combines:
  1. Kaggle NLP Disaster Tweets (train.csv)
  2. Your Filipino barangay reports (reports.csv)

Run: python train.py
Output: saved_model/
"""

import os
import json
import re
import numpy as np
import pandas as pd
import torch
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from sklearn.preprocessing import LabelEncoder
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    Trainer,
    TrainingArguments,
)
from transformers.trainer_utils import get_last_checkpoint
from torch.utils.data import Dataset

# ─── CONFIG ──────────────────────────────────────────────────────────────────
MODEL_NAME      = "jcblaise/roberta-tagalog-base"
KAGGLE_CSV      = "data/train.csv"
LOCAL_CSV       = "data/reports.csv"
MODEL_OUTPUT    = "saved_model/"
MAX_LENGTH      = 128
BATCH_SIZE      = 16
EPOCHS          = 5

# ─── STEP 1: LOAD DATASETS ───────────────────────────────────────────────────

def load_kaggle_data(path):
    print("Loading Kaggle dataset...")
    df = pd.read_csv(path)
    df = df[df['target'] == 1].copy()
    df = df[['text']].rename(columns={'text': 'report_text'})

    def assign_severity(text):
        t = str(text).lower()
        if any(w in t for w in ['dead','death','kill','fatal','trapped','buried','collapse','explosion','crash']):
            return 'Critical'
        elif any(w in t for w in ['injur','rescue','evacuate','destroy','damage','flood','emergency','urgent']):
            return 'High'
        elif any(w in t for w in ['warning','alert','watch','storm','rain','wind']):
            return 'Medium'
        else:
            return 'Low'

    df['severity'] = df['report_text'].apply(assign_severity)
    df['source'] = 'kaggle'
    print(f"   Kaggle disaster tweets: {len(df)}")
    return df

def load_local_data(path):
    print("Loading Filipino barangay dataset...")
    df = pd.read_csv(path)
    df = df[['report_text', 'severity']].copy()
    df['source'] = 'local'
    print(f"   Local rows: {len(df)}")
    return df

def combine_datasets(kaggle_df, local_df):
    print("Combining datasets...")
    local_boosted = pd.concat([local_df] * 3, ignore_index=True)
    combined = pd.concat([kaggle_df, local_boosted], ignore_index=True)
    combined = combined.sample(frac=1, random_state=42).reset_index(drop=True)
    print(f"   Total rows: {len(combined)}")
    print(combined['severity'].value_counts())
    return combined

# ─── STEP 2: PREPROCESS ──────────────────────────────────────────────────────

def clean_text(text):
    text = str(text).lower()
    text = re.sub(r"http\S+", "", text)
    text = re.sub(r"@\w+", "", text)
    text = re.sub(r"#(\w+)", r"\1", text)
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text

# ─── STEP 3: DATASET ─────────────────────────────────────────────────────────

class ReportDataset(Dataset):
    def __init__(self, texts, labels, tokenizer):
        self.encodings = tokenizer(list(texts), truncation=True, padding=True,
                                   max_length=MAX_LENGTH, return_tensors="pt")
        self.labels = torch.tensor(labels, dtype=torch.long)
    def __len__(self): return len(self.labels)
    def __getitem__(self, idx):
        item = {k: v[idx] for k, v in self.encodings.items()}
        item["labels"] = self.labels[idx]
        return item

# ─── STEP 4: TRAIN ───────────────────────────────────────────────────────────

def train(df):
    df["clean_text"] = df["report_text"].apply(clean_text)

    le = LabelEncoder()
    df["label"] = le.fit_transform(df["severity"])
    num_labels = len(le.classes_)

    print(f"\nLabel mapping: {dict(enumerate(le.classes_))}")

    os.makedirs(MODEL_OUTPUT, exist_ok=True)
    label_map = {str(i): label for i, label in enumerate(le.classes_)}
    with open(f"{MODEL_OUTPUT}/label_map_severity.json", "w") as f:
        json.dump(label_map, f)

    X_train, X_test, y_train, y_test = train_test_split(
        df["clean_text"], df["label"], test_size=0.2,
        random_state=42, stratify=df["label"]
    )

    print(f"Train: {len(X_train)} | Test: {len(X_test)}")
    print(f"\nLoading {MODEL_NAME}...")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME, num_labels=num_labels)

    train_ds = ReportDataset(X_train, y_train.tolist(), tokenizer)
    test_ds  = ReportDataset(X_test,  y_test.tolist(),  tokenizer)

    args = TrainingArguments(
        output_dir=MODEL_OUTPUT,
        num_train_epochs=EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        logging_dir="./logs",
        logging_steps=20,
        warmup_steps=100,
        weight_decay=0.01,
    )

    trainer = Trainer(model=model, args=args, train_dataset=train_ds, eval_dataset=test_ds)

    # Auto-resume: if a previous run left checkpoints in MODEL_OUTPUT (e.g. the
    # process got interrupted), pick up from the latest one instead of
    # restarting from scratch.
    last_checkpoint = None
    if os.path.isdir(MODEL_OUTPUT):
        last_checkpoint = get_last_checkpoint(MODEL_OUTPUT)
        if last_checkpoint:
            print(f"\nFound existing checkpoint, resuming from: {last_checkpoint}")

    print("\nTraining started... (takes 10-30 mins depending on your PC)")
    trainer.train(resume_from_checkpoint=last_checkpoint)

    preds = trainer.predict(test_ds)
    y_pred = np.argmax(preds.predictions, axis=1)
    print("\nFinal Evaluation:")
    print(classification_report(y_test, y_pred, target_names=le.classes_))

    model.save_pretrained(MODEL_OUTPUT)
    tokenizer.save_pretrained(MODEL_OUTPUT)
    print(f"\nModel saved to: {MODEL_OUTPUT}")
    print("Now run: python -m uvicorn api:app --host 0.0.0.0 --port 8000 --reload")

# ─── MAIN ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if not os.path.exists(KAGGLE_CSV):
        print(f"ERROR: {KAGGLE_CSV} not found!")
        print("Download train.csv from: kaggle.com/competitions/nlp-getting-started/data")
        exit(1)

    if not os.path.exists(LOCAL_CSV):
        print(f"WARNING: {LOCAL_CSV} not found. Training on Kaggle data only.")
        combined = load_kaggle_data(KAGGLE_CSV)
    else:
        kaggle_df = load_kaggle_data(KAGGLE_CSV)
        local_df  = load_local_data(LOCAL_CSV)
        combined  = combine_datasets(kaggle_df, local_df)

    train(combined)