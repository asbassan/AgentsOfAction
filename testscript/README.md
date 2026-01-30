# testscript - SQL Server Script Validation Framework

A comprehensive, autonomous SQL Server script validation framework that tests SQL scripts for functional correctness, performance optimization, and production readiness.

## Overview

This container provides everything needed to validate, stress test, and optimize SQL Server scripts for the Agents of Action project:

- **Automated Script Validation** - Functional correctness, performance, index usage
- **Claude AI Integration** with `/testscript` skill
- **Background Load Generation** - Realistic production-like stress testing
- **Scoring Framework** - Quantified results (0-10 scale) with recommendations
- **Test Environment Management** - Automatic schema detection and data generation

## Structure

```
testscript/
└── .claude/
    ├── skills/testscript/           # Claude AI skill for script validation
    │   ├── SKILL.md                 # Main orchestration guide
    │   ├── README.md                # User documentation
    │   ├── TOOLS_SETUP.md           # ostress.exe setup guide
    │   ├── END_OF_RUN_FLOW.md       # Interactive flow details
    │   ├── implementation/          # Phase-by-phase implementation
    │   │   ├── PHASE1_CRITERIA_EXTRACTION.md
    │   │   ├── PHASE2_SCHEMA_ANALYSIS.md
    │   │   ├── PHASE3_DATA_GENERATION.md
    │   │   ├── PHASE4_LOAD_GENERATION.md
    │   │   ├── PHASE5_EXECUTION.md
    │   │   ├── PHASE6_EVALUATION.md
    │   │   └── PHASE7_REPORTING.md
    │   └── tools/                   # Bundled testing tools
    │       ├── extract-ostress.bat  # Extraction script
    │       ├── Setup-Ostress.ps1    # PowerShell extraction
    │       └── RMLSetup.msi         # RML Utilities installer
    └── testScriptResults/           # Test results (generated at runtime)
        └── <timestamp>/
            ├── VALIDATION_REPORT.md
            ├── schema/
            ├── background_load/
            ├── execution/
            └── evaluation/
```

## Component Details

### `.claude/skills/testscript/` - Claude AI Skill

Agent-based skill that provides comprehensive SQL script validation through autonomous testing and evaluation.

**Key Features:**
- Multi-source success criteria extraction (script headers, ADO, PR)
- Automatic schema detection and test data generation (50K+ rows)
- Background load on same tables (realistic contention)
- Multi-scenario testing (idle, loaded, parallel)
- Functional validation and scoring (0-10 scale)
- Execution plan analysis (index usage optimization)
- Actionable recommendations with code examples

**What Gets Tested:**
1. ✓ **Functional Correctness** - Returns correct data per criteria
2. ✓ **Output Schema** - Expected columns present
3. ✓ **Performance** - Baseline, under load, parallel stress
4. ✓ **Index Usage** - Seek vs Scan, table scan detection
5. ✓ **QDS Performance** - Query Data Store query analysis
6. ✓ **Blocking & Contention** - Lock behavior under load

**Usage:**
```bash
/testscript ./my-query.sql                    # Local file
/testscript ADO:12345                         # ADO work item
/testscript PR:123                            # Pull request
/testscript ./test.sql --cpu-target 80        # Custom load
/testscript ./test.sql --threads 100          # More threads
```

📖 **Documentation:** [.claude/skills/testscript/README.md](.claude/skills/testscript/README.md)

---

### `.claude/skills/testscript/tools/` - Bundled Testing Tools

Windows-only load testing tools bundled with the skill.

**Contents:**
- `ostress.exe` - Multi-threaded SQL query execution (Microsoft RML Utilities)
- `RMLUtils.dll` - Required dependency
- `extract-ostress.bat` - Extraction script for setup
- `Setup-Ostress.ps1` - PowerShell extraction alternative

**Purpose:**
- Parallel query execution (up to 100+ threads)
- Load generation for stress testing
- Realistic production-like concurrency

📖 **Setup Guide:** [.claude/skills/testscript/TOOLS_SETUP.md](.claude/skills/testscript/TOOLS_SETUP.md)

---

### `.claude/testScriptResults/` - Test Output (Runtime)

Generated during test execution, contains all validation artifacts.

**Structure per test:**
```
testScriptResults/<timestamp>/
├── VALIDATION_REPORT.md              # Main deliverable
├── success_criteria.json             # Detected criteria
├── script_analysis.json              # Script analysis
├── schema/                           # Generated DDL and data scripts
├── background_load/                  # Load generation queries
├── execution/                        # Test results and plans
└── evaluation/                       # Scores and recommendations
```

---

## Quick Start

### Prerequisites

1. **Windows 10/11** (64-bit)
   - This skill is Windows-only (ostress.exe requirement)

2. **Docker Desktop** (8GB RAM minimum)
   - Download: https://www.docker.com/products/docker-desktop
   - Allocate 8GB+ RAM to Docker
   - Ensure 20GB+ free disk space

3. **SQL Server Tools**
   - sqlcmd (included with SQL Server)
   - Or install: https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility

4. **/testsql Skill** (dependency)
   - Location: `../SetupTestSQLInstanceContainer/.claude/skills/testsql/`
   - Provides SQL Server test environment

5. **Optional:**
   - SSMS or Azure Data Studio for manual inspection
   - GitHub CLI (`gh`) for PR integration
   - Azure DevOps tools for ADO integration

### Setup Steps

#### Step 1: Extract ostress.exe

```bash
# Navigate to tools directory
cd .claude/skills/testscript/tools

# Run extraction script
./extract-ostress.bat

# Or use PowerShell
powershell -ExecutionPolicy Bypass -File Setup-Ostress.ps1

# Verify
./ostress.exe -?
```

#### Step 2: Test the Skill

Create a sample script:

```sql
/* sample-query.sql
 * PURPOSE: Find slow queries from Query Data Store
 * SUCCESS CRITERIA:
 * - Returns queries with avg_duration > 1000ms
 * - Executes in under 500ms
 */

SELECT TOP 100
    q.query_id,
    qt.query_sql_text,
    rs.avg_duration
FROM sys.query_store_runtime_stats rs
INNER JOIN sys.query_store_query q ON rs.query_id = q.query_id
INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE rs.avg_duration > 1000
ORDER BY rs.avg_duration DESC;
```

Run validation:

```bash
/testscript ./sample-query.sql
```

### What Happens (Autonomous)

```
Phase 1: Extract Success Criteria (from script header)
Phase 2: Analyze Script (detect tables: query_store_*)
Phase 3: Generate Test Data (populate QDS with 1K+ queries)
Phase 4: Background Load (bring CPU to 75%)
Phase 5: Execute Tests (baseline, loaded, parallel)
Phase 6: Evaluate & Score (0-10 for each criterion)
Phase 7: Generate Report (with recommendations)

User Interaction:
→ Confirm success criteria (can skip)
→ Choose to update ADO/PR (if applicable)
→ Choose when to cleanup database

Result:
→ VALIDATION_REPORT.md with score and recommendations
→ Database remains up for inspection
→ Cleanup on user confirmation
```

---

## Common Workflows

### Validate Monitoring Script

```bash
# Test a production monitoring query
/testscript ./check-blocking-queries.sql

# Review results
cat .claude/testScriptResults/2024-01-29_14-30-00/VALIDATION_REPORT.md

# Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT

# Apply recommended fixes
vim ./check-blocking-queries.sql

# Retest
/testscript ./check-blocking-queries-v2.sql

# Overall Score: 9.2/10 ✓ EXCELLENT

# Cleanup when satisfied
# User will be prompted: "Shutdown and cleanup?"
```

### Test ADO Work Item Script

```bash
# Validate script from ADO work item
/testscript ADO:12345

# Skill will:
# 1. Fetch work item details
# 2. Extract script and requirements
# 3. Run validation
# 4. Ask: "Update work item with results?"
# 5. Post score and recommendations to ADO

# Database stays up for inspection
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB

# When done, cleanup via prompt
```

### Validate PR Changes

```bash
# Test SQL files in a pull request
/testscript PR:456

# Skill will:
# 1. Fetch PR files
# 2. Test each .sql file
# 3. Ask: "Comment on PR with results?"
# 4. Post validation report to PR

# Manual inspection if needed
# Then cleanup when prompted
```

### Compare Before/After Optimization

```bash
# Test original script
/testscript ./original-query.sql
# Score: 5.5/10

# Note recommendations from report
# Apply optimizations

# Test optimized version
/testscript ./optimized-query.sql
# Score: 9.0/10

# Compare reports
diff .claude/testScriptResults/2024-01-29_14-30-00/VALIDATION_REPORT.md \
     .claude/testScriptResults/2024-01-29_15-45-00/VALIDATION_REPORT.md
```

### Custom Load Testing

```bash
# Higher CPU load, more threads
/testscript ./test.sql --cpu-target 90 --threads 100

# Shorter duration for quick test
/testscript ./test.sql --duration 10

# More test data
/testscript ./test.sql --rows-per-table 100000

# Larger database
/testscript ./test.sql --db-size 20 --memory 12
```

---

## Validation Report Example

```markdown
# SQL Server Script Validation Report

**Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT**

## Score Breakdown

| Criterion | Score | Weight | Status |
|-----------|-------|--------|--------|
| Functional Correctness | 6/10 | 25% | ❌ |
| Output Schema | 10/10 | 10% | ✓ |
| Index Usage | 6/10 | 20% | ⚠️  |
| Performance | 5/10 | 30% | ❌ |
| QDS Detection | 10/10 | 10% | ✓ |

## Performance Results

| Test | Duration | CPU | Status |
|------|----------|-----|--------|
| Baseline (Idle) | 340ms | 125ms | ✓ |
| Under Load (75% CPU) | 2,450ms | 890ms | ❌ |
| Parallel (50 threads) | 3,450ms avg | - | ⚠️  |

## Critical Issues

1. **Functional Bug**: 2 rows violate filter criteria (OR should be AND)
2. **Performance**: 621% slower under load
3. **Index Usage**: Using Index Scan instead of Seek

## Recommendations

**Priority 1: Fix WHERE Clause**
```sql
-- BEFORE (incorrect)
WHERE avg_duration > 1000 OR max_duration > 5000

-- AFTER (correct)
WHERE avg_duration > 1000 AND max_duration > 5000
```

**Priority 2: Add Covering Index**
```sql
CREATE INDEX IX_covering ON runtime_stats(avg_duration)
INCLUDE (query_id, execution_count);
```

**Expected Impact:** 7.5/10 → 9.2/10
```

---

## Connection Information

After `/testscript` runs, database remains available:

**Server Details:**
- **Host:** `localhost,1433`
- **Authentication:** SQL Server Authentication
- **Username:** `sa`
- **Password:** `Pass@word1`
- **Database:** `LoadTestDB`

**Connect with sqlcmd:**
```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB
```

**Connect with SSMS:**
1. Server: `localhost,1433`
2. Auth: SQL Server Authentication
3. Login: `sa`
4. Password: `Pass@word1`
5. Trust server certificate: ✓

---

## Architecture

### Test Flow

```
User Script → Criteria Extraction → Schema Analysis → Data Gen
                                                         ↓
Report ← Evaluation ← Test Execution ← Background Load ←┘
```

### Background Load Strategy

**Key Innovation:** Load queries operate on the **SAME tables** as the user's script.

Example:
```
User Script: SELECT * FROM employee WHERE salary > 50000

Background Load (on employee table):
- CPU queries: POWER(salary, 2), complex calculations
- IO queries: Full scans, large joins on employee
- Blocking: UPDATE employee transactions

Result: Realistic contention on the exact tables being tested
```

### Scoring Algorithm

```python
overall_score = (
    functional_correctness * 0.25 +
    output_schema * 0.10 +
    row_count * 0.05 +
    index_usage * 0.20 +
    performance * 0.30 +
    qds_performance * 0.10
)

grade = {
    9.0-10.0: "EXCELLENT",
    7.5-8.9: "GOOD",
    6.0-7.4: "NEEDS IMPROVEMENT",
    0.0-5.9: "POOR"
}
```

---

## Troubleshooting

### "ostress.exe not found"

```bash
# Re-extract tools
cd .claude/skills/testscript/tools
./extract-ostress.bat

# Verify
./ostress.exe -?
```

### "Cannot connect to SQL Server"

```bash
# Check if SQL Server is running
docker ps --filter "name=dams-sqlserver-dev"

# If not running, start with /testsql
/testsql setup LoadTestDB
```

### "Background load won't reach target CPU"

```bash
# Increase threads
/testscript ./test.sql --threads 150

# Or check Docker CPU allocation
# Docker Desktop → Settings → Resources → CPUs: 4+
```

### "Script parsing failed"

- Check for SQL syntax errors
- Avoid dynamic SQL (EXEC, sp_executesql)
- Simplify complex CTEs for parsing

### "High failure rate in parallel test"

- Normal for blocking scenarios (<10% is acceptable)
- If >20%, script may have locking issues
- Check recommendations in report

---

## Dependencies

### Required
- ✓ Windows 10/11 (64-bit)
- ✓ Docker Desktop (8GB+ RAM)
- ✓ `/testsql` skill (SQL Server environment)
- ✓ ostress.exe (bundled, needs extraction)
- ✓ sqlcmd (SQL Server tools)

### Optional
- GitHub CLI (`gh`) for PR integration
- Azure DevOps CLI for ADO integration
- SSMS or Azure Data Studio for manual inspection

---

## Comparison: Traditional vs `/testscript`

| Aspect | Manual Testing | /testscript Skill |
|--------|----------------|-------------------|
| **Setup Time** | Hours | 5 minutes |
| **Test Data** | Manual | Auto-generated (50K+ rows) |
| **Background Load** | Manual scripts | Auto-generated on same tables |
| **Functional Validation** | Manual review | Automated with scoring |
| **Performance Testing** | One-off | 3 scenarios (idle/loaded/parallel) |
| **Index Analysis** | Manual plan review | Automated detection |
| **Report** | Manual docs | Auto-generated markdown |
| **Repeatability** | Low | High |
| **Scalability** | Per-script effort | Reusable framework |

---

## Key Features

### 1. Autonomous Operation ✓
- Minimal user interaction
- Automatic schema detection
- Self-tuning background load
- Complete testing pipeline

### 2. Comprehensive Testing ✓
- Multiple scenarios (idle, loaded, parallel)
- Real background load on same tables
- Functional + performance validation
- Execution plan analysis

### 3. Intelligent Analysis ✓
- Multi-source criteria extraction
- SQL parsing and schema inference
- Index usage optimization detection
- QDS query performance analysis

### 4. Actionable Results ✓
- Quantified scores (0-10)
- Specific issues identified
- Code examples for fixes
- Before/after comparisons

### 5. Integration Ready ✓
- File paths, ADO, PR support
- Interactive ADO/PR updates
- Database persistence for inspection
- Proper cleanup on demand

---

## Known Limitations

1. **Windows-only** - ostress.exe is Windows-only tool
2. **SQL Server only** - Designed for SQL Server, not other databases
3. **Simple SQL parsing** - Complex dynamic SQL may not parse correctly
4. **Requires /testsql** - Depends on /testsql skill for SQL Server environment

---

## Support

### Documentation
- Main Skill: [.claude/skills/testscript/SKILL.md](.claude/skills/testscript/SKILL.md)
- User Guide: [.claude/skills/testscript/README.md](.claude/skills/testscript/README.md)
- Tools Setup: [.claude/skills/testscript/TOOLS_SETUP.md](.claude/skills/testscript/TOOLS_SETUP.md)
- Implementation: [.claude/skills/testscript/implementation/](.claude/skills/testscript/implementation/)

### Common Issues
- Check test logs: `.claude/testScriptResults/{timestamp}/test_log.txt`
- Check SQL Server logs: `docker logs dams-sqlserver-dev`
- Check ostress output: `.claude/testScriptResults/{timestamp}/background_load/ostress.log`

### Reporting Bugs
Include:
- Command used
- Error message and logs
- Script being tested
- OS and Docker version

---

## License

Part of the Agents of Action repository. See main repository LICENSE.

---

## Changelog

### Version 1.0.0 (2024-01-29)
- Initial release
- 7-phase autonomous validation framework
- Multi-source success criteria extraction
- Background load on same tables
- Scoring and evaluation system
- Interactive end-of-run flow
- Bundled ostress.exe support

---

**Status:** Production Ready ✓
**Platform:** Windows 10/11 (64-bit)
**Dependencies:** Docker Desktop, /testsql skill, ostress.exe
**Next Step:** Extract ostress.exe and start validating!

For the latest updates: [AgentsOfAction Repository](https://github.com/your-org/AgentsOfAction)
