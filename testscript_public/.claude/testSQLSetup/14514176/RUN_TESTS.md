# Quick Start: Run DropUnusedIndexDMV Tests

## For PR Reviewers

This document provides quick commands to validate `DropUnusedIndexDMV.sql` functionality.

---

## Option 1: Using Docker (Recommended)

### Prerequisites
- Docker Desktop running
- SQL Server 2022 container (or use CAP-DAMS test rig)

### Commands
```bash
# 1. Start SQL Server container (if not already running)
cd .claude/testSQLSetup
docker compose up -d

# 2. Wait for SQL Server to be ready (check status)
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -C -Q "SELECT @@VERSION"

# 3. Copy test script to container
docker cp src/DAMS-Scripts/ProductSpecificScripts/DropUnusedIndex/Test_DropUnusedIndexDMV.sql \
  dams-sqlserver-dev:/tmp/

# 4. Run test script
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -d capdamstest -C \
  -i /tmp/Test_DropUnusedIndexDMV.sql

# Expected output: "Tests Passed: 10 / 10" and "ALL TESTS PASSED SUCCESSFULLY!"
```

---

## Option 2: Using SQL Server Management Studio (SSMS)

### Steps
1. Open SSMS
2. Connect to test SQL Server instance
3. Open: `src/DAMS-Scripts/ProductSpecificScripts/DropUnusedIndex/Test_DropUnusedIndexDMV.sql`
4. Select test database (or create new test database)
5. Press **F5** to execute
6. Check **Messages** pane for results

### Expected Output
```
========================================
TEST SUMMARY
========================================

Tests Passed: 10 / 10
Success Rate: 100%

╔════════════════════════════════════╗
║   ALL TESTS PASSED SUCCESSFULLY!   ║
╚════════════════════════════════════╝
```

---

## Option 3: Using sqlcmd (Windows Command Line)

```cmd
sqlcmd -S localhost,1433 -U sa -P YourPassword -d testdb ^
  -i src\DAMS-Scripts\ProductSpecificScripts\DropUnusedIndex\Test_DropUnusedIndexDMV.sql
```

---

## What the Test Validates

### ✅ Test Coverage
1. **Empty recommendations** - Script handles no data gracefully
2. **Valid records** - 3 valid records inserted correctly
3. **JSON parsing** - Schema, table, index columns, included columns
4. **Filtering** - Invalid type/reason/state records filtered out
5. **Object resolution** - objectid/indexid resolved from sys.indexes
6. **Key ordinals** - Column ordinal positions extracted
7. **DROP commands** - Valid SQL DROP INDEX statements generated
8. **Duplicate prevention** - No duplicate entries on re-run
9. **Error handling** - Catches and logs errors per index
10. **Final status** - Correct counts of successful/failed/pending drops

### ✅ Test Scenarios
- **3 valid test cases**: Simple index, compound index, production-like scenario
- **3 invalid test cases**: Wrong type, wrong reason, wrong state (all correctly filtered)

---

## Quick Validation

### Just want to verify it works?
Run this one-liner (Docker):
```bash
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -d capdamstest -C -i /tmp/Test_DropUnusedIndexDMV.sql 2>&1 | grep "Tests Passed:"
```

**Expected**: `Tests Passed: 10 / 10`

---

## Troubleshooting

### Error: Container not found
```bash
# Check container status
docker ps -a | grep sqlserver

# Start container if stopped
docker start dams-sqlserver-dev
```

### Error: Database does not exist
```bash
# Create test database
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Pass@word1' -C \
  -Q "CREATE DATABASE capdamstest;"
```

### Error: Login failed
- Verify password in `.claude/testSQLSetup/.env`
- Check SQL Server authentication is enabled

---

## Test Cleanup

By default, test objects remain in the database for inspection.

**To cleanup manually:**
```sql
DROP TABLE dbo.MockTuningRecommendations;
DROP TABLE dbo.DroppedUnusedIndexRecord;
DROP TABLE pjdraft.MSP_WEB_VIEW_FIELDS;
DROP TABLE dbo.TestTable2;
DROP TABLE dbo.TestTable1;
DROP SCHEMA pjdraft;
```

Or uncomment the cleanup section at the end of `Test_DropUnusedIndexDMV.sql`.

---

## Questions?

- **Test Documentation**: See `TEST_RESULTS_DropUnusedIndexDMV.md` for detailed results
- **Script Details**: See `DropUnusedIndexDMV.sql` inline comments
- **Contact**: capdsdataengine@microsoft.com

---

**Test Version**: 1.0
**Last Updated**: 2026-01-26
**Author**: amarpb (Amarpreet Bassan)
