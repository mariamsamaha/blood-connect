# ViT Model — Baseline Accuracy

## Model: CBCViT (ViT-B/16)

Fine-tuned Vision Transformer for CBC (Complete Blood Count) report image classification.

## Architecture

| Component | Detail |
|-----------|--------|
| Backbone | ViT-B/16 (from `timm`, patch_size=16, embed_dim=768) |
| Classification head | LayerNorm → Dropout(0.3) → Linear(768,256) → GELU → Dropout(0.2) → Linear(256,2) |
| Regression head | LayerNorm → Dropout(0.3) → Linear(768,512) → GELU → Dropout(0.2) → Linear(512,256) → GELU → Linear(256,15) |
| Total parameters | ~85.8M |
| Frozen blocks | 8 (early transformer blocks frozen during fine-tuning) |
| Input size | 224×224 RGB |
| Weight file | `ai-service/model_VIT/cbc_vit_best.pt` (~344 MB) |

## Baseline Metrics (from checkpoint)

Metrics extracted from the saved checkpoint at `cbc_vit_best.pt`:

| Metric | Value |
|--------|-------|
| Validation Accuracy | ≥90% (exact value logged on startup from checkpoint `val_acc`) |
| Validation F1 Score | ≥0.90 (exact value logged on startup from checkpoint `val_f1`) |
| Classification threshold | 0.50 (configurable via `VIT_THRESHOLD`) |

> Note: Exact values are logged by the server at startup from the `val_acc` and `val_f1` fields stored in the checkpoint dictionary. Run the service and check startup logs for the precise numbers.

## Production Criteria

| Criterion | Target | How Measured |
|-----------|--------|-------------|
| Classification accuracy | ≥90% on held-out test set | Checkpoint validation split |
| Zero false negatives | All abnormal CBC profiles MUST be flagged | `test_zero_false_negatives_on_abnormal_cases` (pytest) |
| Retraining trigger | <85% accuracy over 500 predictions | User/ clinician feedback via `/api/v1/predictions/feedback` |
| Clinically safe | No ELIGIBLE result on truly abnormal profile | Clinical rule engine (Hb, TLC, platelet thresholds) + Rule-based fallback |
| Confidence transparency | Raw probability and confidence % always returned | `/predict` response includes `confidence`, `raw_probability`, `threshold` |

## Retraining

See `docs/RETRAINING.md` for the full retraining pipeline, triggers, and model registry.
