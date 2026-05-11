# Builds Docker image and pushes to Artifact Registry
$ErrorActionPreference = 'Continue'

# Load .env from project root
$envFile = Join-Path $PSScriptRoot "..\.env"
foreach ($line in [System.IO.File]::ReadAllLines($envFile, [System.Text.Encoding]::UTF8)) {
    $line = $line.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }
    $idx = $line.IndexOf('=')
    if ($idx -lt 0) { continue }
    $key = $line.Substring(0, $idx).Trim()
    $val = $line.Substring($idx + 1).Trim()
    Set-Item "env:$key" $val
}

$IMAGE = "$env:GCP_REGION-docker.pkg.dev/$env:GCP_PROJECT_ID/url-shortener/app"
$GIT_SHA = cmd /c "git rev-parse --short HEAD 2>nul"
if ($LASTEXITCODE -ne 0 -or -not $GIT_SHA) { $GIT_SHA = "no-git" }

gcloud auth configure-docker "$env:GCP_REGION-docker.pkg.dev" --quiet

# Build from project root
$projectRoot = Join-Path $PSScriptRoot ".."
docker build -t "${IMAGE}:latest" -t "${IMAGE}:${GIT_SHA}" $projectRoot
docker push "${IMAGE}:latest"
docker push "${IMAGE}:${GIT_SHA}"

Write-Host "Pushed: ${IMAGE}:latest ($GIT_SHA)"
