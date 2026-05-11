# Creates instance template + managed instance group
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

$IMAGE    = "$env:GCP_REGION-docker.pkg.dev/$env:GCP_PROJECT_ID/url-shortener/app:latest"
# DATABASE_URL must be set explicitly in .env as TCP URL: postgresql://user:pass@CLOUD_SQL_IP/dbname
$CONT_ENV = "DATABASE_URL=$env:DATABASE_URL,SECRET_KEY=$env:SECRET_KEY,BASE_URL=$env:BASE_URL,FLASK_ENV=production"

Write-Host "Creating instance template..."
gcloud compute instance-templates create-with-container url-shortener-template `
    --project=$env:GCP_PROJECT_ID `
    --machine-type=e2-micro `
    --region=$env:GCP_REGION `
    --container-image=$IMAGE `
    --container-env=$CONT_ENV `
    --tags=http-server `
    --scopes=cloud-platform

Write-Host "Creating managed instance group..."
gcloud compute instance-groups managed create url-shortener-mig `
    --project=$env:GCP_PROJECT_ID `
    --base-instance-name=url-shortener `
    --template=url-shortener-template `
    --size=2 `
    --zone=$env:GCP_ZONE

Write-Host "Setting autoscaling..."
gcloud compute instance-groups managed set-autoscaling url-shortener-mig `
    --project=$env:GCP_PROJECT_ID `
    --zone=$env:GCP_ZONE `
    --min-num-replicas=2 `
    --max-num-replicas=5 `
    --target-cpu-utilization=0.6

Write-Host "Creating firewall rule..."
cmd /c "gcloud compute firewall-rules create allow-http-8080 --project=$env:GCP_PROJECT_ID --allow=tcp:8080 --target-tags=http-server --quiet 2>nul"
Write-Host "Firewall rule done (or already existed)."

Write-Host "MIG created: url-shortener-mig"
