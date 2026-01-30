# Phase 3: Generate Test Data

## Goal
Create database schema and populate with 50,000+ rows per table, plus populate Query Data Store if needed.

## Input
- `table_definitions`: From Phase 2
- `detected_qds_query`: From Phase 2
- `rows_per_table`: From parameters (default: 50000)

## Output
- Populated SQL Server database ready for testing
- QDS populated with 1000+ query IDs (if needed)

## Implementation Steps

### Step 1: Start SQL Server Environment

**Action:** Use `/testsql` skill to start container

```bash
# Invoke /testsql skill
Skill tool: /testsql setup LoadTestDB
```

**Wait for Ready:**
- Monitor container status
- Test connection: `sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -Q "SELECT @@VERSION"`
- Verify database created

### Step 2: Create Tables

**Action:** Execute generated CREATE TABLE scripts

```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/schema/create_tables.sql
```

**Display:** "✓ Created {count} tables"

### Step 3: Create Indexes

**Action:** Execute index creation scripts

```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/schema/create_indexes.sql
```

**Display:** "✓ Created {count} indexes"

### Step 4: Generate Data Population Script

**Action:** Create efficient bulk insert script

**For each table:**

```sql
USE [LoadTestDB];
GO

-- Disable indexes for faster insert
ALTER INDEX ALL ON [{table_name}] DISABLE;
GO

-- Generate {rows_per_table} rows
DECLARE @BatchSize INT = 1000;
DECLARE @TotalRows INT = {rows_per_table};
DECLARE @CurrentRow INT = 0;

WHILE @CurrentRow < @TotalRows
BEGIN
    INSERT INTO [{table_name}] ({column_list})
    SELECT TOP (@BatchSize)
        -- Generate appropriate data per column type
        {data_generation_logic}
    FROM sys.all_columns c1
    CROSS JOIN sys.all_columns c2;

    SET @CurrentRow = @CurrentRow + @BatchSize;

    IF @CurrentRow % 10000 = 0
        RAISERROR('Inserted %d rows into {table_name}', 0, 1, @CurrentRow) WITH NOWAIT;
END;

-- Rebuild indexes
ALTER INDEX ALL ON [{table_name}] REBUILD;
GO

-- Update statistics
UPDATE STATISTICS [{table_name}] WITH FULLSCAN;
GO
```

**Data Generation Logic by Type:**

```sql
-- For INT columns:
ABS(CHECKSUM(NEWID())) % 10000 + 1

-- For NVARCHAR columns:
'TestData_' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR)

-- For DATETIME columns:
DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())

-- For DECIMAL columns:
CAST(ABS(CHECKSUM(NEWID())) % 100000 + 100 AS DECIMAL(18,2))

-- For BIT columns:
CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 1 ELSE 0 END

-- For NVARCHAR(MAX) columns (for IO testing):
REPLICATE('x', 1000)  -- 1KB of data
```

**Write to file:**
```bash
Write: .claude/testScriptResults/{timestamp}/schema/populate_data.sql
```

### Step 5: Execute Data Population

**Action:** Run population script with progress monitoring

```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/schema/populate_data.sql \
  2>&1 | tee -a .claude/testScriptResults/{timestamp}/test_log.txt
```

**Display progress:**
```
🏗️  Phase 3: Generating Test Data
═══════════════════════════════════════════════════════

employee:         [████████████████████] 50,000/50,000 ✓
department:       [████████████████████] 50,000/50,000 ✓
salary_history:   [████████████████████] 50,000/50,000 ✓

Total Records: 150,000
Database Size: 2.3 GB
```

### Step 6: Populate Query Data Store (if needed)

**Condition:** Only if `detected_qds_query == true`

**Step 6a: Enable QDS**

```sql
USE [LoadTestDB];
GO

ALTER DATABASE [LoadTestDB]
SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES = 10,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = ALL,
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_PLANS_PER_QUERY = 50,
    WAIT_STATS_CAPTURE_MODE = ON
);
GO
```

**Step 6b: Generate Diverse Queries to Populate QDS**

Create script to execute 1000+ unique queries:

```sql
-- Generate variety of queries against test tables
DECLARE @i INT = 0;
WHILE @i < 1000
BEGIN
    -- Query variant 1: Different filters
    EXEC sp_executesql N'SELECT * FROM employee WHERE employeeid > @id',
        N'@id INT', @id = @i;

    -- Query variant 2: Different aggregations
    EXEC sp_executesql N'SELECT COUNT(*) FROM employee WHERE deptid = @dept',
        N'@dept INT', @dept = (@i % 10);

    -- Query variant 3: Different joins
    EXEC sp_executesql N'SELECT e.*, d.* FROM employee e JOIN department d
        ON e.deptid = d.deptid WHERE e.employeeid > @id',
        N'@id INT', @id = @i;

    SET @i = @i + 1;
END;
GO
```

**Execute to populate QDS:**
```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/schema/populate_qds.sql
```

**Verify QDS population:**
```sql
SELECT COUNT(DISTINCT query_id) AS query_count
FROM sys.query_store_query;
-- Should return 1000+
```

**Display:** "✓ QDS populated with {count} query IDs"

### Step 7: Verify Data Quality

**Action:** Run validation queries

```sql
-- Check row counts
SELECT
    t.name AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
  AND t.is_ms_shipped = 0
GROUP BY t.name;

-- Check database size
EXEC sp_spaceused;

-- Check index health
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    s.used_page_count * 8 / 1024 AS size_mb
FROM sys.indexes i
INNER JOIN sys.dm_db_partition_stats s ON i.object_id = s.object_id
  AND i.index_id = s.index_id
WHERE OBJECT_NAME(i.object_id) NOT LIKE 'sys%'
ORDER BY size_mb DESC;
```

**Save results:** `.claude/testScriptResults/{timestamp}/schema/data_verification.txt`

### Step 8: Create Backup (Optional)

**Action:** Backup populated database for quick restore

```bash
docker exec dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "Pass@word1" -Q \
  "BACKUP DATABASE [LoadTestDB] TO DISK = '/var/opt/mssql/backup/LoadTestDB_populated.bak'"
```

**Display:** "✓ Backup created: LoadTestDB_populated.bak"

## Display Progress

```
🏗️  Phase 3: Generate Test Data
═══════════════════════════════════════════════════════

✓ SQL Server started (localhost:1433)
✓ Database created: LoadTestDB
✓ Created 3 tables
✓ Created 5 indexes

Populating data:
  employee:       [████████████████████] 50,000 ✓
  department:     [████████████████████] 50,000 ✓
  salary_history: [████████████████████] 50,000 ✓

✓ Total records: 150,000
✓ Database size: 2.3 GB
✓ QDS populated: 1,234 query IDs
✓ Backup created

Time elapsed: 3m 45s

→ Proceeding to Phase 4: Generate Background Load
```

## Error Handling

### SQL Server Won't Start
- Check Docker is running
- Check port 1433 availability
- Verify `/testsql` skill is installed
- See `/testsql` documentation

### Table Creation Fails
- Check for SQL syntax errors
- Verify data types are valid
- Check for reserved keywords in column names

### Data Population Slow
- Normal for 50K+ rows per table
- Estimated time: 2-5 minutes per table
- Can reduce with `--rows-per-table` parameter

### QDS Not Enabling
- Check SQL Server version (2016+)
- Check database compatibility level
- Manually enable if auto-enable fails

## Output Summary

**Variables:**
- `db_size_gb`: Actual database size
- `qds_query_count`: Number of queries in QDS (if applicable)
- `tables_created`: List of table names
- `data_populated`: Boolean success flag

**Files:**
- `schema/populate_data.sql`
- `schema/populate_qds.sql` (if QDS detected)
- `schema/data_verification.txt`

**Ready for Phase 4:** YES

---

**End of Phase 3 Implementation**
