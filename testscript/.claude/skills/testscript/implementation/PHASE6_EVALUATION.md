# Phase 6: Evaluate & Score

## Goal
Validate the script against success criteria and assign scores (0-10) for each criterion.

## Input
- `success_criteria`: From Phase 1
- `test_results`: From Phase 5
- `execution_plans`: From Phase 5
- `output_data`: From Phase 5

## Output
- `evaluation_results`: Scores and findings for each criterion
- `overall_score`: Weighted average (0-10)
- `issues_found`: List of problems
- `recommendations`: List of fixes

## Implementation Steps

### Step 1: Evaluate Functional Correctness

**Goal:** Verify script returns correct data per criteria

**Criteria from Phase 1:**
```json
{
  "functional": {
    "expected_data_filter": "avg_duration > 1000ms",
    "expected_row_count_range": [10, 100]
  }
}
```

**Validation Logic:**

```python
def evaluate_functional_correctness(output_data, criteria):
    score = 10
    issues = []

    # Parse output CSV
    rows = parse_csv(output_data['baseline_data.csv'])

    # Validate each row against filter criteria
    filter_condition = criteria['functional']['expected_data_filter']

    for row in rows:
        if not meets_condition(row, filter_condition):
            score -= 0.1  # Deduct for each violating row
            issues.append(f"Row {row['id']} violates filter: {row}")

    # Check row count
    row_count_range = criteria['functional']['expected_row_count_range']
    actual_count = len(rows)

    if not (row_count_range[0] <= actual_count <= row_count_range[1]):
        score -= 2
        issues.append(f"Row count {actual_count} outside expected range {row_count_range}")

    score = max(0, score)  # Floor at 0

    return {
        'score': round(score, 1),
        'issues': issues,
        'rows_validated': len(rows),
        'rows_failed': len(issues)
    }
```

**Example:**
```
Criterion: Returns queries with avg_duration > 1000ms

Validation:
✓ Row 1: query_id=1001, avg_duration=1245ms ✓
✓ Row 2: query_id=1002, avg_duration=2134ms ✓
❌ Row 45: query_id=1234, avg_duration=987ms ✗
❌ Row 67: query_id=5678, avg_duration=654ms ✗

Result: 98/100 rows valid (2 violations)
Score: 6/10
```

**Store:**
```python
evaluation_results['functional_correctness'] = {
    'score': 6.0,
    'weight': 0.25,  # 25% of total score
    'issues': [...],
    'details': {...}
}
```

### Step 2: Evaluate Output Schema

**Goal:** Verify output has expected columns

**Validation:**

```python
def evaluate_output_schema(output_data, criteria):
    score = 10
    issues = []

    # Parse column headers
    columns = parse_csv_headers(output_data['baseline_data.csv'])

    required = criteria['output_schema']['required_columns']
    optional = criteria['output_schema'].get('optional_columns', [])

    # Check required columns present
    missing = set(required) - set(columns)
    if missing:
        score -= 5 * len(missing)  # -5 per missing required column
        issues.append(f"Missing required columns: {missing}")

    # Check for unexpected columns (minor issue)
    unexpected = set(columns) - set(required + optional)
    if unexpected:
        score -= 0.5 * len(unexpected)  # -0.5 per unexpected
        issues.append(f"Unexpected columns (minor): {unexpected}")

    score = max(0, score)

    return {
        'score': round(score, 1),
        'issues': issues,
        'columns_found': columns,
        'columns_expected': required
    }
```

**Example:**
```
Expected: query_id, query_text, avg_duration
Actual: query_id, query_text, avg_duration, execution_count

✓ All required columns present
⚠️  Extra column: execution_count (acceptable)

Score: 9.5/10
```

### Step 3: Evaluate Row Count

**Goal:** Verify result set size is reasonable

```python
def evaluate_row_count(output_data, criteria):
    score = 10
    issues = []

    rows = parse_csv(output_data['baseline_data.csv'])
    actual_count = len(rows)

    expected_range = criteria['functional']['expected_row_count_range']
    min_count, max_count = expected_range

    if actual_count < min_count:
        score -= 3
        issues.append(f"Too few rows: {actual_count} < {min_count}")
    elif actual_count > max_count:
        score -= 1  # Less severe
        issues.append(f"More rows than expected: {actual_count} > {max_count}")

    # Check if TOP clause exists but more rows returned
    if 'TOP' in user_script_content:
        top_value = extract_top_value(user_script_content)
        if actual_count > top_value:
            score -= 2
            issues.append(f"TOP {top_value} specified but {actual_count} rows returned")

    score = max(0, score)

    return {
        'score': round(score, 1),
        'issues': issues,
        'actual_count': actual_count,
        'expected_range': expected_range
    }
```

### Step 4: Evaluate Index Usage

**Goal:** Verify script uses expected indexes efficiently

**Parse Execution Plan:**

```python
def evaluate_index_usage(execution_plans, criteria):
    score = 10
    issues = []

    plan_xml = execution_plans['baseline_plan.xml']
    expected_indexes = criteria['index_usage']['expected_indexes']
    prefer_seeks = criteria['index_usage']['prefer_seeks']
    no_table_scans = criteria['index_usage']['no_table_scans']

    # Parse plan for index operations
    index_ops = extract_index_operations(plan_xml)

    # Check if expected indexes are used
    indexes_used = [op['index_name'] for op in index_ops]
    missing_indexes = set(expected_indexes) - set(indexes_used)

    if missing_indexes:
        score -= 3 * len(missing_indexes)
        issues.append(f"Expected indexes not used: {missing_indexes}")

    # Check for table scans
    table_scans = [op for op in index_ops if op['operation'] == 'Table Scan']
    if no_table_scans and table_scans:
        score -= 4
        issues.append(f"Table scans detected on: {[t['table'] for t in table_scans]}")

    # Check for index scans vs seeks
    index_scans = [op for op in index_ops if op['operation'] == 'Index Scan']
    index_seeks = [op for op in index_ops if op['operation'] == 'Index Seek']

    if prefer_seeks and len(index_scans) > len(index_seeks):
        score -= 2
        issues.append(f"Using Index Scan ({len(index_scans)}) instead of Index Seek ({len(index_seeks)})")

    # Check for missing index warnings
    missing_index_warnings = extract_xpath(plan_xml, '//MissingIndexes')
    if missing_index_warnings:
        score -= 1
        issues.append(f"Missing index warnings: {len(missing_index_warnings)}")

    score = max(0, score)

    return {
        'score': round(score, 1),
        'issues': issues,
        'indexes_used': indexes_used,
        'operation_breakdown': {
            'table_scans': len(table_scans),
            'index_scans': len(index_scans),
            'index_seeks': len(index_seeks)
        }
    }
```

**Example:**
```
Expected: IX_runtime_stats_duration

Analysis:
✓ Index used: IX_runtime_stats_duration
⚠️  Operation: Index Scan (not Seek)
⚠️  Missing index warning detected

Reason: Script filters on multiple columns, optimizer chose scan

Score: 6/10
Recommendation: Add covering index
```

### Step 5: Evaluate Performance

**Goal:** Check if performance meets thresholds

```python
def evaluate_performance(test_results, criteria):
    score = 10
    issues = []

    thresholds = criteria['performance']

    # Check baseline performance
    baseline_duration = test_results['baseline']['duration_ms']
    baseline_threshold = thresholds['baseline_threshold_ms']

    if baseline_duration > baseline_threshold:
        excess_pct = (baseline_duration - baseline_threshold) / baseline_threshold * 100
        score -= min(5, excess_pct / 20)  # -1 per 20% excess, max -5
        issues.append(f"Baseline exceeds threshold: {baseline_duration}ms > {baseline_threshold}ms")

    # Check loaded performance
    loaded_duration = test_results['loaded']['duration_ms']
    loaded_threshold = thresholds['loaded_threshold_ms']

    if loaded_duration > loaded_threshold:
        excess_pct = (loaded_duration - loaded_threshold) / loaded_threshold * 100
        score -= min(5, excess_pct / 20)
        issues.append(f"Under load exceeds threshold: {loaded_duration}ms > {loaded_threshold}ms")

    # Check parallel timeout rate
    parallel_timeout_rate = test_results['parallel']['failure_rate']
    max_timeout_rate = thresholds.get('parallel_timeout_rate_max', 0.05)

    if parallel_timeout_rate > max_timeout_rate:
        score -= 3
        issues.append(f"High failure rate: {parallel_timeout_rate*100}% > {max_timeout_rate*100}%")

    score = max(0, score)

    return {
        'score': round(score, 1),
        'issues': issues,
        'baseline_ms': baseline_duration,
        'loaded_ms': loaded_duration,
        'parallel_failure_rate': parallel_timeout_rate
    }
```

**Example:**
```
Baseline: 340ms (threshold: 500ms) ✓
Under Load: 2,450ms (threshold: 2,000ms) ❌
Parallel: 2.5% failure rate (threshold: 5%) ✓

Score: 5/10
Issues: Exceeds loaded threshold by 22%
```

### Step 6: Evaluate QDS Performance (if applicable)

**Condition:** Only if `detected_qds_query == true`

```python
def evaluate_qds_performance(test_results, criteria):
    score = 10
    issues = []

    qds_threshold = criteria['qds_specific']['qds_performance_threshold_ms']

    # Test with different QDS sizes (from Phase 3)
    # We populated QDS with different query counts
    qds_test_points = criteria['qds_specific']['qds_size_test_points']

    for qds_size in qds_test_points:
        duration = test_results[f'qds_{qds_size}']['duration_ms']

        if duration > qds_threshold:
            # Penalize based on how much over
            excess_pct = (duration - qds_threshold) / qds_threshold * 100
            score -= min(3, excess_pct / 50)
            issues.append(f"Slow on {qds_size} query IDs: {duration}ms > {qds_threshold}ms")

    score = max(0, score)

    return {
        'score': round(score, 1),
        'issues': issues,
        'qds_scaling': {
            str(size): test_results[f'qds_{size}']['duration_ms']
            for size in qds_test_points
        }
    }
```

### Step 7: Calculate Overall Score

**Action:** Weighted average of all criterion scores

```python
def calculate_overall_score(evaluation_results):
    weighted_scores = []

    for criterion, result in evaluation_results.items():
        score = result['score']
        weight = result['weight']
        weighted_scores.append(score * weight)

    overall = sum(weighted_scores)

    # Determine grade
    if overall >= 9.0:
        grade = "EXCELLENT"
        symbol = "✓"
    elif overall >= 7.5:
        grade = "GOOD"
        symbol = "✓"
    elif overall >= 6.0:
        grade = "NEEDS IMPROVEMENT"
        symbol = "⚠️"
    else:
        grade = "POOR"
        symbol = "❌"

    return {
        'overall_score': round(overall, 1),
        'grade': grade,
        'symbol': symbol,
        'breakdown': evaluation_results
    }
```

**Weight Distribution:**
```python
weights = {
    'functional_correctness': 0.25,  # 25%
    'output_schema': 0.10,           # 10%
    'row_count': 0.05,               # 5%
    'index_usage': 0.20,             # 20%
    'performance': 0.30,             # 30%
    'qds_performance': 0.10          # 10% (if applicable)
}
```

### Step 8: Generate Recommendations

**Action:** Provide actionable fixes for each issue

```python
def generate_recommendations(evaluation_results):
    recommendations = []

    # Functional issues
    if evaluation_results['functional_correctness']['score'] < 8:
        recommendations.append({
            'priority': 'HIGH',
            'category': 'Functional Correctness',
            'issue': 'Script returns rows that don't meet filter criteria',
            'fix': 'Review WHERE clause logic, check for OR conditions',
            'code_example': '''
-- BEFORE (incorrect):
WHERE avg_duration > 1000 OR max_duration > 5000

-- AFTER (correct):
WHERE avg_duration > 1000 AND max_duration > 5000
            '''
        })

    # Index issues
    if evaluation_results['index_usage']['score'] < 7:
        recommendations.append({
            'priority': 'MEDIUM',
            'category': 'Index Optimization',
            'issue': 'Using Index Scan instead of Index Seek',
            'fix': 'Add covering index or improve filter selectivity',
            'code_example': '''
-- Create covering index:
CREATE NONCLUSTERED INDEX IX_covering
ON sys.query_store_runtime_stats(avg_duration)
INCLUDE (query_id, execution_count, last_execution_time);
            '''
        })

    # Performance issues
    if evaluation_results['performance']['score'] < 6:
        recommendations.append({
            'priority': 'HIGH',
            'category': 'Performance',
            'issue': 'Slow execution under load',
            'fix': 'Add NOLOCK hints, filter by date, use TOP clause',
            'code_example': '''
-- Add isolation hint:
FROM sys.query_store_runtime_stats WITH (NOLOCK)
WHERE last_execution_time >= DATEADD(HOUR, -1, GETDATE())

-- Limit results:
SELECT TOP 100 ...
            '''
        })

    return sorted(recommendations, key=lambda x: x['priority'])
```

### Step 9: Save Evaluation Results

**Action:** Write JSON files with scores and findings

```bash
Write: .claude/testScriptResults/{timestamp}/evaluation/functional_validation.json
Write: .claude/testScriptResults/{timestamp}/evaluation/schema_validation.json
Write: .claude/testScriptResults/{timestamp}/evaluation/index_analysis.json
Write: .claude/testScriptResults/{timestamp}/evaluation/performance_metrics.json
Write: .claude/testScriptResults/{timestamp}/evaluation/overall_score.json
```

## Display Progress

```
📝 Phase 6: Evaluate & Score
═══════════════════════════════════════════════════════

Evaluating against success criteria...

✓ Functional Correctness: 6/10
  • 98/100 rows valid (2 violations)
  • Issue: 2 rows don't meet filter criteria

✓ Output Schema: 10/10
  • All required columns present

✓ Row Count: 8/10
  • 100 rows (expected 10-100) ✓
  • Minor: TOP clause hardcoded

⚠️  Index Usage: 6/10
  • Using IX_runtime_stats_duration ✓
  • But: Index Scan instead of Seek
  • Missing index warning detected

❌ Performance: 5/10
  • Baseline: 340ms ✓
  • Under load: 2,450ms ❌ (exceeds 2,000ms)
  • Parallel: 2.5% failure rate ✓

✓ QDS Detection: 10/10
  • Correctly queries QDS tables

───────────────────────────────────────────────────────
OVERALL SCORE: 7.5/10 ⚠️  NEEDS IMPROVEMENT
───────────────────────────────────────────────────────

Critical Issues Found: 3
Recommendations Generated: 5

→ Proceeding to Phase 7: Generate Report
```

## Output Summary

**Variables:**
- `evaluation_results`: Full evaluation object with all scores
- `overall_score`: 0-10 score
- `issues_found`: List of all issues
- `recommendations`: List of fixes

**Files:**
- `evaluation/functional_validation.json`
- `evaluation/schema_validation.json`
- `evaluation/index_analysis.json`
- `evaluation/performance_metrics.json`
- `evaluation/overall_score.json`

**Ready for Phase 7:** YES

---

**End of Phase 6 Implementation**
