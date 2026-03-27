# Syzygy Rosetta Sandbox — GCP Deployment Guide

## Overview

This guide covers deploying the Rosetta Sandbox to Google Cloud Platform using Cloud Run.

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Gemini API Key** from [Google AI Studio](https://aistudio.google.com/app/apikey)

## Quick Start

### 1. Set Environment Variables

```powershell
# Windows PowerShell
$env:GCP_PROJECT_ID = "your-project-id"
$env:GCP_REGION = "us-central1"
```

```bash
# Linux/macOS
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
```

### 2. Create Secret for API Key

Store your Gemini API key in Google Secret Manager:

```bash
# Create the secret
echo -n "your-gemini-api-key" | gcloud secrets create gemini-api-key --data-file=-

# Grant Cloud Run access
gcloud secrets add-iam-policy-binding gemini-api-key \
    --member="serviceAccount:${GCP_PROJECT_ID}@appspot.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### 3. Deploy

**Windows:**

```powershell
.\deploy\deploy-gcp.ps1
```

**Linux/macOS:**

```bash
./deploy/deploy-gcp.sh
```

## API Endpoints

Once deployed, your service will have these endpoints:


| Endpoint           | Method | Description                   |
| ------------------ | ------ | ----------------------------- |
| `/health`          | GET    | Health check                  |
| `/scenarios`       | GET    | List available test scenarios |
| `/run`             | POST   | Run full simulation           |
| `/evaluate-single` | POST   | Evaluate single input         |
| `/chat`            | POST   | Multi-turn chat               |


### Governance flow (Rosetta pre-guard)

- **WITHOUT Rosetta**: User → Backend → **AI Model** → User
- **WITH Rosetta**: User → Backend → **Rosetta (evaluate user input)** → (allow / rewrite) **AI Model** → User
  - **allow**: the original user input is sent to the model
  - **rewrite**: Rosetta's `rewrite` is used as the *effective prompt* sent to the model
  - **escalate**: the request is **blocked** and the model is **not called**

### Example: Run Simulation

```bash
curl -X POST https://your-service-url.run.app/run \
  -H "Content-Type: application/json" \
  -d '{"governance": true, "mock": false}'
```

### Example: Evaluate Single Input

```bash
curl -X POST https://your-service-url.run.app/evaluate-single \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "How do I invest my savings?",
    "system_prompt": "You are a financial advisor.",
    "industry": "finance",
    "governance": true
  }'
```

Notes:

- When `governance=true`, the response includes `governance` (Rosetta result) and `effective_prompt`.
- If Rosetta returns `decision=escalate`, the response will indicate it was blocked (and **LLM is not called**).

## Configuration

### Environment Variables


| Variable         | Default                 | Description                         |
| ---------------- | ----------------------- | ----------------------------------- |
| `GEMINI_API_KEY` | -                       | Google Gemini API key (required)    |
| `GEMINI_MODEL`   | `gemma-3-27b-it`        | Model to use (default: Gemma 3 27B) |
| `ROSETTA_URL`    | `http://localhost:8000` | Rosetta governance URL              |
| `ENVIRONMENT`    | `development`           | Environment name                    |
| `PORT`           | `8080`                  | Server port                         |


### Model Options

- `gemma-3-27b-it` - Gemma 3 27B (default)
- `gemini-2.0-flash`, `gemini-2.5-flash` - Gemini family (set `GEMINI_MODEL` in `.env`)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Cloud Run                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  Rosetta Sandbox                            │ │
│  │                                                             │ │
│  │   ┌──────────┐    ┌──────────────────┐    ┌──────────┐    │ │
│  │   │  Flask   │───▶│     Rosetta      │───▶│   LLM    │    │ │
│  │   │  Server  │    │   Governance     │    │  Client  │    │ │
│  │   └──────────┘    └──────────────────┘    └──────────┘    │ │
│  │        │                   │               │               │ │
│  └────────┼───────────────┼───────────────────┼───────────────┘ │
│           │               │                   │                  │
└───────────┼───────────────┼───────────────────┼──────────────────┘
            │               │                   │
            ▼               ▼                   ▼
      ┌──────────┐   ┌──────────────┐   ┌──────────────┐
      │ HTTP     │   │ Gemini/Gemma │   │ Rosetta API  │
      │ Requests │   │ API          │   │ (separate)   │
      └──────────┘   └──────────────┘   └──────────────┘
```

## Deploying Rosetta Governance

The Rosetta governance service needs to be deployed separately. Options:

### Option 1: Same Project (Recommended)

Deploy Rosetta to Cloud Run in the same project:

```bash
# In the rosetta repository
gcloud run deploy rosetta \
    --source . \
    --region us-central1 \
    --allow-unauthenticated
```

Then set `ROSETTA_URL` to the Rosetta Cloud Run URL.

### Option 2: Internal Traffic Only

For production, use VPC connector for internal-only traffic:

```bash
gcloud run deploy rosetta-sandbox \
    --vpc-connector your-connector \
    --set-env-vars "ROSETTA_URL=https://rosetta-internal.run.internal"
```

## Monitoring

### View Logs

```bash
gcloud run logs read rosetta-sandbox --region us-central1
```

### Tail Logs

```bash
gcloud run logs tail rosetta-sandbox --region us-central1
```

## Cost Estimation


| Component      | Estimated Cost             |
| -------------- | -------------------------- |
| Cloud Run      | ~$0-10/month (pay per use) |
| Gemini API     | varies by model + usage    |
| Secret Manager | ~$0.06/secret/month        |


## Troubleshooting

### "Rosetta not connected"

Ensure the Rosetta service is deployed and `ROSETTA_URL` is correctly set.

If you call endpoints with `governance=true` while Rosetta is unreachable, the Sandbox will return a non-2xx error (and will not call the LLM in the governance path).

### "No API key provided"

Create the secret in Secret Manager and ensure Cloud Run has access.

### Timeout Errors

Increase the timeout in Cloud Run settings:

```bash
gcloud run services update rosetta-sandbox --timeout 600
```

