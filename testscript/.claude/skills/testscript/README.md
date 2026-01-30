# SQL Server Load Testing Skill (`/testscript`)

A comprehensive SQL Server load testing framework for Windows that generates realistic database workload scenarios, enabling Query Data Store analysis and performance benchmarking.

## 🎯 Overview

The `/testscript` skill is designed to help you stress test SQL Server databases with production-like workloads. It automatically:

- ✅ Enables and configures Query Data Store with optimal settings
- ✅ Generates high-volume test data (50,000+ rows per table by default)
- ✅ Creates complex query patterns (CTEs, cross joins, cross apply, etc.)
- ✅ Simulates CPU-intensive workloads (10+ minutes at 90%+ utilization)
- ✅ Generates physical IO stress (100+ GB of disk reads)
- ✅ Creates blocking scenarios and query timeouts
- ✅ Captures thousands of unique query IDs for analysis
- ✅ **Includes bundled ostress.exe** - No separate installation needed!
- ✅ Produces detailed performance reports with recommendations

## 📋 Prerequisites

### Required Software
1. **Windows 10/11** - This skill is Windows-only
2. **Docker Desktop for Windows**
   - Minimum: 10 GB disk space, 8 GB RAM allocation
   - Download: https://www.docker.com/products/docker-desktop

3. **SQL Server Command Line Tools**
   - sqlcmd should be available in PATH
   - Usually installed with SQL Server
   - Or install: https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility

4. **/testsql Agent** (dependency)
   - Required for SQL Server environment setup
   - Install from: `SetupTestSQLInstanceContainer/.claude/skills/testsql/`

### Included Tools (Bundled)
- ✅ **ostress.exe** - Bundled in `.claude/skills/testscript/tools/`
- ✅ **RML Utilities** - No separate download needed!

### System Requirements
- **OS:** Windows 10/11 (64-bit)
- **CPU:** 4+ cores recommended
- **RAM:** 16 GB+ recommended (8 GB for SQL Server, rest for OS)
- **Disk:** 20 GB+ free space
- **Network:** Internet connection for Docker images

## 🚀 Quick Start

### Installation
```bash
# 1. Clone or copy the skill to your project
cp -r .claude/skills/testscript /path/to/your/project/.claude/skills/

# 2. Verify ostress.exe is present
ls .claude/skills/testscript/tools/ostress.exe

# 3. That's it! Ready to use.
```

### Basic Usage
```bash
# Test a local SQL script
/testscript ./scripts/my-test-query.sql

# Test with ADO work item
/testscript ADO:12345

# Test with Pull Request
/testscript PR:123
```

### Common Scenarios

#### 1. Quick 15-Minute Test
```bash
/testscript ./test.sql --duration 15 --threads 25
```

#### 2. Extended Stress Test
```bash
/testscript ./test.sql --duration 60 --threads 100 --rows-per-table 100000
```

#### 3. High CPU Focus Test
```bash
/testscript ./test.sql --cpu-load 20 --threads 75
```

#### 4. IO-Intensive Test
```bash
/testscript ./test.sql --io-load 20 --rows-per-table 200000
```

#### 5. Blocking and Deadlock Test
```bash
/testscript ./test.sql --blocking-duration 15 --threads 50
```

#### 6. Large Database Test
```bash
/testscript ./test.sql --db-size 20 --memory 12 --rows-per-table 150000
```

## 📖 Command Reference

### Syntax
```bash
/testscript <scriptpath> [options]
```

### Arguments

#### `<scriptpath>` (Required)
The script to test. Can be one of:

| Format | Description | Example |
|--------|-------------|---------|
| **File Path** | Local .sql file | `/testscript ./scripts/query.sql` |
| **ADO Work Item** | Azure DevOps work item with script | `/testscript ADO:12345` or `/testscript 12345` |
| **Pull Request** | GitHub PR containing SQL files | `/testscript PR:123` or `/testscript #123` |

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--duration <minutes>` | Integer | 30 | Total test duration in minutes |
| `--threads <count>` | Integer | 50 | Number of concurrent ostress.exe threads |
| `--cpu-load <minutes>` | Integer | 10 | Duration of CPU-intensive phase |
| `--io-load <minutes>` | Integer | 10 | Duration of IO-intensive phase |
| `--blocking-duration <minutes>` | Integer | 5 | Duration of blocking scenarios |
| `--rows-per-table <count>` | Integer | 50000 | Number of rows to generate per table |
| `--db-size <GB>` | Integer | 10 | Maximum database size in gigabytes |
| `--memory <GB>` | Integer | 8 | SQL Server memory allocation |
| `--skip-qds` | Flag | false | Skip Query Data Store setup |
| `--output-dir <path>` | String | `./.claude/testScriptResults/<timestamp>` | Custom output directory |

## 🔧 Configuration

### Environment Variables
The skill uses the `/testsql` agent's environment configuration:

```env
# .claude/testSQLSetup/.env
SA_PASSWORD=Pass@word1
DATABASE_NAME=LoadTestDB
SQLSERVER_PORT=1433
CONTAINER_NAME=dams-sqlserver-dev
```

### Docker Configuration
SQL Server container specs (auto-configured):
- **Memory Limit:** Specified via `--memory` (default 8 GB)
- **CPUs:** 4 cores
- **Port:** 1433
- **Max DB Size:** Specified via `--db-size` (default 10 GB)

### Query Data Store Settings
Automatically configured for load testing:
```sql
DATA_FLUSH_INTERVAL_SECONDS = 5        -- Rapid capture
INTERVAL_LENGTH_MINUTES = 1            -- Fine-grained intervals
MAX_STORAGE_SIZE_MB = 2048             -- 2 GB storage
QUERY_CAPTURE_MODE = ALL               -- Capture all queries
WAIT_STATS_CAPTURE_MODE = ON           -- Capture wait stats
```

## 📊 Test Phases

The skill executes load tests in five phases:

### Phase 1: Warmup (2 minutes)
- **Purpose:** Prepare SQL Server caches and connection pools
- **Threads:** 10 (light load)
- **Queries:** Mixed query types
- **Goal:** Stabilize environment before heavy load

### Phase 2: CPU Intensive (default 10 minutes)
- **Purpose:** Generate high CPU utilization
- **Threads:** As specified (default 50)
- **Query Types:**
  - Recursive CTEs
  - Cross joins (Cartesian products)
  - Complex mathematical calculations
  - String manipulations
- **Target:** 90%+ CPU utilization for specified duration

### Phase 3: IO Intensive (default 10 minutes)
- **Purpose:** Generate physical disk IO
- **Threads:** As specified (default 50)
- **Query Types:**
  - Full table scans
  - Large joins with sorts
  - Nested subqueries
  - Hash operations
- **Target:** 100+ GB of physical reads

### Phase 4: Blocking Scenarios (default 5 minutes)
- **Purpose:** Create lock contention and timeouts
- **Threads:** Half of specified (to allow blocking)
- **Query Types:**
  - Long-running transactions
  - Exclusive table locks
  - Deadlock scenarios
- **Target:** 5+ minutes cumulative blocking time

### Phase 5: Mixed Load (remaining time)
- **Purpose:** Simulate realistic mixed workload
- **Threads:** As specified (default 50)
- **Query Types:** All types including user's script
- **Goal:** Sustain load until test duration complete

## 📈 Performance Metrics

### Query Data Store Captures
- **Unique Query IDs:** 1,000+ expected
- **Execution Plans:** 2,000+ expected
- **Wait Statistics:** All wait categories
- **Runtime Stats:** Duration, CPU, IO, memory

### Resource Utilization
- **CPU Usage:** Target 90%+ during CPU phase
- **Memory Usage:** Monitored continuously
- **Disk IO:** Read/write throughput tracked
- **Network IO:** Connection count and bandwidth

### Query Performance
- **Execution Count:** Per query ID
- **Avg/Max Duration:** Milliseconds
- **CPU Time:** Per execution
- **Logical Reads:** Buffer pool hits
- **Physical Reads:** Disk IO operations
- **Blocking Time:** Wait duration

## 📁 Output Structure

After test completion, results are saved in:
```
.claude/testScriptResults/<timestamp>/
├── LOAD_TEST_REPORT.md              # Main results report
├── test_log.txt                     # Execution log
├── cpu_stats.txt                    # CPU monitoring data
├── io_stats.txt                     # IO monitoring data
├── blocking_stats.txt               # Blocking analysis
├── qds_results.txt                  # Query Data Store export
├── setup_qds.sql                    # QDS configuration script
├── cpu_intensive_queries.sql        # Generated CPU queries
├── io_intensive_queries.sql         # Generated IO queries
├── blocking_queries.sql             # Generated blocking queries
├── user_script_enhanced.sql         # User script with variations
├── master_load_test.sql             # Main test orchestration script
├── run_load_test.bat                # ostress.exe execution script
├── phase1_warmup/                   # ostress output files
├── phase2_cpu/                      # ostress output files
├── phase3_io/                       # ostress output files
├── phase4_blocking/                 # ostress output files
└── phase5_mixed/                    # ostress output files
```

### Main Report Contents
The `LOAD_TEST_REPORT.md` includes:
1. **Test Configuration** - All parameters used
2. **Execution Summary** - Phase results and totals
3. **Query Data Store Analysis** - QDS metrics
4. **Top CPU Consumers** - Most expensive queries
5. **Top IO Consumers** - Disk-intensive queries
6. **Wait Statistics** - Blocking and waits breakdown
7. **Performance Metrics** - Resource utilization graphs
8. **User Script Performance** - Specific results for your queries
9. **Recommendations** - Optimization suggestions
10. **Next Steps** - Follow-up actions

## 🔍 Analyzing Results

### Using the Report
```bash
# View the main report
type .claude\testScriptResults\2024-01-29_14-30-00\LOAD_TEST_REPORT.md

# Or open in your default markdown viewer
start .claude\testScriptResults\2024-01-29_14-30-00\LOAD_TEST_REPORT.md
```

### Query Data Store Analysis

#### Connect to Database
```bash
# Using sqlcmd
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB

# Using Azure Data Studio
# Server: localhost,1433
# User: sa
# Password: Pass@word1
# Database: LoadTestDB
```

#### Query Top CPU Consumers
```sql
USE LoadTestDB;

SELECT TOP 20
    q.query_id,
    SUBSTRING(qt.query_sql_text, 1, 200) AS query_text,
    SUM(rs.count_executions) AS executions,
    SUM(rs.count_executions * rs.avg_cpu_time) / 1000000.0 AS total_cpu_seconds,
    AVG(rs.avg_cpu_time) / 1000.0 AS avg_cpu_ms,
    MAX(rs.max_cpu_time) / 1000.0 AS max_cpu_ms
FROM sys.query_store_query q
INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
GROUP BY q.query_id, qt.query_sql_text
ORDER BY total_cpu_seconds DESC;
```

## 🛠️ Troubleshooting

### Common Issues

#### Issue: "ostress.exe not found"
**This shouldn't happen!** ostress.exe is bundled with the skill.

**Solutions:**
1. Verify file exists:
   ```cmd
   dir .claude\skills\testscript\tools\ostress.exe
   ```
2. If missing, re-copy the skill directory from the repository
3. Check file wasn't blocked by Windows:
   ```powershell
   Unblock-File .claude\skills\testscript\tools\ostress.exe
   ```

#### Issue: "Cannot connect to SQL Server"
**Symptoms:**
- Connection timeout errors
- "Login failed for user 'sa'"

**Solutions:**
1. Check container is running:
   ```cmd
   docker ps --filter "name=dams-sqlserver-dev"
   ```
2. If not running, start SQL Server:
   ```bash
   /testsql setup
   ```
3. Test connection manually:
   ```cmd
   sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -Q "SELECT @@VERSION"
   ```
4. Check firewall not blocking port 1433
5. Verify Docker networking

#### Issue: "Out of disk space"
**Solutions:**
1. Check available space:
   ```powershell
   Get-PSDrive C
   ```
2. Clean up Docker:
   ```cmd
   docker system prune -a -f
   docker volume prune -f
   ```
3. Reduce test parameters:
   ```bash
   /testscript ./test.sql --rows-per-table 25000 --db-size 5
   ```

#### Issue: "Query Data Store disabled"
**Solutions:**
1. Check database compatibility (must be SQL Server 2016+):
   ```sql
   SELECT name, compatibility_level
   FROM sys.databases WHERE name = 'LoadTestDB';
   ```
2. Enable manually if needed:
   ```sql
   ALTER DATABASE [LoadTestDB] SET QUERY_STORE = ON;
   ```

#### Issue: "Too many query timeouts"
**Solutions:**
1. Reduce concurrent threads:
   ```bash
   /testscript ./test.sql --threads 25
   ```
2. Allocate more resources:
   ```bash
   /testscript ./test.sql --memory 12 --threads 30
   ```

## 📖 FAQ

### Q: Why Windows-only?
**A:** ostress.exe is a Windows tool. For cross-platform support, we'd need alternative load testing tools.

### Q: Can I use my own ostress.exe version?
**A:** Yes, place it in `.claude/skills/testscript/tools/` to override the bundled version.

### Q: How much does this cost?
**A:** Everything is free:
- SQL Server Developer Edition (free)
- Docker Community Edition (free)
- ostress.exe (free from Microsoft, bundled here)

### Q: Can I test against Azure SQL Database?
**A:** The skill is designed for local containers, but you can manually:
1. Configure QDS on Azure SQL
2. Point ostress.exe to Azure (edit connection string in generated scripts)
3. Analyze using Azure Query Performance Insight

### Q: How do I clean up after testing?
```bash
# Use /testsql shutdown
/testsql shutdown

# Or manually remove container
docker stop dams-sqlserver-dev
docker rm dams-sqlserver-dev

# Remove test data
rmdir /s /q .claude\testScriptResults
```

### Q: Can I test stored procedures?
**A:** Yes! Include them in your script:
```sql
CREATE OR ALTER PROCEDURE TestProc AS
BEGIN
    -- Your logic
END;
GO

EXEC TestProc;
GO
```

## 🔗 Related Documentation

- [/testsql Agent Documentation](../testsql/README.md) - SQL Server environment setup
- [Query Data Store Best Practices](https://docs.microsoft.com/en-us/sql/relational-databases/performance/best-practice-with-the-query-store)
- [ostress.exe Documentation](https://github.com/Microsoft/RMLUtils)
- [Docker SQL Server Setup](https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker)

## 📄 Bundled Tools

### ostress.exe
- **Version:** Latest from RML Utilities
- **Location:** `.claude/skills/testscript/tools/ostress.exe`
- **License:** Microsoft Software License
- **Purpose:** Multi-threaded query execution and load testing

### Dependencies
All required DLLs are bundled in the `tools/` directory:
- ostress.exe
- RMLUtils.dll
- (and other required dependencies)

## 📞 Support

### Getting Help
1. Check this README for common solutions
2. Review error logs:
   - `.claude/testScriptResults/test_log.txt`
   - `docker logs dams-sqlserver-dev`
3. File an issue on GitHub repository

### Reporting Bugs
Include in bug report:
- Command used (sanitize any sensitive data)
- Error message and full stack trace
- Test log contents
- Windows version and Docker version

---

**Version:** 1.0.0
**Last Updated:** 2024-01-29
**Platform:** Windows 10/11 (64-bit)
**Maintainer:** AgentsOfAction Team

For the latest version, see: [AgentsOfAction Repository](https://github.com/your-org/AgentsOfAction)
