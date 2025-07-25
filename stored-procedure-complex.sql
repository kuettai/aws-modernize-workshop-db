-- =============================================
-- Complex Stored Procedure: Comprehensive Loan Eligibility Assessment
-- Features: CTEs, Window Functions, Temp Tables, Cursors, Dynamic SQL, Error Handling
-- Purpose: Demonstrate advanced SQL Server features for workshop migration
-- =============================================

USE LoanApplicationDB;
GO

-- =============================================
-- SP4: sp_ComprehensiveLoanEligibilityAssessment
-- Complex business logic with DSR calculation, credit analysis, and risk assessment
-- =============================================
CREATE OR ALTER PROCEDURE sp_ComprehensiveLoanEligibilityAssessment
    @ApplicationId INT,
    @OverrideRules BIT = 0,
    @AssessmentDetails NVARCHAR(MAX) OUTPUT,
    @RecommendedAction NVARCHAR(50) OUTPUT,
    @RiskScore DECIMAL(5,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables for complex calculations
    DECLARE @CustomerId INT;
    DECLARE @RequestedAmount DECIMAL(12,2);
    DECLARE @CustomerIncome DECIMAL(12,2);
    DECLARE @DSRRatio DECIMAL(5,2);
    DECLARE @CreditScore INT;
    DECLARE @EmploymentYears INT;
    DECLARE @ExistingLoansCount INT;
    DECLARE @TotalExistingDebt DECIMAL(12,2);
    DECLARE @PaymentHistoryScore DECIMAL(5,2);
    DECLARE @DebtToIncomeRatio DECIMAL(5,2);
    DECLARE @FinalDecision NVARCHAR(20);
    DECLARE @ProcessingStartTime DATETIME2 = GETDATE();
    DECLARE @CorrelationId NVARCHAR(50) = NEWID();
    
    -- Dynamic SQL variables
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ParmDefinition NVARCHAR(500);
    
    BEGIN TRY
        BEGIN TRANSACTION LoanAssessment;
        
        -- Log assessment start
        INSERT INTO IntegrationLogs (ApplicationId, LogType, ServiceName, RequestData, LogTimestamp, CorrelationId, UserId)
        VALUES (@ApplicationId, 'Loan Assessment', 'sp_ComprehensiveLoanEligibilityAssessment', 
                'Starting comprehensive assessment', @ProcessingStartTime, @CorrelationId, SYSTEM_USER);
        
        -- =============================================
        -- STEP 1: Data Validation and Basic Info Retrieval
        -- =============================================
        
        -- Validate application exists and get basic info
        SELECT 
            @CustomerId = a.CustomerId,
            @RequestedAmount = a.RequestedAmount,
            @CustomerIncome = c.MonthlyIncome,
            @CreditScore = ISNULL(a.CreditScore, 0),
            @EmploymentYears = ISNULL(c.YearsEmployed, 0)
        FROM Applications a
        INNER JOIN Customers c ON a.CustomerId = c.CustomerId
        WHERE a.ApplicationId = @ApplicationId AND a.IsActive = 1;
        
        IF @CustomerId IS NULL
        BEGIN
            RAISERROR('Application not found or inactive', 16, 1);
            RETURN;
        END
        
        -- =============================================
        -- STEP 2: Create Temporary Tables for Complex Calculations
        -- =============================================
        
        -- Temp table for customer financial profile
        CREATE TABLE #CustomerFinancialProfile (
            ProfileId INT IDENTITY(1,1),
            CustomerId INT,
            IncomeSource NVARCHAR(100),
            MonthlyAmount DECIMAL(10,2),
            IncomeType NVARCHAR(20),
            StabilityScore DECIMAL(3,2)
        );
        
        -- Temp table for existing debt analysis
        CREATE TABLE #ExistingDebtAnalysis (
            DebtId INT IDENTITY(1,1),
            LoanId INT,
            LoanType NVARCHAR(50),
            OutstandingBalance DECIMAL(12,2),
            MonthlyPayment DECIMAL(10,2),
            PaymentHistory NVARCHAR(20),
            RiskFactor DECIMAL(3,2)
        );
        
        -- Temp table for risk factors
        CREATE TABLE #RiskFactors (
            FactorId INT IDENTITY(1,1),
            FactorName NVARCHAR(100),
            FactorValue DECIMAL(10,2),
            WeightPercentage DECIMAL(5,2),
            RiskImpact DECIMAL(5,2)
        );
        
        -- =============================================
        -- STEP 3: CTE for Customer Payment History Analysis
        -- =============================================
        
        WITH PaymentHistoryAnalysis AS (
            -- Get payment patterns for existing loans
            SELECT 
                a.CustomerId,
                l.LoanId,
                l.LoanNumber,
                COUNT(p.PaymentId) as TotalPayments,
                COUNT(CASE WHEN p.PaymentStatus = 'Completed' THEN 1 END) as OnTimePayments,
                COUNT(CASE WHEN p.PaymentStatus = 'Failed' THEN 1 END) as FailedPayments,
                AVG(DATEDIFF(DAY, l.NextPaymentDate, p.PaymentDate)) as AvgPaymentDelay,
                SUM(p.PaymentAmount) as TotalPaid,
                -- Window function to calculate payment consistency
                STDEV(p.PaymentAmount) OVER (PARTITION BY l.LoanId) as PaymentVariability
            FROM Loans l
            LEFT JOIN Payments p ON l.LoanId = p.LoanId
            INNER JOIN Applications a ON l.ApplicationId = a.ApplicationId
            WHERE a.CustomerId = @CustomerId
            GROUP BY a.CustomerId, l.LoanId, l.LoanNumber
        ),
        CreditUtilizationAnalysis AS (
            -- Analyze credit utilization patterns
            SELECT 
                cc.CustomerId,
                COUNT(*) as CreditCheckCount,
                AVG(CAST(cc.CreditScore AS DECIMAL(5,2))) as AvgCreditScore,
                MAX(cc.CreditScore) as MaxCreditScore,
                MIN(cc.CreditScore) as MinCreditScore,
                -- Window function for credit score trend
                CASE 
                    WHEN LAG(cc.CreditScore) OVER (ORDER BY cc.CheckDate) < cc.CreditScore THEN 'Improving'
                    WHEN LAG(cc.CreditScore) OVER (ORDER BY cc.CheckDate) > cc.CreditScore THEN 'Declining'
                    ELSE 'Stable'
                END as CreditTrend
            FROM CreditChecks cc
            WHERE cc.CustomerId = @CustomerId 
                AND cc.CheckDate >= DATEADD(YEAR, -2, GETDATE())
            GROUP BY cc.CustomerId, cc.CreditScore, cc.CheckDate
        )
        -- Insert payment history analysis into temp table
        INSERT INTO #ExistingDebtAnalysis (LoanId, LoanType, OutstandingBalance, MonthlyPayment, PaymentHistory, RiskFactor)
        SELECT 
            pha.LoanId,
            'Personal Loan' as LoanType,
            l.OutstandingBalance,
            l.MonthlyPayment,
            CASE 
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 95 THEN 'Excellent'
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 85 THEN 'Good'
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 70 THEN 'Fair'
                ELSE 'Poor'
            END as PaymentHistory,
            CASE 
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 95 THEN 0.1
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 85 THEN 0.3
                WHEN pha.OnTimePayments * 100.0 / NULLIF(pha.TotalPayments, 0) >= 70 THEN 0.6
                ELSE 1.0
            END as RiskFactor
        FROM PaymentHistoryAnalysis pha
        INNER JOIN Loans l ON pha.LoanId = l.LoanId;
        
        -- =============================================
        -- STEP 4: Dynamic SQL for Flexible Risk Assessment
        -- =============================================
        
        -- Build dynamic query based on customer profile
        SET @SQL = N'
        INSERT INTO #RiskFactors (FactorName, FactorValue, WeightPercentage, RiskImpact)
        SELECT 
            ''Credit Score'' as FactorName,
            @CreditScore as FactorValue,
            25.0 as WeightPercentage,
            CASE 
                WHEN @CreditScore >= 750 THEN 0.1
                WHEN @CreditScore >= 700 THEN 0.3
                WHEN @CreditScore >= 650 THEN 0.6
                WHEN @CreditScore >= 600 THEN 0.8
                ELSE 1.0
            END as RiskImpact
        UNION ALL
        SELECT 
            ''Employment Stability'',
            @EmploymentYears,
            20.0,
            CASE 
                WHEN @EmploymentYears >= 5 THEN 0.1
                WHEN @EmploymentYears >= 3 THEN 0.3
                WHEN @EmploymentYears >= 1 THEN 0.6
                ELSE 1.0
            END
        UNION ALL
        SELECT 
            ''Income Level'',
            @CustomerIncome,
            15.0,
            CASE 
                WHEN @CustomerIncome >= 8000 THEN 0.1
                WHEN @CustomerIncome >= 5000 THEN 0.3
                WHEN @CustomerIncome >= 3000 THEN 0.6
                ELSE 1.0
            END';
        
        SET @ParmDefinition = N'@CreditScore INT, @EmploymentYears INT, @CustomerIncome DECIMAL(12,2)';
        
        EXEC sp_executesql @SQL, @ParmDefinition, 
             @CreditScore = @CreditScore, 
             @EmploymentYears = @EmploymentYears, 
             @CustomerIncome = @CustomerIncome;
        
        -- =============================================
        -- STEP 5: Calculate DSR using Complex Logic
        -- =============================================
        
        -- Get total existing monthly debt payments
        SELECT @TotalExistingDebt = ISNULL(SUM(MonthlyPayment), 0)
        FROM #ExistingDebtAnalysis;
        
        -- Calculate estimated monthly payment for requested loan
        DECLARE @EstimatedMonthlyPayment DECIMAL(10,2);
        DECLARE @InterestRate DECIMAL(5,4) = 0.08; -- 8% default rate
        DECLARE @LoanTermMonths INT = 60; -- 5 years default
        
        -- PMT calculation: P * [r(1+r)^n] / [(1+r)^n - 1]
        SET @EstimatedMonthlyPayment = 
            @RequestedAmount * 
            ((@InterestRate/12) * POWER(1 + (@InterestRate/12), @LoanTermMonths)) / 
            (POWER(1 + (@InterestRate/12), @LoanTermMonths) - 1);
        
        -- Calculate DSR
        SET @DSRRatio = ((@TotalExistingDebt + @EstimatedMonthlyPayment) / @CustomerIncome) * 100;
        
        -- =============================================
        -- STEP 6: Cursor for Detailed Risk Factor Analysis
        -- =============================================
        
        DECLARE @FactorName NVARCHAR(100);
        DECLARE @FactorValue DECIMAL(10,2);
        DECLARE @WeightPercentage DECIMAL(5,2);
        DECLARE @RiskImpact DECIMAL(5,2);
        DECLARE @WeightedRisk DECIMAL(8,4) = 0;
        
        DECLARE risk_cursor CURSOR FOR
        SELECT FactorName, FactorValue, WeightPercentage, RiskImpact
        FROM #RiskFactors;
        
        OPEN risk_cursor;
        FETCH NEXT FROM risk_cursor INTO @FactorName, @FactorValue, @WeightPercentage, @RiskImpact;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calculate weighted risk contribution
            SET @WeightedRisk = @WeightedRisk + (@RiskImpact * @WeightPercentage / 100.0);
            
            -- Log each factor analysis
            INSERT INTO IntegrationLogs (ApplicationId, LogType, ServiceName, RequestData, LogTimestamp, CorrelationId)
            VALUES (@ApplicationId, 'Risk Factor Analysis', 'RiskCursor', 
                    @FactorName + ': ' + CAST(@FactorValue AS NVARCHAR) + ' (Impact: ' + CAST(@RiskImpact AS NVARCHAR) + ')',
                    GETDATE(), @CorrelationId);
            
            FETCH NEXT FROM risk_cursor INTO @FactorName, @FactorValue, @WeightPercentage, @RiskImpact;
        END
        
        CLOSE risk_cursor;
        DEALLOCATE risk_cursor;
        
        -- =============================================
        -- STEP 7: Advanced Decision Logic with Multiple Scenarios
        -- =============================================
        
        -- Calculate final risk score (0-100 scale)
        SET @RiskScore = @WeightedRisk * 100;
        
        -- Add DSR impact to risk score
        SET @RiskScore = @RiskScore + 
            CASE 
                WHEN @DSRRatio <= 30 THEN 0
                WHEN @DSRRatio <= 40 THEN 10
                WHEN @DSRRatio <= 50 THEN 25
                ELSE 40
            END;
        
        -- Decision matrix with complex business rules
        IF @OverrideRules = 1
        BEGIN
            SET @FinalDecision = 'Manual Review Required';
            SET @RecommendedAction = 'MANUAL_REVIEW';
        END
        ELSE
        BEGIN
            -- Multi-factor decision logic
            IF @RiskScore <= 20 AND @DSRRatio <= 35 AND @CreditScore >= 700
            BEGIN
                SET @FinalDecision = 'Auto Approved';
                SET @RecommendedAction = 'APPROVE';
            END
            ELSE IF @RiskScore <= 40 AND @DSRRatio <= 40 AND @CreditScore >= 650
            BEGIN
                SET @FinalDecision = 'Conditional Approval';
                SET @RecommendedAction = 'CONDITIONAL_APPROVE';
            END
            ELSE IF @RiskScore <= 60 AND @DSRRatio <= 45
            BEGIN
                SET @FinalDecision = 'Manual Review';
                SET @RecommendedAction = 'MANUAL_REVIEW';
            END
            ELSE
            BEGIN
                SET @FinalDecision = 'Declined';
                SET @RecommendedAction = 'DECLINE';
            END
        END
        
        -- =============================================
        -- STEP 8: Generate Comprehensive Assessment Report
        -- =============================================
        
        -- Build detailed assessment JSON
        SELECT @AssessmentDetails = (
            SELECT 
                @ApplicationId as ApplicationId,
                @CustomerId as CustomerId,
                @RequestedAmount as RequestedAmount,
                @CustomerIncome as MonthlyIncome,
                @DSRRatio as DSRRatio,
                @CreditScore as CreditScore,
                @RiskScore as RiskScore,
                @FinalDecision as Decision,
                @RecommendedAction as RecommendedAction,
                GETDATE() as AssessmentDate,
                @CorrelationId as CorrelationId,
                (
                    SELECT 
                        FactorName,
                        FactorValue,
                        WeightPercentage,
                        RiskImpact
                    FROM #RiskFactors
                    FOR JSON PATH
                ) as RiskFactors,
                (
                    SELECT 
                        LoanType,
                        OutstandingBalance,
                        MonthlyPayment,
                        PaymentHistory,
                        RiskFactor
                    FROM #ExistingDebtAnalysis
                    FOR JSON PATH
                ) as ExistingDebts
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        
        -- =============================================
        -- STEP 9: Update Application with Assessment Results
        -- =============================================
        
        UPDATE Applications 
        SET 
            DSRRatio = @DSRRatio,
            ApplicationStatus = CASE 
                WHEN @RecommendedAction = 'APPROVE' THEN 'Approved'
                WHEN @RecommendedAction = 'DECLINE' THEN 'Rejected'
                ELSE 'Under Review'
            END,
            DecisionReason = @FinalDecision + ' (Risk Score: ' + CAST(@RiskScore AS NVARCHAR) + ')',
            DecisionDate = CASE 
                WHEN @RecommendedAction IN ('APPROVE', 'DECLINE') THEN GETDATE()
                ELSE NULL
            END,
            ModifiedDate = GETDATE()
        WHERE ApplicationId = @ApplicationId;
        
        -- =============================================
        -- STEP 10: Comprehensive Logging and Audit Trail
        -- =============================================
        
        -- Calculate processing time
        DECLARE @ProcessingEndTime DATETIME2 = GETDATE();
        DECLARE @ProcessingTimeMs INT = DATEDIFF(MILLISECOND, @ProcessingStartTime, @ProcessingEndTime);
        
        -- Log final assessment result
        INSERT INTO IntegrationLogs (
            ApplicationId, LogType, ServiceName, RequestData, ResponseData, 
            StatusCode, IsSuccess, ProcessingTimeMs, LogTimestamp, CorrelationId, UserId
        )
        VALUES (
            @ApplicationId, 'Loan Assessment Complete', 'sp_ComprehensiveLoanEligibilityAssessment',
            'Risk Score: ' + CAST(@RiskScore AS NVARCHAR) + ', DSR: ' + CAST(@DSRRatio AS NVARCHAR),
            @AssessmentDetails,
            '200', 1, @ProcessingTimeMs, @ProcessingEndTime, @CorrelationId, SYSTEM_USER
        );
        
        -- Create audit trail entry
        INSERT INTO AuditTrail (TableName, RecordId, Action, NewValues, ChangedBy, ChangeDate, ApplicationName)
        VALUES ('Applications', @ApplicationId, 'ASSESSMENT', @AssessmentDetails, 
                'sp_ComprehensiveLoanEligibilityAssessment', GETDATE(), 'LoanApplication');
        
        -- Clean up temp tables
        DROP TABLE #CustomerFinancialProfile;
        DROP TABLE #ExistingDebtAnalysis;
        DROP TABLE #RiskFactors;
        
        COMMIT TRANSACTION LoanAssessment;
        
        -- Return summary results
        SELECT 
            @ApplicationId as ApplicationId,
            @FinalDecision as Decision,
            @RecommendedAction as RecommendedAction,
            @RiskScore as RiskScore,
            @DSRRatio as DSRRatio,
            @ProcessingTimeMs as ProcessingTimeMs,
            'Assessment completed successfully' as Message;
            
    END TRY
    BEGIN CATCH
        -- Comprehensive error handling
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION LoanAssessment;
            
        -- Clean up temp tables if they exist
        IF OBJECT_ID('tempdb..#CustomerFinancialProfile') IS NOT NULL
            DROP TABLE #CustomerFinancialProfile;
        IF OBJECT_ID('tempdb..#ExistingDebtAnalysis') IS NOT NULL
            DROP TABLE #ExistingDebtAnalysis;
        IF OBJECT_ID('tempdb..#RiskFactors') IS NOT NULL
            DROP TABLE #RiskFactors;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        DECLARE @ErrorLine INT = ERROR_LINE();
        DECLARE @ErrorProcedure NVARCHAR(128) = ERROR_PROCEDURE();
        
        -- Log comprehensive error details
        INSERT INTO IntegrationLogs (
            ApplicationId, LogType, ServiceName, ErrorMessage, StatusCode, IsSuccess, 
            ProcessingTimeMs, LogTimestamp, CorrelationId, UserId
        )
        VALUES (
            @ApplicationId, 'Assessment Error', 'sp_ComprehensiveLoanEligibilityAssessment',
            'Error at line ' + CAST(@ErrorLine AS NVARCHAR) + ': ' + @ErrorMessage,
            '500', 0, DATEDIFF(MILLISECOND, @ProcessingStartTime, GETDATE()),
            GETDATE(), @CorrelationId, SYSTEM_USER
        );
        
        -- Set error outputs
        SET @AssessmentDetails = '{"error": "' + @ErrorMessage + '", "line": ' + CAST(@ErrorLine AS NVARCHAR) + '}';
        SET @RecommendedAction = 'ERROR';
        SET @RiskScore = -1;
        
        RAISERROR('Assessment failed: %s (Line: %d)', @ErrorSeverity, @ErrorState, @ErrorMessage, @ErrorLine);
    END CATCH
END;
GO

PRINT 'Complex stored procedure created successfully!';
PRINT 'sp_ComprehensiveLoanEligibilityAssessment features:';
PRINT '- 250+ lines of advanced SQL Server code';
PRINT '- CTEs for payment history and credit analysis';
PRINT '- Window functions for trend analysis';
PRINT '- Temporary tables for complex calculations';
PRINT '- Cursors for detailed risk factor processing';
PRINT '- Dynamic SQL for flexible risk assessment';
PRINT '- Comprehensive error handling and transactions';
PRINT '- JSON output for detailed assessment results';
PRINT '- Complete audit trail and logging';
PRINT 'Ready for PostgreSQL conversion challenges!';
GO