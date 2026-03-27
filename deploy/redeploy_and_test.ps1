# Syzygy Rosetta Sandbox — Redeploy & Smoke Test (Cloud Run)
#
# What it does:
# 1) Re-deploy the sandbox to Cloud Run (calls deploy-gcp.ps1)
# 2) Poll the deployed service until it responds to GET /health
# 3) Fetch GET /api/scenarios to validate templates+API routes
# 4) Optionally run local dependency checks (sandbox/test_connections.py)
#
# Usage (PowerShell):
#   $env:GCP_PROJECT_ID="your-project-id"
#   $env:GCP_REGION="us-central1"
#   .\deploy\redeploy_and_test.ps1
#

[CmdletBinding()]
param(
    [string]$ProjectId = $(if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "your-project-id" }),
    [string]$Region = $(if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }),
    [string]$ServiceName = "rosetta-sandbox",
    [int]$HealthPollIntervalSeconds = 5,
    [int]$HealthPollMaxAttempts = 30,
    [switch]$RunLocalConnectionTest = $true
)

$ErrorActionPreference = "Stop"

function Invoke-GetJson {
    param(
        [Parameter(Mandatory=$true)][string]$Url
    )
    return Invoke-RestMethod -Method GET -Uri $Url -ContentType "application/json"
}

Write-Host "========================================"
Write-Host " Syzygy Rosetta Sandbox — Redeploy & Test"
Write-Host "========================================"
Write-Host ""
Write-Host "Project:    $ProjectId"
Write-Host "Region:     $Region"
Write-Host "Service:    $ServiceName"
Write-Host ""

# Ensure deploy-gcp.ps1 can pick up env vars
$env:GCP_PROJECT_ID = $ProjectId
$env:GCP_REGION = $Region

Write-Host "[1/4] Redeploying to Cloud Run..."
& "$PSScriptRoot\deploy-gcp.ps1"

Write-Host ""
Write-Host "[2/4] Getting deployed service URL..."
$serviceUrl = gcloud run services describe $ServiceName --region $Region --format="value(status.url)"
Write-Host "Service URL: $serviceUrl"

Write-Host ""
Write-Host "[3/4] Polling GET $serviceUrl/health ..."
$healthUrl = "$serviceUrl/health"
$healthOk = $false
$attempt = 0

while (-not $healthOk -and $attempt -lt $HealthPollMaxAttempts) {
    $attempt++
    try {
        $resp = Invoke-RestMethod -Method GET -Uri $healthUrl -TimeoutSec 10
        if ($resp.status -eq "healthy") {
            $healthOk = $true
            Write-Host "[OK] Health check passed (attempt $attempt)."
            Write-Host "      environment: $($resp.environment)"
            Write-Host "      llm_provider: $($resp.llm_provider)"
            Write-Host "      gemini_model: $($resp.gemini_model)"
        } else {
            Write-Host "[WARN] Unexpected health response (attempt $attempt): $($resp | ConvertTo-Json -Depth 5)"
        }
    } catch {
        Write-Host "[WAIT] attempt $attempt failed: $($_.Exception.Message)"
    }

    if (-not $healthOk) {
        Start-Sleep -Seconds $HealthPollIntervalSeconds
    }
}

if (-not $healthOk) {
    throw "Health check failed after $HealthPollMaxAttempts attempts: $healthUrl"
}

Write-Host ""
Write-Host "[4/4] Smoke test GET $serviceUrl/api/scenarios ..."
$scenarios = Invoke-GetJson -Url "$serviceUrl/api/scenarios"
Write-Host "Scenarios returned: $($scenarios.total)"

if ($RunLocalConnectionTest) {
    Write-Host ""
    Write-Host "[Optional] Running local dependency test: sandbox/test_connections.py"
    & python "$PSScriptRoot\..\sandbox\test_connections.py"
}

Write-Host ""
Write-Host "========================================"
Write-Host " Redeploy & Smoke Test complete."
Write-Host "========================================"

