# Syzygy Rosetta Sandbox - GCP Deployment Script (PowerShell)
# Deploys the sandbox to Google Cloud Run

$ErrorActionPreference = "Stop"

# Configuration
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "your-project-id" }
$REGION = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }
$SERVICE_NAME = "rosetta-sandbox"
$IMAGE_NAME = "gcr.io/$PROJECT_ID/$SERVICE_NAME"
$GEMINI_MODEL = if ($env:GEMINI_MODEL) { $env:GEMINI_MODEL } else { "gemma-3-27b-it" }
$ROSETTA_URL = if ($env:ROSETTA_URL) { $env:ROSETTA_URL.Trim() } else { "" }

Write-Host "========================================"
Write-Host "  Syzygy Rosetta Sandbox - GCP Deploy"
Write-Host "========================================"
Write-Host ""
Write-Host "Project: $PROJECT_ID"
Write-Host "Region: $REGION"
Write-Host "Service: $SERVICE_NAME"
Write-Host "Gemini model: $GEMINI_MODEL"
if ($ROSETTA_URL) {
    Write-Host "Rosetta URL: $ROSETTA_URL"
} else {
    Write-Host "Rosetta URL: [NOT SET - app default will be used]"
}
Write-Host ""

if ($PROJECT_ID -eq "your-project-id") {
    Write-Host "[ERROR] GCP_PROJECT_ID is not set. Please set it before deployment."
    exit 1
}

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
gcloud services enable secretmanager.googleapis.com

# Build and push container image
Write-Host "[*] Building container image..."
gcloud builds submit --tag $IMAGE_NAME .

# Deploy to Cloud Run
Write-Host "[*] Deploying to Cloud Run..."
$deployEnvVars = "ENVIRONMENT=production,GEMINI_MODEL=$GEMINI_MODEL"
if ($ROSETTA_URL) {
    $deployEnvVars = "$deployEnvVars,ROSETTA_URL=$ROSETTA_URL"
}

gcloud run deploy $SERVICE_NAME `
    --image $IMAGE_NAME `
    --platform managed `
    --region $REGION `
    --allow-unauthenticated `
    --memory 1Gi `
    --cpu 1 `
    --timeout 300 `
    --set-env-vars $deployEnvVars `
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
Write-Host "To run simulator endpoint:"
Write-Host "  Invoke-WebRequest $SERVICE_URL/run"
Write-Host ""
Write-Host "To view logs:"
Write-Host "  gcloud run logs read $SERVICE_NAME --region $REGION"
Write-Host ""
