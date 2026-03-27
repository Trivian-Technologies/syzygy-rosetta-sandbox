# Syzygy Rosetta Sandbox — Local Docker Rebuild & Restart
#
# Goal:
#   You modify the local project -> rebuild Docker image -> restart container -> visit http://localhost:8080
#
# What it does:
#   1) Stops anything listening on :8080 (best-effort)
#   2) docker build the image (using local Dockerfile)
#   3) docker run it with `--env-file .env`
#   4) Waits a bit and prints the endpoint
#
# Usage:
#   .\deploy\rebuild_local_8080.ps1
#

[CmdletBinding()]
param(
    [int]$Port = 8080,
    [string]$ImageTag = "syzygy-rosetta-sandbox-local:latest",
    [string]$ContainerName = "syzygy-rosetta-sandbox-local",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker not found. Please install Docker Desktop and ensure `docker` is available in PATH."
}

if (-not (Test-Path $EnvFile)) {
    # Allow running without env file, but real Gemini/Rosetta usually needs it.
    Write-Host "[WARN] env file not found: $EnvFile. Starting container without --env-file." -ForegroundColor Yellow
    $useEnv = $false
} else {
    $useEnv = $true
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Local Docker Rebuild & Restart" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Port:          $Port"
Write-Host "Image:         $ImageTag"
Write-Host "Container:     $ContainerName"
Write-Host "Env file:      $EnvFile (use: $useEnv)"
Write-Host ""

# 1) Stop anything listening on the port (best effort)
Write-Host "[1/3] Stopping existing listener on port $Port (if any)..." -ForegroundColor Cyan
try {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        $pids = ($conns | Select-Object -ExpandProperty OwningProcess -Unique)
        foreach ($pid in $pids) {
            if ($pid -and ($pid -ne $PID)) {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {
    Write-Host "[WARN] Failed to stop existing listeners: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2) Build image
Write-Host "[2/3] Rebuilding Docker image..." -ForegroundColor Cyan
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
docker build -t $ImageTag .

# Stop/remove existing container if present
Write-Host ""
Write-Host "[2.5/3] Recreating container..." -ForegroundColor Cyan
docker rm -f $ContainerName 2>$null | Out-Null

# 3) Run
Write-Host "[3/3] Starting container..." -ForegroundColor Cyan
if ($useEnv) {
    docker run -d `
        --name $ContainerName `
        -p "$Port`:8080" `
        --env-file $EnvFile `
        $ImageTag | Out-Null
} else {
    docker run -d `
        --name $ContainerName `
        -p "$Port`:8080" `
        $ImageTag | Out-Null
}

Write-Host ""
Write-Host "Done. Open: http://localhost:$Port" -ForegroundColor Green
Write-Host "Tip: If you changed code and re-run, run this script again to rebuild the image." -ForegroundColor Green

