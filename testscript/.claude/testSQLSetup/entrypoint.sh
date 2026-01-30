#!/bin/bash
set -e

echo "=========================================="
echo "DAMS SQL Server Container Starting..."
echo "=========================================="

# Display configuration
echo "Configuration:"
echo "  - SQL Server Edition: ${MSSQL_PID:-Developer}"
echo "  - Memory Limit: ${MSSQL_MEMORY_LIMIT_MB:-6144} MB"
echo "  - SQL Agent: ${MSSQL_AGENT_ENABLED:-true}"
echo "  - Collation: ${MSSQL_COLLATION:-SQL_Latin1_General_CP1_CI_AS}"
echo "=========================================="

# Function to wait for SQL Server to be ready
wait_for_sql() {
    echo "Waiting for SQL Server to start..."
    local retries=30
    local wait_time=5

    for i in $(seq 1 $retries); do
        if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null; then
            echo "SQL Server is ready!"
            return 0
        fi
        echo "Attempt $i/$retries: SQL Server not ready yet, waiting ${wait_time}s..."
        sleep $wait_time
    done

    echo "ERROR: SQL Server failed to start within expected time"
    return 1
}

# Start SQL Server in background
echo "Starting SQL Server..."
/opt/mssql/bin/sqlservr &

# Wait for SQL Server to be ready
if ! wait_for_sql; then
    echo "Failed to start SQL Server"
    exit 1
fi

# Run initialization scripts if they exist
if [ -d "/docker-entrypoint-initdb.d" ]; then
    echo "=========================================="
    echo "Running initialization scripts..."
    echo "=========================================="

    for script in /docker-entrypoint-initdb.d/*.sql; do
        if [ -f "$script" ]; then
            echo "Executing: $(basename $script)"
            /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -i "$script"
            if [ $? -eq 0 ]; then
                echo "  ✓ Successfully executed $(basename $script)"
            else
                echo "  ✗ Failed to execute $(basename $script)"
            fi
        fi
    done

    echo "=========================================="
    echo "Initialization complete!"
    echo "=========================================="
fi

# Display connection information
echo ""
echo "=========================================="
echo "SQL Server Connection Information:"
echo "=========================================="
echo "  Server: localhost,1433"
echo "  Username: sa"
echo "  Password: *********"
echo ""
echo "SSMS Connection String:"
echo "  Server=localhost,1433;User Id=sa;Password=****;"
echo ""
echo "Docker Connection (from host):"
echo "  Server=localhost,1433;User Id=sa;Password=****;"
echo "=========================================="
echo ""

# Keep container running and tail SQL Server error log
echo "SQL Server is running. Tailing error log..."
echo "Press Ctrl+C to stop the container"
echo "=========================================="

# Wait for SQL Server process and tail error log
tail -f /var/opt/mssql/log/errorlog
