# Financial Services Loan Application - Architecture Design

## Application Overview
A Personal Loan Processing System built with .NET MVC and SQL Server, designed to demonstrate database modernization patterns in AWS workshops.

## Business Requirements
- **Loan Type**: Personal Loans only
- **Core Features**: 
  - Loan application submission and processing
  - Salary information collection and validation
  - DSR (Debt Service Ratio) calculation
  - Credit check integration (mockup)
  - Application status tracking
  - Document management

## System Architecture

### Application Layer (.NET MVC)
```
┌─────────────────────────────────────────┐
│              Presentation Layer          │
│  ┌─────────────┐  ┌─────────────────────┐│
│  │   Web UI    │  │    API Controllers  ││
│  │ (MVC Views) │  │   (REST Endpoints)  ││
│  └─────────────┘  └─────────────────────┘│
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│               Business Layer            │
│  ┌─────────────┐  ┌─────────────────────┐│
│  │  Services   │  │     Validators      ││
│  │ (Loan Logic)│  │  (Business Rules)   ││
│  └─────────────┘  └─────────────────────┘│
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│                Data Layer               │
│  ┌─────────────┐  ┌─────────────────────┐│
│  │ Repositories│  │   Entity Framework  ││
│  │ (Data Access)│  │     (ORM Layer)     ││
│  └─────────────┘  └─────────────────────┘│
└─────────────────────────────────────────┘
```

### Database Layer (SQL Server)
```
┌─────────────────────────────────────────┐
│              SQL Server Database         │
│                                         │
│  Core Tables:                           │
│  • Applications                         │
│  • Customers                            │
│  • Loans                                │
│  • Payments                             │
│  • Documents                            │
│                                         │
│  Supporting Tables:                     │
│  • IntegrationLogs                      │
│  • CreditChecks                         │
│  • LoanOfficers                         │
│  • Branches                             │
│  • AuditTrail                           │
│                                         │
│  Stored Procedures:                     │
│  • 3 Simple SPs (CRUD operations)      │
│  • 1 Complex SP (DSR calculation)      │
└─────────────────────────────────────────┘
```

## Core Business Processes

### 1. Loan Application Flow
```
Customer → Application Form → Validation → DSR Calculation → Credit Check → Decision
```

### 2. DSR Calculation Logic
```
DSR = (Total Monthly Debt Payments / Monthly Gross Income) × 100
- Maximum DSR threshold: 40%
- Includes existing loans, credit cards, other obligations
- Considers proposed loan payment
```

### 3. Credit Check Integration
```
Application → External Credit API (Mock) → Credit Score → Risk Assessment → Decision
```

## Technical Specifications

### .NET Application Structure
```
LoanApplication/
├── Controllers/
│   ├── ApplicationController.cs
│   ├── CustomerController.cs
│   └── LoanController.cs
├── Models/
│   ├── Application.cs
│   ├── Customer.cs
│   └── Loan.cs
├── Services/
│   ├── LoanService.cs
│   ├── DSRCalculationService.cs
│   └── CreditCheckService.cs
├── Repositories/
│   ├── ApplicationRepository.cs
│   └── CustomerRepository.cs
└── Views/
    ├── Application/
    ├── Customer/
    └── Loan/
```

### Database Schema Overview
```
Customers (1) ──→ (M) Applications (1) ──→ (1) Loans
    │                    │                      │
    │                    ↓                      ↓
    │              Documents (M)          Payments (M)
    │                    │
    ↓                    ↓
CreditChecks (M)   IntegrationLogs (M)
```

### Key Features for Migration Demonstration

1. **Complex Relationships**: Foreign keys across multiple tables
2. **Advanced SQL Features**: CTEs, window functions, cursors in stored procedures
3. **High-Volume Data**: IntegrationLogs table for DynamoDB migration
4. **Business Logic**: DSR calculation with multiple data sources
5. **External Integration**: Credit check API calls with logging

## Migration Readiness Factors

### Phase 1 (SQL Server → RDS SQL Server)
- **Compatibility**: 100% compatible
- **Migration Method**: Backup/restore or DMS
- **Challenges**: Minimal, mainly connection strings

### Phase 2 (RDS SQL Server → Aurora PostgreSQL)
- **Schema Conversion**: Required for data types
- **Stored Procedures**: Major conversion needed
- **Application Changes**: Connection provider, SQL syntax

### Phase 3 (Table → DynamoDB)
- **Target Table**: IntegrationLogs (time-series data)
- **Access Pattern**: Time-based queries, high write volume
- **Design**: Partition by ApplicationId, Sort by Timestamp

## Sample Data Requirements
- **Customers**: 100 records with varied financial profiles
- **Applications**: 500 records across different statuses
- **Loans**: 200 approved loans with payment histories
- **IntegrationLogs**: 10,000+ records for DynamoDB migration demo
- **Documents**: Various file types and sizes

## Performance Considerations
- **Indexes**: Optimized for common query patterns
- **Stored Procedures**: Performance-tuned with execution plans
- **Data Volume**: Realistic but manageable for workshop environment
- **Response Times**: Sub-second for typical operations

---

**Architecture Status**: ✅ Complete - Ready for implementation
**Next Step**: Step 1.2 - Create database schema with ~10 tables