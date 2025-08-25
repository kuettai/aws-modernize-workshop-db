# Application Architecture and Database Design
## Personal Loan Processing System

### Application Overview

**Business Purpose**: Process personal loan applications with automated debt-service-ratio (DSR) calculations and credit check integrations for financial compliance.

**Architecture Pattern**: 3-tier web application with RESTful API, business logic layer, and data access layer using Entity Framework Core.

### System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │───▶│  .NET 9 Web API │───▶│  SQL Server DB  │
│   (Swagger UI)  │    │  (Controllers)  │    │  (Entity Data)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │ Business Logic  │
                       │ (Services)      │
                       └─────────────────┘
```

### Core Components

#### 1. Controllers Layer
- **LoanController**: Loan application CRUD operations
- **CustomerController**: Customer management
- **ReportController**: Financial reporting and analytics

#### 2. Business Services
- **LoanService**: DSR calculations and approval logic
- **CreditCheckService**: External credit bureau integration
- **ValidationService**: Business rule validation

#### 3. Data Access Layer
- **Entity Framework Core**: ORM with Code First approach
- **Repository Pattern**: Abstracted data access
- **Unit of Work**: Transaction management

### Database Schema

#### Core Tables

**LoanApplications** (Primary Entity)
```sql
CREATE TABLE LoanApplications (
    LoanId UNIQUEIDENTIFIER PRIMARY KEY,
    CustomerId UNIQUEIDENTIFIER NOT NULL,
    LoanAmount DECIMAL(18,2) NOT NULL,
    InterestRate DECIMAL(5,4) NOT NULL,
    LoanTerm INT NOT NULL,
    ApplicationDate DATETIME2 NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    DebtServiceRatio DECIMAL(5,4),
    ApprovalDate DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);
```

**Customers**
```sql
CREATE TABLE Customers (
    CustomerId UNIQUEIDENTIFIER PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    MonthlyIncome DECIMAL(18,2) NOT NULL,
    MonthlyDebt DECIMAL(18,2) NOT NULL,
    CreditScore INT,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);
```

**IntegrationLogs** (High-Volume Table)
```sql
CREATE TABLE IntegrationLogs (
    LogId UNIQUEIDENTIFIER PRIMARY KEY,
    ServiceName NVARCHAR(100) NOT NULL,
    RequestData NVARCHAR(MAX),
    ResponseData NVARCHAR(MAX),
    StatusCode INT NOT NULL,
    ExecutionTime INT NOT NULL,
    LogTimestamp DATETIME2 DEFAULT GETDATE(),
    ErrorMessage NVARCHAR(MAX)
);
```

#### Stored Procedures

**1. Simple Procedures** (CRUD Operations)
- `sp_CreateLoanApplication`: Insert new loan application
- `sp_UpdateLoanStatus`: Update application status
- `sp_GetCustomerLoans`: Retrieve customer loan history

**2. Complex Procedure** (`sp_CalculateLoanMetrics`)
- **Purpose**: Calculate comprehensive loan metrics with DSR analysis
- **Features**: CTEs, window functions, temp tables, cursors, dynamic SQL
- **Size**: 200+ lines with advanced T-SQL patterns

### Data Patterns and Volume

**Transaction Patterns**:
- **LoanApplications**: 50-100 inserts/day, frequent status updates
- **Customers**: Low insert volume, occasional updates
- **IntegrationLogs**: 10,000+ inserts/day (high-volume operational data)

**Query Patterns**:
- **OLTP**: Real-time loan processing and customer lookups
- **Reporting**: Monthly/quarterly loan portfolio analysis
- **Audit**: Time-based log queries for compliance

### Integration Points

**External Services**:
- **Credit Bureau API**: Real-time credit score retrieval
- **Payment Gateway**: Loan disbursement processing
- **Notification Service**: Email/SMS alerts

**Logging Strategy**:
- **Application Logs**: Structured logging with Serilog
- **Integration Logs**: Database-stored for audit compliance
- **Performance Metrics**: Custom counters and timers

### Migration Considerations

#### Phase 1: RDS Migration Readiness
- **Compatibility**: 100% T-SQL compatibility maintained
- **Performance**: Baseline metrics established
- **Backup Strategy**: Point-in-time recovery enabled

#### Phase 2: PostgreSQL Conversion Challenges
- **Schema Differences**: UNIQUEIDENTIFIER → UUID conversion
- **Stored Procedures**: Complex logic requires refactoring
- **Entity Framework**: Provider change from SqlServer to Npgsql

#### Phase 3: DynamoDB Integration Opportunities
- **IntegrationLogs**: Perfect candidate for NoSQL migration
- **Access Patterns**: Time-based queries with service filtering
- **Cost Optimization**: 98% reduction for high-volume logs

### Performance Characteristics

**Current Baseline** (SQL Server):
- **Average Response Time**: 150ms for loan queries
- **Peak Throughput**: 500 requests/minute
- **Database Size**: 2.5GB with 200K loan records
- **Log Volume**: 50MB/day integration logs

**Optimization Targets**:
- **Phase 1**: Maintain current performance
- **Phase 2**: 20% improvement with PostgreSQL
- **Phase 3**: 70% improvement for log queries with DynamoDB

### Security and Compliance

**Data Protection**:
- **Encryption**: TDE for database, HTTPS for API
- **PII Handling**: Customer data encrypted at rest
- **Audit Trail**: Complete transaction logging

**Compliance Requirements**:
- **Financial Regulations**: SOX compliance for loan data
- **Data Retention**: 7-year retention for audit logs
- **Access Control**: Role-based permissions

---

**Q Developer Integration Points**:
- Analyze current architecture patterns
- Identify modernization opportunities
- Generate migration scripts and validation queries
- Optimize performance and apply AWS best practices