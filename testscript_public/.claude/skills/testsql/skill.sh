#!/bin/bash

# =============================================
# /testsql Skill - SQL Server Test Environment Manager
# =============================================
# Usage:
#   /testsql setup         - Setup SQL Server container
#   /testsql shutdown      - Shutdown and backup SQL Server
#   /testsql status        - Check container status
#   /testsql backup        - Backup database only
#   /testsql restore       - Restore from backup
#   /testsql troubleshoot  - Run troubleshooting diagnostics
#   /testsql logs          - Show SQL Server logs
#   /testsql help          - Show help message
# =============================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SQL_SETUP_DIR="${SCRIPT_DIR}/../../testSQLSetup"
BACKUP_DIR="${SQL_SETUP_DIR}/backups"
DATA_DIR="${SQL_SETUP_DIR}/data"
LOG_DIR="${SQL_SETUP_DIR}/logs"
CONTAINER_NAME="sqlserver-dev"
DATABASE_NAME="testdb"
IMAGE_NAME="testsqlsetup-sqlserver"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load environment variables
load_env() {
    if [ -f "${SQL_SETUP_DIR}/.env" ]; then
        source "${SQL_SETUP_DIR}/.env"
    else
        # Set defaults if .env doesn't exist
        SA_PASSWORD="YourSecurePassword123!"
        SQLSERVER_PORT="1433"
    fi
}

# Print colored message
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print header
print_header() {
    echo ""
    print_msg "$CYAN" "=========================================="
    print_msg "$CYAN" "$1"
    print_msg "$CYAN" "=========================================="
    echo ""
}

# Print progress indicator
print_progress() {
    local message=$1
    print_msg "$BLUE" "⏳ ${message}..."
}

# Print success message
print_success() {
    local message=$1
    print_msg "$GREEN" "✓ ${message}"
}

# Print warning message
print_warning() {
    local message=$1
    print_msg "$YELLOW" "⚠ ${message}"
}

# Print error message
print_error() {
    local message=$1
    print_msg "$RED" "✗ ${message}"
}

# Print info message
print_info() {
    local message=$1
    echo "  ${message}"
}

# Create required directories
create_directories() {
    print_progress "Checking required directories"

    local dirs_created=0

    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
        print_info "Created data directory: $DATA_DIR"
        dirs_created=1
    fi

    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        print_info "Created log directory: $LOG_DIR"
        dirs_created=1
    fi

    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        print_info "Created backup directory: $BACKUP_DIR"
        dirs_created=1
    fi

    if [ $dirs_created -eq 0 ]; then
        print_success "All required directories exist"
    else
        print_success "Required directories created"
    fi

    echo ""
}

# Check if Docker image exists
image_exists() {
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:latest$"
}

# Build Docker image
build_image() {
    print_header "Building Docker Image"

    cd "$SQL_SETUP_DIR"

    print_progress "Building ${IMAGE_NAME}:latest"
    print_info "This may take 5-10 minutes on first run (downloading SQL Server image)"
    echo ""

    if docker compose build --progress=plain 2>&1 | grep -E "(Building|Step|Successfully|CACHED)"; then
        echo ""
        print_success "Docker image built successfully"
        return 0
    else
        echo ""
        print_error "Docker image build failed"
        print_info "Try running: cd ${SQL_SETUP_DIR} && docker compose build --no-cache"
        return 1
    fi
}

# Check and build image if needed
ensure_image() {
    if image_exists; then
        print_success "Docker image '${IMAGE_NAME}' exists"
        return 0
    else
        print_warning "Docker image '${IMAGE_NAME}' not found"
        echo ""
        read -p "Build the Docker image now? (Y/n): " -n 1 -r
        echo ""
        echo ""

        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_error "Cannot proceed without Docker image"
            return 1
        fi

        if build_image; then
            return 0
        else
            return 1
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    local missing=0
    local warnings=0

    print_header "Checking Prerequisites"

    # Check Docker Desktop
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Download: https://www.docker.com/products/docker-desktop"
        missing=1
    else
        print_success "Docker is installed: $(docker --version)"
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"
        print_info "Update Docker Desktop to get latest Docker Compose"
        missing=1
    else
        print_success "Docker Compose is available"
    fi

    # Check Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker Desktop is not running"
        print_info "Please start Docker Desktop and try again"
        missing=1
    else
        print_success "Docker Desktop is running"
    fi

    # Check Docker memory
    if [ $missing -eq 0 ]; then
        local docker_memory=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
        if [ -n "$docker_memory" ]; then
            local memory_gb=$((docker_memory / 1024 / 1024 / 1024))
            if [ $memory_gb -lt 6 ]; then
                print_error "Docker memory is ${memory_gb}GB (minimum: 6GB)"
                print_info "Increase in Docker Desktop → Settings → Resources → Memory"
                missing=1
            elif [ $memory_gb -lt 8 ]; then
                print_warning "Docker memory is ${memory_gb}GB (recommended: 8GB+)"
                print_info "Consider increasing in Docker Desktop → Settings → Resources"
                warnings=1
            else
                print_success "Docker memory: ${memory_gb}GB"
            fi
        fi
    fi

    # Check disk space
    if [ -d "$SQL_SETUP_DIR" ]; then
        local available_space=$(df -BG "${SQL_SETUP_DIR}" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
        if [ -n "$available_space" ] && [ "$available_space" -gt 0 ]; then
            if [ $available_space -lt 50 ]; then
                print_error "Available disk space: ${available_space}GB (minimum: 50GB)"
                print_info "Free up disk space before continuing"
                missing=1
            elif [ $available_space -lt 120 ]; then
                print_warning "Available disk space: ${available_space}GB (recommended: 120GB+)"
                warnings=1
            else
                print_success "Available disk space: ${available_space}GB"
            fi
        fi
    fi

    # Check for SSMS (optional, Windows only)
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        if command -v ssms &> /dev/null || [ -f "/c/Program Files (x86)/Microsoft SQL Server Management Studio 19/Common7/IDE/Ssms.exe" ]; then
            print_success "SSMS is installed"
        else
            print_warning "SSMS not detected (optional)"
            print_info "Download: https://aka.ms/ssmsfullsetup"
            warnings=1
        fi
    fi

    echo ""

    if [ $missing -eq 1 ]; then
        print_error "Please fix the issues above before continuing"
        echo ""
        print_info "For help, run: /testsql troubleshoot"
        return 1
    fi

    if [ $warnings -eq 1 ]; then
        echo ""
        read -p "Continue despite warnings? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        fi
        echo ""
    fi

    return 0
}

# Check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

# Check if container is running
container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

# Get container status
get_container_status() {
    if container_running; then
        echo "running"
    elif container_exists; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

# Wait for SQL Server to be ready with better feedback
wait_for_sql() {
    load_env
    local max_retries=60  # Increased from 30 to 60 (5 minutes)
    local retry_count=0
    local last_error=""

    print_progress "Waiting for SQL Server to be ready (this may take 2-3 minutes)"
    echo ""

    while [ $retry_count -lt $max_retries ]; do
        # Try to connect
        local error_output=$(docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT 1'" 2>&1)

        if echo "$error_output" | grep -q "1 rows affected"; then
            echo ""
            print_success "SQL Server is ready!"
            return 0
        fi

        # Extract meaningful error message
        if echo "$error_output" | grep -q "Login failed"; then
            last_error="Login failed (password may be incorrect)"
        elif echo "$error_output" | grep -q "Cannot open database"; then
            last_error="Database not ready yet"
        elif echo "$error_output" | grep -q "server does not exist"; then
            last_error="SQL Server not started yet"
        else
            last_error="Starting up..."
        fi

        retry_count=$((retry_count + 1))

        # Show progress every 5 attempts
        if [ $((retry_count % 5)) -eq 0 ]; then
            local elapsed=$((retry_count * 5))
            print_info "  ${elapsed}s elapsed - ${last_error}"
        fi

        sleep 5
    done

    echo ""
    print_error "SQL Server failed to start within 5 minutes"
    print_info "Last status: ${last_error}"
    echo ""
    print_info "Troubleshooting steps:"
    print_info "  1. Check logs: /testsql logs"
    print_info "  2. Check container: docker ps -a"
    print_info "  3. Restart: docker compose restart"
    print_info "  4. Run diagnostics: /testsql troubleshoot"

    return 1
}

# Check for existing backups
check_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        return 1
    fi

    local backup_count=$(find "$BACKUP_DIR" -name "${DATABASE_NAME}*.bak" 2>/dev/null | wc -l)

    if [ $backup_count -gt 0 ]; then
        print_success "Found $backup_count existing backup(s):"
        find "$BACKUP_DIR" -name "${DATABASE_NAME}*.bak" -exec ls -lh {} \; 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
        echo ""
        return 0
    else
        print_warning "No existing backups found"
        return 1
    fi
}

# Backup database with progress
backup_database() {
    load_env

    if ! container_running; then
        print_error "Container is not running. Cannot backup."
        print_info "Start container with: /testsql setup"
        return 1
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${DATABASE_NAME}_${timestamp}"
    local backup_file="/var/opt/mssql/backup/${backup_name}.bak"

    print_header "Backing Up Database: ${DATABASE_NAME}"

    print_info "Backup name: $backup_name"
    echo ""
    print_progress "Creating backup (this may take 1-2 minutes)"
    echo ""

    local backup_output=$(docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd \
        -C -S localhost \
        -U sa \
        -P '$SA_PASSWORD' \
        -Q \"BACKUP DATABASE [$DATABASE_NAME] TO DISK='$backup_file' WITH FORMAT, COMPRESSION, STATS = 10;\"" 2>&1)

    if echo "$backup_output" | grep -q "100 percent processed"; then
        local backup_size=$(docker exec $CONTAINER_NAME ls -lh /var/opt/mssql/backup/${backup_name}.bak 2>/dev/null | awk '{print $5}')
        echo ""
        print_success "Backup completed successfully!"
        echo ""
        echo "Backup details:"
        print_info "Container path: $backup_file"
        print_info "Host path: ${BACKUP_DIR}/${backup_name}.bak"
        print_info "Size: ${backup_size:-Unknown}"
        print_info "Compression: Enabled"
        return 0
    else
        echo ""
        print_error "Backup failed!"
        echo ""
        print_info "Error output:"
        echo "$backup_output" | grep -i "error" | sed 's/^/  /'
        return 1
    fi
}

# Restore from backup with better UX
restore_database() {
    load_env

    if ! container_running; then
        print_error "Container is not running. Cannot restore."
        print_info "Start container with: /testsql setup"
        return 1
    fi

    print_header "Restore Database from Backup"

    # List available backups
    if ! check_backups; then
        print_error "No backups available to restore"
        print_info "Create a backup with: /testsql backup"
        return 1
    fi

    # Get list of backup files
    local backups=($(find "$BACKUP_DIR" -name "${DATABASE_NAME}*.bak" -printf "%f\n" 2>/dev/null | sort -r))

    if [ ${#backups[@]} -eq 0 ]; then
        print_error "No backups found"
        return 1
    fi

    # If multiple backups, show menu
    if [ ${#backups[@]} -gt 1 ]; then
        echo "Select backup to restore:"
        local i=1
        for backup in "${backups[@]}"; do
            local size=$(ls -lh "${BACKUP_DIR}/${backup}" 2>/dev/null | awk '{print $5}')
            local timestamp=$(echo "$backup" | grep -oP '\d{8}_\d{6}' || echo "unknown")
            echo "  $i) $backup"
            print_info "   Size: $size | Timestamp: $timestamp"
            i=$((i + 1))
        done
        echo ""
        read -p "Enter number (or press Enter for most recent): " choice

        if [ -z "$choice" ]; then
            choice=1
        fi

        local selected_backup="${backups[$((choice - 1))]}"
    else
        local selected_backup="${backups[0]}"
        print_info "Using backup: $selected_backup"
    fi

    if [ -z "$selected_backup" ]; then
        print_error "Invalid selection"
        return 1
    fi

    echo ""
    print_warning "This will replace the current database with the backup!"
    read -p "Continue? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        return 0
    fi

    echo ""
    print_progress "Restoring from: $selected_backup"
    echo ""

    local backup_path="/var/opt/mssql/backup/${selected_backup}"

    # Restore database
    local restore_output=$(docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd \
        -C -S localhost \
        -U sa \
        -P '$SA_PASSWORD' \
        -Q \"RESTORE DATABASE [$DATABASE_NAME] FROM DISK='$backup_path' WITH REPLACE, STATS = 10;\"" 2>&1)

    if echo "$restore_output" | grep -q "100 percent processed"; then
        echo ""
        print_success "Restore completed successfully!"
        print_info "Database '$DATABASE_NAME' restored from $selected_backup"
        return 0
    else
        echo ""
        print_error "Restore failed!"
        echo ""
        print_info "Error output:"
        echo "$restore_output" | grep -i "error" | sed 's/^/  /'
        return 1
    fi
}

# Setup SQL Server with comprehensive checks
setup_sql() {
    print_header "/testsql setup - SQL Server Setup"

    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi

    # Create directories
    create_directories

    # Change to SQL setup directory
    cd "$SQL_SETUP_DIR"

    # Ensure Docker image exists
    if ! ensure_image; then
        return 1
    fi

    # Check container status
    local status=$(get_container_status)

    case $status in
        running)
            print_success "Container '$CONTAINER_NAME' is already running"
            echo ""
            echo "Options:"
            echo "  1) Keep it running (check status)"
            echo "  2) Restart container"
            echo "  3) Cancel"
            echo ""
            read -p "Select option (1-3): " -n 1 -r option
            echo ""
            echo ""

            case $option in
                1)
                    print_progress "Checking SQL Server status"
                    if docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT 1'" &> /dev/null; then
                        print_success "SQL Server is responding"
                    else
                        print_warning "SQL Server may not be ready yet"
                        wait_for_sql
                    fi
                    ;;
                2)
                    print_progress "Restarting container"
                    docker compose restart
                    wait_for_sql
                    ;;
                *)
                    print_info "Cancelled"
                    return 0
                    ;;
            esac
            ;;

        stopped)
            print_warning "Container '$CONTAINER_NAME' exists but is stopped"
            echo ""
            read -p "Start the container? (Y/n): " -n 1 -r
            echo ""
            echo ""

            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_progress "Starting container"
                docker compose start
                wait_for_sql
            else
                return 0
            fi
            ;;

        not_found)
            # Check for existing backups
            if check_backups; then
                echo ""
                read -p "Restore from an existing backup? (y/N): " -n 1 -r
                echo ""
                echo ""

                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    print_progress "Building and starting SQL Server container"
                    docker compose up -d

                    if wait_for_sql; then
                        restore_database
                    fi
                else
                    print_progress "Setting up fresh SQL Server container"
                    docker compose up -d
                    wait_for_sql
                fi
            else
                print_progress "Setting up fresh SQL Server container"
                docker compose up -d
                wait_for_sql
            fi
            ;;
    esac

    # Display connection information
    load_env
    print_header "SQL Server Ready!"

    echo "Connection Information:"
    print_info "Server: localhost,${SQLSERVER_PORT:-1433}"
    print_info "Database: $DATABASE_NAME"
    print_info "Username: sa"
    print_info "Password: $SA_PASSWORD"
    echo ""
    echo "SSMS Connection String:"
    print_info "Server=localhost,${SQLSERVER_PORT:-1433};Database=$DATABASE_NAME;User Id=sa;Password=$SA_PASSWORD;TrustServerCertificate=True;"
    echo ""
    echo "Quick Commands:"
    print_info "/testsql status   - Check status"
    print_info "/testsql backup   - Backup database"
    print_info "/testsql logs     - View SQL Server logs"
    print_info "/testsql shutdown - Shutdown and backup"
    echo ""
    print_msg "$GREEN" "=========================================="
}

# Shutdown SQL Server with better options
shutdown_sql() {
    print_header "/testsql shutdown - SQL Server Shutdown"

    local status=$(get_container_status)

    if [ "$status" == "not_found" ]; then
        print_warning "Container does not exist. Nothing to shutdown."
        return 0
    fi

    if [ "$status" == "stopped" ]; then
        print_warning "Container is not running"
        echo ""
        read -p "Remove the stopped container? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$SQL_SETUP_DIR"
            docker compose down
            print_success "Container removed"
        fi
        return 0
    fi

    # Container is running, show shutdown options
    echo "Shutdown Options:"
    echo ""
    echo "  1) Backup + Stop container (quick, recommended for daily use)"
    echo "     - Creates backup"
    echo "     - Stops container but keeps it"
    echo "     - Fast restart with 'docker compose start'"
    echo ""
    echo "  2) Backup + Remove container (keep data volumes)"
    echo "     - Creates backup"
    echo "     - Removes container"
    echo "     - Keeps all data in volumes"
    echo "     - Next setup will be quick"
    echo ""
    echo "  3) Backup + Remove container and ALL data"
    echo "     - Creates backup"
    echo "     - Removes container"
    echo "     - Deletes all data volumes"
    echo "     - Next setup will be fresh"
    echo ""
    echo "  4) Just stop (no backup, fastest)"
    echo "     - Only stops the container"
    echo "     - No backup created"
    echo "     - Use for quick breaks"
    echo ""
    echo "  5) Cancel"
    echo ""
    read -p "Select option (1-5): " -n 1 -r option
    echo ""
    echo ""

    case $option in
        1)
            # Backup and stop container
            print_msg "$BLUE" "Option 1: Backup → Stop container"
            echo ""

            if backup_database; then
                cd "$SQL_SETUP_DIR"
                print_progress "Stopping container"
                docker compose stop
                print_success "Container stopped. Data preserved."
                print_info "Quick restart: cd ${SQL_SETUP_DIR} && docker compose start"
            else
                print_error "Backup failed. Container not stopped."
                return 1
            fi
            ;;

        2)
            # Backup and remove container, keep volumes
            print_msg "$BLUE" "Option 2: Backup → Remove container (keep data)"
            echo ""

            if backup_database; then
                cd "$SQL_SETUP_DIR"
                print_progress "Removing container"
                docker compose down
                print_success "Container removed. Data volumes preserved."
                print_info "Next /testsql setup will reuse existing data"
            else
                print_error "Backup failed. Container not removed."
                return 1
            fi
            ;;

        3)
            # Backup and remove everything
            print_msg "$YELLOW" "Option 3: Backup → Remove container and ALL DATA"
            echo ""
            print_msg "$RED" "⚠ WARNING: This will delete all data, logs, and volumes!"
            echo ""
            read -p "Type 'yes' to confirm: " confirm

            if [ "$confirm" == "yes" ]; then
                if backup_database; then
                    cd "$SQL_SETUP_DIR"
                    print_progress "Removing container and volumes"
                    docker compose down -v

                    print_progress "Removing data directories"
                    rm -rf data logs

                    print_success "Everything removed"
                    print_info "Backup saved to: ${BACKUP_DIR}/"
                    print_info "Next /testsql setup will create fresh database"
                else
                    print_error "Backup failed. Nothing removed."
                    return 1
                fi
            else
                print_warning "Confirmation not received. Aborting."
                return 0
            fi
            ;;

        4)
            # Just stop container
            print_msg "$BLUE" "Option 4: Stopping container (no backup)"
            cd "$SQL_SETUP_DIR"
            docker compose stop
            print_success "Container stopped"
            print_info "Resume with: cd ${SQL_SETUP_DIR} && docker compose start"
            ;;

        5|*)
            print_info "Shutdown cancelled"
            return 0
            ;;
    esac

    echo ""
    print_msg "$GREEN" "=========================================="
}

# Show status with more details
show_status() {
    print_header "SQL Server Status"

    load_env

    local status=$(get_container_status)

    case $status in
        running)
            print_success "Container is running"

            # Get container stats
            echo ""
            echo "Container Stats:"
            docker stats $CONTAINER_NAME --no-stream --format "  CPU: {{.CPUPerc}}\n  Memory: {{.MemUsage}}\n  Network: {{.NetIO}}\n  Disk: {{.BlockIO}}"

            # Check SQL Server connection
            echo ""
            print_progress "Checking SQL Server connection"

            if docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT 1'" &> /dev/null; then
                print_success "SQL Server is responding"

                # Get database info
                echo ""
                echo "Database Information:"
                local db_info=$(docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -d $DATABASE_NAME -Q \"SET NOCOUNT ON; SELECT 'Database: $DATABASE_NAME' AS Info UNION ALL SELECT 'Status: Online' UNION ALL SELECT 'Size: ' + CAST((SUM(size)*8/1024) AS VARCHAR(20)) + ' MB' FROM sys.master_files WHERE database_id = DB_ID();\" -h -1" 2>/dev/null)
                echo "$db_info" | grep -v "^$" | sed 's/^/  /'
            else
                print_error "SQL Server is not responding"
                print_info "Container may be starting up. Try: /testsql logs"
            fi

            # Show connection info
            echo ""
            echo "Connection:"
            print_info "Server: localhost,${SQLSERVER_PORT:-1433}"
            print_info "Database: $DATABASE_NAME"
            print_info "Username: sa"
            print_info "Password: $SA_PASSWORD"
            ;;

        stopped)
            print_warning "Container exists but is stopped"
            echo ""
            print_info "Start with: /testsql setup"
            ;;

        not_found)
            print_warning "Container does not exist"
            echo ""
            print_info "Create with: /testsql setup"
            ;;
    esac

    # Check Docker image
    echo ""
    if image_exists; then
        print_success "Docker image '${IMAGE_NAME}' exists"
    else
        print_warning "Docker image '${IMAGE_NAME}' not found"
        print_info "Will be built on next setup"
    fi

    # Check for backups
    echo ""
    check_backups || true

    echo ""
    print_msg "$CYAN" "=========================================="
}

# Show logs
show_logs() {
    print_header "SQL Server Logs"

    if ! container_exists; then
        print_error "Container does not exist"
        print_info "Create container with: /testsql setup"
        return 1
    fi

    echo "Showing last 50 lines of logs (Ctrl+C to exit):"
    echo ""

    docker logs $CONTAINER_NAME --tail 50 --follow 2>&1
}

# Troubleshooting
troubleshoot() {
    print_header "Troubleshooting Diagnostics"

    echo "Running diagnostics..."
    echo ""

    # Check Docker
    print_msg "$CYAN" "1. Docker Status"
    if docker info &> /dev/null; then
        print_success "Docker is running"
        local docker_version=$(docker --version)
        print_info "Version: $docker_version"
    else
        print_error "Docker is not running"
        print_info "Fix: Start Docker Desktop"
    fi
    echo ""

    # Check Docker Compose
    print_msg "$CYAN" "2. Docker Compose"
    if docker compose version &> /dev/null; then
        print_success "Docker Compose is available"
        local compose_version=$(docker compose version --short)
        print_info "Version: $compose_version"
    else
        print_error "Docker Compose is not available"
    fi
    echo ""

    # Check container
    print_msg "$CYAN" "3. Container Status"
    local status=$(get_container_status)
    case $status in
        running)
            print_success "Container is running"
            local uptime=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
            print_info "Uptime: $uptime"
            ;;
        stopped)
            print_warning "Container is stopped"
            print_info "Fix: /testsql setup"
            ;;
        not_found)
            print_warning "Container does not exist"
            print_info "Fix: /testsql setup"
            ;;
    esac
    echo ""

    # Check image
    print_msg "$CYAN" "4. Docker Image"
    if image_exists; then
        print_success "Image '${IMAGE_NAME}' exists"
        local image_size=$(docker images ${IMAGE_NAME} --format "{{.Size}}")
        print_info "Size: $image_size"
    else
        print_warning "Image '${IMAGE_NAME}' not found"
        print_info "Fix: cd ${SQL_SETUP_DIR} && docker compose build"
    fi
    echo ""

    # Check directories
    print_msg "$CYAN" "5. Directories"
    local dir_errors=0

    if [ -d "$SQL_SETUP_DIR" ]; then
        print_success "Setup directory exists: $SQL_SETUP_DIR"
    else
        print_error "Setup directory missing: $SQL_SETUP_DIR"
        dir_errors=1
    fi

    if [ -d "$DATA_DIR" ]; then
        print_success "Data directory exists"
        local data_size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
        print_info "Size: ${data_size:-0}"
    else
        print_warning "Data directory missing (will be created)"
    fi

    if [ -d "$LOG_DIR" ]; then
        print_success "Log directory exists"
    else
        print_warning "Log directory missing (will be created)"
    fi

    if [ -d "$BACKUP_DIR" ]; then
        print_success "Backup directory exists"
        local backup_count=$(find "$BACKUP_DIR" -name "*.bak" 2>/dev/null | wc -l)
        print_info "Backups: $backup_count"
    else
        print_warning "Backup directory missing (will be created)"
    fi
    echo ""

    # Check .env file
    print_msg "$CYAN" "6. Configuration"
    if [ -f "${SQL_SETUP_DIR}/.env" ]; then
        print_success ".env file exists"
    else
        print_warning ".env file missing (using defaults)"
    fi
    echo ""

    # Check port
    print_msg "$CYAN" "7. Port Availability"
    if netstat -an 2>/dev/null | grep -q ":1433.*LISTEN"; then
        if container_running; then
            print_success "Port 1433 is in use by our container"
        else
            print_error "Port 1433 is in use by another process"
            print_info "Fix: Stop other SQL Server instances or change port in .env"
        fi
    else
        print_success "Port 1433 is available"
    fi
    echo ""

    # Check SQL Server (if running)
    if container_running; then
        print_msg "$CYAN" "8. SQL Server Connection"
        load_env

        if docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT @@VERSION'" &> /dev/null; then
            print_success "SQL Server is responding"

            # Get version
            local version=$(docker exec $CONTAINER_NAME bash -c "/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT @@VERSION' -h -1" 2>/dev/null | head -1)
            print_info "Version: ${version}"
        else
            print_error "SQL Server is not responding"
            print_info "Check logs: /testsql logs"
        fi
        echo ""
    fi

    # Summary and recommendations
    print_header "Summary"

    if [ $dir_errors -eq 0 ] && [ "$status" == "running" ] && image_exists; then
        print_success "All checks passed!"
        print_info "System appears to be working correctly"
    else
        print_warning "Some issues detected. See above for details."
        echo ""
        echo "Common fixes:"
        print_info "1. Start Docker Desktop if not running"
        print_info "2. Run: /testsql setup"
        print_info "3. Check logs: /testsql logs"
        print_info "4. Rebuild image: cd ${SQL_SETUP_DIR} && docker compose build --no-cache"
    fi
}

# Main command handler
main() {
    local command=${1:-help}

    case $command in
        setup)
            setup_sql
            ;;
        shutdown)
            shutdown_sql
            ;;
        status)
            show_status
            ;;
        backup)
            if container_running; then
                backup_database
            else
                print_error "Container is not running"
                print_info "Start with: /testsql setup"
                exit 1
            fi
            ;;
        restore)
            if container_running; then
                restore_database
            else
                print_error "Container is not running"
                print_info "Start with: /testsql setup"
                exit 1
            fi
            ;;
        logs)
            show_logs
            ;;
        troubleshoot|diagnose|debug)
            troubleshoot
            ;;
        help|*)
            print_header "/testsql - SQL Server Test Environment Manager"
            echo "Usage:"
            echo "  /testsql setup         - Setup and start SQL Server container"
            echo "  /testsql shutdown      - Shutdown SQL Server with backup options"
            echo "  /testsql status        - Show container and database status"
            echo "  /testsql backup        - Backup database only"
            echo "  /testsql restore       - Restore from existing backup"
            echo "  /testsql logs          - Show SQL Server logs"
            echo "  /testsql troubleshoot  - Run diagnostics"
            echo "  /testsql help          - Show this help message"
            echo ""
            echo "Database: ${DATABASE_NAME}"
            echo "Username: sa"
            echo "Password: YourSecurePassword123!"
            echo ""
            echo "For detailed documentation, see:"
            echo "  .claude/testSQLSetup/README.md"
            echo "  .claude/testSQLSetup/README-TESTSQL.md"
            echo ""
            ;;
    esac
}

# Run main function
main "$@"
