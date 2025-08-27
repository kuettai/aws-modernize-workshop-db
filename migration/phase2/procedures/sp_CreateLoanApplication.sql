
-- =============================================
-- SP1: CreateLoanApplication
-- Purpose: Insert new loan application with validation
-- =============================================
CREATE   PROCEDURE sp_CreateLoanApplication
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
