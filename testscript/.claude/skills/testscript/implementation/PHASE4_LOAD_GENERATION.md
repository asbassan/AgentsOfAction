# Phase 4: Generate Background Load

## Goal
Create and execute background load queries on the SAME tables used by the user's script, bringing CPU to target level (default 75%).

## Input
- `table_definitions`: From Phase 2
- `join_relationships`: From Phase 2
- `cpu_target`: From parameters (default: 75%)
- `threads`: From parameters (default: 50)

## Output
- Background load running at target CPU
- `background_load_pid`: Process ID for monitoring/cleanup

## Key Principle
**Background queries MUST operate on the SAME tables as the user's script** to create realistic contention and stress on those specific tables.

## Implementation Steps

### Step 1: Generate CPU-Intensive Queries

**Action:** Create queries that consume CPU on user's tables

**Query Patterns:**

```sql
--==================================
-- CPU-INTENSIVE QUERIES
-- Generated for tables: {table_list}
--==================================
USE [LoadTestDB];
GO

--Query 1: Complex calculations with POWER and LOG
SELECT
    {pk_column},
    POWER({numeric_column}, 2) * LOG({pk_column} + 1) AS complex_calc,
    REPLICATE({text_column}, 50) AS repeated_text,
    CAST(SQRT({numeric_column}) AS VARCHAR(50)) AS sqrt_text
FROM [{table_name}]
WHERE {pk_column} % 2 = 0
OPTION (MAXDOP 1, RECOMPILE);
GO

-- Query 2: Cross join for Cartesian product
SELECT
    t1.{pk_column} AS id1,
    t2.{pk_column} AS id2,
    POWER(t1.{numeric_column}, 2) + POWER(t2.{numeric_column}, 2) AS sum_squares,
    SUBSTRING(t1.{text_column}, 1, 10) + SUBSTRING(t2.{text_column}, 1, 10) AS combined
FROM [{table_name}] t1
CROSS JOIN [{table_name}] t2
WHERE t1.{pk_column} < 100 AND t2.{pk_column} < 100
OPTION (MAXDOP 1, RECOMPILE);
GO

-- Query 3: Recursive CTE
WITH RECURSIVE cte AS (
    SELECT {pk_column}, {numeric_column}, 0 AS level
    FROM [{table_name}]
    WHERE {pk_column} <= 100

    UNION ALL

    SELECT t.{pk_column}, t.{numeric_column}, cte.level + 1
    FROM [{table_name}] t
    INNER JOIN cte ON t.{pk_column} = cte.{pk_column} + 1
    WHERE cte.level < 5
)
SELECT
    level,
    COUNT(*) AS cnt,
    SUM({numeric_column}) AS total,
    AVG({numeric_column}) AS avg_val
FROM cte
GROUP BY level
OPTION (MAXDOP 2, RECOMPILE);
GO
```

**Generate for each table:**
```python
for table_name, columns in table_definitions.items():
    pk_column = find_primary_key(columns)
    numeric_column = find_numeric_column(columns)
    text_column = find_text_column(columns)

    cpu_query = generate_cpu_query(table_name, pk_column, numeric_column, text_column)
    cpu_queries.append(cpu_query)
```

**Write:** `.claude/testScriptResults/{timestamp}/background_load/cpu_intensive.sql`

### Step 2: Generate IO-Intensive Queries

**Action:** Create queries causing physical disk reads

**Query Patterns:**

```sql
--==================================
-- IO-INTENSIVE QUERIES
-- Force table scans and sorts
--==================================
USE [LoadTestDB];
GO

-- Query 1: Full table scan with ORDER BY
SELECT *
FROM [{table_name}]
ORDER BY {pk_column} DESC, {text_column}
OPTION (RECOMPILE, MAXDOP 4);
GO

-- Query 2: Large JOIN with aggregation
SELECT
    {join_table_1}.{pk_column},
    {join_table_2}.{pk_column},
    COUNT(*) AS cnt,
    SUM({join_table_1}.{numeric_column}) AS total,
    STRING_AGG(CAST({join_table_1}.{pk_column} AS VARCHAR), ',') AS ids
FROM [{join_table_1}]
LEFT JOIN [{join_table_2}]
    ON {join_relationship}
GROUP BY {join_table_1}.{pk_column}, {join_table_2}.{pk_column}
HAVING COUNT(*) > 0
ORDER BY total DESC
OPTION (HASH JOIN, ORDER GROUP, MAXDOP 4, RECOMPILE);
GO

-- Query 3: Nested subqueries causing multiple scans
SELECT
    t.{pk_column},
    t.{text_column},
    (SELECT COUNT(*) FROM [{table_name}] WHERE {pk_column} < t.{pk_column}) AS smaller_count,
    (SELECT AVG({numeric_column}) FROM [{table_name}] WHERE {pk_column} > t.{pk_column}) AS larger_avg
FROM [{table_name}] t
WHERE t.{pk_column} % 10 = 0
OPTION (RECOMPILE, MAXDOP 4);
GO
```

**Generate with joins if detected:**
```python
if join_relationships:
    for join in join_relationships:
        io_query = generate_join_io_query(join)
        io_queries.append(io_query)
```

**Write:** `.claude/testScriptResults/{timestamp}/background_load/io_intensive.sql`

### Step 3: Generate Blocking Queries

**Action:** Create transactions that hold locks

**Query Patterns:**

```sql
--==================================
-- BLOCKING QUERIES
-- Hold locks on tables
--==================================
USE [LoadTestDB];
GO

-- Blocking Pattern 1: Long UPDATE transaction
BEGIN TRANSACTION;

UPDATE [{table_name}]
SET {numeric_column} = {numeric_column} * 1.01,
    {text_column} = {text_column} + '_updated'
WHERE {pk_column} % 5 = 0;

WAITFOR DELAY '00:00:05';  -- Hold lock for 5 seconds

COMMIT TRANSACTION;
GO

-- Blocking Pattern 2: Exclusive table lock
BEGIN TRANSACTION;

SELECT * FROM [{table_name}] WITH (TABLOCKX);

WAITFOR DELAY '00:00:03';

ROLLBACK TRANSACTION;
GO

-- Blocking Pattern 3: Deadlock scenario (part A)
BEGIN TRANSACTION;

UPDATE [{table_1}]
SET {column} = {column} + 1
WHERE {pk_column} % 2 = 0;

WAITFOR DELAY '00:00:02';

UPDATE [{table_2}]
SET {column} = {column} + 1
WHERE {pk_column} % 2 = 0;

COMMIT TRANSACTION;
GO

-- Blocking Pattern 3: Deadlock scenario (part B)
BEGIN TRANSACTION;

UPDATE [{table_2}]
SET {column} = {column} + 1
WHERE {pk_column} % 2 = 1;

WAITFOR DELAY '00:00:02';

UPDATE [{table_1}]
SET {column} = {column} + 1
WHERE {pk_column} % 2 = 1;

COMMIT TRANSACTION;
GO
```

**Write:** `.claude/testScriptResults/{timestamp}/background_load/blocking.sql`

### Step 4: Create Master Load Script

**Action:** Combine all load patterns with random selection

```sql
--==================================
-- MASTER BACKGROUND LOAD SCRIPT
-- Randomly executes CPU, IO, and blocking queries
-- Duration: Infinite (until stopped)
--==================================
USE [LoadTestDB];
GO

DECLARE @LoopCounter INT = 0;

WHILE 1 = 1  -- Infinite loop
BEGIN
    SET @LoopCounter = @LoopCounter + 1;

    -- Randomly select query type
    DECLARE @QueryType INT = ABS(CHECKSUM(NEWID())) % 3;

    BEGIN TRY
        IF @QueryType = 0
        BEGIN
            -- Execute CPU-intensive query (60% of time)
            {random_cpu_query}
        END
        ELSE IF @QueryType = 1
        BEGIN
            -- Execute IO-intensive query (30% of time)
            {random_io_query}
        END
        ELSE
        BEGIN
            -- Execute blocking query (10% of time)
            {random_blocking_query}
        END
    END TRY
    BEGIN CATCH
        -- Ignore errors, continue loop
        PRINT 'Error in iteration ' + CAST(@LoopCounter AS VARCHAR);
    END CATCH;

    -- Small delay between iterations
    WAITFOR DELAY '00:00:00.100';  -- 100ms

    -- Progress indicator every 100 iterations
    IF @LoopCounter % 100 = 0
        RAISERROR('Background load: %d iterations', 0, 1, @LoopCounter) WITH NOWAIT;
END;
GO
```

**Write:** `.claude/testScriptResults/{timestamp}/background_load/master_load.sql`

### Step 5: Start Background Load with ostress.exe

**Action:** Launch load using bundled ostress.exe

**Command:**
```bash
# Start with initial thread count
cd .claude/skills/testscript/tools

./ostress.exe \
    -S "localhost,1433" \
    -U sa \
    -P "Pass@word1" \
    -d LoadTestDB \
    -i "../../../testScriptResults/{timestamp}/background_load/master_load.sql" \
    -n {threads} \
    -r 999999 \
    -q \
    -o "../../../testScriptResults/{timestamp}/background_load/ostress_output" \
    > ../../../testScriptResults/{timestamp}/background_load/ostress.log 2>&1 &

# Capture process ID
OSTRESS_PID=$!
echo $OSTRESS_PID > .claude/testScriptResults/{timestamp}/background_load/ostress.pid
```

**Store:** `background_load_pid` for later cleanup

### Step 6: Monitor CPU and Adjust Threads

**Action:** Monitor CPU until target is reached

**Monitoring Loop:**
```bash
TARGET_CPU={cpu_target}
CURRENT_THREADS={threads}
MAX_ADJUSTMENTS=5
ADJUSTMENT_COUNT=0

while [ $ADJUSTMENT_COUNT -lt $MAX_ADJUSTMENTS ]; do
    # Wait 30 seconds for stabilization
    sleep 30

    # Get current CPU usage
    CPU=$(docker stats dams-sqlserver-dev --no-stream --format "{{.CPUPerc}}" | tr -d '%')
    CPU_INT=${CPU%.*}

    echo "Current CPU: ${CPU_INT}% (Target: ${TARGET_CPU}%)"

    # Check if within acceptable range (±5%)
    DIFF=$((CPU_INT - TARGET_CPU))
    ABS_DIFF=${DIFF#-}  # Absolute value

    if [ $ABS_DIFF -le 5 ]; then
        echo "✓ CPU at target: ${CPU_INT}%"
        break
    fi

    # Adjust threads
    if [ $CPU_INT -lt $((TARGET_CPU - 5)) ]; then
        # Too low, increase threads by 25%
        NEW_THREADS=$((CURRENT_THREADS * 125 / 100))
        echo "↑ Increasing threads: $CURRENT_THREADS → $NEW_THREADS"
    else
        # Too high, decrease threads by 20%
        NEW_THREADS=$((CURRENT_THREADS * 80 / 100))
        echo "↓ Decreasing threads: $CURRENT_THREADS → $NEW_THREADS"
    fi

    # Kill current ostress
    kill $OSTRESS_PID
    wait $OSTRESS_PID 2>/dev/null

    # Restart with new thread count
    ./ostress.exe \
        -S "localhost,1433" -U sa -P "Pass@word1" \
        -d LoadTestDB \
        -i "master_load.sql" \
        -n $NEW_THREADS \
        -r 999999 -q \
        -o "ostress_output" &

    OSTRESS_PID=$!
    CURRENT_THREADS=$NEW_THREADS
    ADJUSTMENT_COUNT=$((ADJUSTMENT_COUNT + 1))
done

if [ $ADJUSTMENT_COUNT -eq $MAX_ADJUSTMENTS ]; then
    echo "⚠️  Warning: Could not reach target CPU after $MAX_ADJUSTMENTS adjustments"
    echo "   Current: ${CPU_INT}%, Target: ${TARGET_CPU}%"
    echo "   Proceeding anyway..."
fi
```

**Display progress:**
```
⚡ Phase 4: Starting Background Load
═══════════════════════════════════════════════════════

✓ Generated 45 load queries:
  • CPU-intensive: 18 queries
  • IO-intensive: 15 queries
  • Blocking: 12 queries

Starting ostress.exe with 50 threads...
✓ Background load started (PID: 12345)

Adjusting to target CPU (75%):
  Attempt 1: 45% → Increasing to 63 threads
  Attempt 2: 68% → Increasing to 79 threads
  Attempt 3: 76% ✓ At target!

✓ CPU at target: 76%
✓ Background load stable

Metrics:
• Threads: 79
• Queries/sec: ~450
• Avg duration: 180ms
```

### Step 7: Verify Load Distribution

**Action:** Confirm load is hitting all tables

```sql
-- Check query execution on each table
SELECT
    OBJECT_NAME(ios.object_id) AS table_name,
    SUM(ios.leaf_insert_count) AS inserts,
    SUM(ios.leaf_update_count) AS updates,
    SUM(ios.leaf_delete_count) AS deletes,
    SUM(ios.range_scan_count) AS range_scans,
    SUM(ios.singleton_lookup_count) AS lookups
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) ios
WHERE OBJECT_NAME(ios.object_id) IN ({user_table_list})
GROUP BY ios.object_id
ORDER BY table_name;
```

**Display:** "✓ Load distributed across {count} tables"

## Display Progress

```
⚡ Phase 4: Generate Background Load
═══════════════════════════════════════════════════════

✓ Generated 45 background queries
  • CPU queries: 18 (on employee, department, salary_history)
  • IO queries: 15 (with joins on deptid)
  • Blocking queries: 12 (transactions with delays)

✓ Started ostress.exe (79 threads, PID: 12345)
✓ CPU at target: 76% (target: 75%)
✓ Load stable for 60 seconds

Background Load Status:
• Queries executed: 15,234
• Avg query duration: 180ms
• Tables under load: employee, department, salary_history

Time elapsed: 2m 15s

→ Proceeding to Phase 5: Execute Tests
```

## Error Handling

### Cannot Reach Target CPU

```
⚠️  Warning: Background load only reaching 45% CPU

Possible causes:
- Insufficient data (need more rows)
- Queries too simple
- Hardware too powerful

Options:
1. Increase thread count manually: --threads 150
2. Add more complex queries
3. Proceed with current load (45%)
```

### ostress.exe Crashes

```
❌ Error: ostress.exe process terminated unexpectedly

Check logs: .claude/testScriptResults/{timestamp}/background_load/ostress.log

Common causes:
- Connection timeout
- SQL Server restart
- Out of memory

Retrying with fewer threads...
```

### High Error Rate

```
⚠️  High error rate detected (>10%)

Errors in background queries (likely blocking/deadlocks):
• Total executed: 10,000
• Failures: 1,234 (12.3%)

This is expected with blocking queries, continuing...
```

## Output Summary

**Variables:**
- `background_load_pid`: Process ID for cleanup
- `actual_cpu_percent`: Final CPU level achieved
- `threads_final`: Final thread count used
- `load_stable`: Boolean (true if stable for 60s)

**Files:**
- `background_load/cpu_intensive.sql`
- `background_load/io_intensive.sql`
- `background_load/blocking.sql`
- `background_load/master_load.sql`
- `background_load/ostress.pid`
- `background_load/ostress.log`

**Ready for Phase 5:** YES

**IMPORTANT:** Background load continues running through Phase 5!

---

**End of Phase 4 Implementation**
