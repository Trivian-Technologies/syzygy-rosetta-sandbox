#!/bin/bash
# Syzygy Rosetta Sandbox — GCP Deployment Script
# Deploys the sandbox to Google Cloud Run

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="rosetta-sandbox"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "========================================"
echo "  Syzygy Rosetta Sandbox — GCP Deploy"
echo "========================================"
echo ""
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "[ERROR] gcloud CLI not found. Please install Google Cloud SDK."
    echo "  https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is logged in
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 > /dev/null 2>&1; then
    echo "[*] Please login to Google Cloud..."
    gcloud auth login
fi

# Set project
echo "[*] Setting project to ${PROJECT_ID}..."
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo "[*] Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Build and push container image
echo "[*] Building container image..."
gcloud builds submit --tag ${IMAGE_NAME} .

# Deploy to Cloud Run
echo "[*] Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --timeout 300 \
    --set-env-vars "ENVIRONMENT=production" \
    --set-env-vars "GEMINI_MODEL=gemma-3-27b-it" \
    --set-secrets "GEMINI_API_KEY=gemini-api-key:latest"

# Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format="value(status.url)")

echo ""
echo "========================================"
echo "  Deployment Complete!"
echo "========================================"
echo ""
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "To run the simulator:"
echo "  curl ${SERVICE_URL}/run"
echo ""
echo "To view logs:"
echo "  gcloud run logs read ${SERVICE_NAME} --region ${REGION}"
echo ""
