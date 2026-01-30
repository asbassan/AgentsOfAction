# Phase 5: Execute Tests

## Goal
Run the user's script under multiple scenarios: baseline (idle), under load (75% CPU), and parallel stress test.

## Input
- `user_script_content`: The script being tested
- `background_load_pid`: Running background load process
- `threads`: From parameters
- `duration`: From parameters

## Output
- Test results for all scenarios
- Execution plans (XML)
- Output data (CSV)
- Performance metrics

## Implementation Steps

### Step 1: Prepare User Script for Testing

**Action:** Wrap user script with instrumentation

**Test Wrapper Template:**
```sql
--===============================================
-- USER SCRIPT TEST WRAPPER
-- Captures performance metrics and execution plan
--===============================================
USE [LoadTestDB];
GO

-- Enable statistics
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET SHOWPLAN_XML ON;
GO

-- Execute user script
{user_script_content}
GO

-- Reset settings
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
SET SHOWPLAN_XML OFF;
GO
```

**Write files:**
- `.claude/testScriptResults/{timestamp}/execution/test_baseline.sql` (idle)
- `.claude/testScriptResults/{timestamp}/execution/test_under_load.sql` (same content)

### Step 2: Test A - Baseline (Idle DB)

**Action:** Execute script on idle database

**First, stop background load temporarily:**
```bash
kill -STOP $background_load_pid  # Pause (don't kill)
sleep 5  # Let queries finish
```

**Execute script:**
```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/execution/test_baseline.sql \
  -o .claude/testScriptResults/{timestamp}/execution/baseline_output.txt \
  -y 0 -Y 0 -s "," \
  2>&1
```

**Parse output for metrics:**
```python
# Extract from STATISTICS TIME
parse_pattern(r'CPU time = (\d+) ms')  → baseline_cpu_ms
parse_pattern(r'elapsed time = (\d+) ms')  → baseline_duration_ms

# Extract from STATISTICS IO
parse_pattern(r'logical reads (\d+)')  → baseline_logical_reads
parse_pattern(r'physical reads (\d+)')  → baseline_physical_reads

# Extract execution plan XML
parse_xml_plan()  → baseline_plan_xml
```

**Save data:**
```python
test_results['baseline'] = {
    'duration_ms': baseline_duration_ms,
    'cpu_ms': baseline_cpu_ms,
    'logical_reads': baseline_logical_reads,
    'physical_reads': baseline_physical_reads,
    'blocked_count': 0,  # No blocking on idle DB
    'timeout': False
}
```

**Resume background load:**
```bash
kill -CONT $background_load_pid
```

**Display:**
```
🚀 Phase 5: Executing Tests
═══════════════════════════════════════════════════════

Test A: Baseline (Idle DB)
✓ Executed in 245ms
  • CPU time: 125ms
  • Logical reads: 1,234
  • Physical reads: 0
  • Blocking: None
```

### Step 3: Test B - Under Load (75% CPU Background)

**Action:** Execute script while background load running

**Verify background load still running:**
```bash
if ! ps -p $background_load_pid > /dev/null; then
    echo "❌ Background load stopped! Restarting..."
    # Restart load (see Phase 4)
fi

# Verify CPU is still at target
CPU=$(docker stats --no-stream --format "{{.CPUPerc}}")
echo "Background CPU: $CPU"
```

**Execute script:**
```bash
sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB \
  -i .claude/testScriptResults/{timestamp}/execution/test_under_load.sql \
  -o .claude/testScriptResults/{timestamp}/execution/loaded_output.txt \
  -y 0 -Y 0 -s "," \
  -t 60 \  # 60 second timeout
  2>&1
```

**Monitor during execution:**
- CPU spike detection
- Blocking events
- Deadlocks

**Query for blocking while running:**
```sql
-- Run in parallel
SELECT
    blocking_session_id,
    wait_duration_ms,
    wait_type
FROM sys.dm_exec_requests
WHERE session_id = {test_session_id}
  AND blocking_session_id > 0;
```

**Parse results:**
```python
test_results['loaded'] = {
    'duration_ms': loaded_duration_ms,
    'cpu_ms': loaded_cpu_ms,
    'logical_reads': loaded_logical_reads,
    'physical_reads': loaded_physical_reads,
    'blocked_count': blocked_events_detected,
    'blocked_duration_ms': total_wait_time,
    'timeout': execution_timeout_occurred,
    'db_cpu_during_test': cpu_percentage_peak
}
```

**Display:**
```
Test B: Under Load (75% CPU Background)
✓ Executed in 1,890ms
  • CPU time: 890ms
  • Logical reads: 5,678
  • Physical reads: 234
  • Blocking: 3 events (total 450ms wait)
  • DB CPU peak: 89%
```

### Step 4: Compare Baseline vs Loaded

**Action:** Calculate performance degradation

```python
degradation = {
    'duration_increase_pct': (loaded_duration - baseline_duration) / baseline_duration * 100,
    'cpu_increase_pct': (loaded_cpu - baseline_cpu) / baseline_cpu * 100,
    'physical_io_increase': loaded_physical_reads - baseline_physical_reads,
    'blocking_introduced': test_results['loaded']['blocked_count'] > 0
}
```

**Display:**
```
Comparison (Baseline vs Under Load):
• Duration: 245ms → 1,890ms (↑ 671%)
• CPU: 125ms → 890ms (↑ 612%)
• Physical IO: 0 → 234 reads (blocking caused disk reads)
• Blocking: None → 3 events

⚠️  Script performance degrades significantly under load!
```

### Step 5: Test C - Parallel Stress (50 Threads)

**Action:** Run THE USER'S SCRIPT in parallel with ostress.exe

**Create ostress script (runs THE USER'S SCRIPT):**
```sql
-- ostress_user_script.sql
-- THIS IS THE USER'S SCRIPT
-- Run in parallel to stress test it
{user_script_content}
GO
```

**Important:** Background load CONTINUES running during this test!

**Execute with ostress.exe:**
```bash
cd .claude/skills/testscript/tools

./ostress.exe \
    -S "localhost,1433" \
    -U sa \
    -P "Pass@word1" \
    -d LoadTestDB \
    -i "../../../testScriptResults/{timestamp}/execution/ostress_user_script.sql" \
    -n {threads} \
    -r 100 \  # 100 iterations per thread = 5,000 total executions
    -q \
    -t 30 \  # 30 second timeout per query
    -o "../../../testScriptResults/{timestamp}/execution/parallel_output" \
    2>&1 | tee .claude/testScriptResults/{timestamp}/execution/parallel_log.txt
```

**Monitor CPU during parallel test:**
```bash
# In background
while ostress running; do
    CPU=$(docker stats --no-stream --format "{{.CPUPerc}}")
    echo "$(date +%T) CPU: $CPU" >> cpu_log.txt
    sleep 2
done
```

**Parse ostress output:**
```
Total Time: 180 seconds
Total Iterations: 5000
Successful: 4873
Failed: 127 (2.5%)
Avg Duration: 3,450ms
Min Duration: 890ms
Max Duration: 28,450ms
```

**Save results:**
```python
test_results['parallel'] = {
    'total_executions': 5000,
    'successful': 4873,
    'failed': 127,
    'failure_rate': 0.025,
    'avg_duration_ms': 3450,
    'min_duration_ms': 890,
    'max_duration_ms': 28450,
    'timeout_count': 67,
    'cpu_peak_pct': 98,
    'duration_seconds': 180
}
```

**Display:**
```
Test C: Parallel Stress (50 threads × 100 iterations)
✓ Completed in 3m 0s
  • Total executions: 5,000
  • Successful: 4,873 (97.5%)
  • Failed: 127 (2.5%)
  • Timeouts: 67 (1.3%)
  • Avg duration: 3,450ms
  • Max duration: 28,450ms
  • DB CPU peak: 98%

⚠️  High failure rate and timeouts detected!
```

### Step 6: Capture Execution Plans

**Action:** Extract and save execution plans

**For baseline and loaded tests:**
```bash
# Plans are in the output files as XML
grep -A 10000 '<ShowPlanXML' .claude/testScriptResults/{timestamp}/execution/baseline_output.txt \
  > .claude/testScriptResults/{timestamp}/execution/baseline_plan.xml

grep -A 10000 '<ShowPlanXML' .claude/testScriptResults/{timestamp}/execution/loaded_output.txt \
  > .claude/testScriptResults/{timestamp}/execution/loaded_plan.xml
```

**Parse plans for key information:**
```python
def parse_execution_plan(plan_xml):
    # Extract index usage
    index_scans = extract_xpath(plan_xml, '//IndexScan')
    index_seeks = extract_xpath(plan_xml, '//IndexSeek')

    # Extract cost
    total_cost = extract_xpath(plan_xml, '//StmtSimple/@StatementSubTreeCost')

    # Extract warnings
    warnings = extract_xpath(plan_xml, '//Warnings')

    return {
        'index_scans': len(index_scans),
        'index_seeks': len(index_seeks),
        'total_cost': float(total_cost),
        'warnings': [w.text for w in warnings]
    }
```

### Step 7: Extract Output Data

**Action:** Save query results for functional validation (Phase 6)

**Parse CSV output:**
```bash
# Output is in baseline_output.txt and loaded_output.txt
# Extract data rows (skip statistics output)

grep -v "CPU time" .claude/testScriptResults/{timestamp}/execution/baseline_output.txt | \
  grep -v "elapsed time" | \
  grep -v "Table" | \
  grep -v "Scan count" \
  > .claude/testScriptResults/{timestamp}/execution/baseline_data.csv
```

**Verify data:**
- Row count
- Column count
- Data types
- No truncation

### Step 8: Stop Background Load

**Action:** Clean up background processes

```bash
# Stop background load ostress
kill $background_load_pid
wait $background_load_pid 2>/dev/null

# Clean up ostress processes
pkill -f "ostress.*LoadTestDB"

# Verify stopped
sleep 5
CPU=$(docker stats --no-stream --format "{{.CPUPerc}}")
echo "CPU after stop: $CPU (should be <10%)"
```

**Display:** "✓ Background load stopped"

### Step 9: Collect Final Metrics

**Action:** Query SQL Server DMVs for test statistics

```sql
-- Query execution stats from this session
SELECT
    deqs.execution_count,
    deqs.total_worker_time / 1000 AS total_cpu_ms,
    deqs.total_elapsed_time / 1000 AS total_duration_ms,
    deqs.total_logical_reads,
    deqs.total_physical_reads,
    SUBSTRING(dest.text, 1, 500) AS query_text
FROM sys.dm_exec_query_stats deqs
CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) dest
WHERE dest.text LIKE '%{user_script_identifier}%'
  AND deqs.last_execution_time >= DATEADD(MINUTE, -30, GETDATE())
ORDER BY deqs.total_elapsed_time DESC;

-- Blocking statistics
SELECT
    COUNT(*) AS total_blocking_events,
    SUM(wait_duration_ms) AS total_wait_ms
FROM sys.dm_exec_session_wait_stats
WHERE session_id = {test_session_id};

-- Deadlocks (if any)
-- Check system_health extended events
```

## Display Progress

```
🚀 Phase 5: Execute Tests
═══════════════════════════════════════════════════════

Test A: Baseline (Idle DB)
✓ Duration: 245ms | CPU: 125ms | IO: 0 physical reads

Test B: Under Load (75% CPU)
✓ Duration: 1,890ms | CPU: 890ms | IO: 234 physical reads
✓ Blocking: 3 events (450ms total wait)

Comparison:
  Duration: 245ms → 1,890ms (↑ 671%)
  CPU: 125ms → 890ms (↑ 612%)
  ⚠️  Significant performance degradation!

Test C: Parallel Stress (50 threads × 100 iterations)
✓ Total executions: 5,000
✓ Successful: 4,873 (97.5%)
❌ Failed: 127 (2.5%)
⚠️  Avg duration: 3,450ms
⚠️  Timeouts: 67 queries

Artifacts saved:
• baseline_output.txt, baseline_data.csv, baseline_plan.xml
• loaded_output.txt, loaded_data.csv, loaded_plan.xml
• parallel_log.txt, parallel_output/

Time elapsed: 8m 30s

→ Proceeding to Phase 6: Evaluate & Score
```

## Error Handling

### Script Execution Fails

```
❌ Error: User script failed to execute

Error message: {sql_error}

Possible causes:
- Missing tables/columns
- SQL syntax error
- Permission denied

Cannot proceed with evaluation.
```

### Timeout in Baseline Test

```
⚠️  Warning: Script timeout on IDLE database!

Script timed out after 60 seconds on idle DB.
This indicates the script is extremely slow.

Recommendation: Optimize script before load testing.
```

### 100% Failure Rate in Parallel

```
❌ Critical: All parallel executions failed!

Success rate: 0% (0/5000)

Common causes:
- Deadlocks
- Resource exhaustion
- Connection pool limits

Check: parallel_log.txt for details
```

## Output Summary

**Variables:**
- `test_results`: Dict with all test scenario results
- `execution_plans`: Dict with parsed plan data
- `output_data`: Query result datasets

**Files:**
- `execution/test_baseline.sql`
- `execution/test_under_load.sql`
- `execution/ostress_user_script.sql`
- `execution/baseline_output.txt`
- `execution/baseline_data.csv`
- `execution/baseline_plan.xml`
- `execution/loaded_output.txt`
- `execution/loaded_data.csv`
- `execution/loaded_plan.xml`
- `execution/parallel_log.txt`
- `execution/parallel_output/*`

**Ready for Phase 6:** YES

---

**End of Phase 5 Implementation**
