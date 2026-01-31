# SetupTestSQLInstanceContainer

A complete SQL Server test environment for YourProject development, featuring Docker-based SQL Server 2022, Claude AI agent skills, and automated database management.

## Overview

This container provides everything needed to set up, manage, and test SQL Server databases for the Agents of Action project:

- **Automated SQL Server Setup** via Docker
- **Claude AI Integration** with `/testsql` skill
- **Sample Databases** (Northwind) for quick testing
- **Database Backup/Restore** utilities
- **SSMS/Azure Data Studio** connectivity

## Structure

```
SetupTestSQLInstanceContainer/
└── .claude/
    ├── skills/testsql/           # Claude AI skill for SQL Server management
    ├── testsql/                  # Bootstrap scripts and sample databases
    └── testSQLSetup/             # Docker-based SQL Server 2022 environment
```

### Component Details

#### 1. `.claude/skills/testsql/` - Claude AI Skill

Agent-based skill that provides intelligent SQL Server management through natural language commands.

**Key Features:**
- Smart database detection from scripts
- Automatic backup on shutdown
- Default Northwind database
- Bootstrap script execution
- Connection info display

**Usage:**
```bash
/testsql setup              # Start with Northwind sample database
/testsql setup script.sql   # Start with custom script
/testsql backup             # Backup current database
/testsql restore backup.bak # Restore from backup
/testsql status             # Show connection info
/testsql shutdown           # Backup and stop container
```

📖 **Documentation:** [.claude/skills/testsql/README.md](.claude/skills/testsql/README.md)

---

#### 2. `.claude/testsql/` - Bootstrap Scripts

Sample databases and initialization scripts for quick test environment setup.

**Contents:**
- `bootstrap/northwind.sql` - Northwind sample database
- `bootstrap/instnwnd.sql` - Northwind installation script
- Custom bootstrap scripts for various test scenarios

**Purpose:**
- Pre-built test databases
- Schema templates for YourProject testing
- Quick data population for development

---

#### 3. `.claude/testSQLSetup/` - Docker SQL Server Environment

Complete Docker Compose setup for SQL Server 2022 Developer Edition with full DBA capabilities.

**Specifications:**
- **Edition:** SQL Server 2022 Developer (full-featured, free)
- **Memory:** 6GB allocated to SQL Server
- **Storage:** 100GB capacity (data, logs, backups)
- **Port:** 1433 (exposed for SSMS)
- **SQL Agent:** Enabled
- **Persistent Volumes:** Data preserved across restarts

📖 **Documentation:** [.claude/testSQLSetup/README.md](.claude/testSQLSetup/README.md)

---

## Quick Start

### Prerequisites

1. **Docker Desktop** (8GB RAM minimum)
   - Download: https://www.docker.com/products/docker-desktop
   - Allocate 8GB+ RAM to Docker
   - Ensure 120GB+ free disk space

2. **Shell Environment** (Windows users need Git Bash or WSL)
   - macOS/Linux: Native bash/zsh ✓
   - Windows: Git Bash (https://git-scm.com/download/win)

3. **SQL Client** (Optional but recommended)
   - SSMS: https://aka.ms/ssmsfullsetup (Windows only)
   - Azure Data Studio: https://aka.ms/azuredatastudio (Cross-platform)

### Setup Steps

#### Option A: Using `/testsql` Skill (Recommended)

```bash
# Start SQL Server with default Northwind database
/testsql setup

# Connect via SSMS or Azure Data Studio:
# Server: localhost,1433
# Username: sa
# Password: YourSecurePassword123!
# Database: testdb
```

#### Option B: Manual Docker Setup

```bash
# Navigate to setup directory
cd .claude/testSQLSetup

# Start SQL Server container
docker compose up -d

# Wait for SQL Server to initialize (~60 seconds)
docker compose logs -f
```

### Connection Information

**Server Details:**
- **Host:** `localhost,1433` (note: comma, not colon)
- **Authentication:** SQL Server Authentication
- **Username:** `sa`
- **Password:** `YourSecurePassword123!`
- **Default Database:** `testdb` or `testdb`

**Connection String (C#/.NET):**
```
Server=localhost,1433;Database=testdb;User Id=sa;Password=YourSecurePassword123!;TrustServerCertificate=True;
```

**SSMS Connection:**
1. Open SQL Server Management Studio
2. Server name: `localhost,1433`
3. Authentication: SQL Server Authentication
4. Login: `sa`
5. Password: `YourSecurePassword123!`
6. Options → Connection Properties → Enable "Trust server certificate" ✓

---

## Common Workflows

### Daily Development

```bash
# Morning: Start SQL Server
/testsql setup

# Work in SSMS or your application...

# Evening: Backup and shutdown
/testsql shutdown
```

### Testing YourProject Scripts

```bash
# Setup test environment with custom schema
/testsql setup your-test.sql

# Backup before testing
/testsql backup

# Copy script to container
docker cp script.sql sqlserver-dev:/tmp/

# Execute script
docker exec -it sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'YourSecurePassword123!' -d testdb -C \
  -i /tmp/script.sql

# If test fails: restore from backup
/testsql restore

# If test succeeds: create new backup
/testsql backup
```

### Multiple Test Scenarios

```bash
# Test Scenario A
/testsql setup scenario-a.sql
# Work, test...
/testsql backup  # Creates timestamped backup

# Test Scenario B (destroys current database)
/testsql setup scenario-b.sql
# Work, test...
/testsql backup

# Restore Scenario A to compare
/testsql restore testdb_20260129_100000.bak
```

---

## Features

### Automated Database Management

- **Smart Database Detection:** Automatically detects database name from CREATE DATABASE statements
- **Default Database:** Creates `testdb` with Northwind sample data if no script provided
- **Timestamped Backups:** Automatic backup naming with date/time (e.g., `testdb_20260129_143022.bak`)
- **Quick Restore:** Interactive menu to restore from any previous backup

### Docker Architecture

- **Persistent Volumes:** Data survives container restarts
- **Health Checks:** Automatic container health monitoring
- **Resource Limits:** Configured memory (6GB) and CPU limits
- **Isolation:** Runs in isolated container, no host SQL Server installation needed

### Development Tools Integration

- **SSMS Compatible:** Full SQL Server Management Studio support
- **Azure Data Studio:** Cross-platform SQL editor support
- **sqlcmd:** Command-line tools available inside container
- **Language SDKs:** Connect from C#, Python, Node.js, etc.

---

## File Structure

```
SetupTestSQLInstanceContainer/
├── README.md                              # This file
└── .claude/
    ├── skills/testsql/
    │   ├── SKILL.md                       # Claude agent instructions
    │   ├── README.md                      # /testsql documentation
    │   ├── ENGINES.md                     # SQL engine configurations
    │   └── skill.sh                       # (Not used - agent-based)
    │
    ├── testsql/bootstrap/
    │   ├── northwind.sql                  # Northwind sample database
    │   ├── instnwnd.sql                   # Northwind installer
    │   └── *.bak                          # Timestamped backups
    │
    └── testSQLSetup/
        ├── docker-compose.yml             # Container orchestration
        ├── Dockerfile                     # SQL Server custom image
        ├── mssql.conf                     # SQL Server configuration
        ├── .env                           # Environment variables
        ├── setup.sh / setup.ps1           # Setup scripts
        ├── teardown.sh                    # Cleanup script
        ├── data/                          # Database files (Docker volume)
        ├── logs/                          # SQL Server logs (Docker volume)
        ├── backups/                       # Database backups (Docker volume)
        └── init-scripts/                  # Auto-run on first start
            └── 01-create-test-database.sql
```

---

## PR Testing Organization

Test artifacts for Pull Request validation are organized by PR ID:

```
.claude/testSQLSetup/{PR_ID}/
├── README.md                          # Test overview
├── Test_*.sql                         # Test scripts
├── TEST_RESULTS_*.md                  # Execution results
├── RUN_TESTS.md                       # Quick start for reviewers
└── PR_COMMENT_*.md                    # Formatted PR comments
```

**Example:** PR #14514176 test artifacts in `.claude/testSQLSetup/14514176/`

**Benefits:**
- ✅ Isolated test environments per PR
- ✅ Traceable test history by PR number
- ✅ Reusable regression tests
- ✅ Self-documented test procedures

---

## Troubleshooting

### Container Won't Start

```bash
# Check Docker is running
docker info

# View container logs
cd .claude/testSQLSetup
docker compose logs -f

# Rebuild container (if corrupted)
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Cannot Connect via SSMS

1. Verify container is running: `docker ps | grep dams-sqlserver`
2. Check server name format: `localhost,1433` (comma, not colon!)
3. Enable "Trust server certificate" in SSMS connection options
4. Test connection inside container:
   ```bash
   docker exec -it sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -U sa -P 'YourSecurePassword123!' -C -Q "SELECT @@VERSION"
   ```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Remove old Docker images
docker system prune -a

# Delete old backups (keep latest 5)
cd .claude/testsql/bootstrap
ls -t testdb*.bak | tail -n +6 | xargs rm -f
```

---

## Security Considerations

### For Development/Testing Only

**Default Credentials:**
- Username: `sa`
- Password: `YourSecurePassword123!`

⚠️ **WARNING:** These are insecure defaults for local development only. Never use these credentials in production.

### Production Hardening (if needed)

1. **Change SA Password:**
   - Edit `.claude/testSQLSetup/.env`
   - Set `SA_PASSWORD=YourStrongP@ssw0rd!`
   - Recreate container: `docker compose up -d --force-recreate`

2. **Create Non-SA Users:**
   ```sql
   CREATE LOGIN [app_user] WITH PASSWORD = 'StrongP@ssw0rd!';
   USE [testdb];
   CREATE USER [app_user] FOR LOGIN [app_user];
   ALTER ROLE db_datareader ADD MEMBER [app_user];
   ALTER ROLE db_datawriter ADD MEMBER [app_user];
   ```

3. **Restrict Network Access:**
   ```yaml
   # docker-compose.yml
   ports:
     - "127.0.0.1:1433:1433"  # Localhost only
   ```

---

## Performance Tuning

### Increase Memory

```yaml
# .claude/testSQLSetup/docker-compose.yml
environment:
  - MSSQL_MEMORY_LIMIT_MB=8192  # 8GB instead of 6GB

mem_limit: 10g
mem_reservation: 8g
```

### Increase CPU

```yaml
# .claude/testSQLSetup/docker-compose.yml
cpus: 8.0  # Allocate 8 CPU cores
```

### Optimize Disk I/O

- Use SSD for Docker volumes
- Avoid WSL2 bind mounts on Windows (use Docker volumes instead)
- Allocate more disk space to Docker Desktop

---

## Maintenance

### Regular Tasks

- **Daily:** Check container status (`docker ps`)
- **Weekly:** Backup databases (`/testsql backup`)
- **Monthly:** Clean old backups (keep latest 10)
- **Quarterly:** Update SQL Server image (`docker pull mcr.microsoft.com/mssql/server:2022-latest`)

### Backup Strategy

```bash
# Manual backup
/testsql backup

# Automatic backup on shutdown
/testsql shutdown

# List all backups
ls -lh .claude/testsql/bootstrap/*.bak

# Restore specific backup
/testsql restore testdb_20260129_143022.bak
```

---

## Documentation

### Main Documentation

- **This README** - Overview and quick start
- [.claude/skills/testsql/README.md](.claude/skills/testsql/README.md) - `/testsql` skill complete reference
- [.claude/testSQLSetup/README.md](.claude/testSQLSetup/README.md) - Docker setup detailed guide

### External Resources

- **SQL Server on Docker:** https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- **SQL Server 2022 Docs:** https://learn.microsoft.com/en-us/sql/sql-server/
- **Docker Compose:** https://docs.docker.com/compose/
- **SSMS Download:** https://aka.ms/ssmsfullsetup
- **Azure Data Studio:** https://aka.ms/azuredatastudio

---

## Support

**Project:** Agents of Action
**Repository:** https://github.com/your-org/AgentsOfAction
**Team:** Database Tools Team

For issues, questions, or contributions, please open an issue on GitHub.

---

## License

This setup is for development and testing purposes. SQL Server Developer Edition is free for non-production use.

**Created:** 2026-01-29
**Version:** 1.0
**Type:** SQL Server Test Environment Container
**Maintained by:** Database Tools Team
