#!/bin/bash

# =============================================
# SQL Server Database Backup Script
# =============================================

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

CONTAINER_NAME=${CONTAINER_NAME:-sqlserver-dev}
SA_PASSWORD=${SA_PASSWORD:-YourSecurePassword123!}

# Function to display usage
usage() {
    echo "Usage: $0 <database_name> [backup_name]"
    echo ""
    echo "Examples:"
    echo "  $0 TestDB"
    echo "  $0 TestDB my_backup"
    echo ""
    echo "This will create a backup in the ./backups directory"
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

DATABASE_NAME=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME=${2:-${DATABASE_NAME}_${TIMESTAMP}}
BACKUP_FILE="/var/opt/mssql/backup/${BACKUP_NAME}.bak"

echo "=========================================="
echo "SQL Server Database Backup"
echo "=========================================="
echo "Database: $DATABASE_NAME"
echo "Backup name: $BACKUP_NAME"
echo "Container: $CONTAINER_NAME"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

# Execute backup
echo "Starting backup..."
docker exec -it $CONTAINER_NAME /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "$SA_PASSWORD" \
    -Q "BACKUP DATABASE [$DATABASE_NAME] TO DISK='$BACKUP_FILE' WITH FORMAT, COMPRESSION, STATS = 10;"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Backup completed successfully!"
    echo ""
    echo "Backup location:"
    echo "  Container: $BACKUP_FILE"
    echo "  Host: ./backups/${BACKUP_NAME}.bak"
    echo ""

    # Get backup size
    BACKUP_SIZE=$(docker exec $CONTAINER_NAME ls -lh /var/opt/mssql/backup/${BACKUP_NAME}.bak | awk '{print $5}')
    echo "Backup size: $BACKUP_SIZE"
else
    echo ""
    echo "✗ Backup failed!"
    exit 1
fi

echo "=========================================="
