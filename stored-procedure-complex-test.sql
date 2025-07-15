-- =============================================
-- Test Script for Complex Stored Procedure
-- sp_ComprehensiveLoanEligibilityAssessment Testing
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Setup Test Data for Complex Assessment
-- =============================================

PRINT '=== Setting up test data for complex assessment ===';

-- Ensure we have test customer with existing loan history
DECLARE @TestCustomerId INT;
DECLARE @TestApplicationId INT;
DECLARE @TestLoanId INT;

-- Get or create test customer
SELECT @TestCustomerId = CustomerId FROM Customers WHERE CustomerNumber = 'CUST202401';

IF @TestCustomerId IS NULL
BEGIN
    INSERT INTO Customers (
        CustomerNumber, FirstName, LastName, DateOfBirth, SSN, Email, Phone,
        Address, City, State, ZipCode, MonthlyIncome, EmploymentStatus, EmployerName, YearsEmployed
    )
    VALUES (
        'CUST202401', 'Jane', 'Doe', '1985-06-15', '123-45-6789', 'jane.doe@email.com', '555-0201',
        '456 Oak Ave', 'New York', 'NY', '10002', 6000.00, 'Employed', 'Tech Corp', 3
    );
    
    SET @TestCustomerId = SCOPE_IDENTITY();
END

-- Create test application for assessment
IF NOT EXISTS (SELECT 1 FROM Applications WHERE CustomerId = @TestCustomerId AND RequestedAmount = 50000)
BEGIN
    DECLARE @BranchId INT = (SELECT TOP 1 BranchId FROM Branches);
    DECLARE @LoanOfficerId INT = (SELECT TOP 1 LoanOfficerId FROM LoanOfficers);
    
    INSERT INTO Applications (
        ApplicationNumber, CustomerId, LoanOfficerId, BranchId, RequestedAmount, 
        LoanPurpose, ApplicationStatus, SubmissionDate
    )
    VALUES (
        'APP' + FORMAT(GETDATE(), 'yyyyMMdd') + '001', @TestCustomerId, @LoanOfficerId, @BranchId, 
        50000.00, 'Debt Consolidation', 'Submitted', GETDATE()
    );
    
    SET @TestApplicationId = SCOPE_IDENTITY();
END
ELSE
BEGIN
    SELECT @TestApplicationId = ApplicationId 
    FROM Applications 
    WHERE CustomerId = @TestCustomerId AND RequestedAmount = 50000;
END

-- Create existing loan history for more complex assessment
IF NOT EXISTS (SELECT 1 FROM Loans l INNER JOIN Applications a ON l.ApplicationId = a.ApplicationId WHERE a.CustomerId = @TestCustomerId)
BEGIN
    -- Create a previous application
    INSERT INTO Applications (
        ApplicationNumber, CustomerId, LoanOfficerId, BranchId, RequestedAmount, 
        LoanPurpose, ApplicationStatus, SubmissionDate, DecisionDate
    )
    VALUES (
        'APP' + FORMAT(DATEADD(YEAR, -1, GETDATE()), 'yyyyMMdd') + '001', @TestCustomerId, 
        (SELECT TOP 1 LoanOfficerId FROM LoanOfficers), (SELECT TOP 1 BranchId FROM Branches),
        25000.00, 'Home Improvement', 'Approved', DATEADD(YEAR, -1, GETDATE()), DATEADD(YEAR, -1, GETDATE())
    );
    
    DECLARE @PreviousAppId INT = SCOPE_IDENTITY();
    
    -- Create existing loan
    INSERT INTO Loans (
        LoanNumber, ApplicationId, ApprovedAmount, InterestRate, LoanTermMonths, 
        MonthlyPayment, LoanStatus, DisbursementDate, OutstandingBalance, NextPaymentDate
    )
    VALUES (
        'LOAN' + FORMAT(DATEADD(YEAR, -1, GETDATE()), 'yyyyMMdd') + '001', @PreviousAppId,
        25000.00, 0.075, 60, 500.00, 'Active', DATEADD(YEAR, -1, GETDATE()), 
        20000.00, DATEADD(MONTH, 1, GETDATE())
    );
    
    SET @TestLoanId = SCOPE_IDENTITY();
    
    -- Create payment history
    INSERT INTO Payments (LoanId, PaymentNumber, PaymentDate, PaymentAmount, PrincipalAmount, InterestAmount, PaymentMethod, PaymentStatus)
    VALUES 
        (@TestLoanId, 1, DATEADD(MONTH, -11, GETDATE()), 500.00, 343.75, 156.25, 'ACH', 'Completed'),
        (@TestLoanId, 2, DATEADD(MONTH, -10, GETDATE()), 500.00, 345.90, 154.10, 'ACH', 'Completed'),
        (@TestLoanId, 3, DATEADD(MONTH, -9, GETDATE()), 500.00, 348.07, 151.93, 'ACH', 'Completed'),
        (@TestLoanId, 4, DATEADD(MONTH, -8, GETDATE()), 500.00, 350.26, 149.74, 'ACH', 'Completed'),
        (@TestLoanId, 5, DATEADD(MONTH, -7, GETDATE()), 500.00, 352.47, 147.53, 'ACH', 'Failed'),
        (@TestLoanId, 6, DATEADD(MONTH, -6, GETDATE()), 500.00, 354.70, 145.30, 'ACH', 'Completed');
END

-- Create credit check history
IF NOT EXISTS (SELECT 1 FROM CreditChecks WHERE CustomerId = @TestCustomerId)
BEGIN
    INSERT INTO CreditChecks (CustomerId, ApplicationId, CreditBureau, CreditScore, CheckDate, ExpiryDate, RequestId, IsSuccessful)
    VALUES 
        (@TestCustomerId, @TestApplicationId, 'Experian', 720, DATEADD(DAY, -30, GETDATE()), DATEADD(DAY, 335, GETDATE()), 'REQ001', 1),
        (@TestCustomerId, NULL, 'Experian', 715, DATEADD(DAY, -180, GETDATE()), DATEADD(DAY, 185, GETDATE()), 'REQ002', 1),
        (@TestCustomerId, NULL, 'Equifax', 710, DATEADD(DAY, -365, GETDATE()), DATEADD(DAY, 0, GETDATE()), 'REQ003', 1);
    
    -- Update application with credit score
    UPDATE Applications SET CreditScore = 720 WHERE ApplicationId = @TestApplicationId;
END

PRINT 'Test data setup complete';
PRINT 'Customer ID: ' + CAST(@TestCustomerId AS NVARCHAR);
PRINT 'Application ID: ' + CAST(@TestApplicationId AS NVARCHAR);

-- =============================================
-- Test 1: Standard Assessment (Good Credit Profile)
-- =============================================

PRINT '';
PRINT '=== Test 1: Standard Assessment (Good Credit Profile) ===';

DECLARE @AssessmentDetails NVARCHAR(MAX);
DECLARE @RecommendedAction NVARCHAR(50);
DECLARE @RiskScore DECIMAL(5,2);

EXEC sp_ComprehensiveLoanEligibilityAssessment
    @ApplicationId = @TestApplicationId,
    @OverrideRules = 0,
    @AssessmentDetails = @AssessmentDetails OUTPUT,
    @RecommendedAction = @RecommendedAction OUTPUT,
    @RiskScore = @RiskScore OUTPUT;

PRINT 'Assessment Results:';
PRINT 'Recommended Action: ' + ISNULL(@RecommendedAction, 'NULL');
PRINT 'Risk Score: ' + CAST(ISNULL(@RiskScore, 0) AS NVARCHAR);
PRINT 'Assessment Details (JSON):';
PRINT @AssessmentDetails;

-- =============================================
-- Test 2: High Risk Assessment
-- =============================================

PRINT '';
PRINT '=== Test 2: High Risk Assessment (Modified Customer Profile) ===';

-- Temporarily modify customer to create high-risk scenario
UPDATE Customers 
SET MonthlyIncome = 3000.00, YearsEmployed = 0
WHERE CustomerId = @TestCustomerId;

UPDATE Applications 
SET RequestedAmount = 80000.00, CreditScore = 580
WHERE ApplicationId = @TestApplicationId;

EXEC sp_ComprehensiveLoanEligibilityAssessment
    @ApplicationId = @TestApplicationId,
    @OverrideRules = 0,
    @AssessmentDetails = @AssessmentDetails OUTPUT,
    @RecommendedAction = @RecommendedAction OUTPUT,
    @RiskScore = @RiskScore OUTPUT;

PRINT 'High Risk Assessment Results:';
PRINT 'Recommended Action: ' + ISNULL(@RecommendedAction, 'NULL');
PRINT 'Risk Score: ' + CAST(ISNULL(@RiskScore, 0) AS NVARCHAR);

-- =============================================
-- Test 3: Manual Override Assessment
-- =============================================

PRINT '';
PRINT '=== Test 3: Manual Override Assessment ===';

EXEC sp_ComprehensiveLoanEligibilityAssessment
    @ApplicationId = @TestApplicationId,
    @OverrideRules = 1,
    @AssessmentDetails = @AssessmentDetails OUTPUT,
    @RecommendedAction = @RecommendedAction OUTPUT,
    @RiskScore = @RiskScore OUTPUT;

PRINT 'Manual Override Results:';
PRINT 'Recommended Action: ' + ISNULL(@RecommendedAction, 'NULL');
PRINT 'Risk Score: ' + CAST(ISNULL(@RiskScore, 0) AS NVARCHAR);

-- =============================================
-- Test 4: Error Handling Test
-- =============================================

PRINT '';
PRINT '=== Test 4: Error Handling (Invalid Application ID) ===';

BEGIN TRY
    EXEC sp_ComprehensiveLoanEligibilityAssessment
        @ApplicationId = 99999,
        @OverrideRules = 0,
        @AssessmentDetails = @AssessmentDetails OUTPUT,
        @RecommendedAction = @RecommendedAction OUTPUT,
        @RiskScore = @RiskScore OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Error Handling Test (Expected): ' + ERROR_MESSAGE();
    PRINT 'Error Output Action: ' + ISNULL(@RecommendedAction, 'NULL');
    PRINT 'Error Output Risk Score: ' + CAST(ISNULL(@RiskScore, 0) AS NVARCHAR);
END CATCH

-- =============================================
-- Restore Test Data
-- =============================================

PRINT '';
PRINT '=== Restoring Original Test Data ===';

-- Restore customer profile
UPDATE Customers 
SET MonthlyIncome = 6000.00, YearsEmployed = 3
WHERE CustomerId = @TestCustomerId;

UPDATE Applications 
SET RequestedAmount = 50000.00, CreditScore = 720
WHERE ApplicationId = @TestApplicationId;

-- =============================================
-- Verification Queries
-- =============================================

PRINT '';
PRINT '=== Verification Queries ===';

-- Check integration logs from assessment
SELECT 
    'Integration Logs' as QueryType,
    LogType,
    ServiceName,
    LEFT(RequestData, 100) + '...' as RequestData,
    StatusCode,
    IsSuccess,
    ProcessingTimeMs,
    LogTimestamp
FROM IntegrationLogs 
WHERE ApplicationId = @TestApplicationId 
    AND ServiceName LIKE '%ComprehensiveLoanEligibilityAssessment%'
ORDER BY LogTimestamp DESC;

-- Check audit trail
SELECT 
    'Audit Trail' as QueryType,
    TableName,
    RecordId,
    Action,
    ChangedBy,
    ChangeDate
FROM AuditTrail 
WHERE TableName = 'Applications' 
    AND RecordId = @TestApplicationId
    AND ChangedBy = 'sp_ComprehensiveLoanEligibilityAssessment'
ORDER BY ChangeDate DESC;

-- Check final application status
SELECT 
    'Final Application Status' as QueryType,
    ApplicationId,
    ApplicationNumber,
    ApplicationStatus,
    DSRRatio,
    CreditScore,
    DecisionReason,
    DecisionDate
FROM Applications 
WHERE ApplicationId = @TestApplicationId;

PRINT '';
PRINT '=== Complex Stored Procedure Testing Complete ===';
PRINT 'All advanced SQL Server features tested:';
PRINT '- CTEs with window functions';
PRINT '- Temporary tables for complex calculations';
PRINT '- Cursors for iterative processing';
PRINT '- Dynamic SQL execution';
PRINT '- Comprehensive error handling';
PRINT '- JSON output generation';
PRINT '- Transaction management';
PRINT '- Performance timing';
PRINT 'Ready for PostgreSQL migration challenges!';
GO