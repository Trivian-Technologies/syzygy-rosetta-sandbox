# Syzygy Rosetta Sandbox — GCP Deployment Script (PowerShell)
# Deploys the sandbox to Google Cloud Run

$ErrorActionPreference = "Stop"

# Configuration
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "your-project-id" }
$REGION = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }
$SERVICE_NAME = "rosetta-sandbox"
$IMAGE_NAME = "gcr.io/$PROJECT_ID/$SERVICE_NAME"

Write-Host "========================================"
Write-Host "  Syzygy Rosetta Sandbox — GCP Deploy"
Write-Host "========================================"
Write-Host ""
Write-Host "Project: $PROJECT_ID"
Write-Host "Region: $REGION"
Write-Host "Service: $SERVICE_NAME"
Write-Host ""

# Check if gcloud is installed
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] gcloud CLI not found. Please install Google Cloud SDK."
    Write-Host "  https://cloud.google.com/sdk/docs/install"
    exit 1
}

# Set project
Write-Host "[*] Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
Write-Host "[*] Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Build and push container image
Write-Host "[*] Building container image..."
gcloud builds submit --tag $IMAGE_NAME .

# Deploy to Cloud Run
Write-Host "[*] Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME `
    --image $IMAGE_NAME `
    --platform managed `
    --region $REGION `
    --allow-unauthenticated `
    --memory 1Gi `
    --cpu 1 `
    --timeout 300 `
    --set-env-vars "ENVIRONMENT=production" `
    --set-env-vars "GEMINI_MODEL=gemma-3-27b-it" `
    --set-secrets "GEMINI_API_KEY=gemini-api-key:latest"

# Get service URL
$SERVICE_URL = gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)"

Write-Host ""
Write-Host "========================================"
Write-Host "  Deployment Complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Service URL: $SERVICE_URL"
Write-Host ""
Write-Host "To run the simulator:"
Write-Host "  Invoke-WebRequest $SERVICE_URL/run"
Write-Host ""
Write-Host "To view logs:"
Write-Host "  gcloud run logs read $SERVICE_NAME --region $REGION"
Write-Host ""
