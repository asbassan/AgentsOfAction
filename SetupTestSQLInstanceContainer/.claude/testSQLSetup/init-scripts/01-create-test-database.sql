-- =============================================
-- CAP-DAMS SQL Server Test Setup
-- Script: 01-create-test-database.sql
-- Description: Create capdamstest database and configure settings
-- =============================================

USE [master];
GO

-- Create test database for CAP-DAMS development
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'capdamstest')
BEGIN
    PRINT 'Creating capdamstest database...';

    CREATE DATABASE [capdamstest]
    ON PRIMARY
    (
        NAME = N'capdamstest_Data',
        FILENAME = N'/var/opt/mssql/data/capdamstest.mdf',
        SIZE = 1024MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 256MB
    )
    LOG ON
    (
        NAME = N'capdamstest_Log',
        FILENAME = N'/var/opt/mssql/log/capdamstest_log.ldf',
        SIZE = 512MB,
        MAXSIZE = 10GB,
        FILEGROWTH = 128MB
    );

    PRINT 'capdamstest database created successfully.';
END
ELSE
BEGIN
    PRINT 'capdamstest database already exists.';
END
GO

-- Configure database settings
ALTER DATABASE [capdamstest] SET RECOVERY FULL;
ALTER DATABASE [capdamstest] SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE [capdamstest] SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE [capdamstest] SET AUTO_UPDATE_STATISTICS_ASYNC ON;
ALTER DATABASE [capdamstest] SET QUERY_STORE = ON;
GO

-- Configure Query Store settings
ALTER DATABASE [capdamstest]
SET QUERY_STORE
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO
);
GO

-- Create sample table for testing
USE [capdamstest];
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TestTable')
BEGIN
    CREATE TABLE dbo.TestTable
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(256) NOT NULL,
        CreatedOn DATETIME NOT NULL DEFAULT GETUTCDATE(),
        ModifiedOn DATETIME NULL
    );

    PRINT 'TestTable created successfully.';

    -- Insert sample data
    INSERT INTO dbo.TestTable (Name)
    VALUES
        ('CAP-DAMS Test Record 1'),
        ('CAP-DAMS Test Record 2'),
        ('CAP-DAMS Test Record 3');

    PRINT 'Sample data inserted.';
END
GO

-- Display configuration
PRINT '=========================================='
PRINT 'Database Configuration Summary:'
PRINT '=========================================='
PRINT 'Database: capdamstest'
PRINT 'Recovery Model: FULL'
PRINT 'Query Store: ENABLED'
PRINT 'Auto Create Statistics: ON'
PRINT 'Auto Update Statistics: ON'
PRINT '=========================================='
GO
