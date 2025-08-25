-- =============================================
-- Weekly Batch Job 3: Customer Analytics Report
-- Runs weekly to populate WeeklyCustomerAnalytics table
-- Analyzes customer segments, payment behavior, and risk profiles
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Weekly Customer Analytics Batch Job
-- =============================================

DECLARE @ReportWeek DATE = DATEADD(DAY, -(DATEPART(WEEKDAY, GETDATE()) - 2), CAST(DATEADD(WEEK, -1, GETDATE()) AS DATE)); -- Monday of previous week
DECLARE @WeekEnd DATE = DATEADD(DAY, 6, @ReportWeek); -- Sunday of previous week
DECLARE @ExecutionId BIGINT;
DECLARE @RecordsProcessed INT = 0;

-- Start job logging
EXEC sp_StartBatchJob 
    @JobName = 'Weekly Customer Analytics',
    @JobType = 'Weekly',
    @ReportPeriod = @ReportWeek,
    @ExecutionId = @ExecutionId OUTPUT;

PRINT '=== WEEKLY CUSTOMER ANALYTICS BATCH JOB ===';
PRINT 'Processing Week: ' + CAST(@ReportWeek AS VARCHAR) + ' to ' + CAST(@WeekEnd AS VARCHAR);
PRINT 'ExecutionId: ' + CAST(@ExecutionId AS VARCHAR);
PRINT '';

-- Clear existing data for this week (if re-running)
DELETE FROM WeeklyCustomerAnalytics WHERE ReportWeek = @ReportWeek;
PRINT 'Cleared existing data for week of ' + CAST(@ReportWeek AS VARCHAR);

-- Customer Segmentation Analysis
WITH CustomerSegments AS (
    SELECT 
        c.CustomerId,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.MonthlyIncome,
        c.EmploymentStatus,
        CASE 
            WHEN c.MonthlyIncome >= 100000 THEN 'High Income (100K+)'
            WHEN c.MonthlyIncome >= 75000 THEN 'Upper Middle (75K-100K)'
            WHEN c.MonthlyIncome >= 50000 THEN 'Middle Income (50K-75K)'
            WHEN c.MonthlyIncome >= 35000 THEN 'Lower Middle (35K-50K)'
            ELSE 'Low Income (<35K)'
        END AS IncomeSegment,
        CASE 
            WHEN DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 65 THEN 'Senior (65+)'
            WHEN DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 45 THEN 'Middle Age (45-64)'
            WHEN DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 30 THEN 'Young Adult (30-44)'
            ELSE 'Young (18-29)'
        END AS AgeSegment,
        -- Combine income and age for detailed segmentation
        CASE 
            WHEN c.MonthlyIncome >= 75000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) BETWEEN 30 AND 55 THEN 'Prime Customers'
            WHEN c.MonthlyIncome >= 50000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 45 THEN 'Established Professionals'
            WHEN c.MonthlyIncome < 35000 OR DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) < 25 THEN 'High Risk'
            WHEN c.EmploymentStatus = 'Self-Employed' THEN 'Self-Employed'
            WHEN c.EmploymentStatus = 'Retired' THEN 'Retirees'
            ELSE 'Standard Customers'
        END AS CustomerSegment
    FROM Customers c
    WHERE c.IsActive = 1
),
ApplicationData AS (
    SELECT 
        cs.*,
        COUNT(a.ApplicationId) AS TotalApplications,
        COUNT(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
        AVG(CAST(a.CreditScore AS FLOAT)) AS AvgCreditScore,
        AVG(a.RequestedAmount) AS AvgLoanAmount
    FROM CustomerSegments cs
    LEFT JOIN Applications a ON cs.CustomerId = a.CustomerId 
        AND a.SubmissionDate >= @ReportWeek 
        AND a.SubmissionDate <= @WeekEnd
        AND a.IsActive = 1
    GROUP BY cs.CustomerId, cs.CustomerName, cs.MonthlyIncome, cs.EmploymentStatus, 
             cs.IncomeSegment, cs.AgeSegment, cs.CustomerSegment
),
PaymentData AS (
    SELECT 
        ad.*,
        COUNT(p.PaymentId) AS TotalPayments,
        SUM(p.PaymentAmount) AS TotalPaymentAmount,
        AVG(p.PaymentAmount) AS AvgPaymentAmount,
        COUNT(CASE WHEN p.PaymentStatus = 'Failed' THEN 1 END) AS FailedPayments
    FROM ApplicationData ad
    LEFT JOIN Applications a ON ad.CustomerId = a.CustomerId AND a.IsActive = 1
    LEFT JOIN Loans l ON a.ApplicationId = l.ApplicationId
    LEFT JOIN Payments p ON l.LoanId = p.LoanId 
        AND p.PaymentDate >= @ReportWeek 
        AND p.PaymentDate <= @WeekEnd
    GROUP BY ad.CustomerId, ad.CustomerName, ad.MonthlyIncome, ad.EmploymentStatus,
             ad.IncomeSegment, ad.AgeSegment, ad.CustomerSegment, ad.TotalApplications,
             ad.ApprovedApplications, ad.AvgCreditScore, ad.AvgLoanAmount
),
SegmentSummary AS (
    SELECT 
        CustomerSegment,
        COUNT(DISTINCT CustomerId) AS CustomerCount,
        SUM(TotalApplications) AS TotalApplications,
        CASE 
            WHEN SUM(TotalApplications) > 0 
            THEN CAST(SUM(ApprovedApplications) * 100.0 / SUM(TotalApplications) AS DECIMAL(5,2))
            ELSE 0 
        END AS ApprovalRate,
        AVG(AvgCreditScore) AS AvgCreditScore,
        AVG(MonthlyIncome) AS AvgMonthlyIncome,
        AVG(AvgLoanAmount) AS AvgLoanAmount,
        ISNULL(SUM(TotalPaymentAmount), 0) AS TotalPaymentsMade,
        AVG(AvgPaymentAmount) AS AvgPaymentAmount,
        CASE 
            WHEN SUM(TotalPayments) > 0 
            THEN CAST(SUM(FailedPayments) * 100.0 / SUM(TotalPayments) AS DECIMAL(5,2))
            ELSE 0 
        END AS DefaultRate
    FROM PaymentData
    GROUP BY CustomerSegment
)
INSERT INTO WeeklyCustomerAnalytics (
    ReportWeek,
    CustomerSegment,
    CustomerCount,
    TotalApplications,
    ApprovalRate,
    AvgCreditScore,
    AvgMonthlyIncome,
    AvgLoanAmount,
    TotalPaymentsMade,
    AvgPaymentAmount,
    DefaultRate
)
SELECT 
    @ReportWeek,
    CustomerSegment,
    CustomerCount,
    TotalApplications,
    ApprovalRate,
    CAST(AvgCreditScore AS INT),
    AvgMonthlyIncome,
    AvgLoanAmount,
    TotalPaymentsMade,
    AvgPaymentAmount,
    DefaultRate
FROM SegmentSummary;

DECLARE @RecordsInserted INT = @@ROWCOUNT;
PRINT 'Inserted ' + CAST(@RecordsInserted AS VARCHAR) + ' customer segment analytics records.';

-- Display Customer Segment Analysis
PRINT '';
PRINT 'CUSTOMER SEGMENT ANALYSIS:';
PRINT '=========================';

SELECT 
    CustomerSegment,
    CustomerCount,
    TotalApplications,
    ApprovalRate,
    AvgCreditScore,
    FORMAT(AvgMonthlyIncome, 'C', 'en-US') AS AvgMonthlyIncome,
    FORMAT(AvgLoanAmount, 'C', 'en-US') AS AvgLoanAmount,
    FORMAT(TotalPaymentsMade, 'C', 'en-US') AS TotalPaymentsMade,
    FORMAT(AvgPaymentAmount, 'C', 'en-US') AS AvgPaymentAmount,
    DefaultRate
FROM WeeklyCustomerAnalytics 
WHERE ReportWeek = @ReportWeek
ORDER BY CustomerCount DESC;

-- Risk Analysis by Segment
PRINT '';
PRINT 'RISK ANALYSIS BY SEGMENT:';
PRINT '========================';

SELECT 
    CustomerSegment,
    CASE 
        WHEN DefaultRate >= 10 THEN 'High Risk'
        WHEN DefaultRate >= 5 THEN 'Medium Risk'
        WHEN DefaultRate >= 2 THEN 'Low Risk'
        ELSE 'Very Low Risk'
    END AS RiskLevel,
    DefaultRate,
    ApprovalRate,
    AvgCreditScore,
    CustomerCount,
    CASE 
        WHEN DefaultRate >= 10 THEN 'Tighten approval criteria'
        WHEN DefaultRate >= 5 THEN 'Enhanced monitoring required'
        WHEN ApprovalRate < 50 THEN 'Review approval process'
        ELSE 'Continue current strategy'
    END AS Recommendation
FROM WeeklyCustomerAnalytics 
WHERE ReportWeek = @ReportWeek
ORDER BY DefaultRate DESC;

-- Top Performing Segments
PRINT '';
PRINT 'TOP PERFORMING SEGMENTS (High Volume + Low Risk):';
PRINT '===============================================';

SELECT 
    CustomerSegment,
    CustomerCount,
    TotalApplications,
    ApprovalRate,
    DefaultRate,
    FORMAT(TotalPaymentsMade, 'C', 'en-US') AS TotalPaymentsMade,
    CAST((ApprovalRate * 0.4) + ((100 - DefaultRate) * 0.4) + (CASE WHEN CustomerCount >= 100 THEN 20 ELSE CustomerCount * 0.2 END) AS DECIMAL(5,2)) AS PerformanceScore
FROM WeeklyCustomerAnalytics 
WHERE ReportWeek = @ReportWeek
    AND CustomerCount >= 10  -- Minimum volume threshold
ORDER BY PerformanceScore DESC;

-- Week-over-Week Comparison
PRINT '';
PRINT 'WEEK-OVER-WEEK COMPARISON:';
PRINT '==========================';

WITH CurrentWeek AS (
    SELECT * FROM WeeklyCustomerAnalytics WHERE ReportWeek = @ReportWeek
),
PreviousWeek AS (
    SELECT * FROM WeeklyCustomerAnalytics WHERE ReportWeek = DATEADD(WEEK, -1, @ReportWeek)
)
SELECT 
    cw.CustomerSegment,
    cw.CustomerCount AS CurrentCustomers,
    ISNULL(pw.CustomerCount, 0) AS PreviousCustomers,
    cw.CustomerCount - ISNULL(pw.CustomerCount, 0) AS CustomerChange,
    cw.ApprovalRate AS CurrentApprovalRate,
    ISNULL(pw.ApprovalRate, 0) AS PreviousApprovalRate,
    cw.ApprovalRate - ISNULL(pw.ApprovalRate, 0) AS ApprovalRateChange,
    CASE 
        WHEN cw.ApprovalRate > ISNULL(pw.ApprovalRate, 0) THEN 'Improving'
        WHEN cw.ApprovalRate < ISNULL(pw.ApprovalRate, 0) THEN 'Declining'
        ELSE 'Stable'
    END AS Trend
FROM CurrentWeek cw
LEFT JOIN PreviousWeek pw ON cw.CustomerSegment = pw.CustomerSegment
ORDER BY ABS(cw.ApprovalRate - ISNULL(pw.ApprovalRate, 0)) DESC;

-- Customer Acquisition Analysis
PRINT '';
PRINT 'NEW CUSTOMER ACQUISITION (This Week):';
PRINT '====================================';

SELECT 
    CASE 
        WHEN c.MonthlyIncome >= 75000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) BETWEEN 30 AND 55 THEN 'Prime Customers'
        WHEN c.MonthlyIncome >= 50000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 45 THEN 'Established Professionals'
        WHEN c.MonthlyIncome < 35000 OR DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) < 25 THEN 'High Risk'
        WHEN c.EmploymentStatus = 'Self-Employed' THEN 'Self-Employed'
        WHEN c.EmploymentStatus = 'Retired' THEN 'Retirees'
        ELSE 'Standard Customers'
    END AS CustomerSegment,
    COUNT(*) AS NewCustomers,
    AVG(c.MonthlyIncome) AS AvgIncome,
    COUNT(a.ApplicationId) AS ImmediateApplications,
    CASE 
        WHEN COUNT(*) > 0 
        THEN CAST(COUNT(a.ApplicationId) * 100.0 / COUNT(*) AS DECIMAL(5,2))
        ELSE 0 
    END AS ApplicationRate
FROM Customers c
LEFT JOIN Applications a ON c.CustomerId = a.CustomerId 
    AND a.SubmissionDate >= @ReportWeek 
    AND a.SubmissionDate <= @WeekEnd
WHERE c.CreatedDate >= @ReportWeek 
    AND c.CreatedDate <= @WeekEnd
    AND c.IsActive = 1
GROUP BY 
    CASE 
        WHEN c.MonthlyIncome >= 75000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) BETWEEN 30 AND 55 THEN 'Prime Customers'
        WHEN c.MonthlyIncome >= 50000 AND DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) >= 45 THEN 'Established Professionals'
        WHEN c.MonthlyIncome < 35000 OR DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) < 25 THEN 'High Risk'
        WHEN c.EmploymentStatus = 'Self-Employed' THEN 'Self-Employed'
        WHEN c.EmploymentStatus = 'Retired' THEN 'Retirees'
        ELSE 'Standard Customers'
    END
ORDER BY NewCustomers DESC;

-- Complete job logging
SET @RecordsProcessed = (SELECT COUNT(*) FROM Customers WHERE IsActive = 1);

EXEC sp_CompleteBatchJob 
    @ExecutionId = @ExecutionId,
    @RecordsProcessed = @RecordsProcessed,
    @RecordsInserted = @RecordsInserted,
    @Status = 'Completed';

PRINT '';
PRINT 'Records Processed: ' + CAST(@RecordsInserted AS VARCHAR) + ' customer segments';
PRINT '=== END WEEKLY CUSTOMER ANALYTICS JOB ===';

GO