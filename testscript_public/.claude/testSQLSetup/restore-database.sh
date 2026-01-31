#!/bin/bash

# =============================================
# SQL Server Database Restore Script
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
    echo "Usage: $0 <backup_file> <database_name>"
    echo ""
    echo "Examples:"
    echo "  $0 TestDB_20260126.bak TestDB"
    echo "  $0 my_backup.bak RestoredDB"
    echo ""
    echo "Backup file should be in ./backups directory"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

BACKUP_FILE=$1
DATABASE_NAME=$2
BACKUP_PATH="/var/opt/mssql/backup/${BACKUP_FILE}"

echo "=========================================="
echo "SQL Server Database Restore"
echo "=========================================="
echo "Backup file: $BACKUP_FILE"
echo "Database: $DATABASE_NAME"
echo "Container: $CONTAINER_NAME"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

# Check if backup file exists
if ! docker exec $CONTAINER_NAME test -f $BACKUP_PATH; then
    echo "ERROR: Backup file '$BACKUP_FILE' not found in container"
    echo "Available backups:"
    docker exec $CONTAINER_NAME ls -lh /var/opt/mssql/backup/
    exit 1
fi

# Get logical file names from backup
echo "Reading backup file..."
docker exec -it $CONTAINER_NAME /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "$SA_PASSWORD" \
    -Q "RESTORE FILELISTONLY FROM DISK='$BACKUP_PATH';" \
    -o /tmp/filelist.txt

echo ""
read -p "Do you want to restore this backup? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Execute restore
echo ""
echo "Starting restore..."
docker exec -it $CONTAINER_NAME /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "$SA_PASSWORD" \
    -Q "RESTORE DATABASE [$DATABASE_NAME] FROM DISK='$BACKUP_PATH' WITH REPLACE, STATS = 10;"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Restore completed successfully!"
    echo ""
    echo "Database '$DATABASE_NAME' is now available"
else
    echo ""
    echo "✗ Restore failed!"
    exit 1
fi

echo "=========================================="
