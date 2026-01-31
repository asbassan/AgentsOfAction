# ✅ SQL Server Docker Test Environment - Complete Setup

## Summary

A complete SQL Server 2022 Docker test environment for CAP-DAMS has been successfully created with:

- **SQL Server 2022 Developer Edition** (full-featured, free)
- **6GB RAM** allocated to SQL Server process
- **100GB storage** (data + logs + backups)
- **Port 1433** exposed for SSMS connectivity
- **Full DBA capabilities**: backup, restore, execute scripts
- **/testsql skill** for easy management
- **Automatic prerequisite checking**
- **Intelligent backup/restore workflows**
- **Comprehensive documentation**

---

## 📁 What Was Created

### Core Configuration Files

```
.claude/testSQLSetup/
├── docker-compose.yml              ✅ Main Docker Compose configuration
├── Dockerfile                      ✅ Custom SQL Server 2022 image
├── mssql.conf                      ✅ SQL Server configuration (6GB RAM)
├── entrypoint.sh                   ✅ Container startup script
├── .env                            ✅ Environment variables
│                                       - SA_PASSWORD=Pass@word1
│                                       - DATABASE_NAME=capdamstest
├── setup.sh                        ✅ Setup script (Linux/macOS)
├── setup.ps1                       ✅ Setup script (Windows PowerShell)
├── teardown.sh                     ✅ Cleanup script
├── backup-database.sh              ✅ Backup utility script
├── restore-database.sh             ✅ Restore utility script
└── init-scripts/
    └── 01-create-test-database.sql ✅ Auto-creates capdamstest database
```

### Documentation Files

```
.claude/testSQLSetup/
├── README.md                       ✅ Complete technical documentation
├── README-TESTSQL.md              ✅ /testsql skill user guide
├── COMMANDS.md                     ✅ Quick Docker command reference
├── SETUP-SUMMARY.md               ✅ Setup summary document
└── SQL-SERVER-SETUP-COMPLETE.md   ✅ This file
```

### Skill Implementation

```
.claude/
├── skills/
│   └── testsql.sh                 ✅ /testsql skill implementation (18KB)
└── rules/
    └── testsql-setup.md           ✅ Claude reference guide (12KB)
```

### Runtime Directories

```
.claude/testSQLSetup/
├── data/          📁 Database files (.mdf) - ~60GB capacity
├── logs/          📁 SQL Server logs (.ldf) - ~30GB capacity
└── backups/       📁 Database backups (.bak) - ~10GB capacity
```

---

## 🎯 Database Configuration

| Setting | Value |
|---------|-------|
| **Database Name** | `capdamstest` |
| **Server** | `localhost,1433` |
| **Username** | `sa` |
| **Password** | `Pass@word1` |
| **Container Name** | `dams-sqlserver-dev` |
| **SQL Server Edition** | Developer Edition (full-featured, free) |

**Connection String**:
```
Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;
```

**SSMS Connection**:
1. Server name: `localhost,1433`
2. Authentication: SQL Server Authentication
3. Login: `sa`
4. Password: `Pass@word1`
5. Enable "Trust Server Certificate"

---

## 🚀 /testsql Skill Commands

The `/testsql` skill provides easy management of the SQL Server environment.

### Available Commands

```bash
# Setup and start SQL Server (checks prerequisites, handles backups)
/testsql setup

# Shutdown with backup options (3 modes)
/testsql shutdown

# Show status (container, database, backups)
/testsql status

# Backup database (timestamped, compressed)
/testsql backup

# Restore from backup (interactive selection)
/testsql restore

# Show help
/testsql help
```

### Quick Start

```bash
# 1. Start SQL Server
/testsql setup

# 2. Check everything is working
/testsql status

# 3. Connect via SSMS to localhost,1433 (sa / Pass@word1)
# 4. Work with database...

# 5. When done, backup and shutdown
/testsql shutdown
```

---

## ✅ Prerequisites Automatically Checked

The `/testsql setup` command verifies:

- ✅ Docker Desktop installed and running
- ✅ Docker Compose available
- ✅ Docker memory allocation (8GB+ recommended)
- ✅ Available disk space (120GB+ recommended)
- ✅ Port 1433 is available (not in use)
- ⚠️ SSMS installed (optional, Windows only)

---

## 💾 Backup Management

### Automatic Backups

- **Trigger**: `/testsql shutdown` (options 1 & 2)
- **Format**: `capdamstest_YYYYMMDD_HHMMSS.bak`
- **Location**: `.claude/testSQLSetup/backups/`
- **Compression**: Enabled (~70% space savings)

### Shutdown Options

When you run `/testsql shutdown`, you get 4 options:

**1. Backup → Remove container (keep data volumes)**
   - ✅ Recommended for daily shutdown
   - ✅ Quick restart, no data re-download
   - ✅ Preserves data in volumes
   - ✅ Backup created before removal

**2. Backup → Remove container and ALL data**
   - ⚠️ Complete cleanup
   - ⚠️ Requires "yes" confirmation
   - ⚠️ Frees all disk space
   - ✅ Backup created before deletion

**3. Just stop container (no backup)**
   - ⚡ Quick stop without backup
   - ⚡ Use `docker compose start` to resume
   - ⚡ No data lost

**4. Cancel**
   - ❌ Abort shutdown

---

## 📋 Common Workflows

### Daily Development Workflow

```bash
# Morning - Start SQL Server
/testsql setup

# Throughout the day...
# - Connect via SSMS to localhost,1433
# - Run queries and test scripts
# - Create tables, indexes, etc.

# Evening - Shutdown with backup
/testsql shutdown    # Select option 1
```

### Testing Script Changes

```bash
# Setup and create safety backup
/testsql setup
/testsql backup

# Copy script to container
docker cp my-script.sql dams-sqlserver-dev:/tmp/

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/my-script.sql

# If script failed, restore previous state
/testsql restore

# If script succeeded, create new backup
/testsql backup
```

### Weekly Cleanup

```bash
# Check status and available backups
/testsql status

# Delete old backups manually (optional)
rm .claude/testSQLSetup/backups/capdamstest_202601*.bak

# Full cleanup
/testsql shutdown    # Select option 2, type "yes" to confirm
```

---

## 🔧 Container Specifications

| Component | Value |
|-----------|-------|
| **Base Image** | mcr.microsoft.com/mssql/server:2022-latest |
| **Container Name** | dams-sqlserver-dev |
| **Memory Limit** | 7GB total (6GB for SQL Server process) |
| **CPU Limit** | 4.0 cores |
| **Port** | 1433 (exposed to host) |
| **SQL Server Agent** | Enabled |
| **Query Store** | Enabled (for performance analysis) |
| **Recovery Model** | FULL (for backup/restore testing) |
| **Collation** | SQL_Latin1_General_CP1_CI_AS |
| **Restart Policy** | unless-stopped |

---

## 🔍 Integration with CAP-DAMS

### Running DAMS Scripts

```bash
# Copy DAMS script to container
docker cp src/DAMS-Scripts/ProductSpecificScripts/script.sql dams-sqlserver-dev:/tmp/

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/script.sql
```

### Testing with ScriptValidator

```bash
# Setup SQL Server
/testsql setup

# Run ScriptValidator with test database
cd src/ScriptValidator
dotnet run -- \
  --file ../DAMS-Scripts/ProductSpecificScripts/script.sql \
  --connection-string "Server=localhost,1433;Database=capdamstest;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;"
```

### Testing Unused Index Scripts

```bash
# Setup and create test data
/testsql setup

# Create test indexes
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest \
  -Q "CREATE INDEX IX_Test ON TestTable(Name);"

# Copy GetUnusedIndexPreProd.sql to container
docker cp src/DAMS-Scripts/ProductionInvestigationScripts/Mitigation/DAMS/GetUnusedIndexPreProd.sql \
  dams-sqlserver-dev:/tmp/

# Execute script (after editing JSON parameter)
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -i /tmp/GetUnusedIndexPreProd.sql
```

---

## 📖 Documentation Reference

| Document | Purpose | Location |
|----------|---------|----------|
| **README.md** | Complete technical documentation (Docker, SSMS, DBA ops) | `.claude/testSQLSetup/README.md` |
| **README-TESTSQL.md** | /testsql skill user guide (commands, workflows) | `.claude/testSQLSetup/README-TESTSQL.md` |
| **COMMANDS.md** | Quick Docker/SQL command reference | `.claude/testSQLSetup/COMMANDS.md` |
| **SETUP-SUMMARY.md** | Detailed setup summary | `.claude/testSQLSetup/SETUP-SUMMARY.md` |
| **testsql-setup.md** | Claude reference guide | `.claude/rules/testsql-setup.md` |
| **SQL-SERVER-SETUP-COMPLETE.md** | This document | `.claude/testSQLSetup/SQL-SERVER-SETUP-COMPLETE.md` |

---

## ⚡ Quick Operations

### Execute SQL Query

```bash
# Single query
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest \
  -Q "SELECT * FROM TestTable;"

# Interactive SQL session
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest
```

### View Logs

```bash
# Real-time container logs
cd .claude/testSQLSetup
docker compose logs -f

# SQL Server error log
docker exec dams-sqlserver-dev tail -f /var/opt/mssql/log/errorlog
```

### Monitor Resources

```bash
# Real-time stats
docker stats dams-sqlserver-dev

# Check status (via skill)
/testsql status
```

---

## 🛠️ Troubleshooting

### Container Won't Start

```bash
# Check Docker Desktop is running
docker info

# Check port 1433 is free (Windows)
netstat -ano | findstr :1433

# Rebuild container
cd .claude/testSQLSetup
docker compose down
docker compose build --no-cache
/testsql setup
```

### Cannot Connect via SSMS

**Solutions**:
1. Verify container is running: `/testsql status`
2. Try IP address: `127.0.0.1,1433` instead of `localhost,1433`
3. Enable "Trust Server Certificate" in SSMS connection dialog
4. Check Windows Firewall allows Docker Desktop
5. Restart Docker Desktop

### Backup/Restore Failed

```bash
# Check disk space
df -h .claude/testSQLSetup/backups

# Kill active connections if needed
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' \
  -Q "ALTER DATABASE capdamstest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"

# Retry operation
/testsql backup
# or
/testsql restore
```

---

## 🎯 Next Steps

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
   - Login: `sa` / `Pass@word1`
   - Database: `capdamstest`

4. **Run test query**
   ```sql
   USE capdamstest;
   SELECT * FROM dbo.TestTable;
   ```

5. **Shutdown when done**
   ```bash
   /testsql shutdown
   ```

---

## 📝 Key Features

✅ **Easy Setup**: Single command `/testsql setup` with prerequisite checking
✅ **Automatic Backups**: Intelligent shutdown with 3 backup options
✅ **Persistent Storage**: Data survives container restarts
✅ **Full DBA Access**: Backup, restore, execute scripts, create databases
✅ **Resource Management**: 6GB RAM, 100GB storage
✅ **Health Monitoring**: Automatic health checks every 30 seconds
✅ **Query Store**: Enabled for performance analysis
✅ **SQL Server Agent**: Enabled for job scheduling
✅ **Comprehensive Docs**: Complete guides for all scenarios
✅ **CAP-DAMS Integration**: Ready to test all DAMS scripts

---

## 🎉 Summary

You now have a **complete, production-ready SQL Server 2022 test environment** for CAP-DAMS development!

### What You Can Do Now

1. **Start developing**: `/testsql setup`
2. **Connect via SSMS**: `localhost,1433` (sa / Pass@word1)
3. **Run DAMS scripts**: Test any script from `src/DAMS-Scripts/`
4. **Backup anytime**: `/testsql backup`
5. **Shutdown safely**: `/testsql shutdown` with automatic backup

### Key Commands to Remember

```bash
/testsql setup      # Start SQL Server
/testsql status     # Check status
/testsql backup     # Save current state
/testsql restore    # Rollback to previous state
/testsql shutdown   # Stop with backup
```

---

## 📞 Support

### Getting Help

```bash
# Show help
/testsql help

# Check status
/testsql status

# View logs
cd .claude/testSQLSetup
docker compose logs -f
```

### Team Contact

**CAP-DAMS Team**: capdsdataengine@microsoft.com

### External Resources

- **Docker**: https://docs.docker.com/
- **SQL Server on Docker**: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- **SSMS**: https://aka.ms/ssmsfullsetup

---

**Created**: 2026-01-26
**Version**: 1.0
**Maintained by**: CAP-DAMS Team
