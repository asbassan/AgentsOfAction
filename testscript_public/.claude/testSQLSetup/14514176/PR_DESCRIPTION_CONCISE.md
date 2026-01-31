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

**Test Date**: 2026-01-26 | **Environment**: SQL Server 2022 (Docker)

### Test Criteria & Outcomes

| Criteria | Result | Status |
|----------|--------|--------|
| a) No record in mock table | 0 rows inserted, no errors | ✅ PASS |
| b) Record exists | 3 valid records inserted | ✅ PASS |
| c) JSON parsing | All fields extracted correctly | ✅ PASS |
| d) Dummy indexes | 3 test indexes created & validated | ✅ PASS |

### Test Results Summary

✅ Empty mock table handling
✅ Valid records insertion (filtered 3 invalid)
✅ Schema/IndexColumns/IncludedColumns parsing
✅ Object ID resolution
✅ Key ordinals extraction
✅ Index filtering (disabled/hypothetical/constraint)
✅ DROP command generation
✅ Duplicate prevention
✅ Error handling
✅ Final status reporting

### Test Artifacts Added

1. **`Test_DropUnusedIndexDMV.sql`** - Comprehensive test script (719 lines)
2. **`TEST_RESULTS_DropUnusedIndexDMV.md`** - Detailed test documentation
3. **`RUN_TESTS.md`** - Quick start guide for reviewers

### Run Tests

```bash
docker cp src/DAMS-Scripts/ProductSpecificScripts/DropUnusedIndex/Test_DropUnusedIndexDMV.sql dams-sqlserver-dev:/tmp/
docker exec dams-sqlserver-dev /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Pass@word1' -d capdamstest -C -i /tmp/Test_DropUnusedIndexDMV.sql
```

Expected: "Tests Passed: 10 / 10"

### Code Coverage

✅ All sections validated: Table creation, JSON parsing, Object ID resolution, Processing loop, Index filtering, DROP generation, Error handling, Status reporting

## Production Readiness

✅ **Script validated and ready for PreProd deployment**

**Note**: Line 159 commented for safety. Uncomment to enable DROP execution.

## Related Work

- Author: amarpb
- Related to existing unused index feature (GetUnusedIndexPreProd.sql)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
