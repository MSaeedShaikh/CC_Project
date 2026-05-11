# Deletes all GCP resources for this project.
# WARNING: This is irreversible. All data will be lost.
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

$confirm = Read-Host "This will DELETE all resources and data. Type 'yes' to confirm"
if ($confirm -ne 'yes') {
    Write-Host "Aborted."
    exit 1
}

Write-Host "Deleting load balancer..."
gcloud compute forwarding-rules delete url-shortener-rule --project=$env:GCP_PROJECT_ID --global --quiet
gcloud compute target-http-proxies delete url-shortener-proxy --project=$env:GCP_PROJECT_ID --quiet
gcloud compute url-maps delete url-shortener-map --project=$env:GCP_PROJECT_ID --quiet
gcloud compute backend-services delete url-shortener-backend --project=$env:GCP_PROJECT_ID --global --quiet
gcloud compute health-checks delete url-shortener-health --project=$env:GCP_PROJECT_ID --quiet

Write-Host "Deleting instance group + template..."
gcloud compute instance-groups managed delete url-shortener-mig --project=$env:GCP_PROJECT_ID --zone=$env:GCP_ZONE --quiet
gcloud compute instance-templates delete url-shortener-template --project=$env:GCP_PROJECT_ID --quiet

Write-Host "Deleting Cloud SQL..."
gcloud sql instances delete url-shortener-db --project=$env:GCP_PROJECT_ID --quiet

Write-Host "Deleting Artifact Registry..."
gcloud artifacts repositories delete url-shortener --project=$env:GCP_PROJECT_ID --location=$env:GCP_REGION --quiet

Write-Host "Done. All resources deleted."
