-- =============================================
-- Daily Batch Job 1: Daily Application Summary
-- Runs daily to populate DailyApplicationSummary table
-- Analyzes previous day's application activity
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Daily Application Summary Batch Job
-- =============================================

DECLARE @ReportDate DATE = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE); -- Previous day
DECLARE @ExecutionId BIGINT;
DECLARE @RecordsProcessed INT = 0;

-- Start job logging
EXEC sp_StartBatchJob 
    @JobName = 'Daily Application Summary',
    @JobType = 'Daily',
    @ReportPeriod = @ReportDate,
    @ExecutionId = @ExecutionId OUTPUT;

PRINT '=== DAILY APPLICATION SUMMARY BATCH JOB ===';
PRINT 'Processing Date: ' + CAST(@ReportDate AS VARCHAR);
PRINT 'ExecutionId: ' + CAST(@ExecutionId AS VARCHAR);
PRINT '';

-- Check if report already exists for this date
IF EXISTS (SELECT 1 FROM DailyApplicationSummary WHERE ReportDate = @ReportDate)
BEGIN
    PRINT 'Report already exists for ' + CAST(@ReportDate AS VARCHAR) + '. Updating existing record.';
    
    -- Update existing record
    UPDATE DailyApplicationSummary 
    SET 
        TotalApplications = (
            SELECT COUNT(*) 
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND IsActive = 1
        ),
        ApprovedApplications = (
            SELECT COUNT(*) 
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND ApplicationStatus = 'Approved' 
                AND IsActive = 1
        ),
        RejectedApplications = (
            SELECT COUNT(*) 
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND ApplicationStatus = 'Rejected' 
                AND IsActive = 1
        ),
        PendingApplications = (
            SELECT COUNT(*) 
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND ApplicationStatus IN ('Submitted', 'Under Review') 
                AND IsActive = 1
        ),
        ApprovalRate = (
            SELECT CASE 
                WHEN COUNT(*) > 0 
                THEN CAST(COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
                ELSE 0 
            END
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND IsActive = 1
        ),
        TotalRequestedAmount = (
            SELECT ISNULL(SUM(RequestedAmount), 0)
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND IsActive = 1
        ),
        AvgRequestedAmount = (
            SELECT ISNULL(AVG(RequestedAmount), 0)
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND IsActive = 1
        ),
        AvgProcessingHours = (
            SELECT AVG(CAST(DATEDIFF(MINUTE, SubmissionDate, ISNULL(DecisionDate, GETDATE())) AS DECIMAL(8,2)) / 60.0)
            FROM Applications 
            WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
                AND IsActive = 1
                AND DecisionDate IS NOT NULL
        ),
        CreatedDate = GETDATE()
    WHERE ReportDate = @ReportDate;
    
    PRINT 'Existing record updated successfully.';
END
ELSE
BEGIN
    PRINT 'Creating new report record for ' + CAST(@ReportDate AS VARCHAR);
    
    -- Insert new record
    INSERT INTO DailyApplicationSummary (
        ReportDate,
        TotalApplications,
        ApprovedApplications,
        RejectedApplications,
        PendingApplications,
        ApprovalRate,
        TotalRequestedAmount,
        AvgRequestedAmount,
        AvgProcessingHours
    )
    SELECT 
        @ReportDate,
        COUNT(*) AS TotalApplications,
        COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
        COUNT(CASE WHEN ApplicationStatus = 'Rejected' THEN 1 END) AS RejectedApplications,
        COUNT(CASE WHEN ApplicationStatus IN ('Submitted', 'Under Review') THEN 1 END) AS PendingApplications,
        CASE 
            WHEN COUNT(*) > 0 
            THEN CAST(COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
            ELSE 0 
        END AS ApprovalRate,
        ISNULL(SUM(RequestedAmount), 0) AS TotalRequestedAmount,
        ISNULL(AVG(RequestedAmount), 0) AS AvgRequestedAmount,
        AVG(CAST(DATEDIFF(MINUTE, SubmissionDate, ISNULL(DecisionDate, GETDATE())) AS DECIMAL(8,2)) / 60.0) AS AvgProcessingHours
    FROM Applications 
    WHERE CAST(SubmissionDate AS DATE) = @ReportDate 
        AND IsActive = 1;
    
    PRINT 'New record inserted successfully.';
END

-- Display results
PRINT '';
PRINT 'DAILY SUMMARY RESULTS:';
PRINT '=====================';

SELECT 
    ReportDate,
    TotalApplications,
    ApprovedApplications,
    RejectedApplications,
    PendingApplications,
    ApprovalRate,
    FORMAT(TotalRequestedAmount, 'C', 'en-US') AS TotalRequestedAmount,
    FORMAT(AvgRequestedAmount, 'C', 'en-US') AS AvgRequestedAmount,
    CAST(AvgProcessingHours AS DECIMAL(6,2)) AS AvgProcessingHours
FROM DailyApplicationSummary 
WHERE ReportDate = @ReportDate;

-- Performance comparison with previous day
PRINT '';
PRINT 'COMPARISON WITH PREVIOUS DAY:';
PRINT '============================';

WITH CurrentDay AS (
    SELECT * FROM DailyApplicationSummary WHERE ReportDate = @ReportDate
),
PreviousDay AS (
    SELECT * FROM DailyApplicationSummary WHERE ReportDate = DATEADD(DAY, -1, @ReportDate)
)
SELECT 
    'Applications' AS Metric,
    cd.TotalApplications AS Today,
    ISNULL(pd.TotalApplications, 0) AS Yesterday,
    CASE 
        WHEN ISNULL(pd.TotalApplications, 0) > 0 
        THEN CAST((cd.TotalApplications - ISNULL(pd.TotalApplications, 0)) * 100.0 / pd.TotalApplications AS DECIMAL(6,2))
        ELSE 0 
    END AS PercentChange
FROM CurrentDay cd
LEFT JOIN PreviousDay pd ON 1=1

UNION ALL

SELECT 
    'Approval Rate' AS Metric,
    cd.ApprovalRate AS Today,
    ISNULL(pd.ApprovalRate, 0) AS Yesterday,
    cd.ApprovalRate - ISNULL(pd.ApprovalRate, 0) AS PercentChange
FROM CurrentDay cd
LEFT JOIN PreviousDay pd ON 1=1;

-- Weekly trend (last 7 days)
PRINT '';
PRINT 'WEEKLY TREND (Last 7 Days):';
PRINT '===========================';

SELECT 
    ReportDate,
    DATENAME(WEEKDAY, ReportDate) AS DayOfWeek,
    TotalApplications,
    ApprovalRate,
    FORMAT(TotalRequestedAmount, 'C', 'en-US') AS TotalRequestedAmount
FROM DailyApplicationSummary 
WHERE ReportDate >= DATEADD(DAY, -7, @ReportDate)
    AND ReportDate <= @ReportDate
ORDER BY ReportDate DESC;

-- Complete job logging
SET @RecordsProcessed = (SELECT COUNT(*) FROM Applications WHERE CAST(SubmissionDate AS DATE) = @ReportDate AND IsActive = 1);

EXEC sp_CompleteBatchJob 
    @ExecutionId = @ExecutionId,
    @RecordsProcessed = @RecordsProcessed,
    @RecordsInserted = 1,
    @Status = 'Completed';

PRINT '';
PRINT '=== END DAILY APPLICATION SUMMARY JOB ===';

GO