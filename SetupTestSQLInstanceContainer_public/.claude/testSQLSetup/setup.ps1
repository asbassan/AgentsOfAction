# =============================================
# YourProject SQL Server Container Setup Script (PowerShell)
# =============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "YourProject SQL Server Docker Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
}

# Check if Docker Compose is available
$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker Compose is not available" -ForegroundColor Red
    Write-Host "Please install Docker Compose or update Docker Desktop"
    exit 1
}

Write-Host "✓ Docker is installed: $(docker --version)" -ForegroundColor Green
Write-Host "✓ Docker Compose is available: $composeVersion" -ForegroundColor Green
Write-Host ""

# Create necessary directories
Write-Host "Creating data directories..."
New-Item -ItemType Directory -Force -Path data | Out-Null
New-Item -ItemType Directory -Force -Path logs | Out-Null
New-Item -ItemType Directory -Force -Path backups | Out-Null
Write-Host "✓ Directories created" -ForegroundColor Green
Write-Host ""

# Check if .env file exists
if (-not (Test-Path .env)) {
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "Please create .env file with required configuration"
    exit 1
}

# Load environment variables
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2]
        Set-Variable -Name $name -Value $value -Scope Script
    }
}

Write-Host "Configuration:"
Write-Host "  - Container Name: $($CONTAINER_NAME ?? 'sqlserver-dev')"
Write-Host "  - SQL Server Port: $($SQLSERVER_PORT ?? '1433')"
Write-Host "  - Data Path: $($DATA_PATH ?? './data')"
Write-Host "  - Backup Path: $($BACKUP_PATH ?? './backups')"
Write-Host ""

# Check if container already exists
$containerExists = docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$($CONTAINER_NAME ?? 'sqlserver-dev')$"

if ($containerExists) {
    Write-Host "WARNING: Container '$($CONTAINER_NAME ?? 'sqlserver-dev')' already exists" -ForegroundColor Yellow
    $response = Read-Host "Do you want to remove it and recreate? (y/N)"

    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Removing existing container..."
        docker compose down -v
        Write-Host "✓ Container removed" -ForegroundColor Green
    }
    else {
        Write-Host "Aborting setup"
        exit 0
    }
}

# Build and start container
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building and starting SQL Server container..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

docker compose build --no-cache

Write-Host ""
Write-Host "Starting container..."
docker compose up -d

Write-Host ""
Write-Host "Waiting for SQL Server to be ready..."
Start-Sleep -Seconds 10

# Wait for health check
$maxRetries = 30
$retryCount = 0

while ($retryCount -lt $maxRetries) {
    $healthStatus = docker inspect --format='{{.State.Health.Status}}' $($CONTAINER_NAME ?? 'sqlserver-dev') 2>$null

    if ($healthStatus -eq "healthy") {
        Write-Host "✓ SQL Server is healthy and ready!" -ForegroundColor Green
        break
    }

    $retryCount++
    Write-Host "Waiting for SQL Server to be healthy... (attempt $retryCount/$maxRetries)"
    Start-Sleep -Seconds 5

    if ($retryCount -eq $maxRetries) {
        Write-Host "WARNING: SQL Server health check timeout" -ForegroundColor Yellow
        Write-Host "Container may still be starting. Check logs with: docker compose logs -f"
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SQL Server Container Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Connection Information:"
Write-Host "  Server: localhost,$($SQLSERVER_PORT ?? '1433')"
Write-Host "  Username: sa"
Write-Host "  Password: $SA_PASSWORD"
Write-Host ""
Write-Host "SSMS Connection String:"
Write-Host "  Server=localhost,$($SQLSERVER_PORT ?? '1433');User Id=sa;Password=$SA_PASSWORD;"
Write-Host ""
Write-Host "Useful Commands:"
Write-Host "  - View logs:           docker compose logs -f"
Write-Host "  - Stop container:      docker compose stop"
Write-Host "  - Start container:     docker compose start"
Write-Host "  - Restart container:   docker compose restart"
Write-Host "  - Remove container:    docker compose down"
Write-Host "  - Remove with volumes: docker compose down -v"
Write-Host ""
Write-Host "Connect via sqlcmd:"
Write-Host "  docker exec -it $($CONTAINER_NAME ?? 'sqlserver-dev') /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '$SA_PASSWORD'"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
