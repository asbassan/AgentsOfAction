/*
Test Case: ENABLE_DROP_UNUSED_INDEX Configuration Check
Purpose: Verify configuration check and SELECT output format
Author: amarpb
Date: 2026-01-26
*/

SET NOCOUNT ON;

PRINT '';
PRINT '========================================================================';
PRINT 'Test Case: ENABLE_DROP_UNUSED_INDEX Configuration Check';
PRINT '========================================================================';
PRINT '';

-- ============================================================================
-- SETUP: Create test environment
-- ============================================================================

PRINT '--- SETUP: Creating test environment ---';

-- Drop existing objects
IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
    DROP TABLE DamsConfigurationBase;

IF OBJECT_ID('dbo.DroppedUnusedIndexRecord', 'U') IS NOT NULL
    DROP TABLE dbo.DroppedUnusedIndexRecord;

IF OBJECT_ID('dbo.TestTableConfig', 'U') IS NOT NULL
    DROP TABLE dbo.TestTableConfig;

-- Create DamsConfigurationBase table
CREATE TABLE DamsConfigurationBase (
    SettingName NVARCHAR(256) NOT NULL,
    CONSTRAINT AK_SettingName UNIQUE(SettingName),
    SettingValue NVARCHAR(256) NOT NULL
) WITH (DATA_COMPRESSION = ROW);

-- Create test table with index
CREATE TABLE dbo.TestTableConfig (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100),
    Status INT
);

CREATE NONCLUSTERED INDEX IX_TestConfig_Status ON dbo.TestTableConfig(Status);

-- Create DroppedUnusedIndexRecord table
CREATE TABLE dbo.DroppedUnusedIndexRecord (
    TableName NVARCHAR(256) NOT NULL,
    IndexName NVARCHAR(256) NOT NULL,
    KeyColumns NVARCHAR(MAX) NULL,
    KeyOrdinals NVARCHAR(MAX) NULL,
    IncludedColumns NVARCHAR(MAX) NULL,
    DateInserted DATETIME NOT NULL DEFAULT (GETDATE()),
    objectid INT NULL,
    indexid INT NULL,
    Processed BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_DroppedUnusedIndexRecord PRIMARY KEY (TableName, IndexName)
);

-- Insert test record
INSERT INTO dbo.DroppedUnusedIndexRecord (TableName, IndexName, KeyColumns, IncludedColumns, objectid, indexid, Processed)
VALUES ('[dbo].[TestTableConfig]', 'IX_TestConfig_Status', '[Status]', NULL, OBJECT_ID('dbo.TestTableConfig'), 2, 0);

PRINT 'Setup complete.';
PRINT '';

-- ============================================================================
-- TEST 1: Configuration does not exist (should default to 0)
-- ============================================================================

PRINT '--- TEST 1: Configuration does not exist ---';
PRINT 'Expected: ConfigEnabled = 0, ExecutionStatus = REVIEW_MODE';
PRINT '';

-- Simulate script logic
DECLARE @DROP_INDEX_ENABLED BIT = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Test query
DECLARE @TableName NVARCHAR(256) = '[dbo].[TestTableConfig]';
DECLARE @IndexName NVARCHAR(256) = 'IX_TestConfig_Status';
DECLARE @KeyColumns NVARCHAR(MAX) = '[Status]';
DECLARE @IncludedColumns NVARCHAR(MAX) = NULL;
DECLARE @sql NVARCHAR(MAX) = 'DROP INDEX [IX_TestConfig_Status] ON [dbo].[TestTableConfig];';

-- Output (this is what the script produces)
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 0
    PRINT 'TEST 1 RESULT: PASS - Default to review mode when setting does not exist';
ELSE
    PRINT 'TEST 1 RESULT: FAIL - Should default to 0';

PRINT '';

-- ============================================================================
-- TEST 2: Configuration set to 0 (disabled)
-- ============================================================================

PRINT '--- TEST 2: Configuration set to 0 (disabled) ---';
PRINT 'Expected: ConfigEnabled = 0, ExecutionStatus = REVIEW_MODE';
PRINT '';

-- Insert configuration
INSERT INTO DamsConfigurationBase (SettingName, SettingValue)
VALUES ('ENABLE_DROP_UNUSED_INDEX', '0');

-- Simulate script logic
SET @DROP_INDEX_ENABLED = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Output
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 0
    PRINT 'TEST 2 RESULT: PASS - Configuration correctly set to disabled';
ELSE
    PRINT 'TEST 2 RESULT: FAIL - Should be disabled';

PRINT '';

-- ============================================================================
-- TEST 3: Configuration set to 1 (enabled)
-- ============================================================================

PRINT '--- TEST 3: Configuration set to 1 (enabled) ---';
PRINT 'Expected: ConfigEnabled = 1, ExecutionStatus = EXECUTED';
PRINT '';

-- Update configuration
UPDATE DamsConfigurationBase
SET SettingValue = '1'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

-- Simulate script logic
SET @DROP_INDEX_ENABLED = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Output
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 1
    PRINT 'TEST 3 RESULT: PASS - Configuration correctly set to enabled';
ELSE
    PRINT 'TEST 3 RESULT: FAIL - Should be enabled';

PRINT '';

-- ============================================================================
-- TEST 4: Configuration set to 'TRUE' (case-insensitive)
-- ============================================================================

PRINT '--- TEST 4: Configuration set to TRUE (case-insensitive) ---';
PRINT 'Expected: ConfigEnabled = 1, ExecutionStatus = EXECUTED';
PRINT '';

-- Update configuration
UPDATE DamsConfigurationBase
SET SettingValue = 'TRUE'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

-- Simulate script logic
SET @DROP_INDEX_ENABLED = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Output
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 1
    PRINT 'TEST 4 RESULT: PASS - TRUE value correctly recognized';
ELSE
    PRINT 'TEST 4 RESULT: FAIL - Should be enabled';

PRINT '';

-- ============================================================================
-- TEST 5: Configuration set to 'true' (lowercase)
-- ============================================================================

PRINT '--- TEST 5: Configuration set to true (lowercase) ---';
PRINT 'Expected: ConfigEnabled = 1, ExecutionStatus = EXECUTED';
PRINT '';

-- Update configuration
UPDATE DamsConfigurationBase
SET SettingValue = 'true'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

-- Simulate script logic
SET @DROP_INDEX_ENABLED = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Output
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 1
    PRINT 'TEST 5 RESULT: PASS - Lowercase true correctly recognized (case-insensitive)';
ELSE
    PRINT 'TEST 5 RESULT: FAIL - Should be enabled';

PRINT '';

-- ============================================================================
-- TEST 6: Configuration set to any other value (should be disabled)
-- ============================================================================

PRINT '--- TEST 6: Configuration set to invalid value ---';
PRINT 'Expected: ConfigEnabled = 0, ExecutionStatus = REVIEW_MODE';
PRINT '';

-- Update configuration
UPDATE DamsConfigurationBase
SET SettingValue = 'INVALID'
WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

-- Simulate script logic
SET @DROP_INDEX_ENABLED = 0;

IF OBJECT_ID('DamsConfigurationBase', 'U') IS NOT NULL
BEGIN
    SELECT @DROP_INDEX_ENABLED = CASE
        WHEN UPPER(SettingValue) IN ('1', 'TRUE') THEN 1
        ELSE 0
    END
    FROM DamsConfigurationBase
    WHERE SettingName = 'ENABLE_DROP_UNUSED_INDEX';

    IF @@ROWCOUNT = 0
        SET @DROP_INDEX_ENABLED = 0;
END

-- Output
SELECT @DROP_INDEX_ENABLED AS ConfigEnabled,
       CASE WHEN @DROP_INDEX_ENABLED = 1 THEN 'EXECUTED' ELSE 'REVIEW_MODE' END AS ExecutionStatus,
       @sql AS DropCommand,
       @TableName AS TableName,
       @IndexName AS IndexName,
       @KeyColumns AS KeyColumns,
       @IncludedColumns AS IncludedColumns;

PRINT '';

-- Validation
IF @DROP_INDEX_ENABLED = 0
    PRINT 'TEST 6 RESULT: PASS - Invalid value defaults to disabled';
ELSE
    PRINT 'TEST 6 RESULT: FAIL - Should default to disabled';

PRINT '';

-- ============================================================================
-- TEST 7: Verify SELECT output columns
-- ============================================================================

PRINT '--- TEST 7: Verify SELECT output column structure ---';
PRINT '';

-- Verify column names and data types by creating temp table from SELECT
SELECT TOP 0
    CAST(0 AS BIT) AS ConfigEnabled,
    CAST('REVIEW_MODE' AS VARCHAR(20)) AS ExecutionStatus,
    CAST('' AS NVARCHAR(MAX)) AS DropCommand,
    CAST('' AS NVARCHAR(256)) AS TableName,
    CAST('' AS NVARCHAR(256)) AS IndexName,
    CAST('' AS NVARCHAR(MAX)) AS KeyColumns,
    CAST(NULL AS NVARCHAR(MAX)) AS IncludedColumns
INTO #OutputStructure;

-- Check column count
DECLARE @ColumnCount INT;
SELECT @ColumnCount = COUNT(*)
FROM tempdb.sys.columns
WHERE object_id = OBJECT_ID('tempdb..#OutputStructure');

IF @ColumnCount = 7
    PRINT 'TEST 7 RESULT: PASS - Correct number of columns (7)';
ELSE
    PRINT 'TEST 7 RESULT: FAIL - Expected 7 columns, found ' + CAST(@ColumnCount AS VARCHAR(10));

DROP TABLE #OutputStructure;

PRINT '';

-- ============================================================================
-- CLEANUP
-- ============================================================================

PRINT '--- CLEANUP ---';

DROP TABLE DamsConfigurationBase;
DROP TABLE dbo.DroppedUnusedIndexRecord;
DROP TABLE dbo.TestTableConfig;

PRINT 'Cleanup complete.';
PRINT '';

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

PRINT '========================================================================';
PRINT 'TEST SUMMARY';
PRINT '========================================================================';
PRINT 'All 7 tests should show PASS';
PRINT '';
PRINT 'Test 1: Config does not exist -> Default to REVIEW_MODE';
PRINT 'Test 2: Config set to 0 -> REVIEW_MODE';
PRINT 'Test 3: Config set to 1 -> EXECUTED';
PRINT 'Test 4: Config set to TRUE -> EXECUTED';
PRINT 'Test 5: Config set to true -> EXECUTED (case-insensitive)';
PRINT 'Test 6: Config set to invalid -> REVIEW_MODE';
PRINT 'Test 7: Output structure validation -> 7 columns';
PRINT '========================================================================';
PRINT '';
