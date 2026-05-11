# Creates HTTP load balancer pointing to the MIG
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

Write-Host "Creating health check..."
gcloud compute health-checks create http url-shortener-health `
    --project=$env:GCP_PROJECT_ID `
    --port=8080 `
    --request-path=/health

Write-Host "Creating backend service..."
gcloud compute backend-services create url-shortener-backend `
    --project=$env:GCP_PROJECT_ID `
    --protocol=HTTP `
    --port-name=http `
    --health-checks=url-shortener-health `
    --global

Write-Host "Attaching MIG to backend..."
gcloud compute backend-services add-backend url-shortener-backend `
    --project=$env:GCP_PROJECT_ID `
    --instance-group=url-shortener-mig `
    --instance-group-zone=$env:GCP_ZONE `
    --global

Write-Host "Setting named port on MIG..."
gcloud compute instance-groups managed set-named-ports url-shortener-mig `
    --project=$env:GCP_PROJECT_ID `
    --zone=$env:GCP_ZONE `
    --named-ports=http:8080

Write-Host "Creating URL map..."
gcloud compute url-maps create url-shortener-map `
    --project=$env:GCP_PROJECT_ID `
    --default-service=url-shortener-backend

Write-Host "Creating HTTP proxy..."
gcloud compute target-http-proxies create url-shortener-proxy `
    --project=$env:GCP_PROJECT_ID `
    --url-map=url-shortener-map

Write-Host "Creating forwarding rule..."
gcloud compute forwarding-rules create url-shortener-rule `
    --project=$env:GCP_PROJECT_ID `
    --global `
    --target-http-proxy=url-shortener-proxy `
    --ports=80

Write-Host "Load balancer ready. Get IP:"
Write-Host "gcloud compute forwarding-rules describe url-shortener-rule --global --format='get(IPAddress)'"
