-- =============================================
-- Report 1: Application Performance Dashboard
-- Analyzes loan application volume, approval rates, and processing times
-- Target Table: Applications (with joins to Customers, LoanOfficers, Branches)
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Application Performance Dashboard Report
-- =============================================

PRINT '=== APPLICATION PERFORMANCE DASHBOARD ===';
PRINT 'Generated on: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '';

-- =============================================
-- Section 1: Monthly Application Volume Trends
-- =============================================
PRINT '1. MONTHLY APPLICATION VOLUME TRENDS (Last 12 Months)';
PRINT '================================================================';

SELECT 
    YEAR(SubmissionDate) AS Year,
    MONTH(SubmissionDate) AS Month,
    DATENAME(MONTH, SubmissionDate) + ' ' + CAST(YEAR(SubmissionDate) AS VARCHAR) AS MonthYear,
    COUNT(*) AS TotalApplications,
    COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
    COUNT(CASE WHEN ApplicationStatus = 'Rejected' THEN 1 END) AS RejectedApplications,
    COUNT(CASE WHEN ApplicationStatus IN ('Submitted', 'Under Review') THEN 1 END) AS PendingApplications,
    CAST(COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS ApprovalRate,
    SUM(RequestedAmount) AS TotalRequestedAmount,
    AVG(RequestedAmount) AS AvgRequestedAmount
FROM Applications
WHERE SubmissionDate >= DATEADD(MONTH, -12, GETDATE())
    AND IsActive = 1
GROUP BY YEAR(SubmissionDate), MONTH(SubmissionDate), DATENAME(MONTH, SubmissionDate)
ORDER BY Year DESC, Month DESC;

PRINT '';

-- =============================================
-- Section 2: Application Status Summary
-- =============================================
PRINT '2. APPLICATION STATUS SUMMARY (Current)';
PRINT '================================================================';

SELECT 
    ApplicationStatus,
    COUNT(*) AS ApplicationCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage,
    SUM(RequestedAmount) AS TotalRequestedAmount,
    AVG(RequestedAmount) AS AvgRequestedAmount,
    MIN(RequestedAmount) AS MinRequestedAmount,
    MAX(RequestedAmount) AS MaxRequestedAmount
FROM Applications
WHERE IsActive = 1
GROUP BY ApplicationStatus
ORDER BY ApplicationCount DESC;

PRINT '';

-- =============================================
-- Section 3: Processing Time Analysis
-- =============================================
PRINT '3. APPLICATION PROCESSING TIME ANALYSIS';
PRINT '================================================================';

SELECT 
    ApplicationStatus,
    COUNT(*) AS ApplicationCount,
    AVG(CASE 
        WHEN ReviewDate IS NOT NULL 
        THEN DATEDIFF(HOUR, SubmissionDate, ReviewDate) 
        END) AS AvgHoursToReview,
    AVG(CASE 
        WHEN DecisionDate IS NOT NULL 
        THEN DATEDIFF(HOUR, SubmissionDate, DecisionDate) 
        END) AS AvgHoursToDecision,
    MIN(CASE 
        WHEN DecisionDate IS NOT NULL 
        THEN DATEDIFF(HOUR, SubmissionDate, DecisionDate) 
        END) AS MinHoursToDecision,
    MAX(CASE 
        WHEN DecisionDate IS NOT NULL 
        THEN DATEDIFF(HOUR, SubmissionDate, DecisionDate) 
        END) AS MaxHoursToDecision
FROM Applications
WHERE IsActive = 1
    AND SubmissionDate >= DATEADD(MONTH, -6, GETDATE())
GROUP BY ApplicationStatus
ORDER BY ApplicationCount DESC;

PRINT '';

-- =============================================
-- Section 4: Branch Performance Comparison
-- =============================================
PRINT '4. BRANCH PERFORMANCE COMPARISON (Last 6 Months)';
PRINT '================================================================';

SELECT 
    b.BranchCode,
    b.BranchName,
    b.City + ', ' + b.State AS Location,
    COUNT(a.ApplicationId) AS TotalApplications,
    COUNT(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
    CAST(COUNT(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(a.ApplicationId) AS DECIMAL(5,2)) AS ApprovalRate,
    SUM(a.RequestedAmount) AS TotalRequestedAmount,
    AVG(a.RequestedAmount) AS AvgRequestedAmount,
    AVG(CASE 
        WHEN a.DecisionDate IS NOT NULL 
        THEN DATEDIFF(HOUR, a.SubmissionDate, a.DecisionDate) 
        END) AS AvgProcessingHours
FROM Branches b
LEFT JOIN Applications a ON b.BranchId = a.BranchId 
    AND a.SubmissionDate >= DATEADD(MONTH, -6, GETDATE())
    AND a.IsActive = 1
WHERE b.IsActive = 1
GROUP BY b.BranchId, b.BranchCode, b.BranchName, b.City, b.State
HAVING COUNT(a.ApplicationId) > 0
ORDER BY ApprovalRate DESC, TotalApplications DESC;

PRINT '';

-- =============================================
-- Section 5: Credit Score Impact Analysis
-- =============================================
PRINT '5. CREDIT SCORE IMPACT ON APPROVAL RATES';
PRINT '================================================================';

SELECT 
    CASE 
        WHEN CreditScore >= 750 THEN '750+ (Excellent)'
        WHEN CreditScore >= 700 THEN '700-749 (Good)'
        WHEN CreditScore >= 650 THEN '650-699 (Fair)'
        WHEN CreditScore >= 600 THEN '600-649 (Poor)'
        WHEN CreditScore < 600 THEN 'Below 600 (Very Poor)'
        ELSE 'No Credit Score'
    END AS CreditScoreRange,
    COUNT(*) AS TotalApplications,
    COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
    CAST(COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS ApprovalRate,
    AVG(RequestedAmount) AS AvgRequestedAmount,
    AVG(CreditScore) AS AvgCreditScore
FROM Applications
WHERE IsActive = 1
    AND SubmissionDate >= DATEADD(MONTH, -12, GETDATE())
GROUP BY 
    CASE 
        WHEN CreditScore >= 750 THEN '750+ (Excellent)'
        WHEN CreditScore >= 700 THEN '700-749 (Good)'
        WHEN CreditScore >= 650 THEN '650-699 (Fair)'
        WHEN CreditScore >= 600 THEN '600-649 (Poor)'
        WHEN CreditScore < 600 THEN 'Below 600 (Very Poor)'
        ELSE 'No Credit Score'
    END
ORDER BY AvgCreditScore DESC;

PRINT '';

-- =============================================
-- Section 6: Loan Purpose Analysis
-- =============================================
PRINT '6. LOAN PURPOSE ANALYSIS (Last 6 Months)';
PRINT '================================================================';

SELECT 
    LoanPurpose,
    COUNT(*) AS TotalApplications,
    COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
    CAST(COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS ApprovalRate,
    SUM(RequestedAmount) AS TotalRequestedAmount,
    AVG(RequestedAmount) AS AvgRequestedAmount,
    AVG(DSRRatio) AS AvgDSRRatio
FROM Applications
WHERE IsActive = 1
    AND SubmissionDate >= DATEADD(MONTH, -6, GETDATE())
GROUP BY LoanPurpose
ORDER BY TotalApplications DESC;

PRINT '';

-- =============================================
-- Section 7: High-Value Applications Alert
-- =============================================
PRINT '7. HIGH-VALUE APPLICATIONS REQUIRING ATTENTION';
PRINT '================================================================';

SELECT 
    a.ApplicationNumber,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    a.RequestedAmount,
    a.ApplicationStatus,
    a.SubmissionDate,
    DATEDIFF(DAY, a.SubmissionDate, GETDATE()) AS DaysInProcess,
    lo.FirstName + ' ' + lo.LastName AS LoanOfficer,
    b.BranchName,
    a.CreditScore,
    a.DSRRatio
FROM Applications a
INNER JOIN Customers c ON a.CustomerId = c.CustomerId
INNER JOIN LoanOfficers lo ON a.LoanOfficerId = lo.LoanOfficerId
INNER JOIN Branches b ON a.BranchId = b.BranchId
WHERE a.IsActive = 1
    AND a.RequestedAmount >= 100000  -- High-value threshold
    AND a.ApplicationStatus IN ('Submitted', 'Under Review')
    AND a.SubmissionDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY a.RequestedAmount DESC, a.SubmissionDate ASC;

PRINT '';

-- =============================================
-- Section 8: Performance Summary KPIs
-- =============================================
PRINT '8. KEY PERFORMANCE INDICATORS (SUMMARY)';
PRINT '================================================================';

WITH MonthlyStats AS (
    SELECT 
        COUNT(*) AS TotalApplications,
        COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS ApprovedApplications,
        AVG(CASE 
            WHEN DecisionDate IS NOT NULL 
            THEN DATEDIFF(HOUR, SubmissionDate, DecisionDate) 
            END) AS AvgProcessingHours,
        SUM(RequestedAmount) AS TotalRequestedAmount
    FROM Applications
    WHERE IsActive = 1
        AND SubmissionDate >= DATEADD(MONTH, -1, GETDATE())
),
PreviousMonthStats AS (
    SELECT 
        COUNT(*) AS PrevTotalApplications,
        COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) AS PrevApprovedApplications
    FROM Applications
    WHERE IsActive = 1
        AND SubmissionDate >= DATEADD(MONTH, -2, GETDATE())
        AND SubmissionDate < DATEADD(MONTH, -1, GETDATE())
)
SELECT 
    'Current Month Performance' AS Metric,
    ms.TotalApplications AS CurrentValue,
    pms.PrevTotalApplications AS PreviousValue,
    CASE 
        WHEN pms.PrevTotalApplications > 0 
        THEN CAST((ms.TotalApplications - pms.PrevTotalApplications) * 100.0 / pms.PrevTotalApplications AS DECIMAL(5,2))
        ELSE 0 
    END AS PercentChange,
    CAST(ms.ApprovedApplications * 100.0 / ms.TotalApplications AS DECIMAL(5,2)) AS ApprovalRate,
    ms.AvgProcessingHours AS AvgProcessingHours,
    ms.TotalRequestedAmount AS TotalRequestedAmount
FROM MonthlyStats ms
CROSS JOIN PreviousMonthStats pms;

PRINT '';
PRINT '=== END OF APPLICATION PERFORMANCE DASHBOARD ===';
PRINT 'Report completed at: ' + CONVERT(VARCHAR, GETDATE(), 120);

GO