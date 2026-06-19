# Cost Analysis

Estimated monthly cost to run BloodConnect in production.

## Assumptions
- 10,000 active users
- 500 blood requests/month
- 5,000 push notifications/month
- 1,000 AI predictions/month
- US East (N. Virginia) region

## Component Breakdown

| Component | Service | Estimated Monthly Cost | Notes |
|-----------|---------|----------------------|-------|
| **Mobile App** | Flutter (client-side) | $0 | Free (app stores take 15-30% cut) |
| **API Backend** | Render / Fly.io (1-2 instances) | $15-30 | Node.js, 1GB RAM, 2 vCPUs |
| **Notification Backend** | Same instance or micro instance | $5-10 | Node.js, low traffic |
| **AI Service** | Render / Fly.io (GPU instance) | $50-150 | FastAPI + Vision Transformer, GPU recommended |
| **Database** | Supabase Pro (8GB, 10GB disk) | $25 | PostgreSQL + PostGIS, includes auth |
| **Authentication** | Firebase Auth (Blaze) | $0-10 | 10K MAU free tier, beyond is ~$0.01/MAU |
| **Push Notifications** | Firebase Cloud Messaging | $0 | Free tier |
| **AI Assistant Chat** | OpenRouter (Gemini 2.5 Flash) | $5-20 | ~500 conversations/month, ~$0.15/1M input tokens |
| **File Storage** | Supabase Storage (1GB) | $0-5 | For blood report images |
| **CI/CD** | GitHub Actions | $0 | 2,000 min/month free |
| **Monitoring** | Self-hosted or Grafana Cloud free tier | $0-10 | |
| **Domain + TLS** | Namecheap + Let's Encrypt | $15/year | ~$1.25/month |

## Most Expensive Components

1. **AI Service GPU instance** ($50-150/mo) — largest cost driver. Can be reduced by using CPU-only inference with ONNX runtime or quantized models.
2. **API Backend + Database** ($40-55/mo combined) — scales with user base.
3. **AI Assistant (OpenRouter)** ($5-20/mo) — variable based on usage.

## Optimization Opportunities

| Optimization | Savings | Complexity |
|-------------|---------|------------|
| Use CPU-only AI inference (ONNX) | $30-100/mo | Medium |
| Cache AI results for repeat reports | $5-10/mo | Low |
| Batch OpenRouter requests | $2-5/mo | Low |
| Use Supabase free tier for early stage | $25/mo | None |
| Single instance (merge API + notification) | $5-10/mo | Low |

## Total Estimated Range

**Low usage (100 users, 50 requests):** ~$30-50/month  
**Medium usage (1,000 users, 200 requests):** ~$50-100/month  
**High usage (10,000 users, 500 requests):** ~$100-200/month
