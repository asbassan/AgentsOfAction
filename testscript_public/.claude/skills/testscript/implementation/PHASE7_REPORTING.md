# Phase 7: Generate Report

## Goal
Create comprehensive validation report with scores, findings, and actionable recommendations.

## Input
- All data from Phases 1-6
- `evaluation_results`: From Phase 6
- `overall_score`: From Phase 6
- `recommendations`: From Phase 6

## Output
- `VALIDATION_REPORT.md`: Comprehensive markdown report
- Console summary displayed to user
- ADO/PR updated (if applicable)

## Implementation Steps

### Step 1: Generate Report Header

```markdown
# SQL Server Script Validation Report

**Script:** {script_path}
**Test Date:** {timestamp}
**Test Duration:** {total_elapsed_time}
**Overall Score:** {overall_score}/10 {grade_symbol}

## Executive Summary

{summary_paragraph}

**Quick Stats:**
- Database Size: {db_size_gb} GB ({total_rows} rows)
- Test Scenarios: 3 (Baseline, Under Load, Parallel)
- Total Executions: {total_query_executions}
- Background Load: {cpu_target}% CPU on {table_count} tables

**Result:** {grade} - {verdict_message}

---
```

**Example:**
```markdown
# SQL Server Script Validation Report

**Script:** ./check-slow-queries.sql
**Test Date:** 2024-01-29 14:30:00
**Test Duration:** 15m 30s
**Overall Score:** 7.5/10 ⚠️  NEEDS IMPROVEMENT

## Executive Summary

This validation tested a Query Data Store monitoring script that identifies slow queries.
The script performed well functionally (98% accuracy) but showed performance degradation
under load (↑671%) and had suboptimal index usage (Index Scan vs Seek).

**Quick Stats:**
- Database Size: 2.3 GB (150,000 rows across 3 tables)
- Test Scenarios: 3 (Baseline, Under Load, Parallel)
- Total Executions: 5,002
- Background Load: 76% CPU on employee, department, salary_history tables

**Result:** NEEDS IMPROVEMENT - Script requires optimization before production use.

---
```

### Step 2: Generate Detailed Scores Section

```markdown
## Evaluation Results

### Score Breakdown

| Criterion | Score | Weight | Weighted | Status |
|-----------|-------|--------|----------|--------|
| Functional Correctness | {score}/10 | {weight}% | {weighted} | {symbol} |
| Output Schema | {score}/10 | {weight}% | {weighted} | {symbol} |
| Row Count | {score}/10 | {weight}% | {weighted} | {symbol} |
| Index Usage | {score}/10 | {weight}% | {weighted} | {symbol} |
| Performance | {score}/10 | {weight}% | {weighted} | {symbol} |
| QDS Performance | {score}/10 | {weight}% | {weighted} | {symbol} |
| **TOTAL** | **{overall}/10** | **100%** | **{overall}** | **{symbol}** |

### Grading Scale
- 9.0-10.0: ✓ EXCELLENT - Production ready
- 7.5-8.9: ✓ GOOD - Minor improvements recommended
- 6.0-7.4: ⚠️  NEEDS IMPROVEMENT - Optimization required
- 0.0-5.9: ❌ POOR - Significant issues, not recommended

---
```

### Step 3: Generate Performance Analysis

```markdown
## Performance Analysis

### Test Results Summary

| Metric | Baseline (Idle) | Under Load (75% CPU) | Change | Parallel (50 threads) |
|--------|-----------------|----------------------|--------|-----------------------|
| **Duration** | {baseline_ms}ms | {loaded_ms}ms | ↑{pct}% | Avg: {parallel_avg}ms |
| **CPU Time** | {baseline_cpu}ms | {loaded_cpu}ms | ↑{pct}% | - |
| **Logical Reads** | {baseline_reads} | {loaded_reads} | ↑{pct}% | - |
| **Physical Reads** | {baseline_physical} | {loaded_physical} | ↑{reads} | - |
| **Blocking Events** | 0 | {blocked_count} | - | - |
| **Failures** | 0 | {fail_count} | - | {parallel_failures} ({pct}%) |

### Performance Verdict

{detailed_analysis_paragraph}

**Key Findings:**
- {finding_1}
- {finding_2}
- {finding_3}

---
```

**Example:**
```markdown
## Performance Analysis

### Test Results Summary

| Metric | Baseline (Idle) | Under Load (75% CPU) | Change | Parallel (50 threads) |
|--------|-----------------|----------------------|--------|-----------------------|
| **Duration** | 340ms | 2,450ms | ↑621% | Avg: 3,450ms |
| **CPU Time** | 125ms | 890ms | ↑612% | - |
| **Logical Reads** | 1,234 | 5,678 | ↑360% | - |
| **Physical Reads** | 0 | 234 | +234 | - |
| **Blocking Events** | 0 | 3 | - | - |
| **Failures** | 0 | 0 | - | 127 (2.5%) |

### Performance Verdict

❌ **Script shows significant performance degradation under load.**

The script performs acceptably on an idle database (340ms) but degrades dramatically
when the database is under 75% CPU load (2,450ms, a 621% increase). This indicates
the script is sensitive to resource contention and may cause issues in production.

**Key Findings:**
- ⚠️  7x slower under load - indicates poor concurrency handling
- ⚠️  Physical IO introduced under load (0 → 234 reads) - suggests blocking/cache eviction
- ⚠️  3 blocking events detected - script holds locks longer than optimal
- ⚠️  2.5% failure rate in parallel test - acceptable but could be improved

---
```

### Step 4: Generate Index Usage Analysis

```markdown
## Index Usage Analysis

### Execution Plan Summary

**Baseline Plan:**
```
{execution_plan_summary_text}
```

**Operations Breakdown:**
| Operation | Count | Tables Affected |
|-----------|-------|-----------------|
| Index Seek | {seek_count} | {tables} |
| Index Scan | {scan_count} | {tables} |
| Table Scan | {table_scan_count} | {tables} |
| Hash Join | {join_count} | {tables} |

### Index Findings

{index_analysis_details}

**Indexes Used:**
{list_of_indexes_used}

**Missing Index Recommendations (from SQL Server):**
{missing_index_suggestions}

---
```

**Example:**
```markdown
## Index Usage Analysis

### Execution Plan Summary

**Baseline Plan:**
```
SELECT TOP 100
  q.query_id,
  qt.query_sql_text,
  rs.avg_duration
FROM sys.query_store_runtime_stats rs
  INDEX SCAN on IX_runtime_stats_duration (Cost: 35%)
INNER JOIN sys.query_store_query q
  INDEX SEEK on PK_query (Cost: 5%)
INNER JOIN sys.query_store_query_text qt
  CLUSTERED INDEX SEEK (Cost: 10%)
WHERE rs.avg_duration > 1000

Estimated Subtree Cost: 2.845
Actual Rows: 100
```

**Operations Breakdown:**
| Operation | Count | Tables Affected |
|-----------|-------|-----------------|
| Index Seek | 2 | query, query_text |
| Index Scan | 1 | runtime_stats |
| Table Scan | 0 | - |
| Hash Join | 0 | - |

### Index Findings

⚠️  **Suboptimal: Using Index Scan instead of Index Seek on runtime_stats**

The script uses IX_runtime_stats_duration but performs a full index scan rather than
a seek operation. This is because:
1. Filter on avg_duration is selective (good)
2. But also filters on query_text (not in index)
3. Optimizer chose scan to avoid key lookups

**Impact:** Reads entire index (~500MB) instead of targeted rows (~5MB)

**Indexes Used:**
- ✓ IX_runtime_stats_duration (Scan) - primary filter index
- ✓ PK_query (Seek) - join key
- ✓ PK_query_text (Seek) - join key

**Missing Index Recommendations (from SQL Server):**
```sql
CREATE NONCLUSTERED INDEX IX_suggested
ON sys.query_store_runtime_stats(avg_duration)
INCLUDE (query_id, last_execution_time, execution_count);
```

---
```

### Step 5: Generate Issue Details

```markdown
## Issues Found

### Critical Issues (Priority: HIGH)

#### 1. Functional Correctness Bug

**Issue:** Script returns rows that don't meet filter criteria

**Details:**
- Expected: Only queries where avg_duration > 1000ms
- Actual: 2 out of 100 rows had avg_duration < 1000ms
  - Row 45: query_id=1234, avg_duration=987ms
  - Row 67: query_id=5678, avg_duration=654ms

**Root Cause:**
```sql
WHERE avg_duration > 1000
   OR max_duration > 5000  ← This OR clause causes bug
```

The OR condition allows rows with low avg_duration if they have high max_duration.

**Recommendation:**
```sql
WHERE avg_duration > 1000
  AND max_duration > 5000  ← Change to AND
```

---

#### 2. Performance Under Load

**Issue:** Script exceeds performance threshold under 75% CPU load

**Details:**
- Threshold: 2,000ms
- Actual: 2,450ms
- Excess: 22.5%

**Contributing Factors:**
1. Index scan instead of seek (adds 800ms)
2. Blocking events (adds 450ms total wait)
3. Physical IO introduced (cache misses)

**Recommendation:** See optimization recommendations below

---

### Warnings (Priority: MEDIUM)

#### 3. Index Scan vs Index Seek

**Issue:** Suboptimal index operation

**Details:**
- Expected: Index Seek on IX_runtime_stats_duration
- Actual: Index Scan on same index
- Impact: Reads full index instead of targeted rows

**Recommendation:**
Add covering index or remove query_text filter

---

### Minor Issues (Priority: LOW)

- Extra column in output (execution_count) - acceptable
- Hardcoded TOP 100 - consider making configurable

---
```

### Step 6: Generate Recommendations Section

```markdown
## Recommendations

### Priority 1: Fix Functional Bug

**Problem:** OR clause in WHERE allows incorrect rows

**Current Code:**
```sql
WHERE avg_duration > 1000
   OR max_duration > 5000
```

**Fixed Code:**
```sql
WHERE avg_duration > 1000
  AND max_duration > 5000
```

**Expected Impact:**
- Functional Correctness: 6/10 → 10/10
- Overall Score: 7.5/10 → 8.2/10

---

### Priority 2: Optimize Index Usage

**Problem:** Index scan instead of seek

**Option A: Add Covering Index (Recommended)**
```sql
CREATE NONCLUSTERED INDEX IX_runtime_stats_covering
ON sys.query_store_runtime_stats(avg_duration)
INCLUDE (query_id, execution_count, last_execution_time);

-- Drop old index if not used elsewhere
DROP INDEX IX_runtime_stats_duration
ON sys.query_store_runtime_stats;
```

**Option B: Remove Non-Indexed Filter**
```sql
-- Instead of:
WHERE avg_duration > 1000 AND query_text LIKE '%SELECT%'

-- Do:
WHERE avg_duration > 1000
-- Filter query_text in application code if needed
```

**Expected Impact:**
- Index Usage: 6/10 → 9/10
- Performance: 5/10 → 7/10 (faster execution)
- Overall Score: 7.5/10 → 8.8/10

---

### Priority 3: Improve Concurrency

**Problem:** Script sensitive to resource contention

**Recommendations:**

1. **Add NOLOCK hint** (if stale data acceptable):
```sql
FROM sys.query_store_runtime_stats WITH (NOLOCK)
```

2. **Add time filter** to reduce rows scanned:
```sql
WHERE rs.last_execution_time >= DATEADD(HOUR, -1, GETDATE())
  AND rs.avg_duration > 1000
```

3. **Add explicit TOP** to limit results:
```sql
SELECT TOP 100 ...
ORDER BY rs.avg_duration DESC
```

**Expected Impact:**
- Performance: 5/10 → 8/10
- Overall Score: 7.5/10 → 9.0/10

---

### Complete Optimized Script

```sql
/*
 * Optimized version incorporating all recommendations
 */
SELECT TOP 100
    q.query_id,
    qt.query_sql_text,
    rs.avg_duration,
    rs.execution_count
FROM sys.query_store_runtime_stats rs WITH (NOLOCK)
INNER JOIN sys.query_store_query q ON rs.query_id = q.query_id
INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE rs.last_execution_time >= DATEADD(HOUR, -1, GETDATE())
  AND rs.avg_duration > 1000
  AND rs.max_duration > 5000  -- Fixed: Changed OR to AND
ORDER BY rs.avg_duration DESC;
```

---
```

### Step 7: Generate Next Steps Section

```markdown
## Next Steps

### Immediate Actions

1. ✓ **Review this report** - Understand all issues and recommendations
2. ⚠️  **Fix functional bug** - Update OR to AND in WHERE clause (5 min)
3. ⚠️  **Test fixed version** - Run `/testscript` again with updated script
4. ℹ️  **Compare results** - Verify improvements in score

### Short-term (This Week)

- Create covering index on runtime_stats table
- Add NOLOCK hints if stale data acceptable
- Add time-based filter (last 1 hour)
- Re-run validation and compare scores

### Long-term (Next Sprint)

- Monitor script performance in production
- Set up alerts for slow execution (>2s)
- Consider caching results if called frequently
- Document expected performance baseline

---
```

### Step 8: Save Report File

```bash
Write: .claude/testScriptResults/{timestamp}/VALIDATION_REPORT.md
Content: {complete_report_markdown}
```

### Step 9: Display Console Summary

**Action:** Show concise summary to user

```
═══════════════════════════════════════════════════════
  VALIDATION COMPLETE
═══════════════════════════════════════════════════════

Script: ./check-slow-queries.sql
Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT

Score Breakdown:
• Functional Correctness:  6/10 ❌ (2 rows violate criteria)
• Output Schema:          10/10 ✓
• Row Count:               8/10 ✓
• Index Usage:             6/10 ⚠️  (Scan vs Seek)
• Performance:             5/10 ❌ (Slow under load)
• QDS Detection:          10/10 ✓

Critical Issues: 3
Recommendations: 5

Performance Summary:
• Baseline: 340ms ✓
• Under Load: 2,450ms ❌ (↑621%)
• Parallel: 2.5% failure rate ✓

📄 Full Report:
.claude/testScriptResults/2024-01-29_14-30-00/VALIDATION_REPORT.md

🔗 Quick View:
{file_url}

Next Steps:
1. Fix OR→AND bug in WHERE clause
2. Add covering index
3. Retest with /testscript

═══════════════════════════════════════════════════════
```

### Step 10: Ask User About ADO/PR Update

**Action:** Present results and ask user if they want to update ADO/PR

**Condition:** Only if `source_type` is "ado" or "pr"

**Implementation:**

```python
# Prepare update preview
if source_type == "ado":
    update_preview = f"""
ADO Work Item #{work_item_id} Update Preview:

State: Testing Complete
Comment: Validation Score {overall_score}/10 {grade_symbol}
  - Functional: {func_score}/10
  - Performance: {perf_score}/10
  - Index Usage: {index_score}/10
  - Critical Issues: {critical_count}
  - Recommendations: {rec_count}
    """
elif source_type == "pr":
    update_preview = f"""
PR #{pr_number} Comment Preview:

Overall Score: {overall_score}/10 {grade_symbol}
  - Functional: {func_score}/10
  - Performance: {perf_score}/10
  - Index Usage: {index_score}/10
  - Critical Issues: {critical_count}
  - Recommendations: {rec_count}

Comment will include score breakdown, issues, and recommendations.
    """

# Display preview to user
print(update_preview)

# Ask user for confirmation
AskUserQuestion(
  questions: [
    {
      question: "Would you like to update the ADO work item / PR with these results?",
      header: "Update ADO/PR?",
      options: [
        {
          label: "Yes, update now",
          description: "Post validation results to ADO work item / PR"
        },
        {
          label: "No, skip update",
          description: "Keep results local only"
        },
        {
          label: "Let me review first",
          description: "I'll update manually after reviewing the report"
        }
      ],
      multiSelect: false
    }
  ]
)
```

**Handle User Response:**

**If "Yes, update now":**

```python
if source_type == "ado":
    # Format comment for ADO
    ado_comment = f"""
Validation Complete: Score {overall_score}/10 {grade_symbol}

Quick Summary:
- Functional: {func_score}/10
- Performance: {perf_score}/10
- Index Usage: {index_score}/10

Critical Issues: {critical_count}
Status: {grade}

Full report: VALIDATION_REPORT.md

Top 3 Recommendations:
{top_3_recommendations}

Tested on {db_size}GB database with {row_count} rows.
Test duration: {duration}
    """

    # Update work item
    mcp__ado__update_work_item(
        id=work_item_id,
        fields={
            "System.State": "Testing Complete",
            "Microsoft.VSTS.Common.Priority": priority_based_on_score
        },
        comment=ado_comment
    )

    print(f"✓ ADO work item #{work_item_id} updated")

elif source_type == "pr":
    # Format comment for PR
    gh pr comment {pr_number} --body "$(cat <<'EOF'
## 🧪 Script Validation Results

**Overall Score: {overall_score}/10 {grade_symbol}**

### Summary

{summary_paragraph}

### Score Breakdown

| Criterion | Score | Status |
|-----------|-------|--------|
| Functional Correctness | {func_score}/10 | {symbol} |
| Performance | {perf_score}/10 | {symbol} |
| Index Usage | {index_score}/10 | {symbol} |

### Top Issues

1. ❌ {issue_1_title}: {issue_1_summary}
2. ⚠️  {issue_2_title}: {issue_2_summary}
3. ℹ️  {issue_3_title}: {issue_3_summary}

### Recommendations

**Priority 1:** {rec_1_summary}
```sql
{rec_1_code_example}
```

[View Full Report](.claude/testScriptResults/{timestamp}/VALIDATION_REPORT.md)

---
🤖 Generated by `/testscript` validation framework
Test Duration: {duration} | Database: {db_size}GB | Queries: {query_count}
EOF
)"

    print(f"✓ PR #{pr_number} commented")
```

**If "No, skip update" or "Let me review first":**
```python
print("Skipping ADO/PR update. You can update manually using the generated report.")
```

### Step 11: Keep Database Running for User Inspection

**Action:** Inform user that database remains available

**Display:**
```
═══════════════════════════════════════════════════════
  DATABASE STILL RUNNING
═══════════════════════════════════════════════════════

The test database is still available for inspection:

Connection Details:
• Server: localhost,1433
• Username: sa
• Password: Pass@word1
• Database: LoadTestDB

You can:
• Review the data
• Run manual queries
• Check Query Data Store
• Inspect execution plans

Example:
  sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB

The database will remain until you explicitly shut it down.
```

### Step 12: Wait for User Follow-up or Cleanup

**Action:** Ask user if they want to inspect database or clean up

```python
AskUserQuestion(
  questions: [
    {
      question: "What would you like to do next?",
      header: "Next Action?",
      options: [
        {
          label: "Shutdown and cleanup",
          description: "Backup database and stop SQL Server container"
        },
        {
          label: "Keep database running",
          description: "I want to inspect the database or run more queries"
        },
        {
          label: "Run another test",
          description: "Test a modified version of the script"
        }
      ],
      multiSelect: false
    }
  ]
)
```

**Handle User Response:**

**If "Shutdown and cleanup":**

```bash
# Verify /testsql shutdown functionality first
# Check if shutdown takes backup automatically

# Display what will happen
echo "
Shutting down SQL Server environment...

This will:
1. Backup LoadTestDB to .claude/testSQL/bootstrap/
2. Stop SQL Server container
3. Clean up Docker resources

Backup location: .claude/testSQL/bootstrap/LoadTestDB_{timestamp}.bak
"

# Execute shutdown using /testsql skill
Skill tool: /testsql shutdown

# Verify shutdown completed
sleep 5
docker ps --filter "name=dams-sqlserver-dev" --format "{{.Names}}"
# Should return empty (container stopped)

# Display confirmation
echo "
✓ Database backed up
✓ Container stopped
✓ Cleanup complete

Backup saved: .claude/testSQL/bootstrap/LoadTestDB_{timestamp}.bak

You can restore later using:
  /testsql restore LoadTestDB_{timestamp}.bak
"
```

**If "Keep database running":**

```python
print("""
Database will continue running. You can:

• Connect and inspect:
  sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB

• View Query Data Store:
  SELECT * FROM sys.query_store_query;

• Check test data:
  SELECT COUNT(*) FROM employee;

When done, shut down with:
  /testsql shutdown
""")
```

**If "Run another test":**

```python
print("""
Database remains running. You can test a modified script:

  /testscript ./modified-script.sql

This will use the SAME database and tables, so you can compare results.
""")
```

## Display Progress

```
📄 Phase 7: Generate Report
═══════════════════════════════════════════════════════

✓ Generated validation report (2,450 lines)
✓ Created score breakdown tables
✓ Documented 3 critical issues
✓ Generated 5 recommendations with code examples
✓ Saved: VALIDATION_REPORT.md

Time elapsed: 45s

═══════════════════════════════════════════════════════
  ALL PHASES COMPLETE ✓
═══════════════════════════════════════════════════════

Total Time: 17m 30s
Report Location: .claude/testScriptResults/2024-01-29_14-30-00/

Files Generated:
• VALIDATION_REPORT.md (main report)
• success_criteria.json
• script_analysis.json
• execution plans (3 files)
• evaluation results (5 files)
• SQL scripts (12 files)

Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT

{user_sees_console_summary_from_step_9}

───────────────────────────────────────────────────────

🤔 Next Steps (Interactive)

[If source is ADO or PR]
Would you like to update ADO work item #12345 / PR #123 with results?
  → User selects: Yes / No / Let me review first

[User Response: Yes]
✓ ADO work item #12345 updated
  • State: Testing Complete
  • Comment added with results

───────────────────────────────────────────────────────

ℹ️  Database Still Running

The test database remains available for inspection:

Connection: localhost,1433 (LoadTestDB)
Username: sa | Password: Pass@word1

You can manually inspect the database, query data, or check QDS.

───────────────────────────────────────────────────────

🤔 What would you like to do next?
  → Shutdown and cleanup
  → Keep database running
  → Run another test

[User Response: Shutdown and cleanup]

Shutting down SQL Server...
✓ Database backed up: LoadTestDB_2024-01-29_16-45-00.bak
✓ Container stopped
✓ Cleanup complete

═══════════════════════════════════════════════════════
  VALIDATION COMPLETE - ENVIRONMENT CLEANED UP
═══════════════════════════════════════════════════════
```

## Output Summary

**Files Created:**
- `VALIDATION_REPORT.md`: Main deliverable
- All supporting artifacts from previous phases

**Actions Taken:**
- Report generated: YES
- Console summary displayed: YES
- ADO updated: YES/NO (depending on source)
- PR commented: YES/NO (depending on source)

**Complete:** YES ✓

---

**End of Phase 7 Implementation**
**End of All Phases**
