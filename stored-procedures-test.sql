-- =============================================
-- Test Scripts for Simple Stored Procedures
-- Workshop Migration Demo - Testing Basic Operations
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- Test Data Setup (if needed)
-- =============================================

-- Insert test branch if not exists
IF NOT EXISTS (SELECT 1 FROM Branches WHERE BranchCode = 'BR001')
BEGIN
    INSERT INTO Branches (BranchCode, BranchName, Address, City, State, ZipCode, Phone, Email)
    VALUES ('BR001', 'Main Branch', '123 Main St', 'New York', 'NY', '10001', '555-0001', 'main@loanapp.com');
END

-- Insert test loan officer if not exists
IF NOT EXISTS (SELECT 1 FROM LoanOfficers WHERE EmployeeId = 'LO001')
BEGIN
    DECLARE @BranchId INT = (SELECT BranchId FROM Branches WHERE BranchCode = 'BR001');
    INSERT INTO LoanOfficers (EmployeeId, FirstName, LastName, Email, Phone, BranchId, HireDate)
    VALUES ('LO001', 'John', 'Smith', 'john.smith@loanapp.com', '555-0101', @BranchId, '2020-01-15');
END

-- Insert test customer if not exists
IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerNumber = 'CUST202401')
BEGIN
    INSERT INTO Customers (
        CustomerNumber, FirstName, LastName, DateOfBirth, SSN, Email, Phone,
        Address, City, State, ZipCode, MonthlyIncome, EmploymentStatus, EmployerName, YearsEmployed
    )
    VALUES (
        'CUST202401', 'Jane', 'Doe', '1985-06-15', '123-45-6789', 'jane.doe@email.com', '555-0201',
        '456 Oak Ave', 'New York', 'NY', '10002', 5000.00, 'Employed', 'Tech Corp', 5
    );
END

-- =============================================
-- Test SP1: sp_CreateLoanApplication
-- =============================================

PRINT '=== Testing SP1: sp_CreateLoanApplication ===';

DECLARE @CustomerId INT = (SELECT CustomerId FROM Customers WHERE CustomerNumber = 'CUST202401');
DECLARE @LoanOfficerId INT = (SELECT LoanOfficerId FROM LoanOfficers WHERE EmployeeId = 'LO001');
DECLARE @BranchId INT = (SELECT BranchId FROM Branches WHERE BranchCode = 'BR001');
DECLARE @ApplicationNumber NVARCHAR(20);
DECLARE @ApplicationId INT;

-- Test successful application creation
EXEC sp_CreateLoanApplication
    @CustomerId = @CustomerId,
    @LoanOfficerId = @LoanOfficerId,
    @BranchId = @BranchId,
    @RequestedAmount = 25000.00,
    @LoanPurpose = 'Home Improvement',
    @ApplicationNumber = @ApplicationNumber OUTPUT,
    @ApplicationId = @ApplicationId OUTPUT;

PRINT 'Test 1 - Successful Creation:';
PRINT 'Application Number: ' + ISNULL(@ApplicationNumber, 'NULL');
PRINT 'Application ID: ' + CAST(ISNULL(@ApplicationId, 0) AS NVARCHAR);

-- Test validation error (invalid amount)
BEGIN TRY
    EXEC sp_CreateLoanApplication
        @CustomerId = @CustomerId,
        @LoanOfficerId = @LoanOfficerId,
        @BranchId = @BranchId,
        @RequestedAmount = -1000.00,
        @LoanPurpose = 'Invalid Amount Test',
        @ApplicationNumber = @ApplicationNumber OUTPUT,
        @ApplicationId = @ApplicationId OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Test 2 - Validation Error (Expected): ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =============================================
-- Test SP2: sp_GetCustomerLoanHistory
-- =============================================

PRINT '=== Testing SP2: sp_GetCustomerLoanHistory ===';

-- Test successful query
EXEC sp_GetCustomerLoanHistory
    @CustomerId = @CustomerId,
    @IncludePayments = 1;

PRINT 'Test 1 - Customer loan history retrieved successfully';

-- Test with non-existent customer
BEGIN TRY
    EXEC sp_GetCustomerLoanHistory
        @CustomerId = 99999,
        @IncludePayments = 0;
END TRY
BEGIN CATCH
    PRINT 'Test 2 - Invalid Customer Error (Expected): ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =============================================
-- Test SP3: sp_UpdateApplicationStatus
-- =============================================

PRINT '=== Testing SP3: sp_UpdateApplicationStatus ===';

-- Get the application ID we just created
DECLARE @TestApplicationId INT = (
    SELECT TOP 1 ApplicationId 
    FROM Applications 
    WHERE CustomerId = @CustomerId 
    ORDER BY CreatedDate DESC
);

-- Test successful status update
EXEC sp_UpdateApplicationStatus
    @ApplicationId = @TestApplicationId,
    @NewStatus = 'Under Review',
    @DecisionReason = 'Initial review started',
    @UpdatedBy = 'TestUser';

PRINT 'Test 1 - Status updated to Under Review';

-- Test another status update
EXEC sp_UpdateApplicationStatus
    @ApplicationId = @TestApplicationId,
    @NewStatus = 'Approved',
    @DecisionReason = 'Customer meets all criteria',
    @UpdatedBy = 'TestUser';

PRINT 'Test 2 - Status updated to Approved';

-- Test invalid status transition
BEGIN TRY
    EXEC sp_UpdateApplicationStatus
        @ApplicationId = @TestApplicationId,
        @NewStatus = 'Submitted',
        @DecisionReason = 'Invalid transition test',
        @UpdatedBy = 'TestUser';
END TRY
BEGIN CATCH
    PRINT 'Test 3 - Invalid Transition Error (Expected): ' + ERROR_MESSAGE();
END CATCH

-- Test with non-existent application
BEGIN TRY
    EXEC sp_UpdateApplicationStatus
        @ApplicationId = 99999,
        @NewStatus = 'Under Review',
        @UpdatedBy = 'TestUser';
END TRY
BEGIN CATCH
    PRINT 'Test 4 - Application Not Found Error (Expected): ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =============================================
-- Verify Results
-- =============================================

PRINT '=== Verification Queries ===';

-- Check created applications
SELECT 
    'Created Applications' AS QueryType,
    ApplicationId,
    ApplicationNumber,
    RequestedAmount,
    ApplicationStatus,
    SubmissionDate
FROM Applications 
WHERE CustomerId = @CustomerId
ORDER BY CreatedDate DESC;

-- Check integration logs
SELECT 
    'Integration Logs' AS QueryType,
    LogType,
    ServiceName,
    StatusCode,
    IsSuccess,
    LogTimestamp
FROM IntegrationLogs 
WHERE ApplicationId = @TestApplicationId OR ApplicationId IS NULL
ORDER BY LogTimestamp DESC;

-- Check audit trail
SELECT 
    'Audit Trail' AS QueryType,
    TableName,
    RecordId,
    Action,
    ChangedBy,
    ChangeDate
FROM AuditTrail 
WHERE TableName = 'Applications' AND RecordId = @TestApplicationId
ORDER BY ChangeDate DESC;

PRINT '';
PRINT '=== Simple Stored Procedures Testing Complete ===';
PRINT 'All procedures tested with both success and error scenarios';
PRINT 'Ready for complex stored procedure development (Step 1.5)';
GO