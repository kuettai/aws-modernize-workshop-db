-- =============================================
-- Batch Job Execution Log Table
-- Tracks timing and status of all batch reporting jobs
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Table: BatchJobExecutionLog
-- =============================================
CREATE TABLE BatchJobExecutionLog (
    ExecutionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    JobName NVARCHAR(100) NOT NULL,
    JobType NVARCHAR(50) NOT NULL CHECK (JobType IN ('Daily', 'Weekly', 'Monthly', 'Adhoc')),
    ReportPeriod DATE NOT NULL, -- The date/period being processed
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2,
    DurationSeconds INT,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Running' CHECK (Status IN ('Running', 'Completed', 'Failed', 'Cancelled')),
    RecordsProcessed INT DEFAULT 0,
    RecordsInserted INT DEFAULT 0,
    RecordsUpdated INT DEFAULT 0,
    ErrorMessage NVARCHAR(MAX),
    ServerName NVARCHAR(100) DEFAULT @@SERVERNAME,
    DatabaseName NVARCHAR(100) DEFAULT DB_NAME(),
    ExecutedBy NVARCHAR(100) DEFAULT SYSTEM_USER,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE()
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================
CREATE INDEX IX_BatchJobExecutionLog_JobName_ReportPeriod ON BatchJobExecutionLog(JobName, ReportPeriod);
CREATE INDEX IX_BatchJobExecutionLog_StartTime ON BatchJobExecutionLog(StartTime);
CREATE INDEX IX_BatchJobExecutionLog_Status ON BatchJobExecutionLog(Status);
CREATE INDEX IX_BatchJobExecutionLog_JobType ON BatchJobExecutionLog(JobType);

-- =============================================
-- STORED PROCEDURES FOR JOB TRACKING
-- =============================================

-- Start Job Logging
CREATE PROCEDURE sp_StartBatchJob
    @JobName NVARCHAR(100),
    @JobType NVARCHAR(50),
    @ReportPeriod DATE,
    @ExecutionId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO BatchJobExecutionLog (
        JobName,
        JobType,
        ReportPeriod,
        StartTime,
        Status
    )
    VALUES (
        @JobName,
        @JobType,
        @ReportPeriod,
        GETDATE(),
        'Running'
    );
    
    SET @ExecutionId = SCOPE_IDENTITY();
    
    PRINT 'Job started: ' + @JobName + ' (ExecutionId: ' + CAST(@ExecutionId AS VARCHAR) + ')';
END;
GO

-- Complete Job Logging
CREATE PROCEDURE sp_CompleteBatchJob
    @ExecutionId BIGINT,
    @RecordsProcessed INT = 0,
    @RecordsInserted INT = 0,
    @RecordsUpdated INT = 0,
    @Status NVARCHAR(20) = 'Completed',
    @ErrorMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2;
    SELECT @StartTime = StartTime FROM BatchJobExecutionLog WHERE ExecutionId = @ExecutionId;
    
    UPDATE BatchJobExecutionLog 
    SET 
        EndTime = GETDATE(),
        DurationSeconds = DATEDIFF(SECOND, @StartTime, GETDATE()),
        Status = @Status,
        RecordsProcessed = @RecordsProcessed,
        RecordsInserted = @RecordsInserted,
        RecordsUpdated = @RecordsUpdated,
        ErrorMessage = @ErrorMessage
    WHERE ExecutionId = @ExecutionId;
    
    DECLARE @JobName NVARCHAR(100);
    SELECT @JobName = JobName FROM BatchJobExecutionLog WHERE ExecutionId = @ExecutionId;
    
    PRINT 'Job completed: ' + @JobName + ' (Status: ' + @Status + ', Duration: ' + 
          CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + ' seconds)';
END;
GO

-- Get Job Status
CREATE PROCEDURE sp_GetBatchJobStatus
    @JobName NVARCHAR(100) = NULL,
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ExecutionId,
        JobName,
        JobType,
        ReportPeriod,
        StartTime,
        EndTime,
        DurationSeconds,
        Status,
        RecordsProcessed,
        RecordsInserted,
        RecordsUpdated,
        ErrorMessage,
        ExecutedBy
    FROM BatchJobExecutionLog
    WHERE (@JobName IS NULL OR JobName = @JobName)
        AND StartTime >= DATEADD(DAY, -@DaysBack, GETDATE())
    ORDER BY StartTime DESC;
END;
GO

PRINT 'Batch job execution tracking system created successfully!';
PRINT 'Tables: BatchJobExecutionLog';
PRINT 'Stored Procedures: sp_StartBatchJob, sp_CompleteBatchJob, sp_GetBatchJobStatus';
GO