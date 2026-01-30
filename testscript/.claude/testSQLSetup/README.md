# DAMS SQL Server Docker Test Environment

## Overview

This Docker setup provides a fully-configured SQL Server 2022 Developer Edition instance for DAMS testing and development. The container is configured with 6GB RAM, 100GB storage capacity, and full DBA capabilities.

## Features

- **SQL Server 2022 Developer Edition** (full-featured, free)
- **6GB RAM** allocated to SQL Server process
- **100GB storage capacity** across data, logs, and backups
- **Port 1433** exposed for SSMS connectivity
- **SQL Server Agent** enabled
- **Full DBA capabilities**: backup, restore, execute scripts
- **Persistent volumes** for data, logs, and backups
- **Health checks** for container monitoring
- **Automatic initialization** scripts support
- **Query Store** enabled by default

## Prerequisites

- **Docker Desktop** installed and running
  - Download: https://www.docker.com/products/docker-desktop
  - Minimum: 8GB RAM allocated to Docker
  - Minimum: 120GB disk space available
- **Operating System**: Windows 10/11, macOS, or Linux
- **SSMS** (SQL Server Management Studio) for database management
  - Download: https://aka.ms/ssmsfullsetup

## Quick Start

### Recommended: Use /testsql Skill

The easiest way to manage this SQL Server environment is through the `/testsql` skill:

```bash
# Setup and start SQL Server
/testsql setup

# Check status
/testsql status

# Backup database
/testsql backup

# Shutdown with backup
/testsql shutdown
```

See `README-TESTSQL.md` or `.claude/rules/testsql-setup.md` for complete `/testsql` documentation.

### Alternative: Manual Setup

#### 1. Start the SQL Server Container

```bash
# Make scripts executable (Linux/macOS)
chmod +x setup.sh teardown.sh

# Run setup script
./setup.sh
```

**Windows (PowerShell):**
```powershell
# Run setup
.\setup.ps1
```

Or manually:
```bash
docker compose up -d
```

#### 2. Connect via SSMS

**Connection Details:**
- **Server name**: `localhost,1433` or `127.0.0.1,1433`
- **Database**: `capdamstest`
- **Authentication**: SQL Server Authentication
- **Username**: `sa`
- **Password**: `Pass@word1`

**Connection String:**
```
Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;
```

### 3. Verify Setup

```bash
# Check container status
docker ps

# View logs
docker compose logs -f

# Test connection via sqlcmd
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1'
```

## Architecture

### Container Specifications

| Component | Value |
|-----------|-------|
| **Base Image** | mcr.microsoft.com/mssql/server:2022-latest |
| **Container Name** | dams-sqlserver-dev |
| **SQL Server Edition** | Developer (full-featured) |
| **Memory Limit** | 7GB total (6GB for SQL Server process) |
| **CPU Limit** | 4.0 cores |
| **Port** | 1433 (exposed to host) |
| **SQL Server Agent** | Enabled |
| **Collation** | SQL_Latin1_General_CP1_CI_AS |

### Volume Mounts

| Volume | Container Path | Host Path | Purpose | Size |
|--------|----------------|-----------|---------|------|
| **sqlserver_data** | /var/opt/mssql/data | ./data | Database data files (.mdf) | ~60GB |
| **sqlserver_log** | /var/opt/mssql/log | ./logs | Transaction logs (.ldf) | ~30GB |
| **sqlserver_backup** | /var/opt/mssql/backup | ./backups | Database backups (.bak) | ~10GB |
| **sqlserver_secrets** | /var/opt/mssql/secrets | Docker volume | Certificates, keys | - |
| **init-scripts** | /docker-entrypoint-initdb.d | ./init-scripts | Initialization scripts | - |

**Total Allocated Storage**: 100GB+

## File Structure

```
.claude/testSQLSetup/
├── docker-compose.yml          # Main Docker Compose configuration
├── Dockerfile                  # Custom SQL Server image
├── mssql.conf                  # SQL Server configuration file
├── entrypoint.sh              # Container entrypoint script
├── .env                       # Environment variables (SA password, paths)
├── setup.sh                   # Setup script (Linux/macOS)
├── teardown.sh                # Teardown script (Linux/macOS)
├── README.md                  # This file
├── init-scripts/              # SQL scripts executed on first run
│   └── 01-create-test-database.sql
├── data/                      # Database data files (created on first run)
├── logs/                      # SQL Server logs (created on first run)
└── backups/                   # Database backups (created on first run)
```

## Configuration

### Environment Variables (.env)

```bash
# SA password (CHANGE THIS FOR PRODUCTION!)
SA_PASSWORD=Pass@word1

# Volume paths
DATA_PATH=./data
LOG_PATH=./logs
BACKUP_PATH=./backups

# Network configuration
SQLSERVER_PORT=1433

# Container name
CONTAINER_NAME=dams-sqlserver-dev
```

### SQL Server Configuration (mssql.conf)

Key settings:
- **Memory Limit**: 6144 MB (6GB)
- **TCP/IP**: Enabled on port 1433
- **SQL Agent**: Enabled
- **Trace Flag 3226**: Suppress successful backup messages
- **Default Directories**: Configured for data, logs, backups

## DBA Operations

### Backup Database

**Via SSMS:**
1. Right-click database → Tasks → Back Up
2. Destination: `/var/opt/mssql/backup/your_backup.bak`

**Via T-SQL:**
```sql
BACKUP DATABASE [capdamstest]
TO DISK = '/var/opt/mssql/backup/capdamstest_full.bak'
WITH FORMAT, COMPRESSION, STATS = 10;
```

**Via sqlcmd:**
```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -Q "BACKUP DATABASE [capdamstest] TO DISK='/var/opt/mssql/backup/capdamstest.bak' WITH COMPRESSION;"
```

**Access backup file on host:**
```bash
# Backups are in ./backups directory
ls -lh backups/
```

### Restore Database

**Via SSMS:**
1. Right-click Databases → Restore Database
2. Device → Add → `/var/opt/mssql/backup/your_backup.bak`

**Via T-SQL:**
```sql
RESTORE DATABASE [capdamstest]
FROM DISK = '/var/opt/mssql/backup/capdamstest_full.bak'
WITH REPLACE, STATS = 10;
```

### Execute Scripts

**Via SSMS:**
1. File → Open → Open File
2. Execute (F5)

**Via sqlcmd (inside container):**
```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -i /path/to/script.sql
```

**Via sqlcmd (from host):**
```bash
# Copy script to container
docker cp script.sql dams-sqlserver-dev:/tmp/script.sql

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -i /tmp/script.sql
```

**Mount scripts directory:**
```yaml
# Add to docker-compose.yml volumes section:
- ./scripts:/scripts
```

Then execute:
```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -i /scripts/your_script.sql
```

### Create Database

```sql
CREATE DATABASE [YourDatabase]
ON PRIMARY
(
    NAME = N'YourDatabase_Data',
    FILENAME = N'/var/opt/mssql/data/YourDatabase.mdf',
    SIZE = 1024MB,
    FILEGROWTH = 256MB
)
LOG ON
(
    NAME = N'YourDatabase_Log',
    FILENAME = N'/var/opt/mssql/log/YourDatabase_log.ldf',
    SIZE = 512MB,
    FILEGROWTH = 128MB
);
```

### Monitor Performance

```sql
-- Check memory usage
SELECT
    (physical_memory_in_use_kb / 1024) AS memory_used_mb,
    (available_physical_memory_kb / 1024) AS available_memory_mb
FROM sys.dm_os_process_memory;

-- Check database sizes
SELECT
    DB_NAME(database_id) AS DatabaseName,
    (SUM(size) * 8 / 1024) AS SizeMB
FROM sys.master_files
GROUP BY database_id;

-- Active connections
SELECT
    DB_NAME(database_id) AS DatabaseName,
    COUNT(session_id) AS ConnectionCount
FROM sys.dm_exec_sessions
WHERE database_id > 0
GROUP BY database_id;
```

## Docker Commands Reference

### Container Management

```bash
# Start container
docker compose start

# Stop container
docker compose stop

# Restart container
docker compose restart

# View logs (real-time)
docker compose logs -f

# View logs (last 100 lines)
docker compose logs --tail=100

# Check container status
docker compose ps

# Execute command in container
docker exec -it dams-sqlserver-dev bash

# Connect via sqlcmd
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1'
```

### Cleanup

```bash
# Stop and remove container (keep data)
docker compose down

# Stop and remove container + volumes (DELETE ALL DATA)
docker compose down -v

# Remove only stopped containers
docker compose rm

# Prune unused Docker resources
docker system prune
```

### Rebuild Container

```bash
# Rebuild without cache
docker compose build --no-cache

# Rebuild and restart
docker compose up -d --build
```

## Initialization Scripts

Scripts in `init-scripts/` directory are executed automatically on first container startup. They run in alphabetical order.

### Adding New Initialization Scripts

1. Create SQL file in `init-scripts/` directory:
   ```
   init-scripts/
   ├── 01-create-test-database.sql
   ├── 02-create-users.sql
   └── 03-seed-data.sql
   ```

2. Restart container to execute:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Example: Create User Script

```sql
-- init-scripts/02-create-users.sql
USE [master];
GO

CREATE LOGIN [dams_user] WITH PASSWORD = 'P@ssw0rd456!';
GO

USE [capdamstest];
GO

CREATE USER [dams_user] FOR LOGIN [dams_user];
ALTER ROLE db_datareader ADD MEMBER [dams_user];
ALTER ROLE db_datawriter ADD MEMBER [dams_user];
GO
```

## Troubleshooting

### Container Won't Start

**Check Docker logs:**
```bash
docker compose logs
```

**Common issues:**
- Insufficient memory allocated to Docker (need 8GB+)
- Port 1433 already in use
- Incorrect SA password format (must meet complexity requirements)

**Fix port conflict:**
```yaml
# Edit docker-compose.yml, change port mapping:
ports:
  - "1434:1433"  # Use 1434 on host instead

# Or update .env:
SQLSERVER_PORT=1434
```

### Cannot Connect via SSMS

**Verify container is running:**
```bash
docker ps | grep dams-sqlserver
```

**Verify port is exposed:**
```bash
docker port dams-sqlserver-dev
```

**Test connection with sqlcmd:**
```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -Q "SELECT @@VERSION"
```

**Check firewall:**
- Ensure Windows Firewall allows port 1433
- Ensure Docker Desktop is allowed through firewall

**SSMS Connection Options:**
- Enable "Trust Server Certificate" in Connection Properties
- Use IP `127.0.0.1,1433` instead of `localhost,1433`

### Out of Memory

**Check container memory:**
```bash
docker stats dams-sqlserver-dev
```

**Increase Docker memory:**
1. Docker Desktop → Settings → Resources
2. Increase memory to 12GB+ (8GB minimum)

**Check SQL Server memory:**
```sql
SELECT
    (physical_memory_in_use_kb / 1024) AS memory_used_mb
FROM sys.dm_os_process_memory;
```

### Slow Performance

**Check disk space:**
```bash
# On host
df -h

# In container
docker exec -it dams-sqlserver-dev df -h
```

**Check I/O stats:**
```sql
SELECT
    DB_NAME(database_id) AS DatabaseName,
    file_id,
    io_stall_read_ms,
    io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
ORDER BY io_stall_read_ms + io_stall_write_ms DESC;
```

**Optimize Docker performance:**
- Use native filesystem (avoid WSL2 bind mounts on Windows)
- Allocate more CPUs to Docker
- Use SSD for Docker storage

### Data Persistence Issues

**Verify volumes:**
```bash
docker volume ls | grep dams

# Inspect volume
docker volume inspect testSQLSetup_sqlserver_data
```

**Backup before removing volumes:**
```bash
# Backup databases first
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -Q "BACKUP DATABASE [capdamstest] TO DISK='/var/opt/mssql/backup/capdamstest_before_removal.bak'"

# Copy to host
docker cp dams-sqlserver-dev:/var/opt/mssql/backup ./backups/
```

## Security Considerations

### Production Hardening

1. **Change SA password:**
   ```bash
   # Edit .env file
   SA_PASSWORD=YourStrongP@ssw0rd!

   # Recreate container
   docker compose down
   docker compose up -d
   ```

2. **Create non-SA users:**
   ```sql
   CREATE LOGIN [app_user] WITH PASSWORD = 'StrongP@ssw0rd!';
   CREATE USER [app_user] FOR LOGIN [app_user];
   ALTER ROLE db_datareader ADD MEMBER [app_user];
   ALTER ROLE db_datawriter ADD MEMBER [app_user];
   ```

3. **Restrict network access:**
   ```yaml
   # docker-compose.yml - bind to localhost only
   ports:
     - "127.0.0.1:1433:1433"
   ```

4. **Enable TLS/SSL:**
   - Generate certificates
   - Mount to `/var/opt/mssql/secrets`
   - Configure in `mssql.conf`

5. **Regular backups:**
   ```bash
   # Add to cron/Task Scheduler
   docker exec dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -Q "BACKUP DATABASE [capdamstest] TO DISK='/var/opt/mssql/backup/capdamstest_$(date +%Y%m%d_%H%M%S).bak' WITH COMPRESSION"
   ```

## Performance Tuning

### Increase Memory

```yaml
# docker-compose.yml
environment:
  - MSSQL_MEMORY_LIMIT_MB=8192  # 8GB

mem_limit: 10g
mem_reservation: 8g
```

### Increase CPU

```yaml
# docker-compose.yml
cpus: 8.0
```

### Optimize Database

```sql
-- Update statistics
EXEC sp_updatestats;

-- Rebuild indexes
ALTER INDEX ALL ON [TableName] REBUILD;

-- Update database compatibility level
ALTER DATABASE [capdamstest] SET COMPATIBILITY_LEVEL = 160; -- SQL Server 2022
```

## Integration with DAMS

### Connection String for DAMS Scripts

```csharp
// C# connection string
var connectionString = "Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;";
```

### Running DAMS Scripts

```bash
# Copy DAMS scripts to container
docker cp src/DAMS-Scripts dams-sqlserver-dev:/scripts/

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' \
  -i /scripts/ProductSpecificScripts/AutoTune/SomeScript.sql
```

### ScriptValidator Testing

```bash
# Mount DAMS-Scripts directory for validation
docker run --rm \
  -v "$(pwd)/src/DAMS-Scripts:/scripts" \
  -v "$(pwd)/src/ScriptValidator:/validator" \
  dams-sqlserver-dev \
  bash -c "cd /validator && dotnet run -- --directory /scripts"
```

## Maintenance

### Regular Tasks

1. **Check disk space** (weekly)
   ```bash
   docker exec dams-sqlserver-dev df -h
   ```

2. **Backup databases** (daily)
   ```bash
   ./backup.sh  # Create this script
   ```

3. **Check logs** (daily)
   ```bash
   docker compose logs --tail=100
   ```

4. **Update statistics** (weekly)
   ```sql
   EXEC sp_updatestats;
   ```

5. **Rebuild indexes** (monthly)
   ```sql
   EXEC sp_MSforeachtable 'ALTER INDEX ALL ON ? REBUILD';
   ```

## PR Test Organization

### Folder Structure for PR Testing

All test artifacts for PR validation are organized by PR ID:

```
.claude/testSQLSetup/
├── {PR_ID}/                          # One folder per PR (e.g., 14514176)
│   ├── README.md                     # Overview of test artifacts
│   ├── Test_*.sql                    # Test scripts for the PR
│   ├── TEST_RESULTS_*.md             # Detailed test execution results
│   ├── RUN_TESTS.md                  # Quick start guide for reviewers
│   ├── PR_COMMENT_*.md               # Formatted comments for PR
│   └── PR_DESCRIPTION_*.md           # PR description templates
├── data/                             # SQL Server data files
├── logs/                             # SQL Server logs
├── backups/                          # Database backups
├── init-scripts/                     # Startup scripts
├── docker-compose.yml                # Container configuration
├── Dockerfile                        # Custom SQL Server image
└── README.md                         # This file
```

### Example: PR #14514176

```
.claude/testSQLSetup/14514176/
├── README.md                                    # Test overview
├── Test_DropUnusedIndexDMV.sql                 # Comprehensive test (719 lines)
├── TEST_RESULTS_DropUnusedIndexDMV.md          # Detailed results (10/10 passed)
├── RUN_TESTS.md                                # Quick start for reviewers
├── PR_COMMENT_TEST_RESULTS.md                  # Posted to PR
└── PR_DESCRIPTION_CONCISE.md                   # Used in PR description
```

### Workflow for PR Testing

1. **Create PR folder**: `.claude/testSQLSetup/{PR_ID}/`
2. **Develop test script**: `Test_*.sql` with mock data
3. **Run tests**: Against Docker SQL Server container
4. **Document results**: Create `TEST_RESULTS_*.md`
5. **Create quick start**: Write `RUN_TESTS.md` for reviewers
6. **Update PR**: Post test results as comment and update description

### Running Tests from PR Folder

```bash
# Copy test script from PR folder to container
docker cp .claude/testSQLSetup/14514176/Test_DropUnusedIndexDMV.sql dams-sqlserver-dev:/tmp/

# Execute test
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -C \
  -i /tmp/Test_DropUnusedIndexDMV.sql
```

### Benefits of PR-Based Organization

- ✅ **Isolated**: Each PR's tests are self-contained
- ✅ **Traceable**: Easy to find test artifacts by PR number
- ✅ **Reusable**: Tests can be re-run for regression validation
- ✅ **Documented**: README in each folder explains the tests
- ✅ **Gitignored**: Test artifacts not committed to repo (in `.gitignore`)

## Support & Resources

### Official Documentation

- **SQL Server on Docker**: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- **SQL Server 2022**: https://learn.microsoft.com/en-us/sql/sql-server/
- **Docker Compose**: https://docs.docker.com/compose/

### Internal Resources

- **DAMS Documentation**: See `README.md` in repo root
- **Script Validator**: See `src/ScriptValidator/README.md`
- **SQL Script Guidelines**: See `src/DAMS-Scripts/ProductionInvestigationScripts/pull_request_template.md`

### Contact

- **Team**: capdsdataengine@microsoft.com
- **Issues**: https://github.com/anthropics/claude-code/issues

## License

This setup is for internal Microsoft use with CAP-DAMS development and testing.

SQL Server Developer Edition is free for non-production use.

---

**Created**: 2026-01-26
**Version**: 1.0
**Maintained by**: CAP-DAMS Team
