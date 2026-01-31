## Summary

This PR adds a new SQL script that leverages Azure SQL's `sys.dm_db_tuning_recommendations` DMV to automatically identify and drop unused indexes.

## Changes

- **New Script**: `DropUnusedIndexDMV.sql` in `ProductSpecificScripts/DropUnusedIndex/`
- Uses DMV instead of manual JSON input (simplifies workflow)
- Parses JSON details column to extract index metadata directly
- Maintains backward compatibility with existing `DroppedUnusedIndexRecord` tracking table
- Scheduled for daily production runs (#CE# service principal)

## Key Features

- **Input Source**: `sys.dm_db_tuning_recommendations` (type='DropIndex', reason='Unused')
- **Safety**: DROP execution commented out by default for review
- **Error Handling**: Per-index TRY-CATCH with retry capability
- **Backward Compatibility**: Populates objectid/indexid for existing tracking
- **Rollback Support**: Captures key ordinals and column metadata

## Testing Status ✅

**Status**: ✅ **ALL TESTS PASSED (10/10 - 100% Success Rate)**

**Test Date**: 2026-01-26
**Test Environment**: SQL Server 2022 (Docker Container)
**Test Script**: `Test_DropUnusedIndexDMV.sql`

### Test Criteria & Outcomes

| Criteria | Expected | Actual | Status |
|----------|----------|--------|--------|
| **a) No record in mock table** | Script handles empty results gracefully | 0 rows inserted, no errors | ✅ PASS |
| **b) Record exists** | Entry created in DroppedUnusedIndexRecord | 3 valid records inserted | ✅ PASS |
| **c) JSON parsing** | Appropriate indexes selected | All fields parsed correctly:<br>• Schema: `[pjdraft]`<br>• Table: `[MSP_WEB_VIEW_FIELDS]`<br>• IndexColumns: `[SiteId], [WFIELD_NAME_CONV_VALUE]`<br>• IncludedColumns: `[Email], [Age]` | ✅ PASS |
| **d) Dummy indexes** | Test environment with realistic indexes | Created 3 test indexes including production-like scenario | ✅ PASS |

### Detailed Test Results

| # | Test Name | Status |
|---|-----------|--------|
| 1 | Empty Mock Table Handling | ✅ PASS |
| 2 | Valid Records Insertion | ✅ PASS |
| 3 | Schema Parsing | ✅ PASS |
| 4 | IndexColumns Parsing | ✅ PASS |
| 5 | IncludedColumns Parsing | ✅ PASS |
| 6 | Object ID Resolution | ✅ PASS |
| 7 | Key Ordinals Extraction | ✅ PASS |
| 8 | Index Filtering | ✅ PASS |
| 9 | DROP Command Generation | ✅ PASS |
| 10 | Duplicate Prevention | ✅ PASS |

### Test Artifacts Added

1. **`Test_DropUnusedIndexDMV.sql`** - Comprehensive test script (719 lines)
   - Mock environment simulating `sys.dm_db_tuning_recommendations`
   - Tests all code paths and edge cases
   - Self-validating with clear PASS/FAIL output

2. **`TEST_RESULTS_DropUnusedIndexDMV.md`** - Detailed test documentation
   - Complete test results with evidence
   - Execution instructions for reviewers
   - Code coverage analysis

3. **`RUN_TESTS.md`** - Quick start guide for reviewers
   - Copy-paste commands for validation
   - Docker, SSMS, and sqlcmd options

### How to Run Tests (Reviewers)

```bash
# Quick validation using Docker
docker cp src/DAMS-Scripts/ProductSpecificScripts/DropUnusedIndex/Test_DropUnusedIndexDMV.sql dams-sqlserver-dev:/tmp/
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -d capdamstest -C -i /tmp/Test_DropUnusedIndexDMV.sql

# Expected: "Tests Passed: 10 / 10"
```

### Edge Cases Validated

- ✅ Empty recommendations table
- ✅ Filtering invalid records (wrong type/reason/state)
- ✅ Duplicate prevention
- ✅ Schema-qualified table names
- ✅ Indexes with included columns
- ✅ Compound indexes
- ✅ Non-dbo schemas

### Code Coverage

All sections of `DropUnusedIndexDMV.sql` validated:
- ✅ Table creation/schema evolution
- ✅ Cleanup/retention logic
- ✅ JSON parsing from DMV
- ✅ Object ID resolution
- ✅ Main processing loop
- ✅ Index filtering
- ✅ Schema/table name parsing
- ✅ Key ordinals extraction
- ✅ DROP command generation
- ✅ Error handling
- ✅ Final status reporting

## Production Readiness

✅ **Script validated and ready for PreProd deployment**

**Note**: Line 159 is commented for safety (following mitigation script pattern). Uncomment to enable actual DROP execution in production.

## Related Work

- Author: amarpb
- Related to existing unused index feature (GetUnusedIndexPreProd.sql)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
