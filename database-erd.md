# Database Entity Relationship Diagram

## Table Relationships Overview

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Branches  │    │  LoanOfficers   │    │   Customers     │
│             │◄──┤                 │    │                 │
│ BranchId(PK)│   │ LoanOfficerId(PK)│    │ CustomerId(PK)  │
│ BranchCode  │   │ BranchId(FK)    │    │ CustomerNumber  │
│ BranchName  │   │ EmployeeId      │    │ FirstName       │
│ Address     │   │ FirstName       │    │ LastName        │
│ ...         │   │ LastName        │    │ MonthlyIncome   │
└─────────────┘   │ ...             │    │ ...             │
                  └─────────────────┘    └─────────────────┘
                           │                       │
                           │                       │
                           ▼                       ▼
                  ┌─────────────────────────────────────────┐
                  │            Applications                 │
                  │                                         │
                  │ ApplicationId(PK)                       │
                  │ CustomerId(FK) ──────────────────────┐  │
                  │ LoanOfficerId(FK) ────────────────┐  │  │
                  │ BranchId(FK) ──────────────────┐  │  │  │
                  │ ApplicationNumber              │  │  │  │
                  │ RequestedAmount                │  │  │  │
                  │ ApplicationStatus              │  │  │  │
                  │ DSRRatio                       │  │  │  │
                  │ ...                            │  │  │  │
                  └────────────────────────────────┼──┼──┼──┘
                           │                       │  │  │
                           │                       │  │  │
                  ┌────────▼────────┐             │  │  │
                  │     Loans       │             │  │  │
                  │                 │             │  │  │
                  │ LoanId(PK)      │             │  │  │
                  │ ApplicationId(FK)│            │  │  │
                  │ LoanNumber      │             │  │  │
                  │ ApprovedAmount  │             │  │  │
                  │ InterestRate    │             │  │  │
                  │ MonthlyPayment  │             │  │  │
                  │ ...             │             │  │  │
                  └─────────────────┘             │  │  │
                           │                       │  │  │
                           │                       │  │  │
                  ┌────────▼────────┐             │  │  │
                  │    Payments     │             │  │  │
                  │                 │             │  │  │
                  │ PaymentId(PK)   │             │  │  │
                  │ LoanId(FK)      │             │  │  │
                  │ PaymentAmount   │             │  │  │
                  │ PaymentDate     │             │  │  │
                  │ PaymentMethod   │             │  │  │
                  │ ...             │             │  │  │
                  └─────────────────┘             │  │  │
                                                  │  │  │
         ┌────────────────────────────────────────┘  │  │
         │                                           │  │
         ▼                                           │  │
┌─────────────────┐                                 │  │
│   Documents     │                                 │  │
│                 │                                 │  │
│ DocumentId(PK)  │                                 │  │
│ ApplicationId(FK)│                                │  │
│ DocumentType    │                                 │  │
│ DocumentName    │                                 │  │
│ FilePath        │                                 │  │
│ ...             │                                 │  │
└─────────────────┘                                 │  │
                                                    │  │
         ┌──────────────────────────────────────────┘  │
         │                                             │
         ▼                                             │
┌─────────────────┐                                   │
│  CreditChecks   │                                   │
│                 │                                   │
│ CreditCheckId(PK)│                                  │
│ CustomerId(FK)  │◄─────────────────────────────────┘
│ ApplicationId(FK)│
│ CreditBureau    │
│ CreditScore     │
│ CheckDate       │
│ ...             │
└─────────────────┘

┌─────────────────┐
│ IntegrationLogs │  ← Target for DynamoDB Migration
│                 │
│ LogId(PK)       │
│ ApplicationId(FK)│
│ LogType         │
│ ServiceName     │
│ RequestData     │
│ ResponseData    │
│ LogTimestamp    │
│ ...             │
└─────────────────┘

┌─────────────────┐
│   AuditTrail    │
│                 │
│ AuditId(PK)     │
│ TableName       │
│ RecordId        │
│ Action          │
│ OldValues       │
│ NewValues       │
│ ChangedBy       │
│ ChangeDate      │
│ ...             │
└─────────────────┘
```

## Key Relationships

### Primary Relationships
1. **Branches** (1) → (M) **LoanOfficers**
2. **Customers** (1) → (M) **Applications**
3. **LoanOfficers** (1) → (M) **Applications**
4. **Branches** (1) → (M) **Applications**
5. **Applications** (1) → (1) **Loans**
6. **Loans** (1) → (M) **Payments**
7. **Applications** (1) → (M) **Documents**
8. **Customers** (1) → (M) **CreditChecks**
9. **Applications** (1) → (M) **CreditChecks**
10. **Applications** (1) → (M) **IntegrationLogs**

### Migration Considerations

#### Phase 1: SQL Server → RDS SQL Server
- **Impact**: None - Full compatibility
- **Foreign Keys**: All preserved
- **Indexes**: All preserved

#### Phase 2: RDS SQL Server → Aurora PostgreSQL
- **Schema Changes**: Data type conversions required
- **Foreign Keys**: Need recreation with PostgreSQL syntax
- **Indexes**: Need recreation, some optimization opportunities

#### Phase 3: IntegrationLogs → DynamoDB
- **Table Removal**: IntegrationLogs table migrated out
- **Foreign Key Impact**: Remove FK constraint from Applications
- **Access Pattern**: Time-based queries optimized for NoSQL

## Table Sizes (Estimated)
- **Branches**: ~50 records
- **LoanOfficers**: ~200 records  
- **Customers**: ~1,000 records
- **Applications**: ~5,000 records
- **Loans**: ~2,000 records
- **Payments**: ~50,000 records
- **Documents**: ~15,000 records
- **CreditChecks**: ~5,000 records
- **IntegrationLogs**: ~100,000 records (High volume for DynamoDB demo)
- **AuditTrail**: ~25,000 records

**Total Records**: ~200,000+ records for realistic workshop experience