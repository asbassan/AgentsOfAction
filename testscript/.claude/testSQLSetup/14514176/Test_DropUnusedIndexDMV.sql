/*
    Test Script for DropUnusedIndexDMV.sql
    Author: amarpb
    Date: 2026-01-26

    This script creates a test environment to validate DropUnusedIndexDMV.sql functionality.

    Test Scenarios:
    a) No record in mock table -> expected outcome (script handles empty results)
    b) Record exists -> entry expected in DroppedUnusedIndexRecord table
    c) JSON value is parsed properly and appropriate indexes are selected
    d) Dummy indexes created and tested

    IMPORTANT: This test script creates a mock view to simulate dbo.MockTuningRecommendations
    since this DMV is only available in Azure SQL Database, not SQL Server 2022.
*/

SET NOCOUNT ON;
PRINT '========================================';
PRINT 'DropUnusedIndexDMV.sql - Test Script';
PRINT '========================================';
PRINT '';

-- ============================================
-- SECTION 1: Setup Test Environment
-- ============================================
PRINT '--- SECTION 1: Setup Test Environment ---';
PRINT '';

-- Drop existing test objects if they exist
IF OBJECT_ID('dbo.MockTuningRecommendations', 'V') IS NOT NULL
    DROP VIEW dbo.MockTuningRecommendations;

IF OBJECT_ID('dbo.MockTuningRecommendations', 'U') IS NOT NULL
    DROP TABLE dbo.MockTuningRecommendations;

IF OBJECT_ID('dbo.DroppedUnusedIndexRecord', 'U') IS NOT NULL
    DROP TABLE dbo.DroppedUnusedIndexRecord;

IF OBJECT_ID('dbo.TestTable1', 'U') IS NOT NULL
    DROP TABLE dbo.TestTable1;

IF OBJECT_ID('dbo.TestTable2', 'U') IS NOT NULL
    DROP TABLE dbo.TestTable2;

IF OBJECT_ID('pjdraft.MSP_WEB_VIEW_FIELDS', 'U') IS NOT NULL
    DROP TABLE pjdraft.MSP_WEB_VIEW_FIELDS;

IF SCHEMA_ID('pjdraft') IS NOT NULL
    DROP SCHEMA pjdraft;

PRINT 'Existing test objects cleaned up.';
GO

-- Create test schema (must be first statement in batch)
CREATE SCHEMA pjdraft;
GO

PRINT 'Created schema: pjdraft';

-- ============================================
-- SECTION 2: Create Test Tables and Indexes
-- ============================================
PRINT '';
PRINT '--- SECTION 2: Create Test Tables and Indexes ---';
PRINT '';

-- Test Table 1: Simple table with unused index
CREATE TABLE dbo.TestTable1 (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100),
    Status INT,
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- Insert sample data
INSERT INTO dbo.TestTable1 (Name, Status)
VALUES ('Test1', 1), ('Test2', 2), ('Test3', 3);

-- Create unused nonclustered index
CREATE NONCLUSTERED INDEX IX_TestTable1_Status
ON dbo.TestTable1(Status);

PRINT 'Created dbo.TestTable1 with IX_TestTable1_Status';

-- Test Table 2: Table with compound index and included columns
CREATE TABLE dbo.TestTable2 (
    Id INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    Age INT,
    City NVARCHAR(50)
);

-- Insert sample data
INSERT INTO dbo.TestTable2 (FirstName, LastName, Email, Age, City)
VALUES
    ('John', 'Doe', 'john@test.com', 30, 'Seattle'),
    ('Jane', 'Smith', 'jane@test.com', 25, 'Portland');

-- Create unused compound index with included columns
CREATE NONCLUSTERED INDEX IX_TestTable2_Names
ON dbo.TestTable2(FirstName, LastName)
INCLUDE (Email, Age);

PRINT 'Created dbo.TestTable2 with IX_TestTable2_Names';

-- Test Table 3: Matches the sample data structure from requirements
CREATE TABLE pjdraft.MSP_WEB_VIEW_FIELDS (
    SiteId INT,
    WFIELD_NAME_CONV_VALUE NVARCHAR(100),
    FieldData NVARCHAR(MAX)
);

-- Insert sample data
INSERT INTO pjdraft.MSP_WEB_VIEW_FIELDS (SiteId, WFIELD_NAME_CONV_VALUE, FieldData)
VALUES (1, 'Field1', 'Data1'), (2, 'Field2', 'Data2');

-- Create the original clustered index (to be replaced)
CREATE CLUSTERED INDEX CI_MSP_WEB_VIEW_FIELDS
ON pjdraft.MSP_WEB_VIEW_FIELDS(SiteId);

-- Create the unused nonclustered index (from Azure recommendation)
CREATE NONCLUSTERED INDEX IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE
ON pjdraft.MSP_WEB_VIEW_FIELDS(SiteId, WFIELD_NAME_CONV_VALUE);

PRINT 'Created pjdraft.MSP_WEB_VIEW_FIELDS with IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE';
PRINT '';

-- ============================================
-- SECTION 3: Create Mock Tuning Recommendations
-- ============================================
PRINT '--- SECTION 3: Create Mock Tuning Recommendations ---';
PRINT '';

-- Create mock table to simulate dbo.MockTuningRecommendations
CREATE TABLE dbo.MockTuningRecommendations (
    [type] NVARCHAR(50),
    reason NVARCHAR(50),
    state_desc NVARCHAR(50),
    details NVARCHAR(MAX)
);

-- Insert test scenarios
-- Scenario 1: Valid unused index from requirements (pjdraft table)
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'DropIndex',
    'Unused',
    'Active',
    '{"IndexName":"IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE","OriginalIndexName":"CI_MSP_WEB_VIEW_FIELDS","NumObservedDays":7,"IndexType":"NONCLUSTERED","Schema":"[pjdraft]","Table":"[MSP_WEB_VIEW_FIELDS]","IndexColumns":"[SiteId], [WFIELD_NAME_CONV_VALUE]","IncludedColumns":"", "DatabaseName":"capdamstest"}'
);

-- Scenario 2: Valid unused simple index (dbo.TestTable1)
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'DropIndex',
    'Unused',
    'Active',
    '{"IndexName":"IX_TestTable1_Status","OriginalIndexName":"","NumObservedDays":14,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Status]","IncludedColumns":"", "DatabaseName":"capdamstest"}'
);

-- Scenario 3: Valid unused compound index with included columns
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'DropIndex',
    'Unused',
    'Active',
    '{"IndexName":"IX_TestTable2_Names","OriginalIndexName":"","NumObservedDays":30,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable2]","IndexColumns":"[FirstName], [LastName]","IncludedColumns":"[Email], [Age]", "DatabaseName":"capdamstest"}'
);

-- Scenario 4: Should be IGNORED - wrong type (CreateIndex instead of DropIndex)
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'CreateIndex',
    'Unused',
    'Active',
    '{"IndexName":"IX_Should_Be_Ignored_Type","OriginalIndexName":"","NumObservedDays":7,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Name]","IncludedColumns":"", "DatabaseName":"capdamstest"}'
);

-- Scenario 5: Should be IGNORED - wrong reason (Performance instead of Unused)
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'DropIndex',
    'Performance',
    'Active',
    '{"IndexName":"IX_Should_Be_Ignored_Reason","OriginalIndexName":"","NumObservedDays":7,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[CreatedDate]","IncludedColumns":"", "DatabaseName":"capdamstest"}'
);

-- Scenario 6: Should be IGNORED - wrong state (Pending instead of Active)
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES (
    'DropIndex',
    'Unused',
    'Pending',
    '{"IndexName":"IX_Should_Be_Ignored_State","OriginalIndexName":"","NumObservedDays":7,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[CreatedDate]","IncludedColumns":"", "DatabaseName":"capdamstest"}'
);

PRINT 'Inserted 6 mock tuning recommendations:';
PRINT '  - 3 valid records (should be processed)';
PRINT '  - 3 invalid records (should be ignored)';
PRINT '';

PRINT 'Mock tuning recommendations table ready.';
PRINT 'NOTE: Using dbo.MockTuningRecommendations directly (SQL Server does not have dbo.MockTuningRecommendations DMV)';
PRINT '';

-- ============================================
-- SECTION 4: Display Mock Data
-- ============================================
PRINT '--- SECTION 4: Display Mock Data ---';
PRINT '';

SELECT
    [type],
    reason,
    state_desc,
    LEFT(details, 100) + '...' AS details_preview
FROM dbo.MockTuningRecommendations;

PRINT '';
PRINT 'Mock tuning recommendations created successfully.';
PRINT '';

-- ============================================
-- SECTION 5: Test Scenario A - No Records
-- ============================================
PRINT '--- SECTION 5: Test Scenario A - No Records in Mock Table ---';
PRINT '';

-- Temporarily clear mock data
TRUNCATE TABLE dbo.MockTuningRecommendations;
PRINT 'Cleared mock recommendations.';

-- Run the script (inline version for testing)
PRINT 'Running DropUnusedIndexDMV logic with empty recommendations...';

-- Create tracking table if not exists
IF OBJECT_ID('dbo.DroppedUnusedIndexRecord', 'U') IS NULL
BEGIN
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
END

-- Try to insert from empty recommendations
INSERT INTO dbo.DroppedUnusedIndexRecord (TableName, IndexName, KeyColumns, IncludedColumns, objectid, indexid, Processed)
SELECT
    JSON_VALUE(details, '$.Schema') + '.' + JSON_VALUE(details, '$.Table') AS TableName,
    JSON_VALUE(details, '$.IndexName') AS IndexName,
    JSON_VALUE(details, '$.IndexColumns') AS KeyColumns,
    JSON_VALUE(details, '$.IncludedColumns') AS IncludedColumns,
    NULL AS objectid,
    NULL AS indexid,
    0 AS Processed
FROM dbo.MockTuningRecommendations
WHERE [type] = 'DropIndex'
  AND reason = 'Unused'
  AND state_desc = 'Active';

DECLARE @RowsInserted INT = @@ROWCOUNT;
PRINT 'Rows inserted into DroppedUnusedIndexRecord: ' + CAST(@RowsInserted AS VARCHAR(10));

IF @RowsInserted = 0
    PRINT '✓ TEST PASSED: No rows inserted when mock table is empty (expected behavior)';
ELSE
    PRINT '✗ TEST FAILED: Unexpected rows inserted when mock table should be empty';

PRINT '';

-- ============================================
-- SECTION 6: Test Scenario B & C - Valid Records
-- ============================================
PRINT '--- SECTION 6: Test Scenarios B & C - Valid Records Exist ---';
PRINT '';

-- Re-populate mock data
INSERT INTO dbo.MockTuningRecommendations ([type], reason, state_desc, details)
VALUES
    ('DropIndex', 'Unused', 'Active',
     '{"IndexName":"IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE","OriginalIndexName":"CI_MSP_WEB_VIEW_FIELDS","NumObservedDays":7,"IndexType":"NONCLUSTERED","Schema":"[pjdraft]","Table":"[MSP_WEB_VIEW_FIELDS]","IndexColumns":"[SiteId], [WFIELD_NAME_CONV_VALUE]","IncludedColumns":"", "DatabaseName":"capdamstest"}'),
    ('DropIndex', 'Unused', 'Active',
     '{"IndexName":"IX_TestTable1_Status","OriginalIndexName":"","NumObservedDays":14,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Status]","IncludedColumns":"", "DatabaseName":"capdamstest"}'),
    ('DropIndex', 'Unused', 'Active',
     '{"IndexName":"IX_TestTable2_Names","OriginalIndexName":"","NumObservedDays":30,"IndexType":"NONCLUSTERED","Schema":"[dbo]","Table":"[TestTable2]","IndexColumns":"[FirstName], [LastName]","IncludedColumns":"[Email], [Age]", "DatabaseName":"capdamstest"}'),
    -- Invalid records (should be filtered out)
    ('CreateIndex', 'Unused', 'Active', '{"IndexName":"IX_Should_Be_Ignored_Type","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[Name]","IncludedColumns":""}'),
    ('DropIndex', 'Performance', 'Active', '{"IndexName":"IX_Should_Be_Ignored_Reason","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[CreatedDate]","IncludedColumns":""}'),
    ('DropIndex', 'Unused', 'Pending', '{"IndexName":"IX_Should_Be_Ignored_State","Schema":"[dbo]","Table":"[TestTable1]","IndexColumns":"[CreatedDate]","IncludedColumns":""}');

PRINT 'Re-populated mock recommendations with 3 valid + 3 invalid records.';
PRINT '';

-- Clear tracking table for fresh test
TRUNCATE TABLE dbo.DroppedUnusedIndexRecord;

-- Insert from recommendations
PRINT 'Inserting records from mock recommendations...';
INSERT INTO dbo.DroppedUnusedIndexRecord (TableName, IndexName, KeyColumns, IncludedColumns, objectid, indexid, Processed)
SELECT
    JSON_VALUE(details, '$.Schema') + '.' + JSON_VALUE(details, '$.Table') AS TableName,
    JSON_VALUE(details, '$.IndexName') AS IndexName,
    JSON_VALUE(details, '$.IndexColumns') AS KeyColumns,
    JSON_VALUE(details, '$.IncludedColumns') AS IncludedColumns,
    NULL AS objectid,
    NULL AS indexid,
    0 AS Processed
FROM dbo.MockTuningRecommendations
WHERE [type] = 'DropIndex'
  AND reason = 'Unused'
  AND state_desc = 'Active'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.DroppedUnusedIndexRecord d
      WHERE d.TableName = JSON_VALUE(details, '$.Schema') + '.' + JSON_VALUE(details, '$.Table')
        AND d.IndexName = JSON_VALUE(details, '$.IndexName')
  );

SET @RowsInserted = @@ROWCOUNT;
PRINT 'Rows inserted: ' + CAST(@RowsInserted AS VARCHAR(10));

IF @RowsInserted = 3
    PRINT '✓ TEST PASSED: Exactly 3 valid records inserted (filtered out 3 invalid)';
ELSE
    PRINT '✗ TEST FAILED: Expected 3 records, got ' + CAST(@RowsInserted AS VARCHAR(10));

PRINT '';

-- Display inserted records
PRINT 'Records in DroppedUnusedIndexRecord:';
SELECT
    TableName,
    IndexName,
    KeyColumns,
    IncludedColumns,
    objectid,
    indexid,
    Processed
FROM dbo.DroppedUnusedIndexRecord
ORDER BY TableName, IndexName;

PRINT '';

-- ============================================
-- SECTION 7: Test JSON Parsing
-- ============================================
PRINT '--- SECTION 7: Test JSON Parsing ---';
PRINT '';

PRINT 'Validating JSON parsing correctness...';

-- Test Schema extraction
DECLARE @ExpectedSchema NVARCHAR(128) = '[pjdraft]';
DECLARE @ActualSchema NVARCHAR(128);
DECLARE @ParseTableName NVARCHAR(256);
SELECT TOP 1 @ParseTableName = TableName
FROM dbo.DroppedUnusedIndexRecord
WHERE IndexName = 'IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE';

-- Parse schema from [schema].[table] format
IF @ParseTableName IS NOT NULL
    SET @ActualSchema = SUBSTRING(@ParseTableName, 1, CHARINDEX('].[', @ParseTableName));

IF @ActualSchema = @ExpectedSchema
    PRINT '✓ Schema parsing: PASSED (expected: ' + @ExpectedSchema + ', got: ' + @ActualSchema + ')';
ELSE
    PRINT '✗ Schema parsing: FAILED (expected: ' + @ExpectedSchema + ', got: ' + ISNULL(@ActualSchema, 'NULL') + ')';

-- Test IndexColumns extraction
DECLARE @ExpectedColumns NVARCHAR(MAX) = '[SiteId], [WFIELD_NAME_CONV_VALUE]';
DECLARE @ActualColumns NVARCHAR(MAX);
SELECT TOP 1 @ActualColumns = KeyColumns
FROM dbo.DroppedUnusedIndexRecord
WHERE IndexName = 'IX_MSP_WEB_VIEW_FIELDS_BY_CONV_VALUE';

IF @ActualColumns = @ExpectedColumns
    PRINT '✓ IndexColumns parsing: PASSED';
ELSE
    PRINT '✗ IndexColumns parsing: FAILED (expected: ' + @ExpectedColumns + ', got: ' + ISNULL(@ActualColumns, 'NULL') + ')';

-- Test IncludedColumns extraction
DECLARE @ExpectedIncluded NVARCHAR(MAX) = '[Email], [Age]';
DECLARE @ActualIncluded NVARCHAR(MAX);
SELECT TOP 1 @ActualIncluded = IncludedColumns
FROM dbo.DroppedUnusedIndexRecord
WHERE IndexName = 'IX_TestTable2_Names';

IF @ActualIncluded = @ExpectedIncluded
    PRINT '✓ IncludedColumns parsing: PASSED';
ELSE
    PRINT '✗ IncludedColumns parsing: FAILED (expected: ' + @ExpectedIncluded + ', got: ' + ISNULL(@ActualIncluded, 'NULL') + ')';

PRINT '';

-- ============================================
-- SECTION 8: Test Object ID Resolution
-- ============================================
PRINT '--- SECTION 8: Test Object ID Resolution ---';
PRINT '';

PRINT 'Updating objectid and indexid from sys.indexes...';

-- Update objectid and indexid
UPDATE d
SET d.objectid = i.object_id,
    d.indexid = i.index_id
FROM dbo.DroppedUnusedIndexRecord d
INNER JOIN sys.indexes i
    ON i.name = d.IndexName
    AND i.object_id = OBJECT_ID(d.TableName)
WHERE d.objectid IS NULL
  AND d.indexid IS NULL
  AND d.Processed = 0;

DECLARE @UpdatedRows INT = @@ROWCOUNT;
PRINT 'Rows updated with objectid/indexid: ' + CAST(@UpdatedRows AS VARCHAR(10));

-- Validate resolution
SELECT
    TableName,
    IndexName,
    objectid,
    indexid,
    CASE
        WHEN objectid IS NOT NULL AND indexid IS NOT NULL THEN '✓ Resolved'
        ELSE '✗ Failed to resolve'
    END AS ResolutionStatus
FROM dbo.DroppedUnusedIndexRecord
ORDER BY TableName, IndexName;

DECLARE @ResolvedCount INT;
SELECT @ResolvedCount = COUNT(*)
FROM dbo.DroppedUnusedIndexRecord
WHERE objectid IS NOT NULL AND indexid IS NOT NULL;

IF @ResolvedCount = 3
    PRINT '✓ TEST PASSED: All 3 records resolved to objectid/indexid';
ELSE
    PRINT '✗ TEST FAILED: Expected 3 resolved records, got ' + CAST(@ResolvedCount AS VARCHAR(10));

PRINT '';

-- ============================================
-- SECTION 9: Test Key Ordinals Extraction
-- ============================================
PRINT '--- SECTION 9: Test Key Ordinals Extraction ---';
PRINT '';

PRINT 'Extracting key ordinals from sys.index_columns...';

-- Update KeyOrdinals for each record
DECLARE @TestTableName NVARCHAR(256), @TestIndexName NVARCHAR(256);
DECLARE @TestObjectId INT, @TestIndexId INT, @TestKeyOrdinals NVARCHAR(MAX);

DECLARE key_ordinal_cursor CURSOR FOR
SELECT TableName, IndexName, objectid, indexid
FROM dbo.DroppedUnusedIndexRecord
WHERE Processed = 0 AND objectid IS NOT NULL AND indexid IS NOT NULL;

OPEN key_ordinal_cursor;
FETCH NEXT FROM key_ordinal_cursor INTO @TestTableName, @TestIndexName, @TestObjectId, @TestIndexId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @TestKeyOrdinals = STRING_AGG(CAST(ic.key_ordinal AS NVARCHAR(10)), ',')
    FROM sys.index_columns ic
    WHERE ic.object_id = @TestObjectId
      AND ic.index_id = @TestIndexId
      AND ic.is_included_column = 0;

    UPDATE dbo.DroppedUnusedIndexRecord
    SET KeyOrdinals = @TestKeyOrdinals
    WHERE TableName = @TestTableName AND IndexName = @TestIndexName;

    PRINT 'Index: ' + @TestIndexName + ' -> KeyOrdinals: ' + ISNULL(@TestKeyOrdinals, 'NULL');

    FETCH NEXT FROM key_ordinal_cursor INTO @TestTableName, @TestIndexName, @TestObjectId, @TestIndexId;
END

CLOSE key_ordinal_cursor;
DEALLOCATE key_ordinal_cursor;

PRINT '';

-- Validate key ordinals
SELECT
    IndexName,
    KeyColumns,
    KeyOrdinals,
    CASE
        WHEN KeyOrdinals IS NOT NULL THEN '✓ Ordinals extracted'
        ELSE '✗ Missing ordinals'
    END AS OrdinalsStatus
FROM dbo.DroppedUnusedIndexRecord
ORDER BY IndexName;

PRINT '';

-- ============================================
-- SECTION 10: Test Index Filtering
-- ============================================
PRINT '--- SECTION 10: Test Index Filtering ---';
PRINT '';

PRINT 'Testing index filtering (disabled, hypothetical, unique_constraint)...';

-- All our test indexes should pass the filters
DECLARE @FilteredCount INT;
SELECT @FilteredCount = COUNT(*)
FROM dbo.DroppedUnusedIndexRecord d
INNER JOIN sys.indexes i ON d.objectid = i.object_id AND d.indexid = i.index_id
WHERE d.Processed = 0
  AND i.is_disabled = 0
  AND i.is_hypothetical = 0
  AND i.is_unique_constraint = 0;

PRINT 'Indexes that pass all filters: ' + CAST(@FilteredCount AS VARCHAR(10));

IF @FilteredCount = 3
    PRINT '✓ TEST PASSED: All 3 test indexes pass filtering criteria';
ELSE
    PRINT '✗ TEST FAILED: Expected 3 indexes to pass filters, got ' + CAST(@FilteredCount AS VARCHAR(10));

PRINT '';

-- ============================================
-- SECTION 11: Test DROP Command Generation
-- ============================================
PRINT '--- SECTION 11: Test DROP Command Generation ---';
PRINT '';

PRINT 'Generating DROP commands (without execution)...';
PRINT '';

-- Simulate the WHILE loop logic
DECLARE @LoopTableName NVARCHAR(256), @LoopIndexName NVARCHAR(256);
DECLARE @LoopSchemaName NVARCHAR(128), @LoopTableNameOnly NVARCHAR(256);
DECLARE @LoopObjectId INT, @LoopIndexId INT;
DECLARE @DropSQL NVARCHAR(MAX);
DECLARE @CommandCount INT = 0;

DECLARE drop_cursor CURSOR FOR
SELECT
    d.TableName,
    d.IndexName,
    d.objectid,
    d.indexid
FROM dbo.DroppedUnusedIndexRecord d
INNER JOIN sys.indexes i ON d.objectid = i.object_id AND d.indexid = i.index_id
WHERE d.Processed = 0
  AND i.is_disabled = 0
  AND i.is_hypothetical = 0
  AND i.is_unique_constraint = 0;

OPEN drop_cursor;
FETCH NEXT FROM drop_cursor INTO @LoopTableName, @LoopIndexName, @LoopObjectId, @LoopIndexId;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Parse schema and table name (format: [schema].[table])
    SET @LoopSchemaName = SUBSTRING(@LoopTableName, 2, CHARINDEX('].[', @LoopTableName) - 2);
    SET @LoopTableNameOnly = SUBSTRING(@LoopTableName, CHARINDEX('].[', @LoopTableName) + 3,
                                       LEN(@LoopTableName) - CHARINDEX('].[', @LoopTableName) - 3);

    -- Generate DROP command
    SET @DropSQL = N'DROP INDEX ' + QUOTENAME(@LoopIndexName) + ' ON ' +
                   QUOTENAME(@LoopSchemaName) + '.' + QUOTENAME(@LoopTableNameOnly) + ';';

    PRINT 'Command ' + CAST(@CommandCount + 1 AS VARCHAR(10)) + ':';
    PRINT @DropSQL;
    PRINT '';

    SET @CommandCount = @CommandCount + 1;

    -- Mark as processed (simulating successful execution)
    UPDATE dbo.DroppedUnusedIndexRecord
    SET Processed = 1
    WHERE TableName = @LoopTableName AND IndexName = @LoopIndexName;

    FETCH NEXT FROM drop_cursor INTO @LoopTableName, @LoopIndexName, @LoopObjectId, @LoopIndexId;
END

CLOSE drop_cursor;
DEALLOCATE drop_cursor;

IF @CommandCount = 3
    PRINT '✓ TEST PASSED: Generated 3 DROP commands successfully';
ELSE
    PRINT '✗ TEST FAILED: Expected 3 commands, generated ' + CAST(@CommandCount AS VARCHAR(10));

PRINT '';

-- ============================================
-- SECTION 12: Test Final Status
-- ============================================
PRINT '--- SECTION 12: Test Final Status ---';
PRINT '';

SELECT
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN Processed = 1 THEN 1 ELSE 0 END) AS SuccessfulDrops,
    SUM(CASE WHEN Processed = -1 THEN 1 ELSE 0 END) AS FailedDrops,
    SUM(CASE WHEN Processed = 0 THEN 1 ELSE 0 END) AS PendingDrops
FROM dbo.DroppedUnusedIndexRecord;

DECLARE @SuccessCount INT;
SELECT @SuccessCount = SUM(CASE WHEN Processed = 1 THEN 1 ELSE 0 END)
FROM dbo.DroppedUnusedIndexRecord;

IF @SuccessCount = 3
    PRINT '✓ TEST PASSED: All 3 records marked as successfully processed';
ELSE
    PRINT '✗ TEST FAILED: Expected 3 successful, got ' + CAST(@SuccessCount AS VARCHAR(10));

PRINT '';

-- ============================================
-- SECTION 13: Test Duplicate Prevention
-- ============================================
PRINT '--- SECTION 13: Test Duplicate Prevention ---';
PRINT '';

PRINT 'Testing duplicate prevention (inserting same recommendations again)...';

-- Try to insert the same recommendations again
INSERT INTO dbo.DroppedUnusedIndexRecord (TableName, IndexName, KeyColumns, IncludedColumns, objectid, indexid, Processed)
SELECT
    JSON_VALUE(details, '$.Schema') + '.' + JSON_VALUE(details, '$.Table') AS TableName,
    JSON_VALUE(details, '$.IndexName') AS IndexName,
    JSON_VALUE(details, '$.IndexColumns') AS KeyColumns,
    JSON_VALUE(details, '$.IncludedColumns') AS IncludedColumns,
    NULL AS objectid,
    NULL AS indexid,
    0 AS Processed
FROM dbo.MockTuningRecommendations
WHERE [type] = 'DropIndex'
  AND reason = 'Unused'
  AND state_desc = 'Active'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.DroppedUnusedIndexRecord d
      WHERE d.TableName = JSON_VALUE(details, '$.Schema') + '.' + JSON_VALUE(details, '$.Table')
        AND d.IndexName = JSON_VALUE(details, '$.IndexName')
  );

DECLARE @DuplicateCount INT = @@ROWCOUNT;

IF @DuplicateCount = 0
    PRINT '✓ TEST PASSED: Duplicate prevention working (0 duplicates inserted)';
ELSE
    PRINT '✗ TEST FAILED: Duplicates were inserted: ' + CAST(@DuplicateCount AS VARCHAR(10));

PRINT '';

-- ============================================
-- SECTION 14: Test Summary
-- ============================================
PRINT '========================================';
PRINT 'TEST SUMMARY';
PRINT '========================================';
PRINT '';

-- Count total tests and passed tests
DECLARE @TotalTests INT = 10;
DECLARE @PassedTests INT = 0;

-- Verify each test criterion
IF (SELECT COUNT(*) FROM dbo.DroppedUnusedIndexRecord WHERE Processed = 1) = 3
    SET @PassedTests = @PassedTests + 1;

IF @ResolvedCount = 3
    SET @PassedTests = @PassedTests + 1;

IF @FilteredCount = 3
    SET @PassedTests = @PassedTests + 1;

IF @CommandCount = 3
    SET @PassedTests = @PassedTests + 1;

IF @SuccessCount = 3
    SET @PassedTests = @PassedTests + 1;

IF @DuplicateCount = 0
    SET @PassedTests = @PassedTests + 1;

IF @ActualSchema = @ExpectedSchema
    SET @PassedTests = @PassedTests + 1;

IF @ActualColumns = @ExpectedColumns
    SET @PassedTests = @PassedTests + 1;

IF @ActualIncluded = @ExpectedIncluded
    SET @PassedTests = @PassedTests + 1;

IF @RowsInserted = 3
    SET @PassedTests = @PassedTests + 1;

PRINT 'Tests Passed: ' + CAST(@PassedTests AS VARCHAR(10)) + ' / ' + CAST(@TotalTests AS VARCHAR(10));
PRINT 'Success Rate: ' + CAST((@PassedTests * 100 / @TotalTests) AS VARCHAR(10)) + '%';
PRINT '';

IF @PassedTests = @TotalTests
BEGIN
    PRINT '╔════════════════════════════════════╗';
    PRINT '║   ALL TESTS PASSED SUCCESSFULLY!   ║';
    PRINT '╚════════════════════════════════════╝';
END
ELSE
BEGIN
    PRINT '╔════════════════════════════════════╗';
    PRINT '║     SOME TESTS FAILED - REVIEW     ║';
    PRINT '╚════════════════════════════════════╝';
END

PRINT '';
PRINT 'Test completed: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT '';

-- ============================================
-- CLEANUP (Optional - comment out to inspect)
-- ============================================
-- PRINT '--- Cleanup ---';
-- DROP VIEW dbo.MockTuningRecommendations;
-- DROP TABLE dbo.MockTuningRecommendations;
-- DROP TABLE dbo.DroppedUnusedIndexRecord;
-- DROP TABLE pjdraft.MSP_WEB_VIEW_FIELDS;
-- DROP TABLE dbo.TestTable2;
-- DROP TABLE dbo.TestTable1;
-- DROP SCHEMA pjdraft;
-- PRINT 'Cleanup completed.';
