# Phase 1: Extract Success Criteria

## Goal
Determine what "success" means for the script being tested by extracting criteria from multiple sources and confirming with the user.

## Input
- `scriptpath`: Path to script, ADO work item ID, or PR number
- `source_type`: One of: "file", "ado", "pr"
- `user_script_content`: The SQL script text

## Output
- `success_criteria`: Object containing:
  ```json
  {
    "functional": {
      "expected_data_filter": "avg_duration > 1000ms",
      "business_logic": ["Returns slow queries", "Filters by time range"],
      "expected_row_count_range": [10, 100]
    },
    "output_schema": {
      "required_columns": ["query_id", "query_text", "avg_duration"],
      "optional_columns": ["execution_count"]
    },
    "performance": {
      "baseline_threshold_ms": 500,
      "loaded_threshold_ms": 2000,
      "parallel_timeout_rate_max": 0.05
    },
    "index_usage": {
      "expected_indexes": ["IX_runtime_stats_duration"],
      "no_table_scans": true,
      "prefer_seeks": true
    },
    "qds_specific": {
      "queries_qds": true,
      "qds_tables": ["sys.query_store_runtime_stats", "sys.query_store_query"],
      "qds_performance_threshold_ms": 1000
    }
  }
  ```

## Implementation Steps

### Step 1: Parse Script Header Comments

**Action:** Extract criteria from SQL comments at top of script

```sql
/*
 * PURPOSE: Find queries with average duration > 1000ms
 *
 * SUCCESS CRITERIA:
 * - Returns only queries where avg_duration > 1000ms
 * - Output includes: query_id, query_text, avg_duration
 * - Returns 10-100 results
 * - Executes in under 500ms on idle DB
 * - Should use index IX_runtime_stats_duration
 *
 * AUTHOR: John Doe
 * DATE: 2024-01-29
 */
```

**Parsing Logic:**
1. Read user_script_content
2. Extract multi-line comment at beginning (/* ... */)
3. Look for keywords:
   - "PURPOSE:", "GOAL:", "OBJECTIVE:"
   - "SUCCESS CRITERIA:", "EXPECTED:", "REQUIREMENTS:"
   - "OUTPUT:", "RETURNS:", "COLUMNS:"
   - "PERFORMANCE:", "THRESHOLD:"
   - "INDEX:", "INDEXES:"

4. Parse natural language using pattern matching:
   - "avg_duration > 1000" → functional filter
   - "executes in under 500ms" → performance threshold
   - "10-100 results" → row count range
   - "should use index IX_..." → index expectation

**Example Code Pattern:**
```python
# Pseudo-code for parsing
header_comment = extract_comment_block(user_script_content)

criteria = {
  "functional": [],
  "performance": {},
  "index_usage": {},
  "output_schema": {}
}

# Pattern matching
if "avg_duration > " in header_comment:
    threshold = extract_number_after("avg_duration > ")
    criteria["functional"]["expected_data_filter"] = f"avg_duration > {threshold}"

if "executes in under" in header_comment:
    time_ms = extract_number_with_unit(header_comment)
    criteria["performance"]["baseline_threshold_ms"] = time_ms

# ... more patterns
```

**Store:** `criteria_from_header`

---

### Step 2: Fetch ADO Work Item Description (if ADO source)

**Condition:** Only if `source_type == "ado"`

**Action:** Retrieve work item details and extract criteria

**Implementation:**
```bash
# Use ADO MCP tool
mcp__ado__get_work_item(id: work_item_id)
# or
mcp__msazure-ado__get_work_item(id: work_item_id)
```

**Parse Work Item Fields:**
1. **Title**: Look for keywords like "slow queries", "blocking", "monitoring"
2. **Description**: Extract requirements and expected behavior
3. **Acceptance Criteria**: Look for structured criteria
4. **Comments**: Check recent comments for clarifications

**Example ADO Description:**
```
Create script to identify blocking queries from the last hour.

Requirements:
- Must return blocking_session_id, wait_time, query_text
- Should complete in under 1 second
- Only queries from last 60 minutes
- Include queries waiting on locks

Expected Output:
- 0-50 rows typically
- Columns: blocking_session_id, blocked_session_id, wait_time_ms, query_text
```

**Parsing Logic:**
```python
ado_description = work_item["description"]

# Extract requirements
if "blocking_session_id" in ado_description:
    criteria["output_schema"]["required_columns"].append("blocking_session_id")

if "last hour" in ado_description or "last 60 minutes" in ado_description:
    criteria["functional"]["time_filter"] = "last 1 hour"

if "complete in under 1 second" in ado_description:
    criteria["performance"]["baseline_threshold_ms"] = 1000
```

**Store:** `criteria_from_ado`

---

### Step 3: Fetch PR Description (if PR source)

**Condition:** Only if `source_type == "pr"`

**Action:** Retrieve PR details and extract criteria

**Implementation:**
```bash
# Use gh CLI via Bash tool
gh pr view {pr_number} --json title,body,files
```

**Parse PR Fields:**
1. **PR Title**: Look for descriptive keywords
2. **PR Body/Description**: Extract what the script should do
3. **Changed Files**: Check if there's a test file or expected output

**Example PR Description:**
```markdown
## What This PR Does
Adds monitoring query for slow Query Data Store queries.

## Expected Behavior
- Queries `sys.query_store_runtime_stats`
- Returns queries with avg_duration > 1000ms
- Output: query_id, query_text, avg_duration, execution_count
- Performance: <500ms on 1K query IDs

## Testing
Tested on DB with 5K query IDs, returned 47 results in 340ms.
```

**Parsing Logic:**
```python
pr_body = pr_data["body"]

# Extract QDS detection
if "sys.query_store" in pr_body:
    criteria["qds_specific"]["queries_qds"] = True

    # Extract table names
    qds_tables = re.findall(r'sys\.query_store_\w+', pr_body)
    criteria["qds_specific"]["qds_tables"] = qds_tables

# Extract performance threshold
if "<500ms" in pr_body:
    criteria["performance"]["baseline_threshold_ms"] = 500
```

**Store:** `criteria_from_pr`

---

### Step 4: Analyze Script SQL Logic

**Action:** Parse the SQL script itself to infer expected behavior

**Implementation:**

1. **Detect Query Data Store usage:**
```python
if "sys.query_store" in user_script_content:
    criteria["qds_specific"]["queries_qds"] = True

    # Extract specific tables
    qds_tables = extract_table_references(user_script_content, "sys.query_store_%")
    criteria["qds_specific"]["qds_tables"] = qds_tables
```

2. **Extract WHERE clause filters:**
```sql
-- If script has:
WHERE avg_duration > 1000
-- Then:
criteria["functional"]["expected_data_filter"] = "avg_duration > 1000"
```

3. **Extract TOP clause:**
```sql
-- If script has:
SELECT TOP 100 ...
-- Then:
criteria["functional"]["expected_row_count_range"] = [0, 100]
```

4. **Extract SELECT columns:**
```sql
-- If script has:
SELECT query_id, query_text, avg_duration FROM ...
-- Then:
criteria["output_schema"]["required_columns"] = ["query_id", "query_text", "avg_duration"]
```

5. **Detect index hints:**
```sql
-- If script has:
FROM sys.query_store_runtime_stats WITH (INDEX(IX_duration))
-- Then:
criteria["index_usage"]["expected_indexes"] = ["IX_duration"]
```

**Parsing Approach:**
- Use regex for simple patterns
- For complex parsing, use SQL parser library concepts
- Extract key clauses: SELECT, FROM, WHERE, JOIN, TOP

**Store:** `criteria_from_script_analysis`

---

### Step 5: Synthesize Comprehensive Criteria

**Action:** Merge all extracted criteria into single comprehensive object

**Logic:**
```python
success_criteria = {
  "functional": {},
  "output_schema": {},
  "performance": {},
  "index_usage": {},
  "qds_specific": {}
}

# Merge header criteria
merge_into(success_criteria, criteria_from_header)

# Merge ADO criteria (if available)
if criteria_from_ado:
    merge_into(success_criteria, criteria_from_ado)

# Merge PR criteria (if available)
if criteria_from_pr:
    merge_into(success_criteria, criteria_from_pr)

# Merge script analysis
merge_into(success_criteria, criteria_from_script_analysis)

# Apply defaults for missing values
if not success_criteria["performance"]["baseline_threshold_ms"]:
    success_criteria["performance"]["baseline_threshold_ms"] = 500  # default

if not success_criteria["performance"]["loaded_threshold_ms"]:
    # Default to 4x baseline
    success_criteria["performance"]["loaded_threshold_ms"] =
        success_criteria["performance"]["baseline_threshold_ms"] * 4
```

**Conflict Resolution:**
- Header comments take highest priority
- ADO/PR descriptions override script analysis
- Script analysis provides fallback

**Store:** `success_criteria` (final)

---

### Step 6: Format for User Confirmation

**Action:** Create human-readable summary of detected criteria

**Display Format:**
```
🔍 Success Criteria Detected
═══════════════════════════════════════════════════════

FUNCTIONAL CORRECTNESS:
• Script should return queries with avg_duration > 1000ms
• Output must include columns: query_id, query_text, avg_duration
• Expected row count: 10-100 rows (if data exists)
• Time filter: Last 1 hour of data

PERFORMANCE THRESHOLDS:
• Idle DB: Should complete in <500ms
• Loaded DB (75% CPU): Should complete in <2000ms
• Parallel (50 threads): Timeout rate <5%

INDEX USAGE:
• Should use index: IX_runtime_stats_duration
• Should prefer Index Seek over Index Scan
• Should NOT perform full table scans

QUERY DATA STORE:
• Script queries QDS: YES
• Tables: sys.query_store_runtime_stats, sys.query_store_query
• QDS performance threshold: <1000ms on 1K query IDs

ADDITIONAL NOTES:
• Detected from: Script header, ADO work item #12345
• Confidence: High (explicit criteria found)
```

---

### Step 7: Confirm with User via AskUserQuestion

**Action:** Present criteria and ask for confirmation

**Implementation:**
```python
AskUserQuestion(
  questions: [
    {
      question: "I detected the success criteria shown above. Are these correct?",
      header: "Criteria OK?",
      options: [
        {
          label: "Yes, proceed with testing",
          description: "These criteria are correct, start testing"
        },
        {
          label: "Modify criteria",
          description: "I need to adjust some criteria"
        },
        {
          label: "Skip criteria validation",
          description: "Proceed with performance testing only"
        }
      ],
      multiSelect: false
    }
  ]
)
```

**Handle User Response:**

**If "Yes, proceed":**
- Continue to Phase 2
- Store `success_criteria` for Phase 6 evaluation

**If "Modify criteria":**
- Ask follow-up questions:
  ```
  What would you like to modify?
  - Functional requirements
  - Performance thresholds
  - Index expectations
  - Other
  ```
- Present specific fields for editing
- Allow user to specify values
- Update `success_criteria` object
- Re-display for final confirmation

**If "Skip criteria validation":**
- Set flag: `skip_evaluation = true`
- Store minimal criteria (performance only):
  ```json
  {
    "functional": null,
    "output_schema": null,
    "performance": {
      "baseline_threshold_ms": 5000,  # generous default
      "loaded_threshold_ms": 10000
    },
    "index_usage": null,
    "qds_specific": {"queries_qds": null}
  }
  ```
- Continue to Phase 2

---

### Step 8: Save Criteria to File

**Action:** Persist success criteria for reference

**Implementation:**
```bash
# Create output directory
mkdir -p .claude/testScriptResults/{timestamp}

# Write JSON file
Write: .claude/testScriptResults/{timestamp}/success_criteria.json
Content: JSON.stringify(success_criteria, indent=2)
```

**File Content Example:**
```json
{
  "metadata": {
    "detected_from": ["script_header", "ado_work_item_12345"],
    "confidence": "high",
    "timestamp": "2024-01-29T14:30:00Z"
  },
  "functional": {
    "expected_data_filter": "avg_duration > 1000ms",
    "business_logic": [
      "Returns slow queries from Query Data Store",
      "Filters by last 1 hour"
    ],
    "expected_row_count_range": [10, 100]
  },
  "output_schema": {
    "required_columns": ["query_id", "query_text", "avg_duration"],
    "optional_columns": ["execution_count"],
    "column_types": {
      "query_id": "int",
      "query_text": "nvarchar",
      "avg_duration": "float"
    }
  },
  "performance": {
    "baseline_threshold_ms": 500,
    "loaded_threshold_ms": 2000,
    "parallel_avg_threshold_ms": 5000,
    "parallel_timeout_rate_max": 0.05
  },
  "index_usage": {
    "expected_indexes": ["IX_runtime_stats_duration"],
    "no_table_scans": true,
    "prefer_seeks": true,
    "estimated_rows_threshold": 1000000
  },
  "qds_specific": {
    "queries_qds": true,
    "qds_tables": [
      "sys.query_store_runtime_stats",
      "sys.query_store_query"
    ],
    "qds_performance_threshold_ms": 1000,
    "qds_size_test_points": [100, 1000, 5000]
  }
}
```

---

## Display Progress

After completion:
```
🔍 Phase 1: Extract Success Criteria
═══════════════════════════════════════════════════════

✓ Parsed script header comments
✓ Fetched ADO work item #12345
✓ Analyzed script SQL logic
✓ Synthesized 6 success criteria
✓ User confirmed criteria

Criteria Summary:
• Functional: avg_duration > 1000ms
• Performance: <500ms baseline, <2s loaded
• Index: IX_runtime_stats_duration
• QDS Detection: YES

Saved: success_criteria.json

→ Proceeding to Phase 2: Schema Analysis
```

---

## Error Handling

### No Criteria Found
If no criteria can be extracted from any source:
```
⚠️  Warning: No success criteria detected

I couldn't find explicit success criteria in:
- Script header comments
- ADO work item description
- PR description
- Script logic analysis

Options:
1. Proceed with default criteria (performance testing only)
2. Manually specify criteria now
3. Cancel and add criteria to script header
```

Use AskUserQuestion to present options.

### Ambiguous Criteria
If criteria are conflicting or unclear:
```
⚠️  Ambiguous Criteria Detected

Conflict found:
- Script header says: "< 500ms"
- ADO work item says: "< 1000ms"

Which threshold should I use for baseline performance?
- 500ms (from script header) [Recommended]
- 1000ms (from ADO work item)
- Custom value
```

### Invalid Criteria Format
If user provides malformed criteria during modification:
- Validate format
- Show error with example
- Re-prompt for input

---

## Output Summary

**Variables to preserve for next phases:**
- `success_criteria`: Complete criteria object
- `skip_evaluation`: Boolean flag
- `criteria_confidence`: "high", "medium", "low"
- `criteria_sources`: List of sources used

**Files created:**
- `.claude/testScriptResults/{timestamp}/success_criteria.json`

**Ready for Phase 2:** YES

---

**End of Phase 1 Implementation**
