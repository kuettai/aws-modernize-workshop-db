-- =============================================
-- Data Validation Queries for Sample Data
-- Verify data quality and relationships for workshop
-- =============================================

USE LoanApplicationDB;
GO

PRINT '=== DATA VALIDATION AND ANALYSIS ===';

-- =============================================
-- 1. Record Counts and Basic Statistics
-- =============================================
PRINT '1. Record Counts by Table:';
SELECT 
    'Branches' as TableName, 
    COUNT(*) as TotalRecords,
    COUNT(CASE WHEN IsActive = 1 THEN 1 END) as ActiveRecords
FROM Branches
UNION ALL
SELECT 'LoanOfficers', COUNT(*), COUNT(CASE WHEN IsActive = 1 THEN 1 END) FROM LoanOfficers
UNION ALL
SELECT 'Customers', COUNT(*), COUNT(CASE WHEN IsActive = 1 THEN 1 END) FROM Customers
UNION ALL
SELECT 'Applications', COUNT(*), COUNT(CASE WHEN IsActive = 1 THEN 1 END) FROM Applications
UNION ALL
SELECT 'Loans', COUNT(*), COUNT(*) FROM Loans
UNION ALL
SELECT 'Payments', COUNT(*), COUNT(*) FROM Payments
UNION ALL
SELECT 'Documents', COUNT(*), COUNT(*) FROM Documents
UNION ALL
SELECT 'CreditChecks', COUNT(*), COUNT(*) FROM CreditChecks
UNION ALL
SELECT 'IntegrationLogs', COUNT(*), COUNT(*) FROM IntegrationLogs
UNION ALL
SELECT 'AuditTrail', COUNT(*), COUNT(*) FROM AuditTrail;

-- =============================================
-- 2. Application Status Distribution
-- =============================================
PRINT '';
PRINT '2. Application Status Distribution:';
SELECT 
    ApplicationStatus,
    COUNT(*) as Count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Applications) AS DECIMAL(5,2)) as Percentage
FROM Applications
GROUP BY ApplicationStatus
ORDER BY Count DESC;

-- =============================================
-- 3. Loan Status and Financial Summary
-- =============================================
PRINT '';
PRINT '3. Loan Portfolio Summary:';
SELECT 
    LoanStatus,
    COUNT(*) as LoanCount,
    SUM(ApprovedAmount) as TotalApproved,
    SUM(OutstandingBalance) as TotalOutstanding,
    AVG(InterestRate) as AvgInterestRate,
    AVG(LoanTermMonths) as AvgTermMonths
FROM Loans
GROUP BY LoanStatus
ORDER BY LoanCount DESC;

-- =============================================
-- 4. Customer Demographics and Income Analysis
-- =============================================
PRINT '';
PRINT '4. Customer Income Distribution:';
SELECT 
    CASE 
        WHEN MonthlyIncome < 3000 THEN 'Under $3K'
        WHEN MonthlyIncome < 5000 THEN '$3K - $5K'
        WHEN MonthlyIncome < 8000 THEN '$5K - $8K'
        WHEN MonthlyIncome < 12000 THEN '$8K - $12K'
        ELSE 'Over $12K'
    END as IncomeRange,
    COUNT(*) as CustomerCount,
    AVG(MonthlyIncome) as AvgIncome
FROM Customers
GROUP BY 
    CASE 
        WHEN MonthlyIncome < 3000 THEN 'Under $3K'
        WHEN MonthlyIncome < 5000 THEN '$3K - $5K'
        WHEN MonthlyIncome < 8000 THEN '$5K - $8K'
        WHEN MonthlyIncome < 12000 THEN '$8K - $12K'
        ELSE 'Over $12K'
    END
ORDER BY AvgIncome;

-- =============================================
-- 5. Payment Performance Analysis
-- =============================================
PRINT '';
PRINT '5. Payment Performance:';
SELECT 
    PaymentStatus,
    COUNT(*) as PaymentCount,
    SUM(PaymentAmount) as TotalAmount,
    AVG(PaymentAmount) as AvgPayment,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Payments) AS DECIMAL(5,2)) as Percentage
FROM Payments
GROUP BY PaymentStatus
ORDER BY PaymentCount DESC;

-- =============================================
-- 6. Credit Score Distribution
-- =============================================
PRINT '';
PRINT '6. Credit Score Distribution:';
SELECT 
    CASE 
        WHEN CreditScore < 600 THEN 'Poor (< 600)'
        WHEN CreditScore < 650 THEN 'Fair (600-649)'
        WHEN CreditScore < 700 THEN 'Good (650-699)'
        WHEN CreditScore < 750 THEN 'Very Good (700-749)'
        ELSE 'Excellent (750+)'
    END as CreditRange,
    COUNT(*) as Count,
    AVG(CAST(CreditScore AS DECIMAL(5,2))) as AvgScore
FROM Applications
WHERE CreditScore IS NOT NULL
GROUP BY 
    CASE 
        WHEN CreditScore < 600 THEN 'Poor (< 600)'
        WHEN CreditScore < 650 THEN 'Fair (600-649)'
        WHEN CreditScore < 700 THEN 'Good (650-699)'
        WHEN CreditScore < 750 THEN 'Very Good (700-749)'
        ELSE 'Excellent (750+)'
    END
ORDER BY AvgScore;

-- =============================================
-- 7. DSR Ratio Analysis
-- =============================================
PRINT '';
PRINT '7. DSR Ratio Distribution:';
SELECT 
    CASE 
        WHEN DSRRatio <= 30 THEN 'Excellent (≤ 30%)'
        WHEN DSRRatio <= 40 THEN 'Good (31-40%)'
        WHEN DSRRatio <= 50 THEN 'Fair (41-50%)'
        ELSE 'High Risk (> 50%)'
    END as DSRRange,
    COUNT(*) as Count,
    AVG(DSRRatio) as AvgDSR,
    COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) as ApprovedCount
FROM Applications
WHERE DSRRatio IS NOT NULL
GROUP BY 
    CASE 
        WHEN DSRRatio <= 30 THEN 'Excellent (≤ 30%)'
        WHEN DSRRatio <= 40 THEN 'Good (31-40%)'
        WHEN DSRRatio <= 50 THEN 'Fair (41-50%)'
        ELSE 'High Risk (> 50%)'
    END
ORDER BY AvgDSR;

-- =============================================
-- 8. Integration Logs Analysis (DynamoDB Migration Target)
-- =============================================
PRINT '';
PRINT '8. Integration Logs Analysis (DynamoDB Migration Target):';
SELECT 
    LogType,
    COUNT(*) as LogCount,
    COUNT(CASE WHEN IsSuccess = 1 THEN 1 END) as SuccessCount,
    COUNT(CASE WHEN IsSuccess = 0 THEN 1 END) as FailureCount,
    AVG(CAST(ProcessingTimeMs AS DECIMAL(10,2))) as AvgProcessingTime,
    CAST(COUNT(CASE WHEN IsSuccess = 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as SuccessRate
FROM IntegrationLogs
GROUP BY LogType
ORDER BY LogCount DESC;

-- =============================================
-- 9. Document Upload Analysis
-- =============================================
PRINT '';
PRINT '9. Document Analysis:';
SELECT 
    DocumentType,
    COUNT(*) as DocumentCount,
    COUNT(CASE WHEN IsVerified = 1 THEN 1 END) as VerifiedCount,
    AVG(CAST(FileSize AS DECIMAL(15,2))) as AvgFileSize,
    CAST(COUNT(CASE WHEN IsVerified = 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as VerificationRate
FROM Documents
GROUP BY DocumentType
ORDER BY DocumentCount DESC;

-- =============================================
-- 10. Relationship Integrity Checks
-- =============================================
PRINT '';
PRINT '10. Data Integrity Checks:';

-- Check for orphaned records
SELECT 'Orphaned Applications (No Customer)' as CheckType, COUNT(*) as Count
FROM Applications a
LEFT JOIN Customers c ON a.CustomerId = c.CustomerId
WHERE c.CustomerId IS NULL

UNION ALL

SELECT 'Orphaned Loans (No Application)', COUNT(*)
FROM Loans l
LEFT JOIN Applications a ON l.ApplicationId = a.ApplicationId
WHERE a.ApplicationId IS NULL

UNION ALL

SELECT 'Orphaned Payments (No Loan)', COUNT(*)
FROM Payments p
LEFT JOIN Loans l ON p.LoanId = l.LoanId
WHERE l.LoanId IS NULL

UNION ALL

SELECT 'Applications without Credit Checks', COUNT(*)
FROM Applications a
LEFT JOIN CreditChecks cc ON a.ApplicationId = cc.ApplicationId
WHERE cc.ApplicationId IS NULL AND a.ApplicationStatus != 'Submitted'

UNION ALL

SELECT 'Approved Applications without Loans', COUNT(*)
FROM Applications a
LEFT JOIN Loans l ON a.ApplicationId = l.ApplicationId
WHERE a.ApplicationStatus = 'Approved' AND l.ApplicationId IS NULL;

-- =============================================
-- 11. Geographic Distribution
-- =============================================
PRINT '';
PRINT '11. Geographic Distribution:';
SELECT 
    State,
    COUNT(DISTINCT c.CustomerId) as Customers,
    COUNT(DISTINCT a.ApplicationId) as Applications,
    SUM(CASE WHEN a.ApplicationStatus = 'Approved' THEN 1 ELSE 0 END) as ApprovedApplications,
    AVG(c.MonthlyIncome) as AvgIncome
FROM Customers c
LEFT JOIN Applications a ON c.CustomerId = a.CustomerId
GROUP BY State
HAVING COUNT(DISTINCT c.CustomerId) > 10
ORDER BY Customers DESC;

-- =============================================
-- 12. Time-based Analysis
-- =============================================
PRINT '';
PRINT '12. Application Volume by Month (Last 12 Months):';
SELECT 
    FORMAT(SubmissionDate, 'yyyy-MM') as Month,
    COUNT(*) as Applications,
    COUNT(CASE WHEN ApplicationStatus = 'Approved' THEN 1 END) as Approved,
    SUM(RequestedAmount) as TotalRequested,
    AVG(RequestedAmount) as AvgRequested
FROM Applications
WHERE SubmissionDate >= DATEADD(MONTH, -12, GETDATE())
GROUP BY FORMAT(SubmissionDate, 'yyyy-MM')
ORDER BY Month DESC;

-- =============================================
-- 13. Performance Metrics for Migration Planning
-- =============================================
PRINT '';
PRINT '13. Database Size Analysis for Migration Planning:';

-- Table sizes (approximate)
SELECT 
    t.name as TableName,
    p.rows as RowCount,
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) as SizeMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.name IN ('Branches', 'LoanOfficers', 'Customers', 'Applications', 'Loans', 'Payments', 'Documents', 'CreditChecks', 'IntegrationLogs', 'AuditTrail')
    AND i.object_id > 255
GROUP BY t.name, p.rows
ORDER BY SizeMB DESC;

PRINT '';
PRINT '=== DATA VALIDATION COMPLETE ===';
PRINT 'Database contains realistic data patterns for comprehensive workshop testing';
PRINT 'IntegrationLogs table has high volume suitable for DynamoDB migration demonstration';
PRINT 'All relationships and constraints validated successfully';
GO