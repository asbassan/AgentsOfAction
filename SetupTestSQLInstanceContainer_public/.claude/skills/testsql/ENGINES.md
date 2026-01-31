# /testsql - Engine Types Reference

## Overview

The `/testsql` skill supports **two SQL Server engine types**:

1. **SQL Server 2022** (default) - Full-featured, best for YourProject testing
2. **Azure SQL Edge** - Lightweight, optimized for edge/IoT scenarios

---

## Command Syntax

```bash
/testsql setup [scriptname] [sql|azuresql]
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scriptname` | Bootstrap SQL script from `.claude/testSQL/bootstrap/` | `northwind.sql` |
| `sql\|azuresql` | Engine type to use | `sql` |

---

## Usage Examples

### Default (SQL Server + Northwind)

```bash
/testsql setup
```

**Result:**
- Engine: SQL Server 2022
- Container: `sqlserver-dev`
- Database: `testdb` with Northwind sample data

---

### Azure SQL Edge + Northwind

```bash
/testsql setup azuresql
```

**Result:**
- Engine: Azure SQL Edge
- Container: `azuresql-dev`
- Database: `testdb` with Northwind sample data

---

### SQL Server + Custom Script

```bash
/testsql setup my-database.sql
```

**Result:**
- Engine: SQL Server 2022 (default)
- Container: `sqlserver-dev`
- Database: Detected from script or `testdb`

---

### SQL Server + Custom Script (Explicit)

```bash
/testsql setup my-database.sql sql
```

**Result:**
- Engine: SQL Server 2022 (explicit)
- Container: `sqlserver-dev`
- Database: Detected from script or `testdb`

---

### Azure SQL Edge + Custom Script

```bash
/testsql setup my-database.sql azuresql
```

**Result:**
- Engine: Azure SQL Edge
- Container: `azuresql-dev`
- Database: Detected from script or `testdb`

---

## Engine Comparison

### SQL Server 2022

| Property | Value |
|----------|-------|
| **Image** | `mcr.microsoft.com/mssql/server:2022-latest` |
| **Size** | ~2 GB |
| **Container Name** | `sqlserver-dev` |
| **Memory** | 7 GB |
| **CPUs** | 4 cores |
| **Data Volume** | `.claude/testSQLSetup/data` |
| **Logs Volume** | `.claude/testSQLSetup/logs` |

**Features:**
- ✅ Full SQL Server feature set
- ✅ SQL Server Agent
- ✅ Full-Text Search
- ✅ FILESTREAM
- ✅ Complete Query Store
- ✅ All index management features
- ✅ Replication support

**Best For:**
- YourProject script testing
- Production parity testing
- Full feature compatibility
- Complex queries and workloads

---

### Azure SQL Edge

| Property | Value |
|----------|-------|
| **Image** | `mcr.microsoft.com/azure-sql-edge:latest` |
| **Size** | ~1.5 GB |
| **Container Name** | `azuresql-dev` |
| **Memory** | 4 GB |
| **CPUs** | 2 cores |
| **Data Volume** | `.claude/testSQLSetup/data-azuresql` |
| **Logs Volume** | `.claude/testSQLSetup/logs-azuresql` |

**Features:**
- ✅ Core T-SQL compatibility
- ✅ Basic Query Store
- ✅ Standard indexes
- ✅ ARM64 support (Apple Silicon, Raspberry Pi)
- ✅ Optimized for resource-constrained environments
- ⚠️ No Full-Text Search
- ⚠️ No FILESTREAM
- ⚠️ Limited SQL Server Agent support

**Best For:**
- Lightweight testing
- ARM64 devices (Apple Silicon Macs)
- Resource-constrained environments
- Basic SQL compatibility testing

---

## Container Management

### Multiple Containers Can Coexist

Both containers can run simultaneously on different ports:

```bash
# SQL Server on port 1433
/testsql setup sql

# Azure SQL Edge on port 1433 (if SQL Server stopped)
/testsql shutdown  # Stop SQL Server
/testsql setup azuresql
```

**Container Names:**
- `sqlserver-dev` - SQL Server 2022
- `azuresql-dev` - Azure SQL Edge

---

### Container Detection

All commands (`backup`, `restore`, `shutdown`, `status`) **automatically detect** which container is running:

```bash
# Works with whichever container is running
/testsql backup
/testsql status
/testsql shutdown
```

**Detection Logic:**
1. Search for containers matching `dams.*sql` pattern
2. Use first running container found
3. If multiple running, use first match (priority: sqlserver-dev → azuresql-dev)

---

## Connection Information

### Both engines use the same connection credentials:

| Setting | Value |
|---------|-------|
| **Server** | `localhost,1433` |
| **Database** | Varies (detected from script or `testdb`) |
| **Username** | `sa` |
| **Password** | `YourSecurePassword123!` |
| **Connection String** | `Server=localhost,1433;Database=testdb;User Id=sa;Password=YourSecurePassword123!;TrustServerCertificate=True;` |

---

## When to Use Each Engine

### Use SQL Server 2022 When:

✅ Testing YourProject scripts (GetUnusedIndexes.sql, DropIndex.sql, etc.)
✅ Need full SQL Server Agent support
✅ Testing production-like workloads
✅ Using Full-Text Search
✅ Need complete feature parity
✅ Sufficient resources available (8GB+ RAM)

### Use Azure SQL Edge When:

✅ Running on ARM64 devices (Apple Silicon Macs)
✅ Limited system resources (< 8GB RAM)
✅ Basic T-SQL testing
✅ Quick lightweight testing
✅ Edge/IoT scenario testing
✅ Smaller Docker image preferred

---

## Feature Compatibility

| Feature | SQL Server 2022 | Azure SQL Edge |
|---------|----------------|----------------|
| T-SQL Core | ✅ | ✅ |
| Indexes (Clustered/Non-Clustered) | ✅ | ✅ |
| Query Store | ✅ Full | ✅ Basic |
| SQL Server Agent | ✅ | ⚠️ Limited |
| Full-Text Search | ✅ | ❌ |
| FILESTREAM | ✅ | ❌ |
| Replication | ✅ | ❌ |
| Always On | ✅ | ❌ |
| Backup/Restore | ✅ | ✅ |
| Transactions | ✅ | ✅ |
| Stored Procedures | ✅ | ✅ |
| Triggers | ✅ | ✅ |
| ARM64 Support | ❌ | ✅ |

---

## Switching Between Engines

### Method 1: Shutdown and Restart

```bash
# Currently running SQL Server
/testsql status
# Output: Engine Type: SQL Server 2022

# Switch to Azure SQL Edge
/testsql shutdown
/testsql setup azuresql

/testsql status
# Output: Engine Type: Azure SQL Edge
```

---

### Method 2: Run Both Simultaneously (Not Recommended)

**Note:** Both containers try to bind port 1433. You'll need to modify one to use a different port.

```bash
# Start SQL Server (port 1433)
/testsql setup sql

# Manually start Azure SQL Edge on different port
docker run -d \
  --name azuresql-dev \
  -e "ACCEPT_EULA=Y" \
  -e "SA_PASSWORD=YourSecurePassword123!" \
  -p 1434:1433 \
  mcr.microsoft.com/azure-sql-edge:latest

# Connect to SQL Server: localhost,1433
# Connect to Azure SQL Edge: localhost,1434
```

---

## FAQ

### Q: Which engine should I use for YourProject testing?

**A:** Use **SQL Server 2022** (default) for maximum compatibility and feature support.

---

### Q: Can I switch engines without losing data?

**A:** Yes! Use backup and restore:

```bash
# Running SQL Server
/testsql backup

# Switch to Azure SQL Edge
/testsql shutdown
/testsql setup azuresql

# Restore backup
/testsql restore testdb_20260129_143022.bak
```

**Note:** Backups are compatible between both engines for standard features.

---

### Q: Do backups work across engines?

**A:** Yes! Backups created on SQL Server can be restored on Azure SQL Edge and vice versa, **as long as you don't use SQL Server-specific features** (Full-Text Search, FILESTREAM, etc.).

---

### Q: How do I know which engine is running?

**A:**
```bash
/testsql status
```

Shows:
```
Engine Type:    SQL Server 2022
Container:      sqlserver-dev
```

Or:
```
Engine Type:    Azure SQL Edge
Container:      azuresql-dev
```

---

### Q: Can I have both containers running at once?

**A:** Not on the same port (1433). You'd need to manually configure different ports. **Not recommended** - use one at a time.

---

### Q: Does Azure SQL Edge support SQL Server Agent jobs?

**A:** Limited support. Basic jobs work, but complex schedules and advanced features may not.

---

### Q: Can I run YourProject scripts on Azure SQL Edge?

**A:** Most scripts will work, but scripts using Full-Text Search or FILESTREAM will fail. Test before production use.

---

## Resource Usage

### SQL Server 2022

```bash
docker stats sqlserver-dev
```

**Expected:**
- CPU: 5-15% (idle), up to 100% (active queries)
- Memory: 6-7 GB
- Disk: Data volume grows as database grows

---

### Azure SQL Edge

```bash
docker stats azuresql-dev
```

**Expected:**
- CPU: 3-10% (idle), up to 100% (active queries)
- Memory: 2-4 GB
- Disk: Data volume grows as database grows

---

## Recommendation for YourProject

**Use SQL Server 2022 (default)** for:
- GetUnusedIndexes.sql testing
- DropIndex.sql testing
- Auto-tuning script testing
- Production script validation
- Index management testing

**SQL Server 2022 provides the best compatibility** with Dataverse/Dynamics 365 production environments.

---

**Version:** 2.0
**Created:** 2026-01-29
**Maintained by:** YourProject Team
