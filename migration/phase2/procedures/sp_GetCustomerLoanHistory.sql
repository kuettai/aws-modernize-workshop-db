
-- =============================================
-- SP2: GetCustomerLoanHistory
-- Purpose: Retrieve customer's loan history with payments
-- =============================================
CREATE   PROCEDURE sp_GetCustomerLoanHistory
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