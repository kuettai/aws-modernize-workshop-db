-- =============================================
-- Database Initialization Script for Docker
-- Automatically executed when SQL Server container starts
-- =============================================

-- Wait for SQL Server to be ready
WAITFOR DELAY '00:00:10';

-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LoanApplicationDB')
BEGIN
    CREATE DATABASE LoanApplicationDB;
    PRINT 'Database LoanApplicationDB created successfully';
END
ELSE
BEGIN
    PRINT 'Database LoanApplicationDB already exists';
END

-- Switch to the application database
USE LoanApplicationDB;

-- Check if tables already exist (avoid re-creating on container restart)
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Branches')
BEGIN
    PRINT 'Initializing database schema...';
    
    -- Note: In a real deployment, you would include the full schema here
    -- For the workshop, the schema will be applied separately
    -- This script just ensures the database exists
    
    PRINT 'Database initialization completed';
END
ELSE
BEGIN
    PRINT 'Database schema already exists, skipping initialization';
END