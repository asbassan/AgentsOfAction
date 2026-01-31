#!/bin/bash

# =============================================
# SQL Server Container Teardown Script
# =============================================

set -e

echo "=========================================="
echo "SQL Server Docker Teardown"
echo "=========================================="
echo ""

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

CONTAINER_NAME=${CONTAINER_NAME:-sqlserver-dev}

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '${CONTAINER_NAME}' does not exist"
    exit 0
fi

# Ask for confirmation
echo "This will stop and remove the SQL Server container."
read -p "Do you want to also remove data volumes? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "WARNING: This will delete all data, logs, and backups!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and removing container with volumes..."
        docker compose down -v

        echo "Removing data directories..."
        rm -rf data logs backups

        echo "✓ Container and all data removed"
    else
        echo "Aborting"
        exit 0
    fi
else
    echo "Stopping and removing container (keeping volumes)..."
    docker compose down

    echo "✓ Container removed (data preserved)"
    echo ""
    echo "Data directories preserved:"
    echo "  - ./data"
    echo "  - ./logs"
    echo "  - ./backups"
fi

echo ""
echo "=========================================="
echo "Teardown Complete!"
echo "=========================================="
