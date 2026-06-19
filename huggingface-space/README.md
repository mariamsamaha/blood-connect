---
title: BloodConnect AI Service
emoji: 🩸
colorFrom: red
colorTo: gray
sdk: docker
app_port: 7860
pinned: false
---

# BloodConnect AI Service

CBC report eligibility screening via ViT + OCR.

This Space is a deployment mirror of the `ai-service` module from the
[BloodConnect](https://github.com/anomalyco/blood-connect) graduation project.
It runs the same FastAPI application as the Render deployment, built from the
same source files under `ai-service/` — this directory only contains the
Dockerfile and metadata needed by Hugging Face Spaces.

## Build context note

Hugging Face Spaces with the Docker SDK expects the `Dockerfile` at the root
of the Space's git repository and uses that root as the Docker build context.
The `COPY ai-service/...` paths in the Dockerfile assume the `ai-service/`
directory is present at the same level as the Dockerfile.

**How to deploy:**

1. Create a Space at https://huggingface.co/new-space with **SDK = Docker**.
2. Clone the Space locally.
3. Copy `huggingface-space/Dockerfile` to the Space root (or rename and copy).
4. Copy (or symlink) the `ai-service/` directory from the main repo into the
   Space root.
5. Commit and push.

An alternative is to push the whole monorepo as the Space's repository — the
Dockerfile at `huggingface-space/Dockerfile` would then need to be copied to
the root first (HF Spaces reads `Dockerfile`, not `huggingface-space/Dockerfile`).
The GitHub Actions workflow in `.github/workflows/hf-deploy.yml` automates this
by cloning the Space repo and placing the required files there.

## Environment variables

Configure these as **Space secrets** (Settings → Repository Secrets):

| Variable               | Required | Description                                |
|------------------------|----------|--------------------------------------------|
| `AI_ASSISTANT_API_KEY` | No       | OpenRouter API key for the /assistant/chat endpoint |
| `TESTING`              | No       | Set to `true` to skip model loading (rule-engine-only mode) |
| `PORT`                 | No       | Port the container listens on (default 7860, overridden by Dockerfile) |

## Health check

Once deployed, verify at:

```
https://huggingface.co/spaces/<your-username>/<space-name>/health
```
