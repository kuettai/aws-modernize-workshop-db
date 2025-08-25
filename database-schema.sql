-- =============================================
-- Financial Services Loan Application Database Schema
-- SQL Server Database Creation Script
-- =============================================

USE master;
GO

-- Create Database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LoanApplicationDB')
BEGIN
    CREATE DATABASE LoanApplicationDB;
END
GO

USE LoanApplicationDB;
GO

-- =============================================
-- Table 1: Branches
-- =============================================
CREATE TABLE Branches (
    BranchId INT IDENTITY(1,1) PRIMARY KEY,
    BranchCode NVARCHAR(10) NOT NULL UNIQUE,
    BranchName NVARCHAR(100) NOT NULL,
    Address NVARCHAR(255) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    State NVARCHAR(50) NOT NULL,
    ZipCode NVARCHAR(10) NOT NULL,
    Phone NVARCHAR(15),
    Email NVARCHAR(100),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETDATE()
);

-- =============================================
-- Table 2: LoanOfficers
-- =============================================
CREATE TABLE LoanOfficers (
    LoanOfficerId INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId NVARCHAR(20) NOT NULL UNIQUE,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(15),
    BranchId INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    HireDate DATE NOT NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_LoanOfficers_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- =============================================
-- Table 3: Customers
-- =============================================
CREATE TABLE Customers (
    CustomerId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerNumber NVARCHAR(20) NOT NULL UNIQUE,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    SSN NVARCHAR(11) NOT NULL UNIQUE, -- Format: XXX-XX-XXXX
    Email NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(15) NOT NULL,
    Address NVARCHAR(255) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    State NVARCHAR(50) NOT NULL,
    ZipCode NVARCHAR(10) NOT NULL,
    MonthlyIncome DECIMAL(12,2) NOT NULL,
    EmploymentStatus NVARCHAR(20) NOT NULL CHECK (EmploymentStatus IN ('Employed', 'Self-Employed', 'Unemployed', 'Retired')),
    EmployerName NVARCHAR(100),
    YearsEmployed INT,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETDATE()
);

-- =============================================
-- Table 4: Applications
-- =============================================
CREATE TABLE Applications (
    ApplicationId INT IDENTITY(1,1) PRIMARY KEY,
    ApplicationNumber NVARCHAR(20) NOT NULL UNIQUE,
    CustomerId INT NOT NULL,
    LoanOfficerId INT NOT NULL,
    BranchId INT NOT NULL,
    RequestedAmount DECIMAL(12,2) NOT NULL,
    LoanPurpose NVARCHAR(100) NOT NULL,
    ApplicationStatus NVARCHAR(20) NOT NULL DEFAULT 'Submitted' 
        CHECK (ApplicationStatus IN ('Submitted', 'Under Review', 'Approved', 'Rejected', 'Cancelled')),
    SubmissionDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ReviewDate DATETIME2,
    DecisionDate DATETIME2,
    DecisionReason NVARCHAR(500),
    DSRRatio DECIMAL(5,2), -- Debt Service Ratio
    CreditScore INT,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Applications_Customers FOREIGN KEY (CustomerId) REFERENCES Customers(CustomerId),
    CONSTRAINT FK_Applications_LoanOfficers FOREIGN KEY (LoanOfficerId) REFERENCES LoanOfficers(LoanOfficerId),
    CONSTRAINT FK_Applications_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- =============================================
-- Table 5: Loans
-- =============================================
CREATE TABLE Loans (
    LoanId INT IDENTITY(1,1) PRIMARY KEY,
    LoanNumber NVARCHAR(20) NOT NULL UNIQUE,
    ApplicationId INT NOT NULL,
    ApprovedAmount DECIMAL(12,2) NOT NULL,
    InterestRate DECIMAL(5,4) NOT NULL,
    LoanTermMonths INT NOT NULL,
    MonthlyPayment DECIMAL(10,2) NOT NULL,
    LoanStatus NVARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (LoanStatus IN ('Active', 'Paid Off', 'Defaulted', 'Closed')),
    DisbursementDate DATE,
    MaturityDate DATE,
    OutstandingBalance DECIMAL(12,2) NOT NULL,
    NextPaymentDate DATE,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Loans_Applications FOREIGN KEY (ApplicationId) REFERENCES Applications(ApplicationId)
);

-- =============================================
-- Table 6: Payments
-- =============================================
CREATE TABLE Payments (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    LoanId INT NOT NULL,
    PaymentNumber INT NOT NULL,
    PaymentDate DATE NOT NULL,
    PaymentAmount DECIMAL(10,2) NOT NULL,
    PrincipalAmount DECIMAL(10,2) NOT NULL,
    InterestAmount DECIMAL(10,2) NOT NULL,
    PaymentMethod NVARCHAR(20) NOT NULL CHECK (PaymentMethod IN ('ACH', 'Check', 'Online', 'Cash')),
    PaymentStatus NVARCHAR(20) NOT NULL DEFAULT 'Completed' 
        CHECK (PaymentStatus IN ('Pending', 'Completed', 'Failed', 'Reversed')),
    TransactionId NVARCHAR(50),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Payments_Loans FOREIGN KEY (LoanId) REFERENCES Loans(LoanId)
);

-- =============================================
-- Table 7: Documents
-- =============================================
CREATE TABLE Documents (
    DocumentId INT IDENTITY(1,1) PRIMARY KEY,
    ApplicationId INT NOT NULL,
    DocumentType NVARCHAR(50) NOT NULL CHECK (DocumentType IN ('Income Verification', 'Bank Statement', 'Tax Return', 'Employment Letter', 'ID Copy', 'Other')),
    DocumentName NVARCHAR(255) NOT NULL,
    FilePath NVARCHAR(500) NOT NULL,
    FileSize BIGINT NOT NULL,
    ContentType NVARCHAR(100) NOT NULL,
    UploadedBy NVARCHAR(100) NOT NULL,
    UploadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    IsVerified BIT NOT NULL DEFAULT 0,
    VerifiedBy NVARCHAR(100),
    VerificationDate DATETIME2,
    CONSTRAINT FK_Documents_Applications FOREIGN KEY (ApplicationId) REFERENCES Applications(ApplicationId)
);

-- =============================================
-- Table 8: CreditChecks
-- =============================================
CREATE TABLE CreditChecks (
    CreditCheckId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL,
    ApplicationId INT,
    CreditBureau NVARCHAR(20) NOT NULL CHECK (CreditBureau IN ('Experian', 'Equifax', 'TransUnion')),
    CreditScore INT NOT NULL,
    CreditReportData NVARCHAR(MAX), -- JSON format
    CheckDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ExpiryDate DATETIME2 NOT NULL,
    RequestId NVARCHAR(50) NOT NULL,
    ResponseCode NVARCHAR(10),
    IsSuccessful BIT NOT NULL DEFAULT 1,
    ErrorMessage NVARCHAR(500),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_CreditChecks_Customers FOREIGN KEY (CustomerId) REFERENCES Customers(CustomerId),
    CONSTRAINT FK_CreditChecks_Applications FOREIGN KEY (ApplicationId) REFERENCES Applications(ApplicationId)
);

-- =============================================
-- Table 9: IntegrationLogs (Target for DynamoDB migration)
-- =============================================
CREATE TABLE IntegrationLogs (
    LogId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ApplicationId INT,
    LogType NVARCHAR(50) NOT NULL CHECK (LogType IN ('Credit Check', 'Payment Processing', 'Document Upload', 'Email Notification', 'SMS Notification', 'External API')),
    ServiceName NVARCHAR(100) NOT NULL,
    RequestData NVARCHAR(MAX),
    ResponseData NVARCHAR(MAX),
    StatusCode NVARCHAR(10),
    IsSuccess BIT NOT NULL,
    ErrorMessage NVARCHAR(1000),
    ProcessingTimeMs INT,
    LogTimestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
    CorrelationId NVARCHAR(50),
    UserId NVARCHAR(100),
    CONSTRAINT FK_IntegrationLogs_Applications FOREIGN KEY (ApplicationId) REFERENCES Applications(ApplicationId)
);

-- =============================================
-- Table 10: AuditTrail
-- =============================================
CREATE TABLE AuditTrail (
    AuditId BIGINT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(50) NOT NULL,
    RecordId INT NOT NULL,
    Action NVARCHAR(10) NOT NULL CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE')),
    OldValues NVARCHAR(MAX), -- JSON format
    NewValues NVARCHAR(MAX), -- JSON format
    ChangedBy NVARCHAR(100) NOT NULL,
    ChangeDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ApplicationName NVARCHAR(100) DEFAULT 'LoanApplication',
    IPAddress NVARCHAR(45),
    UserAgent NVARCHAR(500)
);

-- =============================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =============================================

-- Customers indexes
CREATE INDEX IX_Customers_CustomerNumber ON Customers(CustomerNumber);
CREATE INDEX IX_Customers_SSN ON Customers(SSN);
CREATE INDEX IX_Customers_Email ON Customers(Email);

-- Applications indexes
CREATE INDEX IX_Applications_ApplicationNumber ON Applications(ApplicationNumber);
CREATE INDEX IX_Applications_CustomerId ON Applications(CustomerId);
CREATE INDEX IX_Applications_Status_Date ON Applications(ApplicationStatus, SubmissionDate);
CREATE INDEX IX_Applications_LoanOfficerId ON Applications(LoanOfficerId);

-- Loans indexes
CREATE INDEX IX_Loans_LoanNumber ON Loans(LoanNumber);
CREATE INDEX IX_Loans_ApplicationId ON Loans(ApplicationId);
CREATE INDEX IX_Loans_Status ON Loans(LoanStatus);
CREATE INDEX IX_Loans_NextPaymentDate ON Loans(NextPaymentDate);

-- Payments indexes
CREATE INDEX IX_Payments_LoanId_Date ON Payments(LoanId, PaymentDate);
CREATE INDEX IX_Payments_PaymentDate ON Payments(PaymentDate);
CREATE INDEX IX_Payments_Status ON Payments(PaymentStatus);

-- IntegrationLogs indexes (optimized for time-series queries)
CREATE INDEX IX_IntegrationLogs_ApplicationId_Timestamp ON IntegrationLogs(ApplicationId, LogTimestamp);
CREATE INDEX IX_IntegrationLogs_LogType_Timestamp ON IntegrationLogs(LogType, LogTimestamp);
CREATE INDEX IX_IntegrationLogs_Timestamp ON IntegrationLogs(LogTimestamp);
CREATE INDEX IX_IntegrationLogs_CorrelationId ON IntegrationLogs(CorrelationId);

-- CreditChecks indexes
CREATE INDEX IX_CreditChecks_CustomerId ON CreditChecks(CustomerId);
CREATE INDEX IX_CreditChecks_ApplicationId ON CreditChecks(ApplicationId);
CREATE INDEX IX_CreditChecks_CheckDate ON CreditChecks(CheckDate);

-- Documents indexes
CREATE INDEX IX_Documents_ApplicationId ON Documents(ApplicationId);
CREATE INDEX IX_Documents_DocumentType ON Documents(DocumentType);
CREATE INDEX IX_Documents_UploadDate ON Documents(UploadDate);

-- AuditTrail indexes
CREATE INDEX IX_AuditTrail_TableName_RecordId ON AuditTrail(TableName, RecordId);
CREATE INDEX IX_AuditTrail_ChangeDate ON AuditTrail(ChangeDate);
CREATE INDEX IX_AuditTrail_ChangedBy ON AuditTrail(ChangedBy);

-- =============================================
-- CONSTRAINTS AND BUSINESS RULES
-- =============================================

-- Ensure loan amount is positive
ALTER TABLE Applications ADD CONSTRAINT CK_Applications_RequestedAmount CHECK (RequestedAmount > 0);
ALTER TABLE Loans ADD CONSTRAINT CK_Loans_ApprovedAmount CHECK (ApprovedAmount > 0);

-- Ensure interest rate is reasonable
ALTER TABLE Loans ADD CONSTRAINT CK_Loans_InterestRate CHECK (InterestRate >= 0 AND InterestRate <= 1);

-- Ensure loan term is reasonable
ALTER TABLE Loans ADD CONSTRAINT CK_Loans_LoanTermMonths CHECK (LoanTermMonths > 0 AND LoanTermMonths <= 360);

-- Ensure payment amounts are positive
ALTER TABLE Payments ADD CONSTRAINT CK_Payments_PaymentAmount CHECK (PaymentAmount > 0);
ALTER TABLE Payments ADD CONSTRAINT CK_Payments_PrincipalAmount CHECK (PrincipalAmount >= 0);
ALTER TABLE Payments ADD CONSTRAINT CK_Payments_InterestAmount CHECK (InterestAmount >= 0);

-- Ensure credit score is in valid range
ALTER TABLE CreditChecks ADD CONSTRAINT CK_CreditChecks_CreditScore CHECK (CreditScore >= 300 AND CreditScore <= 850);

-- Ensure file size is positive
ALTER TABLE Documents ADD CONSTRAINT CK_Documents_FileSize CHECK (FileSize > 0);

-- =============================================
-- COMPUTED COLUMNS
-- =============================================

-- Add computed column for customer full name
ALTER TABLE Customers ADD FullName AS (FirstName + ' ' + LastName);

-- Add computed column for loan age in days
ALTER TABLE Loans ADD LoanAgeDays AS (DATEDIFF(DAY, DisbursementDate, GETDATE()));

-- =============================================
-- BATCH REPORTING TABLES
-- =============================================

-- =============================================
-- Table 11: Daily Application Summary Results
-- =============================================
CREATE TABLE DailyApplicationSummary (
    SummaryId INT IDENTITY(1,1) PRIMARY KEY,
    ReportDate DATE NOT NULL,
    TotalApplications INT NOT NULL,
    ApprovedApplications INT NOT NULL,
    RejectedApplications INT NOT NULL,
    PendingApplications INT NOT NULL,
    ApprovalRate DECIMAL(5,2) NOT NULL,
    TotalRequestedAmount DECIMAL(15,2) NOT NULL,
    AvgRequestedAmount DECIMAL(12,2) NOT NULL,
    AvgProcessingHours DECIMAL(8,2),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_DailyApplicationSummary_ReportDate UNIQUE (ReportDate)
);

-- =============================================
-- Table 12: Monthly Loan Officer Performance Results
-- =============================================
CREATE TABLE MonthlyLoanOfficerPerformance (
    PerformanceId INT IDENTITY(1,1) PRIMARY KEY,
    ReportMonth DATE NOT NULL, -- First day of month
    LoanOfficerId INT NOT NULL,
    LoanOfficerName NVARCHAR(101) NOT NULL,
    BranchName NVARCHAR(100) NOT NULL,
    TotalApplications INT NOT NULL,
    ApprovedApplications INT NOT NULL,
    ApprovalRate DECIMAL(5,2) NOT NULL,
    TotalLoanAmount DECIMAL(15,2) NOT NULL,
    AvgLoanAmount DECIMAL(12,2) NOT NULL,
    AvgProcessingDays DECIMAL(6,2),
    Ranking INT,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_MonthlyLoanOfficerPerformance_LoanOfficer FOREIGN KEY (LoanOfficerId) REFERENCES LoanOfficers(LoanOfficerId),
    CONSTRAINT UK_MonthlyLoanOfficerPerformance_Month_Officer UNIQUE (ReportMonth, LoanOfficerId)
);

-- =============================================
-- Table 13: Weekly Customer Analytics Results
-- =============================================
CREATE TABLE WeeklyCustomerAnalytics (
    AnalyticsId INT IDENTITY(1,1) PRIMARY KEY,
    ReportWeek DATE NOT NULL, -- Monday of the week
    CustomerSegment NVARCHAR(50) NOT NULL,
    CustomerCount INT NOT NULL,
    TotalApplications INT NOT NULL,
    ApprovalRate DECIMAL(5,2) NOT NULL,
    AvgCreditScore INT,
    AvgMonthlyIncome DECIMAL(12,2),
    AvgLoanAmount DECIMAL(12,2),
    TotalPaymentsMade DECIMAL(15,2),
    AvgPaymentAmount DECIMAL(10,2),
    DefaultRate DECIMAL(5,2),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_WeeklyCustomerAnalytics_Week_Segment UNIQUE (ReportWeek, CustomerSegment)
);

-- =============================================
-- Table 14: Daily Branch Performance Results
-- =============================================
CREATE TABLE DailyBranchPerformance (
    PerformanceId INT IDENTITY(1,1) PRIMARY KEY,
    ReportDate DATE NOT NULL,
    BranchId INT NOT NULL,
    BranchCode NVARCHAR(10) NOT NULL,
    BranchName NVARCHAR(100) NOT NULL,
    TotalApplications INT NOT NULL,
    ApprovedApplications INT NOT NULL,
    ApprovalRate DECIMAL(5,2) NOT NULL,
    TotalRequestedAmount DECIMAL(15,2) NOT NULL,
    AvgProcessingHours DECIMAL(8,2),
    ActiveLoanOfficers INT NOT NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_DailyBranchPerformance_Branch FOREIGN KEY (BranchId) REFERENCES Branches(BranchId),
    CONSTRAINT UK_DailyBranchPerformance_Date_Branch UNIQUE (ReportDate, BranchId)
);

-- =============================================
-- Table 15: Monthly Risk Analysis Results
-- =============================================
CREATE TABLE MonthlyRiskAnalysis (
    RiskAnalysisId INT IDENTITY(1,1) PRIMARY KEY,
    ReportMonth DATE NOT NULL, -- First day of month
    CreditScoreRange NVARCHAR(30) NOT NULL,
    TotalApplications INT NOT NULL,
    ApprovedApplications INT NOT NULL,
    ApprovalRate DECIMAL(5,2) NOT NULL,
    AvgDSRRatio DECIMAL(5,2),
    AvgLoanAmount DECIMAL(12,2),
    DefaultRate DECIMAL(5,2),
    TotalLossAmount DECIMAL(15,2),
    RiskScore DECIMAL(5,2),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_MonthlyRiskAnalysis_Month_Range UNIQUE (ReportMonth, CreditScoreRange)
);

-- =============================================
-- Table 16: Batch Job Execution Log
-- =============================================
CREATE TABLE BatchJobExecutionLog (
    ExecutionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    JobName NVARCHAR(100) NOT NULL,
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2,
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Running', 'Completed', 'Failed', 'Cancelled')),
    RecordsProcessed INT,
    ErrorMessage NVARCHAR(MAX),
    DurationSeconds AS (DATEDIFF(SECOND, StartTime, EndTime)),
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE()
);

-- =============================================
-- REPORTING INDEXES FOR PERFORMANCE
-- =============================================

-- Daily Application Summary indexes
CREATE INDEX IX_DailyApplicationSummary_ReportDate ON DailyApplicationSummary(ReportDate);
CREATE INDEX IX_DailyApplicationSummary_ApprovalRate ON DailyApplicationSummary(ApprovalRate);

-- Monthly Loan Officer Performance indexes
CREATE INDEX IX_MonthlyLoanOfficerPerformance_ReportMonth ON MonthlyLoanOfficerPerformance(ReportMonth);
CREATE INDEX IX_MonthlyLoanOfficerPerformance_Ranking ON MonthlyLoanOfficerPerformance(Ranking);
CREATE INDEX IX_MonthlyLoanOfficerPerformance_ApprovalRate ON MonthlyLoanOfficerPerformance(ApprovalRate);

-- Weekly Customer Analytics indexes
CREATE INDEX IX_WeeklyCustomerAnalytics_ReportWeek ON WeeklyCustomerAnalytics(ReportWeek);
CREATE INDEX IX_WeeklyCustomerAnalytics_Segment ON WeeklyCustomerAnalytics(CustomerSegment);

-- Daily Branch Performance indexes
CREATE INDEX IX_DailyBranchPerformance_ReportDate ON DailyBranchPerformance(ReportDate);
CREATE INDEX IX_DailyBranchPerformance_BranchId ON DailyBranchPerformance(BranchId);

-- Monthly Risk Analysis indexes
CREATE INDEX IX_MonthlyRiskAnalysis_ReportMonth ON MonthlyRiskAnalysis(ReportMonth);
CREATE INDEX IX_MonthlyRiskAnalysis_CreditScoreRange ON MonthlyRiskAnalysis(CreditScoreRange);

-- Batch Job Execution Log indexes
CREATE INDEX IX_BatchJobExecutionLog_JobName ON BatchJobExecutionLog(JobName);
CREATE INDEX IX_BatchJobExecutionLog_StartTime ON BatchJobExecutionLog(StartTime);
CREATE INDEX IX_BatchJobExecutionLog_Status ON BatchJobExecutionLog(Status);

PRINT 'Database schema created successfully!';
PRINT 'Total Tables: 16 (10 core + 6 reporting)';
PRINT 'Total Indexes: 30+';
PRINT 'Ready for stored procedures and sample data generation.';
GO