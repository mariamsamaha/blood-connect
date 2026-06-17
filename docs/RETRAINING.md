# AI retraining strategy

## ViT model (CBC image classifier)

### When to retrain

| Trigger | Action | Priority |
|---------|--------|----------|
| Feedback accuracy drops below 85% over 500 predictions | Flag for retraining | High |
| 5,000+ new labeled samples collected | Start retraining pipeline | Medium |
| New CBC report format discovered (new laboratory) | Add to training set | Medium |
| Clinical guidelines change (reference ranges updated) | Update labels, retrain | High |

### Retraining pipeline

1. **Data collection**: Store OCR-extracted CBC values + ViT prediction + user feedback in `prediction_feedback` table (Supabase)
2. **Export**: `ai-service/scripts/export_training_data.py` → CSV with columns: image_hash, original_prediction, user_feedback, ocr_text, timestamp
3. **Label review**: Data scientist reviews ambiguous cases (where user feedback differs from AI prediction)
4. **Synthetic augmentation**: Generate synthetic CBC reports from real OCR+feedback pairs
5. **Fine-tune**: Resume from `model_VIT/pytorch_model.bin`, train for 3-5 epochs
6. **Evaluate**: Run against held-out test set — must achieve ≥90% accuracy to proceed
7. **Deploy**: Upload new `pytorch_model.bin` to model registry → CD pipeline deploys as `ai-service:latest`

### Model registry

- Trained models stored in a cloud bucket (Supabase storage or S3-compatible)
- Naming: `cbcvit_{epochs}e_{accuracy:.2f}acc_{date}.bin`
- Current prod model symlink: `pytorch_model.bin`
- Each model tagged with Git SHA of training script used

## OpenRouter prompt A/B testing

### Variant registration

Prompt variants are defined in `ai-service/prompts/` as YAML files:

```yaml
# prompts/v1.yaml
id: v1
description: Baseline medical assistant
system_prompt: |
  You are a medical information assistant for a blood donation center...
temperature: 0.3
max_tokens: 800
```

### Traffic splitting

| Variant | Weight | When |
|---------|--------|------|
| `v1` (current) | 70% | Default |
| `v2` (shorter) | 30% | Experimental: test if brevity improves user satisfaction |

### Metrics tracked per variant

- Average response length (tokens)
- User satisfaction (feedback thumbs up/down)
- Response time (latency)
- Rephrase rate (user asks "can you explain differently")

### Promoting a variant

1. Run for ≥500 conversations per variant
2. Compare satisfaction rate — must be statistically significant (p < 0.05)
3. Winner becomes default `v1`
4. Looser variant retired or modified

## Data retention

| Data type | Retention | Reason |
|-----------|-----------|--------|
| Prediction logs | 90 days | Monitoring & debugging |
| User feedback | 365 days | Retraining data |
| Raw images | 7 days | Privacy — delete after OCR |
| Chat conversations | 30 days | Quality analysis |
| Training dataset | Indefinite | Versioned via Git LFS or S3 |

## Future Improvements

### Async Job Queue for ViT Inference

**Current state:** AI predictions are synchronous — the mobile app waits with a loading spinner for the ViT result (~1-15s).

**Recommended change:** Add an async job queue pattern:
- Flutter submits prediction request → receives `job_id` immediately
- AI service processes inference in background (Celery + Redis as broker)
- Flutter polls `GET /predictions/{job_id}/status` every 2s
- Result fetched when ready

**Benefits:** Eliminates cold-start UX problem (~15s first request), allows prioritizing jobs, enables retry without blocking user.
**Complexity:** Medium — requires Celery, Redis (already in stack), additional FastAPI endpoint, Flutter polling logic.
**Cost:** Negligible (Redis already provisioned).

### Async Polling for Prediction Results

**Current state:** Flutter sends image → blocks on HTTP response → displays result.

**Recommended change:** 
1. `POST /predict` returns `{"job_id": "abc123", "status": "processing"}` immediately
2. Flutter polls `GET /predict/jobs/abc123` every 2-3s
3. AI worker processes on background thread (or separate Celery worker)
4. Flutter displays result when `status == "completed"`

**Benefits:** No request timeouts for slow CPU inference, graceful handling of GPU contention, measurable queue depth.
**Complexity:** Low-Medium — requires new status endpoint, Flutter polling widget.
**Note:** This is a subset of the full async job queue approach above.

### Auto-Correction of Low-Confidence Outputs (Completed)

**Status:** ✅ Implemented in v3.1.0

Predictions with confidence below `VIT_THRESHOLD` (50%) are automatically flagged as `NEEDS_REVIEW` with bilingual explanations. The result includes `"prediction_flagged": true` so the mobile UI can show a warning banner. See `ai-service/main.py` for implementation.
