# /testsql - SQL Server Test Environment Manager

Complete reference documentation for the `/testsql` agent-based skill.

---

## Overview

The `/testsql` skill is an **agent-based skill** (no bash script, Claude executes it) that manages a Docker-based SQL Server 2022 test environment for CAP-DAMS development.

### Key Features

✅ **Smart Database Detection** - Automatically detects database name from scripts
✅ **Default Northwind Database** - Sample database created if no script provided
✅ **Bootstrap Scripts** - Run custom SQL scripts on setup
✅ **Automatic Backups** - Timestamped backups on shutdown
✅ **Easy Restore** - Restore from any backup file
✅ **Clear Connection Info** - SSMS-ready credentials displayed

---

## Prerequisites

### Required Software

#### 1. Docker Desktop

**Minimum Requirements:**
- **Memory**: 8GB allocated to Docker (6GB minimum)
- **Disk Space**: 120GB free space (50GB minimum)
- **Docker Version**: 20.0+ with Compose v2.0+

**Windows:**
1. Download: https://www.docker.com/products/docker-desktop
2. Install Docker Desktop
3. Open Docker Desktop → Settings → Resources
4. Set Memory: 8192 MB (8GB)
5. Set Disk image size: 120GB
6. Apply & Restart

**macOS:**
1. Download: https://www.docker.com/products/docker-desktop
2. Drag Docker.app to Applications
3. Open Docker Desktop → Preferences → Resources
4. Set Memory: 8GB
5. Set Disk image size: 120GB
6. Apply & Restart

**Linux:**
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose plugin
sudo apt-get install docker-compose-plugin

# Add user to docker group (avoid sudo)
sudo usermod -aG docker $USER
newgrp docker
```

**Verify Installation:**
```bash
docker --version
# Expected: Docker version 20.0+ or higher

docker compose version
# Expected: Docker Compose version v2.0+ or higher

docker info | grep "Total Memory"
# Expected: Total Memory: 8.0+ GiB
```

---

#### 2. Shell Environment (for Windows users)

**The `/testsql` skill uses bash commands.** Windows users need one of:

**Option A: Git Bash (Recommended)**
- Included with Git for Windows: https://git-scm.com/download/win
- Already installed if you use Git
- Supports all `/testsql` commands

**Option B: Windows Subsystem for Linux (WSL 2)**
- Install: https://learn.microsoft.com/en-us/windows/wsl/install
- Better Docker integration
- Native Linux environment

**Option C: PowerShell**
- Built into Windows
- May require command syntax adjustments
- Less tested with `/testsql`

**macOS/Linux users:** Native bash/zsh already available ✓

---

#### 3. No SQL Tools Needed on Host!

**Important:** You do NOT need to install SQL Server tools on your host machine.

❌ **NOT required on host:**
- SQL Server
- sqlcmd
- mssql-tools
- ODBC drivers

✅ **All SQL tools are inside the Docker container:**
- `/opt/mssql-tools18/bin/sqlcmd` (inside container)
- SQL Server 2022 (inside container)
- All necessary drivers (inside container)

The `/testsql` skill manages everything via `docker exec` commands.

---

### Optional Software

#### SQL Server Management Studio (SSMS)

**Platform:** Windows only
**Version:** 19.0+ recommended
**Download:** https://aka.ms/ssmsfullsetup

**Features:**
- Full GUI for database management
- Query editor with IntelliSense
- Object Explorer
- Backup/restore wizards
- Best for Windows developers

---

#### Azure Data Studio

**Platform:** Windows, macOS, Linux
**Version:** 1.40+ recommended
**Download:** https://aka.ms/azuredatastudio

**Features:**
- Cross-platform SQL editor
- Modern UI with extensions
- Notebooks support
- Git integration
- Best for cross-platform teams

---

## Commands

### /testsql setup [scriptname]

Setup SQL Server with optional bootstrap script.

```bash
# Default: Northwind sample database in testdb
/testsql setup

# Custom script WITH CREATE DATABASE
/testsql setup my-database.sql

# Custom script WITHOUT CREATE DATABASE (uses testdb)
/testsql setup schema-only.sql
```

**Output:**
```
========================================
  SQL Server Connection Information
========================================
Server Name:    localhost,1433
Database Name:  testdb
Username:       sa
Password:       Pass@word1

Connection String:
Server=localhost,1433;Database=testdb;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;
========================================
```

---

### /testsql backup

Backup current database to bootstrap folder.

```bash
/testsql backup
```

**Output:**
```
✓ Backup completed successfully

Backup Details:
  File: testdb_20260129_143022.bak
  Location: .claude/testSQL/bootstrap/
  Size: 15.2 MB (compressed)
```

---

### /testsql restore <filename>

Restore database from backup file.

```bash
# Specific backup
/testsql restore testdb_20260129_143022.bak

# Interactive menu (lists all backups)
/testsql restore
```

**Output:**
```
✓ Database restored successfully

Restore Details:
  Database: testdb
  Size: 45.6 MB
  Source: testdb_20260129_143022.bak
```

---

### /testsql shutdown

Backup and teardown container.

```bash
/testsql shutdown
```

**Output:**
```
========================================
  Shutdown Complete
========================================
✓ Backup created: testdb_20260129_173045.bak
✓ Container stopped and removed
✓ Data volumes preserved
✓ Port 1433 released
✓ Memory freed: ~7 GB

Next startup will be fast (~30 seconds)
========================================
```

---

### /testsql status

Show connection info and system status.

```bash
/testsql status
```

**Output:**
```
========================================
  SQL Server Status
========================================
Container: ✓ Running (2h 34m uptime)
CPU: 12.5% | Memory: 6.2/7.0 GB
SQL Server Version: 2022 (RTM) 16.0.1000.6

========================================
  Connection Information
========================================
Server:     localhost,1433
Database:   testdb
Username:   sa
Password:   Pass@word1

Connection String:
Server=localhost,1433;Database=testdb;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;

========================================
  Available Backups
========================================
testdb_20260129_143022.bak  15.2 MB
testdb_20260128_091534.bak  12.8 MB

Total: 2 backups, 28.0 MB
========================================
```

---

## Database Creation Logic

### Scenario 1: No Script (Default)

```bash
/testsql setup
```

**Result:**
- Creates `testdb` with Northwind sample data
- Tables: Customers, Orders, Products
- Sample data included

---

### Scenario 2: Script WITH `CREATE DATABASE`

```sql
-- .claude/testSQL/bootstrap/my-db.sql
CREATE DATABASE MyCustomDB;
GO
USE MyCustomDB;
GO
CREATE TABLE Users (ID INT PRIMARY KEY);
```

```bash
/testsql setup my-db.sql
```

**Result:**
- Database name: `MyCustomDB` (detected from script)
- Connection info shows: `Database Name: MyCustomDB`

---

### Scenario 3: Script WITHOUT `CREATE DATABASE`

```sql
-- .claude/testSQL/bootstrap/schema-only.sql
-- No CREATE DATABASE
CREATE TABLE Products (ProductID INT PRIMARY KEY);
INSERT INTO Products VALUES (1);
```

```bash
/testsql setup schema-only.sql
```

**Result:**
- Database name: `testdb` (default)
- Script runs inside `testdb`
- Connection info shows: `Database Name: testdb`

**What happens:**
```sql
-- Automatically executed before your script:
CREATE DATABASE testdb;
GO
USE testdb;
GO

-- Your script runs here:
CREATE TABLE Products (...);
```

---

## Bootstrap Scripts

### Location

```
.claude/testSQL/bootstrap/
├── northwind.sql              # Auto-created default
├── your-script.sql           # Your custom scripts
└── *.bak                     # Backup files
```

---

### Example: CAP-DAMS Test Schema

```sql
-- .claude/testSQL/bootstrap/dams-test.sql
CREATE DATABASE DAMSTest;
GO
USE DAMSTest;
GO

-- Simulate Dataverse OrganizationBase
CREATE TABLE OrganizationBase (
    OrganizationId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(256) NOT NULL,
    CreatedOn DATETIME DEFAULT GETDATE()
);

-- UnusedIndexes tracking
CREATE TABLE UnusedIndexes (
    SchemaName NVARCHAR(256),
    TableName NVARCHAR(256),
    IndexName NVARCHAR(256),
    TimeInserted DATETIME DEFAULT GETDATE()
);

-- Test data
CREATE TABLE AccountBase (
    AccountId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(256)
);

CREATE INDEX IX_Account_Name ON AccountBase(Name);

PRINT 'CAP-DAMS test schema created';
```

**Usage:**
```bash
/testsql setup dams-test.sql
# Database: DAMSTest
```

---

### Example: Schema-Only (No Database)

```sql
-- .claude/testSQL/bootstrap/simple.sql
-- No CREATE DATABASE

CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY IDENTITY,
    Name NVARCHAR(100)
);

INSERT INTO Employees (Name) VALUES ('Alice'), ('Bob');
```

**Usage:**
```bash
/testsql setup simple.sql
# Database: testdb (auto-created, script runs inside it)
```

---

## Connection Information

### SSMS (SQL Server Management Studio)

**Connection Dialog:**
- Server: `localhost,1433` (comma, not colon!)
- Authentication: SQL Server Authentication
- Login: `sa`
- Password: `Pass@word1`
- Options → Enable "Trust server certificate"

---

### Azure Data Studio

**New Connection:**
- Server: `localhost,1433`
- Authentication: SQL Login
- User: `sa`
- Password: `Pass@word1`
- Database: `testdb`
- Trust Server Certificate: Yes

---

### C# / .NET

```csharp
using Microsoft.Data.SqlClient;

var connStr = "Server=localhost,1433;Database=testdb;User Id=sa;Password=Pass@word1;TrustServerCertificate=True;";

using var conn = new SqlConnection(connStr);
await conn.OpenAsync();
Console.WriteLine("Connected!");
```

---

### Python

```python
import pyodbc

conn_str = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=localhost,1433;"
    "DATABASE=testdb;"
    "UID=sa;"
    "PWD=Pass@word1;"
    "TrustServerCertificate=yes;"
)

with pyodbc.connect(conn_str) as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT @@VERSION")
    print(cursor.fetchone()[0])
```

---

### sqlcmd (Command Line)

```bash
sqlcmd -S localhost,1433 -U sa -P Pass@word1 -d testdb -Q "SELECT * FROM Customers"
```

---

## Workflow Examples

### Daily Development

```bash
# Morning: Start SQL Server
/testsql setup

# Work in SSMS...

# Before lunch: Backup
/testsql backup

# Evening: Shutdown
/testsql shutdown
```

---

### Test CAP-DAMS Script

```bash
# Setup test environment
/testsql setup dams-test.sql

# Backup before testing
/testsql backup

# Copy script to container
docker cp src/DAMS-Scripts/script.sql dams-sqlserver-dev:/tmp/

# Run script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d DAMSTest \
  -i /tmp/script.sql

# If failed: restore
/testsql restore testdb_20260129_143022.bak

# If succeeded: backup
/testsql backup
```

---

### Multiple Test Scenarios

```bash
# Scenario A
/testsql setup scenario-a.sql
# Work, test...
/testsql backup  # Saved

# Scenario B
/testsql setup scenario-b.sql
# Work, test...
/testsql backup  # Saved

# Compare: Restore A
/testsql restore testdb_20260129_100000.bak
```

---

## Troubleshooting

### Container Won't Start

**Symptom:** `/testsql setup` hangs or fails

**Solution:**
```bash
# Check Docker running
docker info

# Rebuild container
cd .claude/testSQLSetup
docker compose down -v
docker compose build --no-cache
/testsql setup
```

---

### Cannot Connect via SSMS

**Symptom:** "Network error" or "Login failed"

**Solution:**
1. Verify container running: `/testsql status`
2. Check server name: `localhost,1433` (comma!)
3. Enable "Trust server certificate"
4. Test connection:
   ```bash
   docker exec dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
     -S localhost -U sa -P 'Pass@word1' -Q "SELECT 1"
   ```

---

### Backup Failed

**Symptom:** "Insufficient disk space" error

**Solution:**
```bash
# Check disk space
df -h .claude/testSQL/bootstrap

# Delete old backups
cd .claude/testSQL/bootstrap
ls -t testdb*.bak | tail -n +6 | xargs rm -f
```

---

### Bootstrap Script Failed

**Symptom:** SQL syntax errors during setup

**Solution:**
1. Test script manually in SSMS
2. Check for missing `GO` statements between commands
3. Verify `CREATE DATABASE` and `USE` statements

---

## File Locations

```
.claude/
├── skills/testsql/
│   ├── SKILL.md                    # Agent instructions (main file)
│   └── README.md                   # This file
│
├── testSQL/bootstrap/
│   ├── northwind.sql               # Default database (auto-created)
│   ├── your-script.sql            # Your custom scripts
│   └── testdb_YYYYMMDD_HHMMSS.bak # Timestamped backups
│
└── testSQLSetup/
    ├── docker-compose.yml          # Container config
    ├── Dockerfile                  # SQL Server image
    ├── .env                       # Environment variables
    ├── data/                      # Database files (Docker volume)
    └── logs/                      # SQL Server logs (Docker volume)
```

---

## FAQ

**Q: How much disk space needed?**
A: 120GB minimum (image: 2GB, data: 60GB, logs: 30GB, backups: 10GB+, overhead: 20GB)

**Q: Can I change database name?**
A: Yes! Include `CREATE DATABASE [YourName]` in bootstrap script

**Q: What if script doesn't specify database?**
A: System creates `testdb` and runs script inside it

**Q: How long does first setup take?**
A: 5-10 minutes first time (downloads image), 30-60 seconds after

**Q: Can I have multiple databases?**
A: Yes! Create them in bootstrap script

**Q: Can I connect from Python/Node.js?**
A: Yes! Use standard SQL Server connection libraries (see examples above)

**Q: How do I completely remove everything?**
A:
```bash
/testsql shutdown
cd .claude/testSQLSetup
docker compose down -v
rm -rf data logs
rm -rf .claude/testSQL/bootstrap/*
```

---

## Agent-Based Architecture

**This is an agent-based skill** (not script-based):

- **SKILL.md** contains instructions for Claude to follow
- **No .sh file** needed - Claude executes using tools
- Claude uses **Bash, Read, Write tools** to accomplish tasks
- More flexible and intelligent than bash scripts

**How it works:**
```
User → /testsql setup → Claude reads SKILL.md
                      → Claude follows instructions
                      → Uses Bash tool to run commands
                      → Intelligent error handling
                      → Formatted output
```

---

## Support

**Team Contact:** capdsdataengine@microsoft.com

**Resources:**
- Docker: https://docs.docker.com/
- SQL Server on Docker: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- SQL Server 2022: https://learn.microsoft.com/en-us/sql/sql-server/

---

**Version:** 2.0 (Agent-Based)
**Created:** 2026-01-29
**Type:** Agent-Based Skill
**Maintained by:** CAP-DAMS Team
