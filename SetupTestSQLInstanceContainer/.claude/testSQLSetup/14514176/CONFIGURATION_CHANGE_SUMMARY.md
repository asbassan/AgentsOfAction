# Configuration Change Summary - DropUnusedIndexDMV.sql

**Commit**: 28b2f0ea2
**Branch**: user/amarpb/DropUnusedIndexDMV
**Date**: 2026-01-26
**Author**: amarpb (Amarpreet Bassan)

---

## Overview

Modified `DropUnusedIndexDMV.sql` to add dynamic configuration control via `DamsConfigurationBase` table, eliminating the need to manually edit the script to enable/disable DROP INDEX execution.

---

## What Changed

### 1. Added Configuration Check (Lines 37-69)

**Location**: After `SET LOCK_TIMEOUT 60000;`

**Added**:
```sql
-- ============================================================================
-- Configuration: Check ENABLE_DROP_UNUSED_INDEX setting from DamsConfigurationBase
-- ============================================================================
-- NOTE: ENABLE_DROP_UNUSED_INDEX will be added to DamsConfigurationBase via another script.
-- This setting controls whether the script actually executes DROP INDEX commands.
-- - Value '1' or 'TRUE': Enable actual DROP INDEX execution
-- - Value '0' or 'FALSE' or not exists: Review mode only (no drops executed)
-- ============================================================================

DECLARE @DROP_INDEX_ENABLED BIT = 0;  -- Default: Review mode (no drops)

-- Check if DamsConfigurationBase exists and read configuration
IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    -- If setting doesn't exist, default to 0 (review mode)
    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Display current configuration
PRINT '============================================================================';
PRINT 'DROP INDEX Configuration:';
PRINT '  ENABLE_DROP_UNUSED_INDEX = ' + CAST(@DROP_INDEX_ENABLED AS VARCHAR(1));
PRINT '  Mode: ' + CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTE (drops enabled)' ELSE 'REVIEW ONLY (drops disabled)' END;
PRINT '============================================================================';
PRINT '';
```

**Purpose**:
- Reads `ENABLE_DROP_UNUSED_INDEX` setting from `DamsConfigurationBase` table
- Defaults to `0` (review mode) if table doesn't exist or setting is not found
- Accepts values: `'1'`, `'TRUE'` (case-insensitive) = enabled
- Any other value or missing setting = disabled (review mode)
- Displays clear output showing current configuration

---

### 2. Modified DROP INDEX Execution (Lines 193-211)

**Before**:
```sql
--EXEC sp_executesql @sql;  -- COMMENTED FOR SAFETY - UNCOMMENT TO EXECUTE DROPS

-- Output DROP command for review
SELECT @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;
```

**After**:
```sql
-- Execute DROP INDEX only if ENABLE_DROP_UNUSED_INDEX is enabled
IF @DROP_INDEX_ENABLED = 1
BEGIN
    EXEC sp_executesql @sql;
    PRINT 'EXECUTED: ' + @sql;
END
ELSE
BEGIN
    -- Review mode: Display DROP command without executing
    PRINT 'REVIEW MODE (not executed): ' + @sql;
END

-- Output DROP command for review
SELECT @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns,
       @DROP_INDEX_ENABLED AS WasExecuted;
```

**Changes**:
- Replaced commented `EXEC sp_executesql @sql;` with conditional execution
- Checks `@DROP_INDEX_ENABLED` flag before executing DROP INDEX
- Adds clear PRINT statements indicating execution status
- Added `WasExecuted` column to SELECT output for visibility

---

## DamsConfigurationBase Structure

The script queries the following table:

```sql
CREATE TABLE DamsConfigurationBase (
    SettingName NVARCHAR(256) NOT NULL,
    CONSTRAINT AK_SettingName UNIQUE(SettingName),
    SettingValue NVARCHAR(256) NOT NULL
)
WITH (DATA_COMPRESSION = ROW)
```

**Query Pattern**:
```sql
SELECT SettingValue
FROM DamsConfigurationBase
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

---

## How to Enable DROP INDEX Execution

### Option 1: Add Setting to DamsConfigurationBase (Recommended)

**To enable**:
```sql
-- If DamsConfigurationBase doesn't exist, create it first
IF OBJECT_ID('DamsConfigurationBase', 'U') IS NULL
BEGIN
    CREATE TABLE DamsConfigurationBase (
        SettingName NVARCHAR(256) NOT NULL,
        CONSTRAINT AK_SettingName UNIQUE(SettingName),
        SettingValue NVARCHAR(256) NOT NULL
    )
    WITH (DATA_COMPRESSION = ROW);
END

-- Insert or update ENABLE_DROP_UNUSED_INDEX setting
IF NOT EXISTS (SELECT 1 FROM DamsConfigurationBase WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX')
BEGIN
    INSERT INTO DamsConfigurationBase (SettingName, SettingValue)
    VALUES ('ENABLE_DROP_UNUSED_INDEX', '1');
END
ELSE
BEGIN
    UPDATE DamsConfigurationBase
    SET SettingValue = '1'
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
END
```

**To disable**:
```sql
UPDATE DamsConfigurationBase
SET SettingValue = '0'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

**To check current status**:
```sql
SELECT SettingName, SettingValue
FROM DamsConfigurationBase
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

---

### Option 2: Without DamsConfigurationBase Table

If `DamsConfigurationBase` table doesn't exist, the script automatically defaults to **review mode** (no drops executed).

---

## Output Changes

### Configuration Output (Always Displayed)

When the script runs, it displays:

**Example 1 - Review Mode** (drops disabled):
```
============================================================================
DROP INDEX Configuration:
  ENABLE_DROP_UNUSED_INDEX = 0
  Mode: REVIEW ONLY (drops disabled)
============================================================================
```

**Example 2 - Execute Mode** (drops enabled):
```
============================================================================
DROP INDEX Configuration:
  ENABLE_DROP_UNUSED_INDEX = 1
  Mode: EXECUTE (drops enabled)
============================================================================
```

---

### Per-Index Output

**Review Mode** (ENABLE_DROP_UNUSED_INDEX = 0):
```
REVIEW MODE (not executed): DROP INDEX [IX_TestIndex] ON [dbo].[TestTable];

DropCommand                                    TableName         IndexName      KeyColumns  IncludedColumns  WasExecuted
---------------------------------------------  ----------------  -------------  ----------  ---------------  -----------
DROP INDEX [IX_TestIndex] ON [dbo].[TestTable]  dbo.TestTable   IX_TestIndex   [Id]        [Name]           0
```

**Execute Mode** (ENABLE_DROP_UNUSED_INDEX = 1):
```
EXECUTED: DROP INDEX [IX_TestIndex] ON [dbo].[TestTable];

DropCommand                                    TableName         IndexName      KeyColumns  IncludedColumns  WasExecuted
---------------------------------------------  ----------------  -------------  ----------  ---------------  -----------
DROP INDEX [IX_TestIndex] ON [dbo].[TestTable]  dbo.TestTable   IX_TestIndex   [Id]        [Name]           1
```

**New Column**: `WasExecuted` (BIT) - Indicates whether the DROP was actually executed (1) or just reviewed (0)

---

## Benefits

1. **No Script Editing Required** - Configuration change via database setting
2. **Safe Default** - Defaults to review mode (0) if setting doesn't exist
3. **Clear Visibility** - Output shows current mode and execution status
4. **Per-Database Control** - Each database can have its own configuration
5. **Auditable** - Can track when setting was changed (add LastModified column to DamsConfigurationBase)
6. **Backward Compatible** - Works without DamsConfigurationBase table (defaults to review mode)

---

## Safety Features

1. **Default to Review Mode**: If `DamsConfigurationBase` doesn't exist → drops disabled
2. **Default to Review Mode**: If `ENABLE_DROP_UNUSED_INDEX` setting doesn't exist → drops disabled
3. **Explicit Enable Required**: Must explicitly set to `'1'` or `'TRUE'` to enable drops
4. **Clear Output**: PRINT statements clearly indicate execution status
5. **Visible Flag**: `WasExecuted` column in SELECT output shows execution state

---

## Testing the Configuration

### Test 1: Review Mode (Default)

**Setup**:
```sql
-- No DamsConfigurationBase table or setting doesn't exist
```

**Expected Output**:
```
Mode: REVIEW ONLY (drops disabled)
REVIEW MODE (not executed): DROP INDEX ...
WasExecuted = 0
```

**Result**: No indexes dropped ✅

---

### Test 2: Explicitly Disabled

**Setup**:
```sql
UPDATE DamsConfigurationBase
SET SettingValue = '0'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

**Expected Output**:
```
Mode: REVIEW ONLY (drops disabled)
REVIEW MODE (not executed): DROP INDEX ...
WasExecuted = 0
```

**Result**: No indexes dropped ✅

---

### Test 3: Enabled with '1'

**Setup**:
```sql
UPDATE DamsConfigurationBase
SET SettingValue = '1'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

**Expected Output**:
```
Mode: EXECUTE (drops enabled)
EXECUTED: DROP INDEX ...
WasExecuted = 1
```

**Result**: Indexes actually dropped ✅

---

### Test 4: Enabled with 'TRUE'

**Setup**:
```sql
UPDATE DamsConfigurationBase
SET SettingValue = 'TRUE'  -- Case-insensitive
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';
```

**Expected Output**:
```
Mode: EXECUTE (drops enabled)
EXECUTED: DROP INDEX ...
WasExecuted = 1
```

**Result**: Indexes actually dropped ✅

---

## Related Files

- **Modified Script**: `src/DAMS-Scripts/ProductSpecificScripts/DropUnusedIndex/DropUnusedIndexDMV.sql`
- **Configuration Table Creation**: `src/DAMS-Scripts/ProductSpecificScripts/Configuration/CreateDamsConfigurationBase.sql`
- **Similar Pattern**: `src/DAMS-Scripts/ProductSpecificScripts/IndexManagement/ToggleIsDropIndexEnabledForDatabase.sql` (uses `IS_DROP_INDEX_ENABLED` for API-driven drops)

---

## Next Steps

1. **Create ENABLE_DROP_UNUSED_INDEX setting** via separate script (as noted in comments)
2. **Test configuration changes** in PreProd environment
3. **Document in runbook** how to enable/disable drops per database
4. **Update monitoring** to check `WasExecuted` column in output
5. **Consider adding audit trail** (LastModified, ModifiedBy columns to DamsConfigurationBase)

---

## Commit Details

**Commit Hash**: 28b2f0ea2
**Commit Message**:
```
Add ENABLE_DROP_UNUSED_INDEX configuration check to DropUnusedIndexDMV.sql

- Added configuration check from DamsConfigurationBase table
- Script now reads ENABLE_DROP_UNUSED_INDEX setting (defaults to 0/review mode)
- DROP INDEX execution only occurs when setting is '1' or 'TRUE'
- Added clear output indicating whether drops are enabled or in review mode
- Added WasExecuted column to output for visibility
- NOTE: ENABLE_DROP_UNUSED_INDEX will be added to DamsConfigurationBase via separate script

This change allows dynamic control of DROP INDEX execution without editing the script file.
```

**Files Changed**: 1 file, 47 insertions(+), 2 deletions(-)

**Pushed to**: origin/user/amarpb/DropUnusedIndexDMV

---

**Document Version**: 1.0
**Created**: 2026-01-26
**Author**: amarpb (Amarpreet Bassan)
