# /testsql Skill - SQL Server Test Environment Manager

## Overview

The `/testsql` skill provides a command-line interface for managing a SQL Server 2022 Docker container for CAP-DAMS testing and development. It handles setup, shutdown, backup, restore, and status monitoring with intelligent workflows.

## Quick Start

### Prerequisites

Before using `/testsql`, ensure you have:

1. **Docker Desktop** installed and running
   - Download: https://www.docker.com/products/docker-desktop
   - Memory: 8GB+ allocated to Docker
   - Disk Space: 120GB+ available

2. **SQL Server Management Studio (SSMS)** (optional but recommended)
   - Download: https://aka.ms/ssmsfullsetup

### Basic Usage

```bash
# Setup and start SQL Server
/testsql setup

# Check status
/testsql status

# Backup database
/testsql backup

# Restore from backup
/testsql restore

# Shutdown with options
/testsql shutdown

# Show help
/testsql help
```

## Commands

### /testsql setup

**Purpose**: Initialize and start the SQL Server container

**Behavior**:
1. Checks prerequisites (Docker, memory, disk space)
2. Creates directories (data, logs, backups) if needed
3. Checks for existing container:
   - **If running**: Offers to restart
   - **If stopped**: Offers to start
   - **If not exists**: Creates new container
4. Checks for existing backups:
   - **If found**: Offers to restore from backup
   - **If not found**: Creates fresh database
5. Waits for SQL Server to be ready
6. Displays connection information

**Example**:
```bash
/testsql setup
```

**Output**:
```
==========================================
/testsql setup - SQL Server Setup
==========================================

Checking Prerequisites
==========================================

✓ Docker is installed: Docker version 29.1.3, build f52814d
✓ Docker Compose is available
✓ Docker Desktop is running
✓ Docker memory: 12GB
✓ Available disk space: 250GB

Found 2 existing backup(s):
  - capdamstest_20260126_143022.bak (125M)
  - capdamstest_20260125_091534.bak (118M)

Do you want to restore from an existing backup? (y/N):
```

### /testsql shutdown

**Purpose**: Stop and optionally remove SQL Server container with backup

**Shutdown Options**:

1. **Backup → Remove container (keep data)**
   - Backs up database to `.claude/testSQLSetup/backups/`
   - Removes container
   - Preserves data volumes for quick restart
   - Recommended for temporary shutdown

2. **Backup → Remove container and ALL data**
   - Backs up database
   - Removes container
   - Deletes all data volumes
   - Requires confirmation ("yes")
   - Use for complete cleanup

3. **Just stop container (no backup)**
   - Stops container without backup
   - Preserves all data
   - Quick restart with `docker compose start`

4. **Cancel**
   - Aborts shutdown

**Example**:
```bash
/testsql shutdown
```

**Output**:
```
==========================================
/testsql shutdown - SQL Server Shutdown
==========================================

Shutdown Options:
  1) Backup database, then remove container (keep data volumes)
  2) Backup database, then remove container and all data volumes
  3) Just stop container (no backup, keep everything)
  4) Cancel

Select option (1-4): 1

Backing Up Database: capdamstest
==========================================

Backup name: capdamstest_20260126_151045

10 percent processed.
20 percent processed.
...
100 percent processed.
Processed 12800 pages for database 'capdamstest', file 'capdamstest_Data' on file 1.
Processed 2 pages for database 'capdamstest', file 'capdamstest_Log' on file 1.
BACKUP DATABASE successfully processed 12802 pages in 1.234 seconds (80.925 MB/sec).

✓ Backup completed successfully!

Backup location:
  Container: /var/opt/mssql/backup/capdamstest_20260126_151045.bak
  Host: .claude/testSQLSetup/backups/capdamstest_20260126_151045.bak
  Size: 125M

Removing container...
✓ Container removed. Data volumes preserved.

==========================================
```

### /testsql status

**Purpose**: Display container and database status

**Information Shown**:
- Container running status
- CPU, memory, network, disk usage
- SQL Server connection status
- Database name and size
- Connection credentials
- Available backups

**Example**:
```bash
/testsql status
```

**Output**:
```
==========================================
SQL Server Status
==========================================

✓ Container is running

Container Stats:
  CPU: 2.45%
  Memory: 4.2GiB / 12GiB
  Network: 1.5kB / 890B
  Disk: 256MB / 12MB

✓ SQL Server is responding

Database Information:
  Database: capdamstest
  Status: Online
  Size: 1280 MB

Connection:
  Server: localhost,1433
  Database: capdamstest
  Username: sa
  Password: Pass@word1

Found 3 existing backup(s):
  - capdamstest_20260126_151045.bak (125M)
  - capdamstest_20260126_143022.bak (125M)
  - capdamstest_20260125_091534.bak (118M)

==========================================
```

### /testsql backup

**Purpose**: Create a timestamped backup of the database

**Backup Details**:
- Backup name: `capdamstest_YYYYMMDD_HHMMSS.bak`
- Location: `.claude/testSQLSetup/backups/`
- Compression: Enabled (saves ~70% space)
- Format: Native SQL Server backup format

**Example**:
```bash
/testsql backup
```

**Output**:
```
==========================================
Backing Up Database: capdamstest
==========================================

Backup name: capdamstest_20260126_152317

10 percent processed.
...
100 percent processed.

✓ Backup completed successfully!

Backup location:
  Container: /var/opt/mssql/backup/capdamstest_20260126_152317.bak
  Host: .claude/testSQLSetup/backups/capdamstest_20260126_152317.bak
  Size: 125M
```

### /testsql restore

**Purpose**: Restore database from an existing backup

**Behavior**:
1. Lists all available backups in `.claude/testSQLSetup/backups/`
2. If multiple backups exist, shows selection menu
3. Prompts for confirmation
4. Restores selected backup (replaces current database)

**Example**:
```bash
/testsql restore
```

**Output**:
```
==========================================
Restore Database from Backup
==========================================

Found 3 existing backup(s):
  - capdamstest_20260126_151045.bak (125M)
  - capdamstest_20260126_143022.bak (125M)
  - capdamstest_20260125_091534.bak (118M)

Select backup to restore:
  1) capdamstest_20260126_151045.bak (125M)
  2) capdamstest_20260126_143022.bak (125M)
  3) capdamstest_20260125_091534.bak (118M)

Enter number (or press Enter for most recent): 1

Restoring from: capdamstest_20260126_151045.bak

10 percent processed.
...
100 percent processed.

✓ Restore completed successfully!
```

## Configuration

### Database Configuration

| Setting | Value |
|---------|-------|
| **Database Name** | capdamstest |
| **Username** | sa |
| **Password** | Pass@word1 |
| **Port** | 1433 |
| **Server** | localhost,1433 |

### Connection String

```
Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;
```

### SSMS Connection

1. Open SQL Server Management Studio
2. Connect to Server:
   - **Server name**: `localhost,1433`
   - **Authentication**: SQL Server Authentication
   - **Login**: `sa`
   - **Password**: `Pass@word1`
3. Click "Connect"

### Environment Variables (.env)

```bash
# SQL Server Configuration
SA_PASSWORD=Pass@word1
DATABASE_NAME=capdamstest

# Paths
DATA_PATH=./data
LOG_PATH=./logs
BACKUP_PATH=./backups

# Network
SQLSERVER_PORT=1433

# Container
CONTAINER_NAME=dams-sqlserver-dev
```

## Backup Management

### Backup Location

All backups are stored in:
```
.claude/testSQLSetup/backups/
```

### Backup Naming Convention

```
capdamstest_YYYYMMDD_HHMMSS.bak
```

Examples:
- `capdamstest_20260126_143022.bak` → Jan 26, 2026 at 2:30:22 PM
- `capdamstest_20260125_091534.bak` → Jan 25, 2026 at 9:15:34 AM

### Manual Backup Management

```bash
# List backups
ls -lh .claude/testSQLSetup/backups/

# Copy backup to another location
cp .claude/testSQLSetup/backups/capdamstest_20260126_143022.bak ~/my-backups/

# Delete old backups (older than 30 days)
find .claude/testSQLSetup/backups/ -name "capdamstest*.bak" -mtime +30 -delete
```

### Backup Compression

Backups use SQL Server native compression:
- **Uncompressed database**: ~400 MB
- **Compressed backup**: ~125 MB (~70% reduction)

## Workflows

### Daily Development Workflow

```bash
# Morning - Start SQL Server
/testsql setup

# Work throughout the day...
# (Connect via SSMS, run scripts, test features)

# Evening - Shutdown with backup
/testsql shutdown
# Select option 1: Backup → Remove container (keep data)
```

### Weekly Cleanup Workflow

```bash
# Check status and backups
/testsql status

# Clean up old backups manually
cd .claude/testSQLSetup/backups
rm capdamstest_2026*.bak  # Delete old backups

# Full shutdown (removes all data)
/testsql shutdown
# Select option 2: Backup → Remove container and ALL data
# Type "yes" to confirm
```

### Testing Script Workflow

```bash
# Setup fresh environment
/testsql setup

# Copy script to container
docker cp my-script.sql dams-sqlserver-dev:/tmp/

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/my-script.sql

# Check results via SSMS or sqlcmd

# If testing succeeded, backup
/testsql backup

# Continue testing or shutdown
/testsql shutdown
```

### Restore to Known Good State

```bash
# Setup container
/testsql setup

# Restore from specific backup
/testsql restore
# Select backup from menu

# Verify restoration
/testsql status
```

## Troubleshooting

### Container Won't Start

**Problem**: `/testsql setup` fails or hangs

**Solutions**:

1. **Check Docker Desktop is running**
   ```bash
   docker info
   ```

2. **Check port 1433 is not in use**
   ```bash
   # Windows
   netstat -ano | findstr :1433

   # Linux/macOS
   lsof -i :1433
   ```

3. **Check logs**
   ```bash
   cd .claude/testSQLSetup
   docker compose logs
   ```

4. **Rebuild container**
   ```bash
   cd .claude/testSQLSetup
   docker compose down
   docker compose build --no-cache
   /testsql setup
   ```

### Cannot Connect via SSMS

**Problem**: Connection timeout or "Server not found"

**Solutions**:

1. **Verify container is running**
   ```bash
   /testsql status
   ```

2. **Check firewall**
   - Windows: Allow Docker Desktop through Windows Firewall
   - Add rule for port 1433 if needed

3. **Try IP address instead of localhost**
   - Server: `127.0.0.1,1433`

4. **Enable "Trust Server Certificate"**
   - In SSMS connection dialog: Options → Connection Properties
   - Check "Trust server certificate"

### Backup Failed

**Problem**: `/testsql backup` returns error

**Solutions**:

1. **Check disk space**
   ```bash
   df -h .claude/testSQLSetup/backups
   ```

2. **Check permissions**
   ```bash
   ls -la .claude/testSQLSetup/backups
   ```

3. **Manual backup**
   ```bash
   docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
     -S localhost -U sa -P 'Pass@word1' \
     -Q "BACKUP DATABASE [capdamstest] TO DISK='/var/opt/mssql/backup/manual.bak' WITH COMPRESSION;"
   ```

### Restore Failed

**Problem**: `/testsql restore` returns error

**Possible Causes**:
- Database is in use (close SSMS connections)
- Backup file is corrupted
- Insufficient disk space

**Solutions**:

1. **Kill active connections**
   ```sql
   ALTER DATABASE capdamstest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   RESTORE DATABASE capdamstest FROM DISK='/var/opt/mssql/backup/backup.bak' WITH REPLACE;
   ALTER DATABASE capdamstest SET MULTI_USER;
   ```

2. **Verify backup file**
   ```bash
   docker exec dams-sqlserver-dev ls -lh /var/opt/mssql/backup/
   ```

3. **Check backup integrity**
   ```sql
   RESTORE VERIFYONLY FROM DISK='/var/opt/mssql/backup/capdamstest_20260126.bak';
   ```

### Out of Memory

**Problem**: Container crashes or SQL Server stops responding

**Solutions**:

1. **Check Docker memory allocation**
   - Docker Desktop → Settings → Resources
   - Increase to 12GB+ if possible

2. **Check container memory**
   ```bash
   docker stats dams-sqlserver-dev
   ```

3. **Restart container**
   ```bash
   /testsql shutdown  # Option 3: Just stop
   /testsql setup
   ```

## Advanced Usage

### Execute SQL Scripts

```bash
# Method 1: Copy script to container
docker cp my-script.sql dams-sqlserver-dev:/tmp/
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/my-script.sql

# Method 2: Mount scripts directory
# Edit docker-compose.yml, add volume:
#   volumes:
#     - ./scripts:/scripts

# Then execute:
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /scripts/my-script.sql
```

### Query Database via Command Line

```bash
# Single query
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest \
  -Q "SELECT * FROM TestTable;"

# Interactive session
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest
```

### Export Data

```bash
# Export table to CSV
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest \
  -Q "SELECT * FROM TestTable;" -o /tmp/export.csv -s "," -W

# Copy to host
docker cp dams-sqlserver-dev:/tmp/export.csv ./export.csv
```

### Performance Monitoring

```bash
# CPU and memory
docker stats dams-sqlserver-dev

# Database size
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest \
  -Q "SELECT (SUM(size)*8/1024) AS SizeMB FROM sys.master_files WHERE database_id = DB_ID();"

# Active connections
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' \
  -Q "SELECT COUNT(*) AS Connections FROM sys.dm_exec_sessions WHERE database_id = DB_ID('capdamstest');"
```

## Best Practices

1. **Backup before major changes**
   ```bash
   /testsql backup
   # Make changes
   # If something goes wrong: /testsql restore
   ```

2. **Regular cleanup**
   - Delete backups older than 30 days
   - Keep at least 2-3 recent backups

3. **Use meaningful backup points**
   ```bash
   # Before testing new feature
   /testsql backup

   # After successful testing
   /testsql backup
   ```

4. **Shutdown when not in use**
   - Saves system resources
   - Frees up memory for other tasks

5. **Monitor disk space**
   ```bash
   df -h .claude/testSQLSetup
   ```

## Integration with CAP-DAMS

### Running DAMS Scripts

```bash
# Copy DAMS script to container
docker cp src/DAMS-Scripts/script.sql dams-sqlserver-dev:/tmp/

# Execute with proper database context
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/script.sql
```

### Testing Script Validator

```bash
# Setup SQL Server
/testsql setup

# Run script validator against test database
dotnet run --project src/ScriptValidator -- \
  --file src/DAMS-Scripts/ProductSpecificScripts/AutoTune/script.sql \
  --connection-string "Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;"
```

## Support

### File Structure

```
.claude/
├── testSQLSetup/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── mssql.conf
│   ├── entrypoint.sh
│   ├── .env
│   ├── setup.sh
│   ├── teardown.sh
│   ├── backup-database.sh
│   ├── restore-database.sh
│   ├── init-scripts/
│   │   └── 01-create-test-database.sql
│   ├── data/          (created on first run)
│   ├── logs/          (created on first run)
│   ├── backups/       (created on first run)
│   ├── README.md
│   ├── README-TESTSQL.md (this file)
│   └── COMMANDS.md
└── skills/
    └── testsql.sh
```

### Getting Help

```bash
# Show help
/testsql help

# Check status
/testsql status

# View Docker logs
cd .claude/testSQLSetup
docker compose logs -f
```

### Related Documentation

- **Main README**: `.claude/testSQLSetup/README.md`
- **Command Reference**: `.claude/testSQLSetup/COMMANDS.md`
- **Rules Reference**: `.claude/rules/testsql-setup.md`

---

**Version**: 1.0
**Created**: 2026-01-26
**Maintained by**: CAP-DAMS Team
