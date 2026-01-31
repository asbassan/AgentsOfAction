# SQL Server Script Testing & Validation Skill - Main Orchestration

## User Documentation

### Overview
The `/testscript` skill is an autonomous script validation framework that tests SQL scripts for functional correctness, performance, and optimization. It validates that your script returns the correct data, uses proper indexes, and performs well under load.

### Usage
```bash
/testscript <scriptpath> [options]
```

### Arguments
- `<scriptpath>` (required): Can be one of:
  - Local file path: `/path/to/script.sql`
  - ADO Work Item: `ADO:12345` or just `12345`
  - PR Number: `PR:123` or just `#123`

### Options
- `--duration <minutes>`: Total test duration (default: 30)
- `--threads <count>`: Concurrent threads for load testing (default: 50)
- `--cpu-target <percent>`: Target CPU for background load (default: 75)
- `--rows-per-table <count>`: Test data rows per table (default: 50000)
- `--skip-criteria`: Skip success criteria confirmation
- `--skip-evaluation`: Skip functional evaluation (performance only)
- `--output-dir <path>`: Output directory (default: `./.claude/testScriptResults/<timestamp>`)

### Examples
```bash
# Basic test
/testscript ./my-monitoring-query.sql

# ADO work item test
/testscript ADO:12345 --duration 45

# PR test with custom load
/testscript PR:123 --cpu-target 80 --threads 75

# Quick test without evaluation
/testscript ./test.sql --duration 15 --skip-evaluation
```

### What Gets Tested

#### 1. Functional Correctness ✓
- Does the script return the **correct data**?
- Does output match expected schema?
- Are business logic conditions satisfied?

#### 2. Performance ✓
- How does script perform on idle DB?
- How does script perform under 75% CPU load?
- Response time with parallel execution?

#### 3. Index Usage ✓
- Does script use the right indexes?
- Index Seek vs Index Scan?
- Table scans detected?

#### 4. Query Data Store Detection ✓
- Does script query `sys.query_store_*` tables?
- QDS query performance analysis

#### 5. Blocking & Contention ✓
- Does script cause blocking?
- Does script get blocked under load?
- Deadlock susceptibility?

### Connection Information
After setup, connect using:
- **Server:** `localhost,1433`
- **Username:** `sa`
- **Password:** `Pass@word1`
- **Database:** Auto-detected or `LoadTestDB`

---

## Implementation Instructions for Claude

### High-Level Orchestration Flow

```
User invokes: /testscript ./script.sql

Phase 1: Extract Success Criteria         → implementation/PHASE1_CRITERIA_EXTRACTION.md
         ↓
Phase 2: Analyze Script & Extract Schema  → implementation/PHASE2_SCHEMA_ANALYSIS.md
         ↓
Phase 3: Generate Test Data                → implementation/PHASE3_DATA_GENERATION.md
         ↓
Phase 4: Generate Background Load          → implementation/PHASE4_LOAD_GENERATION.md
         ↓
Phase 5: Execute Tests                     → implementation/PHASE5_EXECUTION.md
         ↓
Phase 6: Evaluate & Score                  → implementation/PHASE6_EVALUATION.md
         ↓
Phase 7: Generate Report                   → implementation/PHASE7_REPORTING.md
         ↓
Phase 8: Update ADO/PR (if applicable)     → See Phase 7
```

### Phase Execution Order

Execute each phase sequentially. Each phase file contains detailed implementation instructions.

---

## Phase 1: Extract Success Criteria

**Goal:** Determine what "success" means for this script

**Implementation:** See `implementation/PHASE1_CRITERIA_EXTRACTION.md`

**Key Actions:**
1. Parse script header comments for criteria
2. Fetch ADO work item description (if ADO source)
3. Fetch PR description (if PR source)
4. Analyze script SQL to infer expected behavior
5. Synthesize comprehensive success criteria
6. Confirm with user via AskUserQuestion

**Output:**
- `success_criteria` object with:
  - Functional requirements
  - Expected output schema
  - Performance thresholds
  - Index usage expectations

---

## Phase 2: Analyze Script & Extract Schema

**Goal:** Understand what tables/columns the script uses

**Implementation:** See `implementation/PHASE2_SCHEMA_ANALYSIS.md`

**Key Actions:**
1. Parse SQL to extract table names
2. Extract column references
3. Detect JOIN patterns
4. Identify WHERE clause filters
5. Determine if script queries Query Data Store
6. Generate CREATE TABLE statements

**Output:**
- `table_definitions` list
- `detected_qds_query` boolean
- `script_analysis` object

---

## Phase 3: Generate Test Data

**Goal:** Create and populate tables detected in Phase 2

**Implementation:** See `implementation/PHASE3_DATA_GENERATION.md`

**Key Actions:**
1. Start SQL Server using `/testsql` skill
2. Execute CREATE TABLE statements
3. Generate 50,000+ rows per table
4. Create indexes (including those expected by criteria)
5. Populate Query Data Store if script queries it

**Output:**
- Populated database ready for testing
- QDS with 1000+ query IDs (if needed)

---

## Phase 4: Generate Background Load

**Goal:** Create load queries on the SAME tables to stress the environment

**Implementation:** See `implementation/PHASE4_LOAD_GENERATION.md`

**Key Actions:**
1. Generate CPU-intensive queries on detected tables
2. Generate IO-intensive queries
3. Generate blocking queries
4. Create `background_load.sql` file
5. Start background load with ostress.exe
6. Monitor until CPU reaches target (75%)

**Output:**
- Background load running at target CPU
- Database "busy" and realistic

---

## Phase 5: Execute Tests

**Goal:** Run the user's script under various conditions

**Implementation:** See `implementation/PHASE5_EXECUTION.md`

**Key Actions:**
1. **Test A:** Baseline (idle DB, single execution)
2. **Test B:** Under load (75% CPU, single execution)
3. **Test C:** Parallel stress (50 threads, ostress.exe)
4. Capture execution plans (XML)
5. Capture performance metrics
6. Save output data (CSV)

**Output:**
- Execution results for all test scenarios
- Execution plans (XML)
- Output data files
- Performance metrics

---

## Phase 6: Evaluate & Score

**Goal:** Validate against success criteria and score the script

**Implementation:** See `implementation/PHASE6_EVALUATION.md`

**Key Actions:**
1. Validate functional correctness (data validation)
2. Validate output schema
3. Validate row count expectations
4. Analyze execution plan for index usage
5. Check performance thresholds
6. Score each criterion (0-10 scale)
7. Calculate overall score

**Output:**
- `evaluation_results` object with scores
- `issues_found` list
- `recommendations` list
- `overall_score` (0-10)

---

## Phase 7: Generate Report

**Goal:** Create comprehensive report with scores and recommendations

**Implementation:** See `implementation/PHASE7_REPORTING.md`

**Key Actions:**
1. Generate markdown report
2. Include scores for each criterion
3. Highlight critical issues
4. Provide actionable recommendations
5. Include before/after code examples
6. Display summary to user
7. Update ADO/PR if applicable

**Output:**
- `VALIDATION_REPORT.md`
- Console summary displayed to user
- ADO/PR updated with results

---

## Error Handling

### Phase Failures
If any phase fails:
1. Log error to `test_log.txt`
2. Determine if recoverable
3. If recoverable: retry with adjusted parameters
4. If not recoverable: report error and suggest fixes
5. Offer to continue with partial results

### Common Errors

#### "Cannot parse SQL script"
- Script has syntax errors
- Display line number of error
- Ask user to fix or proceed with manual schema definition

#### "Background load won't reach target CPU"
- Increase threads: `--threads 100`
- Check Docker CPU allocation
- Verify container has 4 cores available

#### "Evaluation failed - no output data"
- Script produced no results
- Check if script executed successfully
- Review script logic and filters

#### "ostress.exe not found"
- Verify bundled tool: `.claude/skills/testscript/tools/ostress.exe`
- Re-run extraction script if missing
- See TOOLS_SETUP.md

---

## Output Structure

All test artifacts saved to:
```
.claude/testScriptResults/<timestamp>/
├── VALIDATION_REPORT.md              # Main report with scores
├── test_log.txt                      # Execution log
├── success_criteria.json             # Detected criteria
├── script_analysis.json              # Script analysis results
├── user_script.sql                   # Copy of script under test
├── schema/
│   ├── create_tables.sql             # Generated schema
│   └── populate_data.sql             # Data generation script
├── background_load/
│   ├── cpu_intensive.sql             # CPU load queries
│   ├── io_intensive.sql              # IO load queries
│   ├── blocking.sql                  # Blocking queries
│   └── master_load.sql               # Combined load script
├── execution/
│   ├── test_baseline.sql             # Baseline test wrapper
│   ├── test_under_load.sql           # Load test wrapper
│   ├── baseline_output.csv           # Baseline results
│   ├── loaded_output.csv             # Under-load results
│   ├── baseline_plan.xml             # Execution plan
│   └── loaded_plan.xml               # Execution plan
├── evaluation/
│   ├── functional_validation.json    # Functional test results
│   ├── schema_validation.json        # Schema test results
│   ├── index_analysis.json           # Index usage analysis
│   ├── performance_metrics.json      # Performance data
│   └── overall_score.json            # Final scores
└── recommendations/
    ├── fixes.sql                     # Recommended fixes
    └── optimizations.md              # Optimization guide
```

---

## Status Indicators

Throughout execution, display progress:

```
🔍 Phase 1: Extracting Success Criteria...
✓ Detected 6 criteria from script header
✓ User confirmed criteria

📊 Phase 2: Analyzing Script...
✓ Detected 3 tables: employee, department, salary_history
✓ Query Data Store detected: YES

🏗️  Phase 3: Generating Test Data...
✓ Created 3 tables
✓ Populated 150,000 rows
✓ QDS populated with 1,234 query IDs

⚡ Phase 4: Starting Background Load...
✓ Generated 45 load queries
✓ CPU at target: 76%

🚀 Phase 5: Executing Tests...
✓ Baseline: 245ms
✓ Under Load: 1,890ms
✓ Parallel: 3,450ms avg

📝 Phase 6: Evaluating Results...
⚠️  Functional: 6/10 (2 rows failed criteria)
✓ Schema: 10/10
✓ Row Count: 10/10
⚠️  Index Usage: 6/10 (Index Scan detected)
❌ Performance: 5/10 (Exceeds threshold)
✓ QDS Detection: 10/10

📊 Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT

📄 Phase 7: Generating Report...
✓ Report saved: VALIDATION_REPORT.md
✓ Recommendations generated
✓ ADO work item updated
```

---

## Success Criteria

A successful test execution produces:
- ✓ All 7 phases completed
- ✓ Success criteria extracted and confirmed
- ✓ Test data generated (50K+ rows per table)
- ✓ Background load achieved target CPU
- ✓ User script executed in all scenarios
- ✓ Evaluation completed with scores
- ✓ Comprehensive report generated
- ✓ Recommendations provided

---

## Autonomous Operation

This skill is designed to be **fully autonomous**:

1. **User input:** `/testscript ./script.sql`
2. **Autonomous execution:** All phases run automatically
3. **User output:** Validation report with scores

**User interaction required only for:**
- Success criteria confirmation (can skip with `--skip-criteria`)
- Adjusting parameters if prompted

**Everything else is automated:**
- SQL Server setup via `/testsql`
- Schema extraction and table creation
- Background load generation and execution
- Script testing under multiple scenarios
- Functional validation and scoring
- Report generation

---

## Integration with Other Skills

### `/testsql` Dependency
This skill requires `/testsql` for SQL Server environment:
```bash
# Automatically invoked in Phase 3
Skill tool: /testsql setup LoadTestDB
```

### ADO Integration
If source is ADO work item:
```bash
# Fetch work item details
mcp__ado__get_work_item(id)

# Update work item with results
mcp__ado__update_work_item(id, {
  comment: "Validation complete: Score 7.5/10",
  state: "Testing Complete"
})
```

### PR Integration
If source is Pull Request:
```bash
# Fetch PR details
gh pr view {pr_number} --json body,files

# Comment on PR with results
gh pr comment {pr_number} --body "..."
```

---

## Implementation Notes for Claude

### File References
When implementing each phase, read the corresponding file:

```python
# Phase 1
Read: .claude/skills/testscript/implementation/PHASE1_CRITERIA_EXTRACTION.md

# Phase 2
Read: .claude/skills/testscript/implementation/PHASE2_SCHEMA_ANALYSIS.md

# ... and so on
```

### Context Preservation
Maintain state between phases using variables:
- `success_criteria`: From Phase 1
- `table_definitions`: From Phase 2
- `script_analysis`: From Phase 2
- `background_load_pid`: From Phase 4
- `test_results`: From Phase 5
- `evaluation_results`: From Phase 6

### Tool Usage
Primary tools used:
- **Read**: Read script files
- **Write**: Generate SQL scripts
- **Bash**: Execute sqlcmd, ostress.exe, docker
- **Skill**: Invoke `/testsql`
- **Grep**: Search for patterns in execution plans
- **AskUserQuestion**: Confirm success criteria
- **ADO/GitHub tools**: Update work items/PRs

### Parallel Operations
Where possible, run operations in parallel:
- Generate CPU + IO + blocking queries simultaneously (Write tool)
- Fetch ADO details + Parse script header in parallel (if ADO source)

### Progress Display
Show progress after each major step using the status indicator format shown above.

---

**End of Main Orchestration Guide**

For detailed implementation of each phase, see the `implementation/` directory.
