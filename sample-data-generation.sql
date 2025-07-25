-- =============================================
-- Sample Data Generation for Loan Application System
-- Realistic test data for AWS Database Modernization Workshop
-- =============================================

USE LoanApplicationDB;
GO

-- Disable constraints temporarily for bulk insert
ALTER TABLE Applications NOCHECK CONSTRAINT ALL;
ALTER TABLE Loans NOCHECK CONSTRAINT ALL;
ALTER TABLE Payments NOCHECK CONSTRAINT ALL;
ALTER TABLE Documents NOCHECK CONSTRAINT ALL;
ALTER TABLE CreditChecks NOCHECK CONSTRAINT ALL;
ALTER TABLE IntegrationLogs NOCHECK CONSTRAINT ALL;
GO

PRINT 'Starting sample data generation...';

-- =============================================
-- 1. BRANCHES (50 records)
-- =============================================
PRINT 'Generating Branches...';

INSERT INTO Branches (BranchCode, BranchName, Address, City, State, ZipCode, Phone, Email, IsActive)
VALUES 
('BR001', 'Manhattan Main', '100 Wall Street', 'New York', 'NY', '10005', '212-555-0001', 'manhattan@loanapp.com', 1),
('BR002', 'Brooklyn Heights', '200 Montague Street', 'Brooklyn', 'NY', '11201', '718-555-0002', 'brooklyn@loanapp.com', 1),
('BR003', 'Queens Center', '300 Northern Blvd', 'Queens', 'NY', '11354', '718-555-0003', 'queens@loanapp.com', 1),
('BR004', 'Bronx Plaza', '400 Grand Concourse', 'Bronx', 'NY', '10451', '718-555-0004', 'bronx@loanapp.com', 1),
('BR005', 'Staten Island', '500 Richmond Ave', 'Staten Island', 'NY', '10314', '718-555-0005', 'si@loanapp.com', 1),
('BR006', 'Los Angeles Downtown', '600 Spring Street', 'Los Angeles', 'CA', '90014', '213-555-0006', 'la@loanapp.com', 1),
('BR007', 'San Francisco Financial', '700 Montgomery St', 'San Francisco', 'CA', '94111', '415-555-0007', 'sf@loanapp.com', 1),
('BR008', 'Chicago Loop', '800 LaSalle Street', 'Chicago', 'IL', '60602', '312-555-0008', 'chicago@loanapp.com', 1),
('BR009', 'Miami Beach', '900 Ocean Drive', 'Miami Beach', 'FL', '33139', '305-555-0009', 'miami@loanapp.com', 1),
('BR010', 'Dallas Central', '1000 Main Street', 'Dallas', 'TX', '75201', '214-555-0010', 'dallas@loanapp.com', 1);

-- Generate additional branches
DECLARE @i INT = 11;
WHILE @i <= 50
BEGIN
    INSERT INTO Branches (BranchCode, BranchName, Address, City, State, ZipCode, Phone, Email, IsActive)
    VALUES (
        'BR' + FORMAT(@i, '000'),
        'Branch ' + CAST(@i AS NVARCHAR),
        CAST(@i * 100 AS NVARCHAR) + ' Main Street',
        CASE (@i % 10)
            WHEN 1 THEN 'Houston' WHEN 2 THEN 'Phoenix' WHEN 3 THEN 'Philadelphia'
            WHEN 4 THEN 'San Antonio' WHEN 5 THEN 'San Diego' WHEN 6 THEN 'Detroit'
            WHEN 7 THEN 'San Jose' WHEN 8 THEN 'Austin' WHEN 9 THEN 'Jacksonville'
            ELSE 'Columbus'
        END,
        CASE (@i % 10)
            WHEN 1 THEN 'TX' WHEN 2 THEN 'AZ' WHEN 3 THEN 'PA'
            WHEN 4 THEN 'TX' WHEN 5 THEN 'CA' WHEN 6 THEN 'MI'
            WHEN 7 THEN 'CA' WHEN 8 THEN 'TX' WHEN 9 THEN 'FL'
            ELSE 'OH'
        END,
        FORMAT(@i * 100 + 1000, '00000'),
        FORMAT(@i * 100 + 5550000, '000-000-0000'),
        'branch' + CAST(@i AS NVARCHAR) + '@loanapp.com',
        1
    );
    SET @i = @i + 1;
END

-- =============================================
-- 2. LOAN OFFICERS (200 records)
-- =============================================
PRINT 'Generating Loan Officers...';

-- Sample loan officers with realistic names
DECLARE @FirstNames TABLE (Name NVARCHAR(50));
INSERT INTO @FirstNames VALUES ('James'),('Mary'),('John'),('Patricia'),('Robert'),('Jennifer'),('Michael'),('Linda'),('William'),('Elizabeth'),
('David'),('Barbara'),('Richard'),('Susan'),('Joseph'),('Jessica'),('Thomas'),('Sarah'),('Christopher'),('Karen'),('Charles'),('Nancy'),('Daniel'),('Lisa'),('Matthew'),('Betty');

DECLARE @LastNames TABLE (Name NVARCHAR(50));
INSERT INTO @LastNames VALUES ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),('Rodriguez'),('Martinez'),
('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),('Thomas'),('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),('White'),('Harris'),('Sanchez');

DECLARE @LoanOfficerCount INT = 1;
WHILE @LoanOfficerCount <= 200
BEGIN
    INSERT INTO LoanOfficers (EmployeeId, FirstName, LastName, Email, Phone, BranchId, IsActive, HireDate)
    SELECT 
        'LO' + FORMAT(@LoanOfficerCount, '000'),
        (SELECT TOP 1 Name FROM @FirstNames ORDER BY NEWID()),
        (SELECT TOP 1 Name FROM @LastNames ORDER BY NEWID()),
        'lo' + CAST(@LoanOfficerCount AS NVARCHAR) + '@loanapp.com',
        FORMAT(CAST(RAND() * 9000000000 AS BIGINT) + 1000000000, '000-000-0000'),
        ((@LoanOfficerCount - 1) % 50) + 1, -- Distribute across branches
        1,
        DATEADD(DAY, -CAST(RAND() * 1825 AS INT), GETDATE()) -- Random hire date within 5 years
    SET @LoanOfficerCount = @LoanOfficerCount + 1;
END

-- =============================================
-- 3. CUSTOMERS (1,000 records)
-- =============================================
PRINT 'Generating Customers...';

DECLARE @CustomerCount INT = 1;
WHILE @CustomerCount <= 1000
BEGIN
    INSERT INTO Customers (
        CustomerNumber, FirstName, LastName, DateOfBirth, SSN, Email, Phone,
        Address, City, State, ZipCode, MonthlyIncome, EmploymentStatus, EmployerName, YearsEmployed, IsActive
    )
    SELECT 
        'CUST' + FORMAT(YEAR(GETDATE()), '0000') + FORMAT(@CustomerCount, '000000'),
        (SELECT TOP 1 Name FROM @FirstNames ORDER BY NEWID()),
        (SELECT TOP 1 Name FROM @LastNames ORDER BY NEWID()),
        DATEADD(YEAR, -CAST(RAND() * 50 + 18 AS INT), GETDATE()), -- Age 18-68
        FORMAT(CAST(RAND() * 900000000 AS INT) + 100000000, '000-00-0000'),
        'customer' + CAST(@CustomerCount AS NVARCHAR) + '@email.com',
        FORMAT(CAST(RAND() * 9000000000 AS BIGINT) + 1000000000, '000-000-0000'),
        CAST(CAST(RAND() * 9999 + 1 AS INT) AS NVARCHAR) + ' ' + 
        CASE CAST(RAND() * 10 AS INT)
            WHEN 0 THEN 'Main St' WHEN 1 THEN 'Oak Ave' WHEN 2 THEN 'Pine Rd'
            WHEN 3 THEN 'Elm Dr' WHEN 4 THEN 'Maple Ln' WHEN 5 THEN 'Cedar Blvd'
            WHEN 6 THEN 'Park Ave' WHEN 7 THEN 'First St' WHEN 8 THEN 'Second Ave'
            ELSE 'Third St'
        END,
        CASE CAST(RAND() * 10 AS INT)
            WHEN 0 THEN 'New York' WHEN 1 THEN 'Los Angeles' WHEN 2 THEN 'Chicago'
            WHEN 3 THEN 'Houston' WHEN 4 THEN 'Phoenix' WHEN 5 THEN 'Philadelphia'
            WHEN 6 THEN 'San Antonio' WHEN 7 THEN 'San Diego' WHEN 8 THEN 'Dallas'
            ELSE 'San Jose'
        END,
        CASE CAST(RAND() * 10 AS INT)
            WHEN 0 THEN 'NY' WHEN 1 THEN 'CA' WHEN 2 THEN 'IL'
            WHEN 3 THEN 'TX' WHEN 4 THEN 'AZ' WHEN 5 THEN 'PA'
            WHEN 6 THEN 'TX' WHEN 7 THEN 'CA' WHEN 8 THEN 'TX'
            ELSE 'CA'
        END,
        FORMAT(CAST(RAND() * 90000 + 10000 AS INT), '00000'),
        CAST(RAND() * 15000 + 2000 AS DECIMAL(12,2)), -- Income $2K-$17K
        CASE CAST(RAND() * 4 AS INT)
            WHEN 0 THEN 'Employed' WHEN 1 THEN 'Self-Employed'
            WHEN 2 THEN 'Employed' ELSE 'Employed' -- 75% employed
        END,
        CASE CAST(RAND() * 10 AS INT)
            WHEN 0 THEN 'Tech Corp' WHEN 1 THEN 'Finance Inc' WHEN 2 THEN 'Healthcare LLC'
            WHEN 3 THEN 'Retail Co' WHEN 4 THEN 'Manufacturing Ltd' WHEN 5 THEN 'Consulting Group'
            WHEN 6 THEN 'Education Org' WHEN 7 THEN 'Government' WHEN 8 THEN 'Non-Profit'
            ELSE 'Services Company'
        END,
        CAST(RAND() * 20 AS INT), -- 0-20 years employment
        1;
    
    SET @CustomerCount = @CustomerCount + 1;
END

-- =============================================
-- 4. APPLICATIONS (5,000 records)
-- =============================================
PRINT 'Generating Applications...';

DECLARE @AppCount INT = 1;
WHILE @AppCount <= 5000
BEGIN
    DECLARE @RandomCustomerId INT = CAST(RAND() * 1000 + 1 AS INT);
    DECLARE @RandomLoanOfficerId INT = CAST(RAND() * 200 + 1 AS INT);
    DECLARE @RandomBranchId INT = CAST(RAND() * 50 + 1 AS INT);
    DECLARE @RandomAmount DECIMAL(12,2) = CAST(RAND() * 95000 + 5000 AS DECIMAL(12,2)); -- $5K-$100K
    DECLARE @RandomStatus NVARCHAR(20) = 
        CASE CAST(RAND() * 10 AS INT)
            WHEN 0 THEN 'Submitted' WHEN 1 THEN 'Under Review' WHEN 2 THEN 'Approved'
            WHEN 3 THEN 'Approved' WHEN 4 THEN 'Approved' WHEN 5 THEN 'Rejected'
            WHEN 6 THEN 'Approved' WHEN 7 THEN 'Under Review' WHEN 8 THEN 'Approved'
            ELSE 'Approved' -- 60% approved
        END;
    
    INSERT INTO Applications (
        ApplicationNumber, CustomerId, LoanOfficerId, BranchId, RequestedAmount, LoanPurpose,
        ApplicationStatus, SubmissionDate, ReviewDate, DecisionDate, DecisionReason,
        DSRRatio, CreditScore, IsActive
    )
    VALUES (
        'APP' + FORMAT(DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()), 'yyyyMM') + FORMAT(@AppCount, '000000'),
        @RandomCustomerId,
        @RandomLoanOfficerId,
        @RandomBranchId,
        @RandomAmount,
        CASE CAST(RAND() * 8 AS INT)
            WHEN 0 THEN 'Debt Consolidation' WHEN 1 THEN 'Home Improvement' WHEN 2 THEN 'Auto Purchase'
            WHEN 3 THEN 'Medical Expenses' WHEN 4 THEN 'Education' WHEN 5 THEN 'Business Investment'
            WHEN 6 THEN 'Wedding' ELSE 'Personal Use'
        END,
        @RandomStatus,
        DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()),
        CASE WHEN @RandomStatus != 'Submitted' THEN DATEADD(DAY, CAST(RAND() * 7 + 1 AS INT), DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE())) ELSE NULL END,
        CASE WHEN @RandomStatus IN ('Approved', 'Rejected') THEN DATEADD(DAY, CAST(RAND() * 14 + 1 AS INT), DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE())) ELSE NULL END,
        CASE 
            WHEN @RandomStatus = 'Approved' THEN 'Meets all criteria'
            WHEN @RandomStatus = 'Rejected' THEN 'High DSR ratio'
            ELSE NULL
        END,
        CAST(RAND() * 50 + 10 AS DECIMAL(5,2)), -- DSR 10-60%
        CAST(RAND() * 250 + 600 AS INT), -- Credit score 600-850
        1
    );
    
    SET @AppCount = @AppCount + 1;
END

-- =============================================
-- 5. LOANS (2,000 records - from approved applications)
-- =============================================
PRINT 'Generating Loans...';

INSERT INTO Loans (
    LoanNumber, ApplicationId, ApprovedAmount, InterestRate, LoanTermMonths,
    MonthlyPayment, LoanStatus, DisbursementDate, MaturityDate, OutstandingBalance, NextPaymentDate
)
SELECT TOP 2000
    'LOAN' + FORMAT(a.SubmissionDate, 'yyyyMM') + FORMAT(ROW_NUMBER() OVER (ORDER BY a.ApplicationId), '000000'),
    a.ApplicationId,
    a.RequestedAmount * (0.8 + RAND() * 0.2), -- 80-100% of requested
    0.05 + RAND() * 0.10, -- 5-15% interest rate
    CASE CAST(RAND() * 4 AS INT)
        WHEN 0 THEN 36 WHEN 1 THEN 48 WHEN 2 THEN 60 ELSE 72
    END, -- 3-6 year terms
    0, -- Will calculate below
    CASE CAST(RAND() * 10 AS INT)
        WHEN 0 THEN 'Paid Off' WHEN 1 THEN 'Defaulted' ELSE 'Active'
    END, -- 80% active, 10% paid off, 10% defaulted
    DATEADD(DAY, CAST(RAND() * 30 + 7 AS INT), a.DecisionDate),
    NULL, -- Will calculate below
    0, -- Will calculate below
    NULL -- Will calculate below
FROM Applications a
WHERE a.ApplicationStatus = 'Approved'
ORDER BY NEWID();

-- Update calculated fields for loans
UPDATE Loans 
SET 
    MonthlyPayment = ApprovedAmount * ((InterestRate/12) * POWER(1 + (InterestRate/12), LoanTermMonths)) / (POWER(1 + (InterestRate/12), LoanTermMonths) - 1),
    MaturityDate = DATEADD(MONTH, LoanTermMonths, DisbursementDate),
    OutstandingBalance = CASE 
        WHEN LoanStatus = 'Paid Off' THEN 0
        WHEN LoanStatus = 'Defaulted' THEN ApprovedAmount * 0.7
        ELSE ApprovedAmount * (0.3 + RAND() * 0.6) -- 30-90% remaining
    END,
    NextPaymentDate = CASE 
        WHEN LoanStatus = 'Active' THEN DATEADD(MONTH, 1, GETDATE())
        ELSE NULL
    END;

-- =============================================
-- 6. PAYMENTS (50,000 records)
-- =============================================
PRINT 'Generating Payments...';

-- Generate payments for active loans
DECLARE @LoanId INT;
DECLARE @PaymentCount INT;
DECLARE @MonthlyPayment DECIMAL(10,2);
DECLARE @InterestRate DECIMAL(5,4);
DECLARE @OutstandingBalance DECIMAL(12,2);
DECLARE @DisbursementDate DATE;

DECLARE loan_cursor CURSOR FOR
SELECT LoanId, MonthlyPayment, InterestRate, OutstandingBalance, DisbursementDate
FROM Loans 
WHERE LoanStatus = 'Active';

OPEN loan_cursor;
FETCH NEXT FROM loan_cursor INTO @LoanId, @MonthlyPayment, @InterestRate, @OutstandingBalance, @DisbursementDate;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @PaymentCount = CAST(RAND() * 24 + 1 AS INT); -- 1-24 payments per loan
    
    DECLARE @PaymentNum INT = 1;
    DECLARE @PaymentDate DATE = DATEADD(MONTH, 1, @DisbursementDate);
    DECLARE @RemainingBalance DECIMAL(12,2) = @OutstandingBalance;
    
    WHILE @PaymentNum <= @PaymentCount AND @RemainingBalance > 0
    BEGIN
        DECLARE @InterestPortion DECIMAL(10,2) = @RemainingBalance * (@InterestRate / 12);
        DECLARE @PrincipalPortion DECIMAL(10,2) = @MonthlyPayment - @InterestPortion;
        DECLARE @PaymentStatus NVARCHAR(20) = 
            CASE CAST(RAND() * 20 AS INT)
                WHEN 0 THEN 'Failed' ELSE 'Completed' -- 5% failure rate
            END;
        
        INSERT INTO Payments (
            LoanId, PaymentNumber, PaymentDate, PaymentAmount, PrincipalAmount, InterestAmount,
            PaymentMethod, PaymentStatus, TransactionId
        )
        VALUES (
            @LoanId, @PaymentNum, @PaymentDate, @MonthlyPayment, @PrincipalPortion, @InterestPortion,
            CASE CAST(RAND() * 4 AS INT)
                WHEN 0 THEN 'ACH' WHEN 1 THEN 'Online' WHEN 2 THEN 'Check' ELSE 'ACH'
            END,
            @PaymentStatus,
            'TXN' + FORMAT(@LoanId, '000000') + FORMAT(@PaymentNum, '000')
        );
        
        IF @PaymentStatus = 'Completed'
            SET @RemainingBalance = @RemainingBalance - @PrincipalPortion;
        
        SET @PaymentNum = @PaymentNum + 1;
        SET @PaymentDate = DATEADD(MONTH, 1, @PaymentDate);
    END
    
    FETCH NEXT FROM loan_cursor INTO @LoanId, @MonthlyPayment, @InterestRate, @OutstandingBalance, @DisbursementDate;
END

CLOSE loan_cursor;
DEALLOCATE loan_cursor;

-- =============================================
-- 7. DOCUMENTS (15,000 records)
-- =============================================
PRINT 'Generating Documents...';

DECLARE @DocCount INT = 1;
WHILE @DocCount <= 15000
BEGIN
    DECLARE @RandomDocAppId INT = CAST(RAND() * 5000 + 1 AS INT);
    
    INSERT INTO Documents (
        ApplicationId, DocumentType, DocumentName, FilePath, FileSize, ContentType,
        UploadedBy, UploadDate, IsVerified, VerifiedBy, VerificationDate
    )
    VALUES (
        @RandomDocAppId,
        CASE CAST(RAND() * 6 AS INT)
            WHEN 0 THEN 'Income Verification' WHEN 1 THEN 'Bank Statement' WHEN 2 THEN 'Tax Return'
            WHEN 3 THEN 'Employment Letter' WHEN 4 THEN 'ID Copy' ELSE 'Other'
        END,
        'Document_' + CAST(@DocCount AS NVARCHAR) + '_' + FORMAT(GETDATE(), 'yyyyMMdd') + '.pdf',
        '/documents/app_' + CAST(@RandomDocAppId AS NVARCHAR) + '/doc_' + CAST(@DocCount AS NVARCHAR) + '.pdf',
        CAST(RAND() * 5000000 + 100000 AS BIGINT), -- 100KB - 5MB
        'application/pdf',
        'customer' + CAST(@RandomDocAppId AS NVARCHAR) + '@email.com',
        DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()),
        CASE CAST(RAND() * 10 AS INT) WHEN 0 THEN 0 ELSE 1 END, -- 90% verified
        CASE CAST(RAND() * 10 AS INT) WHEN 0 THEN NULL ELSE 'verifier@loanapp.com' END,
        CASE CAST(RAND() * 10 AS INT) WHEN 0 THEN NULL ELSE DATEADD(DAY, CAST(RAND() * 7 + 1 AS INT), DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE())) END
    );
    
    SET @DocCount = @DocCount + 1;
END

-- =============================================
-- 8. CREDIT CHECKS (5,000 records)
-- =============================================
PRINT 'Generating Credit Checks...';

INSERT INTO CreditChecks (
    CustomerId, ApplicationId, CreditBureau, CreditScore, CreditReportData,
    CheckDate, ExpiryDate, RequestId, ResponseCode, IsSuccessful
)
SELECT 
    c.CustomerId,
    a.ApplicationId,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'Experian' WHEN 1 THEN 'Equifax' ELSE 'TransUnion'
    END,
    CAST(RAND() * 250 + 600 AS INT), -- 600-850
    '{"score": ' + CAST(CAST(RAND() * 250 + 600 AS INT) AS NVARCHAR) + ', "factors": ["Payment History", "Credit Utilization"]}',
    DATEADD(DAY, -CAST(RAND() * 30 AS INT), a.SubmissionDate),
    DATEADD(DAY, 365, DATEADD(DAY, -CAST(RAND() * 30 AS INT), a.SubmissionDate)),
    'REQ' + FORMAT(a.ApplicationId, '000000') + FORMAT(CAST(RAND() * 1000 AS INT), '000'),
    CASE CAST(RAND() * 20 AS INT) WHEN 0 THEN '404' ELSE '200' END, -- 5% failure
    CASE CAST(RAND() * 20 AS INT) WHEN 0 THEN 0 ELSE 1 END
FROM Applications a
INNER JOIN Customers c ON a.CustomerId = c.CustomerId
ORDER BY NEWID();

-- =============================================
-- 9. INTEGRATION LOGS (100,000+ records - High volume for DynamoDB demo)
-- =============================================
PRINT 'Generating Integration Logs (High Volume)...';

-- Generate logs for various services
DECLARE @LogCount INT = 1;
WHILE @LogCount <= 100000
BEGIN
    DECLARE @RandomLogAppId INT = CASE CAST(RAND() * 10 AS INT) WHEN 0 THEN NULL ELSE CAST(RAND() * 5000 + 1 AS INT) END;
    DECLARE @LogType NVARCHAR(50) = 
        CASE CAST(RAND() * 6 AS INT)
            WHEN 0 THEN 'Credit Check' WHEN 1 THEN 'Payment Processing' WHEN 2 THEN 'Document Upload'
            WHEN 3 THEN 'Email Notification' WHEN 4 THEN 'SMS Notification' ELSE 'External API'
        END;
    
    INSERT INTO IntegrationLogs (
        ApplicationId, LogType, ServiceName, RequestData, ResponseData, StatusCode,
        IsSuccess, ErrorMessage, ProcessingTimeMs, LogTimestamp, CorrelationId, UserId
    )
    VALUES (
        @RandomLogAppId,
        @LogType,
        @LogType + ' Service',
        '{"request": "sample_data_' + CAST(@LogCount AS NVARCHAR) + '"}',
        CASE CAST(RAND() * 10 AS INT) 
            WHEN 0 THEN NULL 
            ELSE '{"response": "success", "id": "' + CAST(@LogCount AS NVARCHAR) + '"}' 
        END,
        CASE CAST(RAND() * 20 AS INT)
            WHEN 0 THEN '404' WHEN 1 THEN '500' ELSE '200'
        END,
        CASE CAST(RAND() * 20 AS INT) WHEN 0 THEN 0 ELSE 1 END, -- 5% failure
        CASE CAST(RAND() * 20 AS INT) 
            WHEN 0 THEN 'Service temporarily unavailable' 
            WHEN 1 THEN 'Timeout error'
            ELSE NULL 
        END,
        CAST(RAND() * 5000 + 100 AS INT), -- 100-5000ms processing time
        DATEADD(MINUTE, -CAST(RAND() * 525600 AS INT), GETDATE()), -- Random time within last year
        NEWID(),
        'system_user_' + CAST(CAST(RAND() * 100 AS INT) AS NVARCHAR)
    );
    
    SET @LogCount = @LogCount + 1;
    
    -- Progress indicator
    IF @LogCount % 10000 = 0
        PRINT 'Generated ' + CAST(@LogCount AS NVARCHAR) + ' integration logs...';
END

-- =============================================
-- 10. AUDIT TRAIL (25,000 records)
-- =============================================
PRINT 'Generating Audit Trail...';

DECLARE @AuditCount INT = 1;
WHILE @AuditCount <= 25000
BEGIN
    INSERT INTO AuditTrail (
        TableName, RecordId, Action, OldValues, NewValues, ChangedBy, ChangeDate, ApplicationName, IPAddress
    )
    VALUES (
        CASE CAST(RAND() * 4 AS INT)
            WHEN 0 THEN 'Applications' WHEN 1 THEN 'Customers' WHEN 2 THEN 'Loans' ELSE 'Payments'
        END,
        CAST(RAND() * 5000 + 1 AS INT),
        CASE CAST(RAND() * 3 AS INT)
            WHEN 0 THEN 'INSERT' WHEN 1 THEN 'UPDATE' ELSE 'UPDATE'
        END,
        '{"old_status": "Submitted"}',
        '{"new_status": "Approved", "decision_date": "' + FORMAT(GETDATE(), 'yyyy-MM-dd') + '"}',
        'user_' + CAST(CAST(RAND() * 200 AS INT) AS NVARCHAR),
        DATEADD(MINUTE, -CAST(RAND() * 525600 AS INT), GETDATE()),
        'LoanApplication',
        '192.168.' + CAST(CAST(RAND() * 255 AS INT) AS NVARCHAR) + '.' + CAST(CAST(RAND() * 255 AS INT) AS NVARCHAR)
    );
    
    SET @AuditCount = @AuditCount + 1;
END

-- Re-enable constraints
ALTER TABLE Applications CHECK CONSTRAINT ALL;
ALTER TABLE Loans CHECK CONSTRAINT ALL;
ALTER TABLE Payments CHECK CONSTRAINT ALL;
ALTER TABLE Documents CHECK CONSTRAINT ALL;
ALTER TABLE CreditChecks CHECK CONSTRAINT ALL;
ALTER TABLE IntegrationLogs CHECK CONSTRAINT ALL;
GO

-- =============================================
-- DATA GENERATION SUMMARY
-- =============================================
PRINT '';
PRINT '=== SAMPLE DATA GENERATION COMPLETE ===';
PRINT 'Records generated:';
SELECT 'Branches' as TableName, COUNT(*) as RecordCount FROM Branches
UNION ALL SELECT 'LoanOfficers', COUNT(*) FROM LoanOfficers
UNION ALL SELECT 'Customers', COUNT(*) FROM Customers
UNION ALL SELECT 'Applications', COUNT(*) FROM Applications
UNION ALL SELECT 'Loans', COUNT(*) FROM Loans
UNION ALL SELECT 'Payments', COUNT(*) FROM Payments
UNION ALL SELECT 'Documents', COUNT(*) FROM Documents
UNION ALL SELECT 'CreditChecks', COUNT(*) FROM CreditChecks
UNION ALL SELECT 'IntegrationLogs', COUNT(*) FROM IntegrationLogs
UNION ALL SELECT 'AuditTrail', COUNT(*) FROM AuditTrail;

PRINT '';
PRINT 'Database ready for workshop with realistic test data!';
PRINT 'High-volume IntegrationLogs table (100K+ records) ready for DynamoDB migration demo';
PRINT 'Diverse data patterns for comprehensive migration testing';
GO