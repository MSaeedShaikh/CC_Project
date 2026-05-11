# Creates Cloud SQL PostgreSQL instance + database + user
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

$INSTANCE_NAME = "url-shortener-db"

Write-Host "Creating Cloud SQL instance..."
gcloud sql instances create $INSTANCE_NAME `
    --project=$env:GCP_PROJECT_ID `
    --database-version=POSTGRES_15 `
    --region=$env:GCP_REGION `
    --tier=db-f1-micro `
    --authorized-networks=0.0.0.0/0

Write-Host "Creating database..."
gcloud sql databases create $env:DB_NAME `
    --project=$env:GCP_PROJECT_ID `
    --instance=$INSTANCE_NAME

Write-Host "Creating user..."
gcloud sql users create $env:DB_USER `
    --project=$env:GCP_PROJECT_ID `
    --instance=$INSTANCE_NAME `
    --password="$env:DB_PASS"

$SQL_IP = gcloud sql instances describe $INSTANCE_NAME --project=$env:GCP_PROJECT_ID --format="get(ipAddresses[0].ipAddress)"
Write-Host "Cloud SQL ready."
Write-Host "Public IP: $SQL_IP"
Write-Host "Set this in .env: DATABASE_URL=postgresql://$env:DB_USER`:$env:DB_PASS`@$SQL_IP/$env:DB_NAME"
