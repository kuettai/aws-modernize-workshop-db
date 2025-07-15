-- =============================================
-- Simple Stored Procedures for Loan Application System
-- 3 Basic CRUD Operations for Workshop Migration Demo
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- SP1: CreateLoanApplication
-- Purpose: Insert new loan application with validation
-- =============================================
CREATE OR ALTER PROCEDURE sp_CreateLoanApplication
    @CustomerId INT,
    @LoanOfficerId INT,
    @BranchId INT,
    @RequestedAmount DECIMAL(12,2),
    @LoanPurpose NVARCHAR(100),
    @ApplicationNumber NVARCHAR(20) OUTPUT,
    @ApplicationId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate customer exists and is active
        IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerId = @CustomerId AND IsActive = 1)
        BEGIN
            RAISERROR('Customer not found or inactive', 16, 1);
            RETURN;
        END
        
        -- Validate loan officer exists and is active
        IF NOT EXISTS (SELECT 1 FROM LoanOfficers WHERE LoanOfficerId = @LoanOfficerId AND IsActive = 1)
        BEGIN
            RAISERROR('Loan Officer not found or inactive', 16, 1);
            RETURN;
        END
        
        -- Validate branch exists and is active
        IF NOT EXISTS (SELECT 1 FROM Branches WHERE BranchId = @BranchId AND IsActive = 1)
        BEGIN
            RAISERROR('Branch not found or inactive', 16, 1);
            RETURN;
        END
        
        -- Validate requested amount
        IF @RequestedAmount <= 0 OR @RequestedAmount > 1000000
        BEGIN
            RAISERROR('Invalid loan amount. Must be between $1 and $1,000,000', 16, 1);
            RETURN;
        END
        
        -- Generate application number
        DECLARE @AppCount INT;
        SELECT @AppCount = COUNT(*) FROM Applications;
        SET @ApplicationNumber = 'APP' + FORMAT(GETDATE(), 'yyyyMM') + FORMAT(@AppCount + 1, 'D6');
        
        -- Insert application
        INSERT INTO Applications (
            ApplicationNumber,
            CustomerId,
            LoanOfficerId,
            BranchId,
            RequestedAmount,
            LoanPurpose,
            ApplicationStatus,
            SubmissionDate,
            IsActive,
            CreatedDate,
            ModifiedDate
        )
        VALUES (
            @ApplicationNumber,
            @CustomerId,
            @LoanOfficerId,
            @BranchId,
            @RequestedAmount,
            @LoanPurpose,
            'Submitted',
            GETDATE(),
            1,
            GETDATE(),
            GETDATE()
        );
        
        SET @ApplicationId = SCOPE_IDENTITY();
        
        -- Log the creation
        INSERT INTO IntegrationLogs (
            ApplicationId,
            LogType,
            ServiceName,
            RequestData,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            @ApplicationId,
            'Application Creation',
            'sp_CreateLoanApplication',
            'CustomerId: ' + CAST(@CustomerId AS NVARCHAR) + ', Amount: ' + CAST(@RequestedAmount AS NVARCHAR),
            '200',
            1,
            GETDATE(),
            SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @ApplicationId AS ApplicationId,
            @ApplicationNumber AS ApplicationNumber,
            'Application created successfully' AS Message;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log the error
        INSERT INTO IntegrationLogs (
            LogType,
            ServiceName,
            ErrorMessage,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            'Application Creation Error',
            'sp_CreateLoanApplication',
            @ErrorMessage,
            '500',
            0,
            GETDATE(),
            SYSTEM_USER
        );
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- =============================================
-- SP2: GetCustomerLoanHistory
-- Purpose: Retrieve customer's loan history with payments
-- =============================================
CREATE OR ALTER PROCEDURE sp_GetCustomerLoanHistory
    @CustomerId INT,
    @IncludePayments BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Validate customer exists
        IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerId = @CustomerId)
        BEGIN
            RAISERROR('Customer not found', 16, 1);
            RETURN;
        END
        
        -- Get customer basic info
        SELECT 
            c.CustomerId,
            c.CustomerNumber,
            c.FirstName + ' ' + c.LastName AS FullName,
            c.Email,
            c.MonthlyIncome
        FROM Customers c
        WHERE c.CustomerId = @CustomerId;
        
        -- Get applications and loans
        SELECT 
            a.ApplicationId,
            a.ApplicationNumber,
            a.RequestedAmount,
            a.ApplicationStatus,
            a.SubmissionDate,
            a.DecisionDate,
            a.DSRRatio,
            a.CreditScore,
            l.LoanId,
            l.LoanNumber,
            l.ApprovedAmount,
            l.InterestRate,
            l.LoanTermMonths,
            l.MonthlyPayment,
            l.LoanStatus,
            l.DisbursementDate,
            l.OutstandingBalance,
            l.NextPaymentDate,
            CASE 
                WHEN l.LoanId IS NOT NULL THEN 'Loan Created'
                ELSE 'Application Only'
            END AS RecordType
        FROM Applications a
        LEFT JOIN Loans l ON a.ApplicationId = l.ApplicationId
        WHERE a.CustomerId = @CustomerId
        ORDER BY a.SubmissionDate DESC;
        
        -- Get payment history if requested
        IF @IncludePayments = 1
        BEGIN
            SELECT 
                p.PaymentId,
                p.LoanId,
                l.LoanNumber,
                p.PaymentNumber,
                p.PaymentDate,
                p.PaymentAmount,
                p.PrincipalAmount,
                p.InterestAmount,
                p.PaymentMethod,
                p.PaymentStatus,
                p.TransactionId
            FROM Payments p
            INNER JOIN Loans l ON p.LoanId = l.LoanId
            INNER JOIN Applications a ON l.ApplicationId = a.ApplicationId
            WHERE a.CustomerId = @CustomerId
            ORDER BY p.PaymentDate DESC;
        END
        
        -- Log the query
        INSERT INTO IntegrationLogs (
            LogType,
            ServiceName,
            RequestData,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            'Customer Query',
            'sp_GetCustomerLoanHistory',
            'CustomerId: ' + CAST(@CustomerId AS NVARCHAR),
            '200',
            1,
            GETDATE(),
            SYSTEM_USER
        );
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log the error
        INSERT INTO IntegrationLogs (
            LogType,
            ServiceName,
            ErrorMessage,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            'Customer Query Error',
            'sp_GetCustomerLoanHistory',
            @ErrorMessage,
            '500',
            0,
            GETDATE(),
            SYSTEM_USER
        );
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- =============================================
-- SP3: UpdateApplicationStatus
-- Purpose: Update application status with audit logging
-- =============================================
CREATE OR ALTER PROCEDURE sp_UpdateApplicationStatus
    @ApplicationId INT,
    @NewStatus NVARCHAR(20),
    @DecisionReason NVARCHAR(500) = NULL,
    @UpdatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate application exists
        DECLARE @CurrentStatus NVARCHAR(20);
        DECLARE @CustomerId INT;
        
        SELECT 
            @CurrentStatus = ApplicationStatus,
            @CustomerId = CustomerId
        FROM Applications 
        WHERE ApplicationId = @ApplicationId;
        
        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Application not found', 16, 1);
            RETURN;
        END
        
        -- Validate status transition
        IF @NewStatus NOT IN ('Submitted', 'Under Review', 'Approved', 'Rejected', 'Cancelled')
        BEGIN
            RAISERROR('Invalid application status', 16, 1);
            RETURN;
        END
        
        -- Prevent invalid status transitions
        IF @CurrentStatus = 'Approved' AND @NewStatus IN ('Submitted', 'Under Review')
        BEGIN
            RAISERROR('Cannot change status from Approved to earlier stage', 16, 1);
            RETURN;
        END
        
        IF @CurrentStatus = 'Rejected' AND @NewStatus NOT IN ('Cancelled')
        BEGIN
            RAISERROR('Cannot change status from Rejected except to Cancelled', 16, 1);
            RETURN;
        END
        
        -- Store old values for audit
        DECLARE @OldValues NVARCHAR(MAX);
        SELECT @OldValues = (
            SELECT 
                ApplicationStatus,
                DecisionReason,
                ModifiedDate
            FROM Applications 
            WHERE ApplicationId = @ApplicationId
            FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER
        );
        
        -- Update application
        UPDATE Applications 
        SET 
            ApplicationStatus = @NewStatus,
            DecisionReason = @DecisionReason,
            DecisionDate = CASE 
                WHEN @NewStatus IN ('Approved', 'Rejected') THEN GETDATE()
                ELSE DecisionDate
            END,
            ReviewDate = CASE 
                WHEN @NewStatus = 'Under Review' AND ReviewDate IS NULL THEN GETDATE()
                ELSE ReviewDate
            END,
            ModifiedDate = GETDATE()
        WHERE ApplicationId = @ApplicationId;
        
        -- Store new values for audit
        DECLARE @NewValues NVARCHAR(MAX);
        SELECT @NewValues = (
            SELECT 
                ApplicationStatus,
                DecisionReason,
                ModifiedDate
            FROM Applications 
            WHERE ApplicationId = @ApplicationId
            FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER
        );
        
        -- Create audit trail
        INSERT INTO AuditTrail (
            TableName,
            RecordId,
            Action,
            OldValues,
            NewValues,
            ChangedBy,
            ChangeDate,
            ApplicationName
        )
        VALUES (
            'Applications',
            @ApplicationId,
            'UPDATE',
            @OldValues,
            @NewValues,
            ISNULL(@UpdatedBy, SYSTEM_USER),
            GETDATE(),
            'LoanApplication'
        );
        
        -- Log the status change
        INSERT INTO IntegrationLogs (
            ApplicationId,
            LogType,
            ServiceName,
            RequestData,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            @ApplicationId,
            'Status Update',
            'sp_UpdateApplicationStatus',
            'From: ' + @CurrentStatus + ' To: ' + @NewStatus,
            '200',
            1,
            GETDATE(),
            ISNULL(@UpdatedBy, SYSTEM_USER)
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @ApplicationId AS ApplicationId,
            @CurrentStatus AS OldStatus,
            @NewStatus AS NewStatus,
            'Status updated successfully' AS Message;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log the error
        INSERT INTO IntegrationLogs (
            ApplicationId,
            LogType,
            ServiceName,
            ErrorMessage,
            StatusCode,
            IsSuccess,
            LogTimestamp,
            UserId
        )
        VALUES (
            @ApplicationId,
            'Status Update Error',
            'sp_UpdateApplicationStatus',
            @ErrorMessage,
            '500',
            0,
            GETDATE(),
            ISNULL(@UpdatedBy, SYSTEM_USER)
        );
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- =============================================
-- Test Scripts for Simple Stored Procedures
-- =============================================

PRINT 'Simple stored procedures created successfully!';
PRINT 'SP1: sp_CreateLoanApplication - Insert new loan application with validation';
PRINT 'SP2: sp_GetCustomerLoanHistory - Retrieve customer loan history with payments';
PRINT 'SP3: sp_UpdateApplicationStatus - Update application status with audit logging';
PRINT '';
PRINT 'Each procedure includes:';
PRINT '- Parameter validation';
PRINT '- Error handling with try/catch';
PRINT '- Transaction management';
PRINT '- Integration logging';
PRINT '- Audit trail (SP3)';
GO