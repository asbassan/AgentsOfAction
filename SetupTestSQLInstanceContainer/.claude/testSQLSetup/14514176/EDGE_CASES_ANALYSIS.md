# Edge Cases Analysis - DropUnusedIndexDMV.sql

## Overview

This document analyzes edge cases that were **tested** vs **not tested** in our test suite, and provides recommendations for additional testing.

**Current Test Coverage**: 10/10 tests passed
**Test Date**: 2026-01-26

---

## ✅ Edge Cases We DID Test

### 1. Empty Recommendations Table
- ✅ **Tested**: No records in mock table
- **Result**: 0 rows inserted, no errors
- **Line**: Section 5 of test script

### 2. Invalid Filtering Values
- ✅ **Tested**: Wrong type ('CreateIndex' instead of 'DropIndex')
- ✅ **Tested**: Wrong reason ('Performance' instead of 'Unused')
- ✅ **Tested**: Wrong state ('Pending' instead of 'Active')
- **Result**: All 3 invalid records correctly filtered out
- **Line**: Section 6 - inserted 6 records, only 3 processed

### 3. Duplicate Prevention
- ✅ **Tested**: Re-inserting same recommendations
- **Result**: 0 duplicates inserted (primary key constraint works)
- **Line**: Section 13

### 4. Multiple Schemas
- ✅ **Tested**: `dbo` and `pjdraft` schemas
- **Result**: Both schemas handled correctly
- **Line**: TestTable1/TestTable2 in dbo, MSP_WEB_VIEW_FIELDS in pjdraft

### 5. Empty IncludedColumns
- ✅ **Tested**: Index with no included columns
- **Result**: Empty string handled correctly
- **Line**: IX_TestTable1_Status, IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE

### 6. Compound Indexes
- ✅ **Tested**: Multi-column index (FirstName, LastName)
- **Result**: KeyOrdinals extracted correctly (1,2)
- **Line**: IX_TestTable2_Names

### 7. Object ID Resolution
- ✅ **Tested**: All indexes resolved to objectid/indexid
- **Result**: sys.indexes JOIN successful for all 3 indexes
- **Line**: Section 8

---

## ❌ Edge Cases We DID NOT Test

### **Category A: Name Handling Edge Cases**

#### 1. Special Characters in Names 🔴 **HIGH PRIORITY**
**Not Tested**:
- Index names with spaces: `[My Index Name]`
- Table names with special characters: `[Table-Name]`, `[Table.Name]`
- Schema names with numbers: `[schema123]`
- Names with quotes: `[Table's Name]`
- Names with brackets inside: `[Table[0]]`

**Risk**: SQL injection or parsing failures
**Script Line**: 133-157 (schema/table name parsing)

**Example Test**:
```sql
-- Create table with special characters
CREATE TABLE [dbo].[Test Table-Name] (Id INT);
CREATE NONCLUSTERED INDEX [IX_Test Index] ON [dbo].[Test Table-Name](Id);

-- JSON with special characters
{"IndexName":"IX_Test Index","Schema":"[dbo]","Table":"[Test Table-Name]","IndexColumns":"[Id]","IncludedColumns":""}
```

#### 2. NULL vs Empty String in JSON 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- `"IncludedColumns": null` (vs `""`)
- `"IndexColumns": null`
- Missing JSON fields entirely

**Risk**: JSON_VALUE returns NULL, could cause issues
**Script Line**: 74-77 (JSON parsing)

**Example Test**:
```json
{"IndexName":"IX_Test","Schema":"[dbo]","Table":"[MyTable]","IndexColumns":null,"IncludedColumns":null}
```

#### 3. Very Long Names 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Index name > 128 characters (SQL Server limit)
- Table name > 128 characters
- Schema name > 128 characters
- KeyColumns string > NVARCHAR(MAX) practical limit

**Risk**: Truncation or overflow errors
**Script Line**: 40-43 (table schema definition uses NVARCHAR(256))

#### 4. Case Sensitivity 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Same index name but different case: `IX_Index` vs `ix_index`
- Same table name different case

**Risk**: Depends on database collation
**Script Line**: 86-89 (duplicate check is case-sensitive)

---

### **Category B: Index State Edge Cases**

#### 5. Index Already Dropped 🔴 **HIGH PRIORITY**
**Not Tested**:
- Index in recommendations but already dropped manually
- Index exists in DMV but not in sys.indexes

**Risk**: Error during objectid/indexid resolution or DROP
**Script Line**: 92-101 (object ID resolution), 151-157 (DROP execution)

**Expected Behavior**:
- objectid/indexid UPDATE would fail (no rows updated)
- Index would remain Processed = 0 (skipped)

**Example Test**:
```sql
-- Insert recommendation for non-existent index
INSERT INTO MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{"IndexName":"IX_DoesNotExist","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Name]","IncludedColumns":""}'
);
-- Expected: Skip (no objectid resolution)
```

#### 6. Table Doesn't Exist 🔴 **HIGH PRIORITY**
**Not Tested**:
- Table referenced in DMV but dropped

**Risk**: OBJECT_ID() returns NULL, objectid/indexid resolution fails
**Script Line**: 98 (OBJECT_ID call)

**Example Test**:
```json
{"IndexName":"IX_Test","Schema":"[dbo]","Table":"[DroppedTable]","IndexColumns":"[Id]","IncludedColumns":""}
```

#### 7. Index Currently Locked/In Use 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Index being used by active query during DROP
- Table locked by another transaction

**Risk**: DROP INDEX fails with lock timeout
**Script Line**: 151-157 (DROP execution), TRY-CATCH should handle this

**Expected Behavior**: Caught by TRY-CATCH, marked Processed = -1

#### 8. Disabled Index 🟢 **LOW PRIORITY** (Script filters this)
**Not Tested**: Explicitly, but script has filter
**Script Line**: 113 (`is_disabled = 0` filter)
**Status**: Implicitly tested (filter should work)

#### 9. Clustered Index in Recommendations 🟢 **LOW PRIORITY**
**Not Tested**: Clustered index (type_desc = 'CLUSTERED')
**Note**: Azure SQL typically doesn't recommend dropping clustered indexes
**Script filters**: Only looks at sys.indexes (doesn't check type)

**Potential Issue**: Script doesn't explicitly filter for NONCLUSTERED
**Recommendation**: Add type_desc filter or test

---

### **Category C: Data Integrity Edge Cases**

#### 10. Malformed JSON 🔴 **HIGH PRIORITY**
**Not Tested**:
- Invalid JSON syntax in details column
- Truncated JSON
- JSON with unexpected structure

**Risk**: JSON_VALUE returns NULL, could cause errors
**Script Line**: 72-89 (JSON parsing)

**Example Test**:
```sql
INSERT INTO MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{InvalidJSON: "missing quotes"}'
);
-- Expected: JSON_VALUE returns NULL, no insert
```

#### 11. Missing Required JSON Fields 🔴 **HIGH PRIORITY**
**Not Tested**:
- JSON missing `Schema` field
- JSON missing `Table` field
- JSON missing `IndexName` field

**Risk**: JSON_VALUE returns NULL, TableName or IndexName becomes NULL
**Script Line**: 74-76 (could violate NOT NULL on TableName/IndexName)

**Current Primary Key**: (TableName, IndexName) both NOT NULL
**Expected Behavior**: INSERT would fail (NULL violation)

**Example Test**:
```json
{"IndexName":"IX_Test","IndexColumns":"[Id]","IncludedColumns":""}
// Missing Schema and Table
```

#### 12. KeyOrdinals Not Sequential 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Key ordinals with gaps: 1, 3, 5 (if columns deleted/altered)

**Risk**: Rollback script might have wrong column order
**Script Line**: 137-141 (STRING_AGG key_ordinal)

**Example**:
```sql
-- If someone did:
-- ALTER TABLE DROP COLUMN MiddleColumn
-- Ordinals: 1, 3 (skipping 2)
```

#### 13. Unicode Characters in Data 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Index names with Unicode: `IX_Índex_中文`
- Schema/table names with Unicode

**Risk**: Encoding issues (we saw this with checkmarks in PR comment)
**Script Line**: All string handling

---

### **Category D: Concurrent Execution Edge Cases**

#### 14. Concurrent Script Execution 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Two instances of script running simultaneously
- Race condition on Processed flag

**Risk**: Primary key violation or deadlock
**Script Line**: 86-89 (NOT EXISTS check not atomic)

**Expected Behavior**:
- Primary key constraint should prevent duplicates
- Potential deadlock on UPDATE Processed

#### 15. External Changes During Execution 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Index dropped externally while script is running
- Table altered during processing

**Risk**: DROP INDEX fails with "index not found"
**Expected Behavior**: TRY-CATCH should handle, mark Processed = -1

---

### **Category E: Volume/Performance Edge Cases**

#### 16. Large Batch (1000+ Indexes) 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Performance with 1000+ indexes to process
- Memory usage with large DroppedUnusedIndexRecord table

**Risk**: Timeout, performance degradation
**Script Line**: 109-191 (WHILE loop)

**Current Test**: Only 3 indexes

#### 17. Cleanup Edge Case (Exactly 10 Rows) 🟢 **LOW PRIORITY**
**Not Tested**:
- Exactly 10 rows older than 10 days
- 11 rows older than 10 days

**Script Line**: 66-68 (`DELETE TOP (10)`)
**Expected**: Deletes 10 rows, leaves 1 for next run

---

### **Category F: Permission/Security Edge Cases**

#### 18. Permission Denied 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- User lacks ALTER permission on table
- User lacks CREATE TABLE permission (for tracking table)

**Risk**: DROP INDEX fails with permission error
**Expected Behavior**: Caught by TRY-CATCH, marked Processed = -1

#### 19. Database in Read-Only Mode 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Database set to READ_ONLY
- Table in read-only filegroup

**Risk**: All writes fail (table creation, INSERT, UPDATE, DROP)
**Expected Behavior**: Script fails immediately

---

### **Category G: Schema Evolution Edge Cases**

#### 20. Existing Tracking Table with Different Schema 🟡 **MEDIUM PRIORITY**
**Not Tested**:
- Table exists but missing KeyOrdinals column
- Table exists but has incompatible primary key

**Script Line**: 54-63 (ALTER TABLE logic)

**Current Test**: Creates table from scratch

**What Script Does**:
- Checks for missing columns
- Adds them with ALTER TABLE
- **But**: Doesn't handle incompatible primary key

**Potential Issue**: If existing table has PK on (objectid, indexid) instead of (TableName, IndexName)

---

## 📊 Priority Summary

### 🔴 HIGH PRIORITY (Must Test)
1. **Special characters in names** - SQL injection risk
2. **Index already dropped** - Common in production
3. **Table doesn't exist** - Common in production
4. **Malformed JSON** - Data quality issue
5. **Missing required JSON fields** - Causes NULL violations

### 🟡 MEDIUM PRIORITY (Should Test)
6. **NULL vs empty string in JSON** - Edge case handling
7. **Very long names** - Boundary testing
8. **Case sensitivity** - Collation-dependent
9. **Index locked/in use** - Concurrency issue
10. **KeyOrdinals not sequential** - Rollback accuracy
11. **Unicode characters** - Encoding issues
12. **Concurrent execution** - Race conditions
13. **External changes during execution** - Real-world scenario
14. **Large batch (1000+ indexes)** - Performance
15. **Permission denied** - Security
16. **Database read-only** - Environment state
17. **Existing table schema mismatch** - Upgrade scenario

### 🟢 LOW PRIORITY (Nice to Have)
18. **Disabled index** - Already filtered by script
19. **Clustered index** - Unlikely from Azure recommendations
20. **Cleanup edge case** - Minor boundary condition

---

## 🎯 Recommended Additional Tests

### Test Suite v2.0 - Additional Edge Cases

Create `Test_DropUnusedIndexDMV_EdgeCases.sql` with:

```sql
-- HIGH PRIORITY TESTS

-- Test 1: Special characters in names
CREATE TABLE [dbo].[Test-Table Name] (Id INT);
CREATE NONCLUSTERED INDEX [IX Test-Index] ON [dbo].[Test-Table Name](Id);

-- Test 2: Index already dropped
INSERT MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{"IndexName":"IX_NonExistent","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Id]","IncludedColumns":""}'
);

-- Test 3: Table doesn't exist
INSERT MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{"IndexName":"IX_Test","Schema":"[dbo]","Table":"[NonExistentTable]","IndexColumns":"[Id]","IncludedColumns":""}'
);

-- Test 4: Malformed JSON
INSERT MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{InvalidJSON}'
);

-- Test 5: Missing required JSON fields
INSERT MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{"IndexName":"IX_Test","IndexColumns":"[Id]"}'  -- Missing Schema and Table
);

-- MEDIUM PRIORITY TESTS

-- Test 6: NULL in JSON
INSERT MockTuningRecommendations VALUES (
    'DropIndex', 'Unused', 'Active',
    '{"IndexName":"IX_Test","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":null,"IncludedColumns":null}'
);

-- Test 7: Very long names (130 chars, exceeds 128 limit)
DECLARE @LongName NVARCHAR(200) = 'IX_' + REPLICATE('A', 130);
-- Test script behavior

-- Test 8: Unicode characters
CREATE TABLE dbo.TestTableUnicode (Id INT);
CREATE NONCLUSTERED INDEX [IX_Índex_中文] ON dbo.TestTableUnicode(Id);

-- Test 9: Large batch (simulate 100 indexes)
-- Generate 100 mock recommendations
```

---

## 🔍 Testing Recommendations

### Phase 1: Immediate (HIGH PRIORITY)
1. **Special characters test** - 1 hour
2. **Non-existent index/table tests** - 30 minutes
3. **JSON edge cases** - 1 hour

**Estimated Time**: 2.5 hours
**Value**: Prevents production failures

### Phase 2: Short-term (MEDIUM PRIORITY)
4. **Concurrency test** - 2 hours (requires multi-threading setup)
5. **Large batch test** - 1 hour (generate 1000 mock records)
6. **Permission tests** - 1 hour (create limited user)

**Estimated Time**: 4 hours
**Value**: Ensures production scalability

### Phase 3: Long-term (LOW PRIORITY)
7. **Schema evolution test** - 1 hour
8. **Performance benchmarking** - 2 hours

**Estimated Time**: 3 hours
**Value**: Future-proofing

---

## 📝 Current Test Coverage Assessment

| Category | Tests Written | Tests Needed | Coverage % |
|----------|--------------|--------------|------------|
| Happy Path | 10 | 10 | 100% |
| Filtering Logic | 3 | 3 | 100% |
| Name Handling | 2 | 7 | 29% |
| Index State | 0 | 5 | 0% |
| Data Integrity | 1 | 5 | 20% |
| Concurrency | 0 | 2 | 0% |
| Volume/Performance | 0 | 2 | 0% |
| Security | 0 | 2 | 0% |
| **Total** | **16** | **36** | **44%** |

---

## ✅ Action Items

### For PR #14514176
- ✅ **Current tests sufficient for initial PR approval** (10/10 passed)
- ⚠️ **Document known limitations** in PR comment
- 📝 **Create follow-up work item** for edge case testing

### For Production Deployment
- 🔴 **Must test** before PreProd: Special characters, non-existent objects
- 🟡 **Should test** before Production: Large batch, concurrency
- 🟢 **Can defer**: Long-term edge cases

### For Documentation
- Update TEST_RESULTS with "Known Limitations" section
- Create EDGE_CASES_TODO.md for tracking
- Add to script comments: "Tested with synthetic data only"

---

**Document Version**: 1.0
**Created**: 2026-01-26
**Author**: Analysis for PR #14514176
**Status**: Recommendations for Phase 2 testing
