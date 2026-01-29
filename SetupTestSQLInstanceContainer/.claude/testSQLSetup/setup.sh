#!/bin/bash

# =============================================
# DAMS SQL Server Container Setup Script
# =============================================

set -e

echo "=========================================="
echo "DAMS SQL Server Docker Setup"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose is not available"
    echo "Please install Docker Compose or update Docker Desktop"
    exit 1
fi

echo "✓ Docker is installed: $(docker --version)"
echo "✓ Docker Compose is available: $(docker compose version)"
echo ""

# Create necessary directories
echo "Creating data directories..."
mkdir -p data logs backups
echo "✓ Directories created"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    echo "Please create .env file with required configuration"
    exit 1
fi

# Load environment variables
source .env

echo "Configuration:"
echo "  - Container Name: ${CONTAINER_NAME:-dams-sqlserver-dev}"
echo "  - SQL Server Port: ${SQLSERVER_PORT:-1433}"
echo "  - Data Path: ${DATA_PATH:-./data}"
echo "  - Backup Path: ${BACKUP_PATH:-./backups}"
echo ""

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME:-dams-sqlserver-dev}$"; then
    echo "WARNING: Container '${CONTAINER_NAME:-dams-sqlserver-dev}' already exists"
    read -p "Do you want to remove it and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing container..."
        docker compose down -v
        echo "✓ Container removed"
    else
        echo "Aborting setup"
        exit 0
    fi
fi

# Build and start container
echo "=========================================="
echo "Building and starting SQL Server container..."
echo "=========================================="
echo ""

docker compose build --no-cache

echo ""
echo "Starting container..."
docker compose up -d

echo ""
echo "Waiting for SQL Server to be ready..."
sleep 10

# Wait for health check
max_retries=30
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME:-dams-sqlserver-dev} 2>/dev/null | grep -q "healthy"; then
        echo "✓ SQL Server is healthy and ready!"
        break
    fi

    retry_count=$((retry_count + 1))
    echo "Waiting for SQL Server to be healthy... (attempt $retry_count/$max_retries)"
    sleep 5

    if [ $retry_count -eq $max_retries ]; then
        echo "WARNING: SQL Server health check timeout"
        echo "Container may still be starting. Check logs with: docker compose logs -f"
    fi
done

echo ""
echo "=========================================="
echo "SQL Server Container Setup Complete!"
echo "=========================================="
echo ""
echo "Connection Information:"
echo "  Server: localhost,${SQLSERVER_PORT:-1433}"
echo "  Username: sa"
echo "  Password: ${SA_PASSWORD}"
echo ""
echo "SSMS Connection String:"
echo "  Server=localhost,${SQLSERVER_PORT:-1433};User Id=sa;Password=${SA_PASSWORD};"
echo ""
echo "Useful Commands:"
echo "  - View logs:           docker compose logs -f"
echo "  - Stop container:      docker compose stop"
echo "  - Start container:     docker compose start"
echo "  - Restart container:   docker compose restart"
echo "  - Remove container:    docker compose down"
echo "  - Remove with volumes: docker compose down -v"
echo ""
echo "Connect via sqlcmd:"
echo "  docker exec -it ${CONTAINER_NAME:-dams-sqlserver-dev} /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '${SA_PASSWORD}'"
echo ""
echo "=========================================="
