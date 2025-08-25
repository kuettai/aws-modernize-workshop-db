-- =============================================
-- Monthly Batch Job 2: Loan Officer Performance Report
-- Runs monthly to populate MonthlyLoanOfficerPerformance table
-- Analyzes loan officer productivity and rankings
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Monthly Loan Officer Performance Batch Job
-- =============================================

DECLARE @ReportMonth DATE = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1); -- First day of previous month
DECLARE @ExecutionId BIGINT;
DECLARE @RecordsProcessed INT = 0;

-- Start job logging
EXEC sp_StartBatchJob 
    @JobName = 'Monthly Loan Officer Performance',
    @JobType = 'Monthly',
    @ReportPeriod = @ReportMonth,
    @ExecutionId = @ExecutionId OUTPUT;

PRINT '=== MONTHLY LOAN OFFICER PERFORMANCE BATCH JOB ===';
PRINT 'Processing Month: ' + CAST(@ReportMonth AS VARCHAR);
PRINT 'ExecutionId: ' + CAST(@ExecutionId AS VARCHAR);
PRINT '';

-- Clear existing data for this month (if re-running)
DELETE FROM MonthlyLoanOfficerPerformance WHERE ReportMonth = @ReportMonth;
PRINT 'Cleared existing data for ' + CAST(@ReportMonth AS VARCHAR);

-- Insert performance data with ranking
WITH LoanOfficerStats AS (
    SELECT 
        lo.LoanOfficerId,
        lo.FirstName + ' ' + lo.LastName AS LoanOfficerName,
        b.BranchName,
        COUNT(a.ApplicationId) AS TotalApplications,
        COUNT(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
        CASE 
            WHEN COUNT(a.ApplicationId) > 0 
            THEN CAST(COUNT(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(a.ApplicationId) AS DECIMAL(5,2))
            ELSE 0 
        END AS ApprovalRate,
        ISNULL(SUM(CASE WHEN a.ApplicationStatus = 'Approved' THEN a.RequestedAmount ELSE 0 END), 0) AS TotalLoanAmount,
        ISNULL(AVG(CASE WHEN a.ApplicationStatus = 'Approved' THEN a.RequestedAmount END), 0) AS AvgLoanAmount,
        AVG(CASE 
            WHEN a.DecisionDate IS NOT NULL 
            THEN CAST(DATEDIFF(HOUR, a.SubmissionDate, a.DecisionDate) AS DECIMAL(8,2)) / 24.0
            END) AS AvgProcessingDays
    FROM LoanOfficers lo
    INNER JOIN Branches b ON lo.BranchId = b.BranchId
    LEFT JOIN Applications a ON lo.LoanOfficerId = a.LoanOfficerId 
        AND a.SubmissionDate >= @ReportMonth 
        AND a.SubmissionDate < DATEADD(MONTH, 1, @ReportMonth)
        AND a.IsActive = 1
    WHERE lo.IsActive = 1
    GROUP BY lo.LoanOfficerId, lo.FirstName, lo.LastName, b.BranchName
    HAVING COUNT(a.ApplicationId) > 0  -- Only include officers with applications
),
RankedOfficers AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY ApprovalRate DESC, TotalLoanAmount DESC, TotalApplications DESC) AS Ranking
    FROM LoanOfficerStats
)
INSERT INTO MonthlyLoanOfficerPerformance (
    ReportMonth,
    LoanOfficerId,
    LoanOfficerName,
    BranchName,
    TotalApplications,
    ApprovedApplications,
    ApprovalRate,
    TotalLoanAmount,
    AvgLoanAmount,
    AvgProcessingDays,
    Ranking
)
SELECT 
    @ReportMonth,
    LoanOfficerId,
    LoanOfficerName,
    BranchName,
    TotalApplications,
    ApprovedApplications,
    ApprovalRate,
    TotalLoanAmount,
    AvgLoanAmount,
    AvgProcessingDays,
    Ranking
FROM RankedOfficers;

DECLARE @RecordsInserted INT = @@ROWCOUNT;
PRINT 'Inserted ' + CAST(@RecordsInserted AS VARCHAR) + ' loan officer performance records.';

-- Display Top 10 Performers
PRINT '';
PRINT 'TOP 10 LOAN OFFICERS (By Approval Rate & Volume):';
PRINT '================================================';

SELECT 
    Ranking,
    LoanOfficerName,
    BranchName,
    TotalApplications,
    ApprovedApplications,
    ApprovalRate,
    FORMAT(TotalLoanAmount, 'C', 'en-US') AS TotalLoanAmount,
    FORMAT(AvgLoanAmount, 'C', 'en-US') AS AvgLoanAmount,
    CAST(AvgProcessingDays AS DECIMAL(5,2)) AS AvgProcessingDays
FROM MonthlyLoanOfficerPerformance 
WHERE ReportMonth = @ReportMonth
    AND Ranking <= 10
ORDER BY Ranking;

-- Branch Performance Summary
PRINT '';
PRINT 'BRANCH PERFORMANCE SUMMARY:';
PRINT '==========================';

SELECT 
    BranchName,
    COUNT(*) AS ActiveOfficers,
    SUM(TotalApplications) AS BranchTotalApplications,
    SUM(ApprovedApplications) AS BranchApprovedApplications,
    CAST(SUM(ApprovedApplications) * 100.0 / SUM(TotalApplications) AS DECIMAL(5,2)) AS BranchApprovalRate,
    FORMAT(SUM(TotalLoanAmount), 'C', 'en-US') AS BranchTotalLoanAmount,
    AVG(ApprovalRate) AS AvgOfficerApprovalRate,
    MIN(Ranking) AS BestOfficerRank,
    MAX(Ranking) AS WorstOfficerRank
FROM MonthlyLoanOfficerPerformance 
WHERE ReportMonth = @ReportMonth
GROUP BY BranchName
ORDER BY BranchApprovalRate DESC, BranchTotalLoanAmount DESC;

-- Performance Distribution Analysis
PRINT '';
PRINT 'PERFORMANCE DISTRIBUTION:';
PRINT '========================';

SELECT 
    CASE 
        WHEN ApprovalRate >= 80 THEN 'Excellent (80%+)'
        WHEN ApprovalRate >= 70 THEN 'Good (70-79%)'
        WHEN ApprovalRate >= 60 THEN 'Average (60-69%)'
        WHEN ApprovalRate >= 50 THEN 'Below Average (50-59%)'
        ELSE 'Poor (<50%)'
    END AS PerformanceCategory,
    COUNT(*) AS OfficerCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage,
    AVG(TotalApplications) AS AvgApplicationsPerOfficer,
    FORMAT(AVG(TotalLoanAmount), 'C', 'en-US') AS AvgLoanAmountPerOfficer
FROM MonthlyLoanOfficerPerformance 
WHERE ReportMonth = @ReportMonth
GROUP BY 
    CASE 
        WHEN ApprovalRate >= 80 THEN 'Excellent (80%+)'
        WHEN ApprovalRate >= 70 THEN 'Good (70-79%)'
        WHEN ApprovalRate >= 60 THEN 'Average (60-69%)'
        WHEN ApprovalRate >= 50 THEN 'Below Average (50-59%)'
        ELSE 'Poor (<50%)'
    END
ORDER BY MIN(ApprovalRate) DESC;

-- Officers Needing Attention (Bottom 10%)
PRINT '';
PRINT 'OFFICERS NEEDING ATTENTION (Bottom 10%):';
PRINT '=======================================';

DECLARE @TotalOfficers INT = (SELECT COUNT(*) FROM MonthlyLoanOfficerPerformance WHERE ReportMonth = @ReportMonth);
DECLARE @Bottom10Percent INT = CEILING(@TotalOfficers * 0.1);

SELECT 
    Ranking,
    LoanOfficerName,
    BranchName,
    TotalApplications,
    ApprovalRate,
    FORMAT(TotalLoanAmount, 'C', 'en-US') AS TotalLoanAmount,
    CAST(AvgProcessingDays AS DECIMAL(5,2)) AS AvgProcessingDays,
    'Performance Review Recommended' AS ActionRequired
FROM MonthlyLoanOfficerPerformance 
WHERE ReportMonth = @ReportMonth
    AND Ranking > (@TotalOfficers - @Bottom10Percent)
ORDER BY Ranking DESC;

-- Month-over-Month Comparison (if previous month data exists)
PRINT '';
PRINT 'MONTH-OVER-MONTH COMPARISON (Top 5 Officers):';
PRINT '============================================';

WITH CurrentMonth AS (
    SELECT TOP 5 * FROM MonthlyLoanOfficerPerformance 
    WHERE ReportMonth = @ReportMonth 
    ORDER BY Ranking
),
PreviousMonth AS (
    SELECT * FROM MonthlyLoanOfficerPerformance 
    WHERE ReportMonth = DATEADD(MONTH, -1, @ReportMonth)
)
SELECT 
    cm.LoanOfficerName,
    cm.TotalApplications AS CurrentApps,
    ISNULL(pm.TotalApplications, 0) AS PreviousApps,
    cm.ApprovalRate AS CurrentApprovalRate,
    ISNULL(pm.ApprovalRate, 0) AS PreviousApprovalRate,
    cm.ApprovalRate - ISNULL(pm.ApprovalRate, 0) AS ApprovalRateChange,
    CASE 
        WHEN cm.ApprovalRate > ISNULL(pm.ApprovalRate, 0) THEN 'Improved'
        WHEN cm.ApprovalRate < ISNULL(pm.ApprovalRate, 0) THEN 'Declined'
        ELSE 'Stable'
    END AS Trend
FROM CurrentMonth cm
LEFT JOIN PreviousMonth pm ON cm.LoanOfficerId = pm.LoanOfficerId
ORDER BY cm.Ranking;

-- Complete job logging
SET @RecordsProcessed = (SELECT COUNT(*) FROM LoanOfficers WHERE IsActive = 1);

EXEC sp_CompleteBatchJob 
    @ExecutionId = @ExecutionId,
    @RecordsProcessed = @RecordsProcessed,
    @RecordsInserted = @RecordsInserted,
    @Status = 'Completed';

PRINT '';
PRINT 'Records Processed: ' + CAST(@RecordsInserted AS VARCHAR) + ' loan officers';
PRINT '=== END MONTHLY LOAN OFFICER PERFORMANCE JOB ===';

GO