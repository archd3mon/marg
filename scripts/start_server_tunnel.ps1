# Marg Transit Planner - Backend & Cloudflare HTTPS Tunnel Launcher
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot "pump\backend"
$pythonExe = Join-Path $backendDir "venv\Scripts\python.exe"
$cloudflaredExe = Join-Path $repoRoot "tools\cloudflared.exe"

if (!(Test-Path $pythonExe)) {
    Write-Error "Virtual environment not found at $pythonExe"
}

if (!(Test-Path $cloudflaredExe)) {
    Write-Host "Downloading cloudflared..." -ForegroundColor Cyan
    curl.exe -L -o $cloudflaredExe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " 🚌 Starting Marg Backend on http://127.0.0.1:8000..." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# Start uvicorn in a separate process or job
$backendJob = Start-Process -FilePath $pythonExe -ArgumentList "-m uvicorn app.main:app --host 127.0.0.1 --port 8000" -WorkingDirectory $backendDir -PassThru

# Wait for backend to become healthy
Write-Host "Waiting for backend engines to load..." -ForegroundColor Yellow
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/v1/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($res.status -in @("ok", "degraded")) {
            $healthy = $true
            break
        }
    } catch {}
    Write-Host "." -NoNewline -ForegroundColor DarkGray
}
Write-Host ""

if (!$healthy) {
    Write-Error "Backend failed to become healthy within 60 seconds."
}

Write-Host "[OK] Marg Backend is UP and HEALTHY!" -ForegroundColor Green
Write-Host "Starting Cloudflare Public HTTPS Tunnel..." -ForegroundColor Cyan
Write-Host "Look for the *.trycloudflare.com URL below:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

try {
    & $cloudflaredExe tunnel --url http://127.0.0.1:8000
} finally {
    Write-Host "Stopping backend process..." -ForegroundColor Red
    if ($backendJob -and !$backendJob.HasExited) {
        Stop-Process -Id $backendJob.Id -Force
    }
}
