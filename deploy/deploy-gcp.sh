#!/bin/bash
# Syzygy Rosetta Sandbox - GCP Deployment Script
# Deploys the sandbox to Google Cloud Run
#
# Loads deploy/gcp.env (same directory as this script) unless already exported in the shell.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GCP_ENV="${SCRIPT_DIR}/gcp.env"

if [[ -f "${GCP_ENV}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${GCP_ENV}"
  set +a
  echo "[*] Loaded ${GCP_ENV}"
else
  echo "[WARN] deploy/gcp.env not found. Copy deploy/gcp.env.example to deploy/gcp.env and fill values."
  echo "       Or export GCP_PROJECT_ID etc. before running."
fi

PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-rosetta-sandbox}"
GEMINI_MODEL="${GEMINI_MODEL:-mock}"
ROSETTA_URL="${ROSETTA_URL:-}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "========================================"
echo "  Syzygy Rosetta Sandbox - GCP Deploy"
echo "========================================"
echo ""
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo "Gemini model: ${GEMINI_MODEL}"
if [[ -n "${ROSETTA_URL}" ]]; then
  echo "Rosetta URL: ${ROSETTA_URL}"
else
  echo "Rosetta URL: [NOT SET - app default will be used]"
fi
echo ""

if [[ "${PROJECT_ID}" == "your-project-id" || "${PROJECT_ID}" == "your-gcp-project-id" ]]; then
  echo "[ERROR] Set GCP_PROJECT_ID in deploy/gcp.env (or export it). Still a placeholder."
  exit 1
fi

if ! command -v gcloud &> /dev/null; then
  echo "[ERROR] gcloud CLI not found."
  echo "  https://cloud.google.com/sdk/docs/install"
  exit 1
fi

cd "${REPO_ROOT}"

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n 1 | grep -q .; then
  echo "[*] Please login to Google Cloud..."
  gcloud auth login
fi

echo "[*] Setting project to ${PROJECT_ID}..."
gcloud config set project "${PROJECT_ID}"

echo "[*] Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com

echo "[*] Building container image..."
gcloud builds submit --tag "${IMAGE_NAME}" .

DEPLOY_ENV="ENVIRONMENT=production,GEMINI_MODEL=${GEMINI_MODEL}"
if [[ -n "${ROSETTA_URL}" ]]; then
  DEPLOY_ENV="${DEPLOY_ENV},ROSETTA_URL=${ROSETTA_URL}"
fi

echo "[*] Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE_NAME}" \
  --platform managed \
  --region "${REGION}" \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --timeout 300 \
  --set-env-vars "${DEPLOY_ENV}" \
  --set-secrets "GEMINI_API_KEY=gemini-api-key:latest"

SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(status.url)")

echo ""
echo "========================================"
echo "  Deployment Complete!"
echo "========================================"
echo ""
echo "Service URL: ${SERVICE_URL}"
echo ""
