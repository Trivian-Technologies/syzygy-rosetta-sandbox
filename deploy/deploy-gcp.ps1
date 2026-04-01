# Syzygy Rosetta Sandbox - GCP Deployment Script (PowerShell)
# Deploys the sandbox to Google Cloud Run
#
# Loads deploy/gcp.env first (same folder as this script) unless variables are already set in the shell.
# Keys: GCP_PROJECT_ID, GCP_REGION, SERVICE_NAME, GEMINI_MODEL, ROSETTA_URL
# Optional: GEMINI_API_KEY (not sent to Cloud Run by this script; use Secret Manager bootstrap in docs)

$ErrorActionPreference = "Stop"

function Import-GcpDeployEnvFile {
    param([string]$Path)
    $allowed = @(
        "GCP_PROJECT_ID", "GCP_REGION", "SERVICE_NAME",
        "GEMINI_MODEL", "ROSETTA_URL", "GEMINI_API_KEY"
    )
    if (-not (Test-Path $Path)) { return $false }
    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { return }
        $key = $line.Substring(0, $eq).Trim()
        if ($key -notin $allowed) { return }
        $val = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
        $current = [Environment]::GetEnvironmentVariable($key, "Process")
        if (-not [string]::IsNullOrWhiteSpace($current)) { return }
        [Environment]::SetEnvironmentVariable($key, $val, "Process")
    }
    return $true
}

$GcpEnvPath = Join-Path $PSScriptRoot "gcp.env"
$LoadedGcpEnv = Import-GcpDeployEnvFile -Path $GcpEnvPath
if (-not $LoadedGcpEnv) {
    Write-Host "[WARN] deploy/gcp.env not found. Copy deploy/gcp.env.example to deploy/gcp.env and fill values."
    Write-Host "       Or set GCP_PROJECT_ID (and optional GCP_REGION, etc.) in this shell before running."
    Write-Host ""
}

# Configuration
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "your-project-id" }
$REGION = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }
$SERVICE_NAME = if ($env:SERVICE_NAME) { $env:SERVICE_NAME.Trim() } else { "rosetta-sandbox" }
$IMAGE_NAME = "gcr.io/$PROJECT_ID/$SERVICE_NAME"
$GEMINI_MODEL = if ($env:GEMINI_MODEL) { $env:GEMINI_MODEL } else { "mock" }
$ROSETTA_URL = if ($env:ROSETTA_URL) { $env:ROSETTA_URL.Trim() } else { "" }

Write-Host "========================================"
Write-Host "  Syzygy Rosetta Sandbox - GCP Deploy"
Write-Host "========================================"
Write-Host ""
Write-Host "Config file: $GcpEnvPath ($(if ($LoadedGcpEnv) { 'loaded' } else { 'missing' }))"
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

if ($PROJECT_ID -eq "your-project-id" -or $PROJECT_ID -eq "your-gcp-project-id") {
    Write-Host "[ERROR] Set GCP_PROJECT_ID in deploy/gcp.env (or export it in this shell). Current value is still a placeholder."
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

# Build and push container image (run from repo root)
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    Write-Host "[*] Building container image..."
    gcloud builds submit --tag $IMAGE_NAME .
} finally {
    Pop-Location
}

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
