# YourProject SQL Server Test Environment - Setup Summary

## What Was Created

This document summarizes the complete SQL Server Docker test environment created for YourProject development.

## Key Features

✅ **SQL Server 2022 Developer Edition** in Docker container
✅ **6GB RAM** allocated to SQL Server process
✅ **100GB storage** capacity (data + logs + backups)
✅ **Port 1433** exposed for SSMS connectivity
✅ **Full DBA capabilities**: backup, restore, execute scripts
✅ **/testsql skill** for easy management
✅ **Automatic backups** on shutdown
✅ **Persistent volumes** for data retention
✅ **Health checks** for monitoring
✅ **Query Store** enabled by default

## Configuration

### Database Settings

| Setting | Value |
|---------|-------|
| **Database Name** | testdb |
| **Server** | localhost,1433 |
| **Username** | sa |
| **Password** | YourSecurePassword123! |
| **SQL Server Edition** | Developer (full-featured, free) |
| **SQL Server Agent** | Enabled |
| **Query Store** | Enabled |
| **Recovery Model** | FULL |

### Connection String

```
Server=localhost,1433;Database=testdb;User Id=sa;Password=YourSecurePassword123!;TrustServerCertificate=True;
```

### SSMS Connection

1. Server: `localhost,1433`
2. Authentication: SQL Server Authentication
3. Login: `sa`
4. Password: `YourSecurePassword123!`
5. Enable "Trust Server Certificate"

## Files Created

### Core Configuration Files

```
.claude/testSQLSetup/
├── docker-compose.yml              ✅ Main Docker Compose configuration
├── Dockerfile                      ✅ Custom SQL Server image
├── mssql.conf                      ✅ SQL Server configuration
├── entrypoint.sh                   ✅ Container startup script
├── .env                           ✅ Environment variables (credentials, paths)
├── setup.sh                       ✅ Setup script (Linux/macOS)
├── setup.ps1                      ✅ Setup script (Windows PowerShell)
├── teardown.sh                    ✅ Cleanup script
├── backup-database.sh             ✅ Backup script
├── restore-database.sh            ✅ Restore script
└── init-scripts/
    └── 01-create-test-database.sql ✅ Auto-creates testdb database
```

### Documentation Files

```
.claude/testSQLSetup/
├── README.md                       ✅ Complete technical documentation
├── README-TESTSQL.md              ✅ /testsql skill user guide
├── COMMANDS.md                     ✅ Quick command reference
└── SETUP-SUMMARY.md               ✅ This file
```

### Skill Implementation

```
.claude/
├── skills/
│   └── testsql.sh                 ✅ /testsql skill implementation
└── rules/
    └── testsql-setup.md           ✅ Reference guide for Claude
```

### Runtime Directories (created on first run)

```
.claude/testSQLSetup/
├── data/                          📁 Database files (.mdf) - ~60GB
├── logs/                          📁 SQL Server logs (.ldf) - ~30GB
└── backups/                       📁 Database backups (.bak) - ~10GB
```

## /testsql Skill Commands

### Primary Commands

```bash
# Setup and start SQL Server (checks prerequisites, handles backups)
/testsql setup

# Shutdown with backup options (3 modes: backup+remove, full cleanup, just stop)
/testsql shutdown

# Show status (container, SQL Server, database, backups)
/testsql status

# Backup database (timestamped, compressed)
/testsql backup

# Restore from backup (interactive selection)
/testsql restore

# Show help
/testsql help
```

### Usage Examples

```bash
# Daily workflow
/testsql setup          # Morning: Start SQL Server
# ... work throughout the day ...
/testsql shutdown       # Evening: Backup and shutdown

# Check everything is working
/testsql status

# Before risky operation
/testsql backup

# Recover from mistake
/testsql restore
```

## Prerequisites Checked

The `/testsql setup` command automatically checks:

✅ **Docker Desktop** installed and running
✅ **Docker Compose** available
✅ **Docker Memory** 8GB+ recommended
✅ **Disk Space** 120GB+ available
✅ **Port 1433** available (not in use)
⚠ **SSMS** installed (optional, Windows only)

## Container Specifications

| Component | Value |
|-----------|-------|
| **Base Image** | mcr.microsoft.com/mssql/server:2022-latest |
| **Container Name** | sqlserver-dev |
| **Memory Limit** | 7GB total (6GB for SQL Server) |
| **CPU Limit** | 4.0 cores |
| **Port** | 1433 |
| **Restart Policy** | unless-stopped |
| **Health Check** | Every 30 seconds |

## Volume Mounts

| Volume | Host Path | Container Path | Purpose |
|--------|-----------|----------------|---------|
| **sqlserver_data** | ./data | /var/opt/mssql/data | Database files (.mdf) |
| **sqlserver_log** | ./logs | /var/opt/mssql/log | Transaction logs (.ldf) |
| **sqlserver_backup** | ./backups | /var/opt/mssql/backup | Backups (.bak) |
| **sqlserver_secrets** | Docker volume | /var/opt/mssql/secrets | Certificates, keys |
| **init-scripts** | ./init-scripts | /docker-entrypoint-initdb.d | Initialization scripts |

## Default Database Schema

### Tables Created on First Run

**TestTable** (in testdb database):
```sql
CREATE TABLE dbo.TestTable
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(256) NOT NULL,
    CreatedOn DATETIME NOT NULL DEFAULT GETUTCDATE(),
    ModifiedOn DATETIME NULL
);
```

**Sample Data**:
- 'YourProject Test Record 1'
- 'YourProject Test Record 2'
- 'YourProject Test Record 3'

## Backup Management

### Automatic Backups

- **Trigger**: `/testsql shutdown` (options 1 & 2)
- **Format**: `testdb_YYYYMMDD_HHMMSS.bak`
- **Location**: `.claude/testSQLSetup/backups/`
- **Compression**: Enabled (~70% space savings)

### Manual Backups

```bash
# Via /testsql skill
/testsql backup

# Via script
./backup-database.sh testdb

# Via sqlcmd
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' \
  -Q "BACKUP DATABASE [testdb] TO DISK='/var/opt/mssql/backup/manual.bak' WITH COMPRESSION;"
```

### Restore Operations

```bash
# Via /testsql skill (interactive)
/testsql restore

# Via script
./restore-database.sh testdb_20260126.bak testdb

# Via sqlcmd
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' \
  -Q "RESTORE DATABASE [testdb] FROM DISK='/var/opt/mssql/backup/backup.bak' WITH REPLACE;"
```

## Common Operations

### Execute SQL Script

```bash
# Method 1: Copy and execute
docker cp script.sql sqlserver-dev:/tmp/
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb -i /tmp/script.sql

# Method 2: Direct query
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb \
  -Q "SELECT * FROM TestTable;"
```

### Access Container

```bash
# Interactive SQL session
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb

# Bash shell
docker exec -it sqlserver-dev bash

# View logs
docker exec sqlserver-dev tail -f /var/opt/mssql/log/errorlog
```

### Monitor Resources

```bash
# Container stats
docker stats sqlserver-dev

# SQL Server memory
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' \
  -Q "SELECT (physical_memory_in_use_kb/1024) AS memory_used_mb FROM sys.dm_os_process_memory;"

# Database size
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' \
  -Q "SELECT DB_NAME(database_id) AS DatabaseName, (SUM(size)*8/1024) AS SizeMB FROM sys.master_files GROUP BY database_id;"
```

## Integration with YourProject

### Running DAMS Scripts

```bash
# Copy DAMS script to container
docker cp src/DAMS-Scripts/ProductSpecificScripts/script.sql sqlserver-dev:/tmp/

# Execute with proper database
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb -i /tmp/script.sql
```

### Testing with ScriptValidator

```bash
# Setup SQL Server
/testsql setup

# Run ScriptValidator
cd src/ScriptValidator
dotnet run -- \
  --file ../DAMS-Scripts/ProductSpecificScripts/script.sql \
  --connection-string "Server=localhost,1433;Database=testdb;User Id=sa;Password=YourSecurePassword123!;TrustServerCertificate=True;"
```

### Testing Unused Index Feature

```bash
# Setup
/testsql setup

# Copy script
docker cp src/DAMS-Scripts/ProductionInvestigationScripts/Mitigation/DAMS/GetUnusedIndexPreProd.sql \
  sqlserver-dev:/tmp/

# Execute (after editing JSON parameter)
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb -i /tmp/GetUnusedIndexPreProd.sql
```

## Troubleshooting

### Issue: Container won't start

**Check**:
```bash
docker info                    # Docker Desktop running?
netstat -ano | findstr :1433  # Port 1433 available? (Windows)
df -h                         # Disk space available?
```

**Fix**:
```bash
cd .claude/testSQLSetup
docker compose down
docker compose build --no-cache
/testsql setup
```

### Issue: Cannot connect via SSMS

**Solutions**:
1. Verify container running: `/testsql status`
2. Use IP instead: `127.0.0.1,1433`
3. Enable "Trust Server Certificate" in SSMS
4. Check Windows Firewall allows Docker

### Issue: Out of memory

**Fix**:
1. Docker Desktop → Settings → Resources
2. Increase memory to 12GB+
3. Restart Docker Desktop
4. `/testsql setup`

### Issue: Backup/Restore failed

**Common causes**:
- Database in use (close SSMS connections)
- Insufficient disk space
- Corrupted backup file

**Fix**:
```bash
# Check disk space
df -h .claude/testSQLSetup/backups

# Kill connections and retry
docker exec -it sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' \
  -Q "ALTER DATABASE testdb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"

# Then retry backup/restore
```

## Next Steps

### First Time Setup

1. **Verify Docker Desktop is running**
   ```bash
   docker info
   ```

2. **Setup SQL Server**
   ```bash
   /testsql setup
   ```

3. **Connect via SSMS**
   - Server: `localhost,1433`
   - Login: `sa` / `YourSecurePassword123!`

4. **Run test query**
   ```sql
   SELECT * FROM testdb.dbo.TestTable;
   ```

5. **Backup when done**
   ```bash
   /testsql backup
   /testsql shutdown
   ```

### Daily Workflow

```bash
# Morning
/testsql setup

# Work in SSMS, run scripts, test features...

# Evening
/testsql backup    # Optional: Save current state
/testsql shutdown  # Option 1: Backup and remove
```

### Weekly Maintenance

```bash
# Check status and backups
/testsql status

# Clean up old backups (keep last 3-5)
ls -lt .claude/testSQLSetup/backups/
rm .claude/testSQLSetup/backups/testdb_old*.bak

# Optional: Full cleanup
/testsql shutdown  # Option 2: Remove all data
```

## Documentation References

| Document | Purpose | Location |
|----------|---------|----------|
| **README.md** | Complete technical documentation | `.claude/testSQLSetup/README.md` |
| **README-TESTSQL.md** | /testsql skill user guide | `.claude/testSQLSetup/README-TESTSQL.md` |
| **COMMANDS.md** | Quick command reference | `.claude/testSQLSetup/COMMANDS.md` |
| **testsql-setup.md** | Claude reference guide | `.claude/rules/testsql-setup.md` |
| **SETUP-SUMMARY.md** | This document | `.claude/testSQLSetup/SETUP-SUMMARY.md` |

## Support

### Getting Help

```bash
# Skill help
/testsql help

# Check status
/testsql status

# View Docker logs
cd .claude/testSQLSetup
docker compose logs -f

# Check SQL Server error log
docker exec sqlserver-dev tail -f /var/opt/mssql/log/errorlog
```

### Team Contact

**YourProject Team**: team@example.com

### External Resources

- Docker: https://docs.docker.com/
- SQL Server on Docker: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- SSMS: https://aka.ms/ssmsfullsetup

---

## Summary

✅ **Complete SQL Server 2022 test environment** ready to use
✅ **Easy management** via `/testsql` skill
✅ **Automatic backups** with multiple shutdown options
✅ **Full DBA capabilities** for testing YourProject scripts
✅ **Comprehensive documentation** for all scenarios

**Quick Start**: Run `/testsql setup` to begin!

---

**Created**: 2026-01-26
**Version**: 1.0
**Maintained by**: YourProject Team
