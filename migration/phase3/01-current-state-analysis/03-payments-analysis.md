# Payments Table Analysis for DynamoDB Migration
## Phase 3 Enhancement: Multi-Table NoSQL Migration

### 🎯 Analysis Objectives
- Analyze Payments table structure and relationships
- Identify access patterns for DynamoDB design
- Design optimal partition and sort key strategy
- Plan Global Secondary Indexes (GSI) for query patterns

### 📊 Current Payments Table Structure

#### SQL Server/PostgreSQL Schema
```sql
-- Payments table structure
CREATE TABLE Payments (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL,
    LoanId INT NOT NULL,
    PaymentAmount DECIMAL(18,2) NOT NULL,
    PaymentDate DATETIME2 NOT NULL,
    PaymentMethod VARCHAR(50) NOT NULL, -- 'BankTransfer', 'CreditCard', 'Cash', 'Check'
    PaymentStatus VARCHAR(20) NOT NULL, -- 'Pending', 'Completed', 'Failed', 'Refunded'
    TransactionReference VARCHAR(100),
    ProcessedDate DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    UpdatedDate DATETIME2,
    
    FOREIGN KEY (CustomerId) REFERENCES Customers(CustomerId),
    FOREIGN KEY (LoanId) REFERENCES Loans(LoanId)
);

-- Indexes for performance
CREATE INDEX IX_Payments_CustomerId ON Payments(CustomerId);
CREATE INDEX IX_Payments_LoanId ON Payments(LoanId);
CREATE INDEX IX_Payments_PaymentDate ON Payments(PaymentDate);
CREATE INDEX IX_Payments_Status ON Payments(PaymentStatus);
```

#### Sample Data Analysis
```sql
-- Analyze payment patterns
SELECT 
    PaymentMethod,
    PaymentStatus,
    COUNT(*) as PaymentCount,
    AVG(PaymentAmount) as AvgAmount,
    MIN(PaymentDate) as EarliestPayment,
    MAX(PaymentDate) as LatestPayment
FROM Payments 
GROUP BY PaymentMethod, PaymentStatus
ORDER BY PaymentCount DESC;

-- Customer payment frequency
SELECT 
    CustomerId,
    COUNT(*) as PaymentCount,
    SUM(PaymentAmount) as TotalPaid,
    MIN(PaymentDate) as FirstPayment,
    MAX(PaymentDate) as LastPayment
FROM Payments 
GROUP BY CustomerId
ORDER BY PaymentCount DESC
LIMIT 10;
```

### 🔍 Access Pattern Analysis

#### Primary Access Patterns
1. **Customer Payment History**: Get all payments for a specific customer
2. **Recent Payments**: Get payments within date range for a customer
3. **Payment Status Queries**: Find payments by status (Pending, Failed)
4. **Loan Payment Tracking**: Get all payments for a specific loan
5. **Payment Method Analysis**: Query payments by payment method
6. **Daily Payment Processing**: Get all payments for a specific date

#### Query Frequency Analysis
```sql
-- Most common query patterns (estimated frequency)
-- 1. Customer payment history: 40% of queries
SELECT * FROM Payments WHERE CustomerId = ? ORDER BY PaymentDate DESC;

-- 2. Payment status monitoring: 25% of queries  
SELECT * FROM Payments WHERE PaymentStatus = 'Pending' AND PaymentDate >= ?;

-- 3. Loan payment tracking: 20% of queries
SELECT * FROM Payments WHERE LoanId = ? ORDER BY PaymentDate DESC;

-- 4. Date range queries: 15% of queries
SELECT * FROM Payments WHERE PaymentDate BETWEEN ? AND ? ORDER BY PaymentDate DESC;
```

### 🏗️ DynamoDB Table Design

#### Primary Table Structure
```json
{
  "TableName": "Payments",
  "KeySchema": [
    {
      "AttributeName": "CustomerId",
      "KeyType": "HASH"
    },
    {
      "AttributeName": "PaymentDateId",
      "KeyType": "RANGE"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "CustomerId",
      "AttributeType": "N"
    },
    {
      "AttributeName": "PaymentDateId",
      "AttributeType": "S"
    },
    {
      "AttributeName": "PaymentStatus",
      "AttributeType": "S"
    },
    {
      "AttributeName": "LoanId",
      "AttributeType": "N"
    },
    {
      "AttributeName": "PaymentDate",
      "AttributeType": "S"
    }
  ]
}
```

#### Sort Key Design Strategy
```
PaymentDateId = PaymentDate#PaymentId
Example: "2024-01-15T10:30:00Z#12345"

Benefits:
- Natural chronological ordering
- Unique identifier combination
- Efficient range queries by date
- Supports pagination
```

#### Global Secondary Indexes (GSI)

**GSI 1: Payment Status Index**
```json
{
  "IndexName": "PaymentStatusIndex",
  "KeySchema": [
    {
      "AttributeName": "PaymentStatus",
      "KeyType": "HASH"
    },
    {
      "AttributeName": "PaymentDate",
      "KeyType": "RANGE"
    }
  ],
  "Projection": {
    "ProjectionType": "ALL"
  }
}
```

**GSI 2: Loan Payment Index**
```json
{
  "IndexName": "LoanPaymentIndex", 
  "KeySchema": [
    {
      "AttributeName": "LoanId",
      "KeyType": "HASH"
    },
    {
      "AttributeName": "PaymentDateId",
      "KeyType": "RANGE"
    }
  ],
  "Projection": {
    "ProjectionType": "ALL"
  }
}
```

### 📈 Performance & Cost Analysis

#### Expected Performance Improvements
```
Query Type                 | PostgreSQL | DynamoDB | Improvement
---------------------------|------------|----------|------------
Customer payment history   | 150ms      | 45ms     | 70% faster
Payment status queries     | 200ms      | 60ms     | 70% faster
Recent payments (30 days)  | 180ms      | 50ms     | 72% faster
Loan payment tracking      | 160ms      | 55ms     | 66% faster
```

#### Cost Comparison (Monthly)
```
Component                  | PostgreSQL | DynamoDB | Savings
---------------------------|------------|----------|--------
Storage (500K payments)    | $45        | $12      | 73%
Read operations (1M/month) | $15        | $8       | 47%
Write operations (50K/month)| $8         | $6       | 25%
Total Monthly Cost         | $68        | $26      | 62%
```

### 🔄 Migration Strategy

#### Data Transformation Logic
```csharp
// PostgreSQL to DynamoDB transformation
public class PaymentTransformer
{
    public Dictionary<string, AttributeValue> TransformPayment(Payment payment)
    {
        return new Dictionary<string, AttributeValue>
        {
            ["CustomerId"] = new AttributeValue { N = payment.CustomerId.ToString() },
            ["PaymentDateId"] = new AttributeValue { S = $"{payment.PaymentDate:yyyy-MM-ddTHH:mm:ssZ}#{payment.PaymentId}" },
            ["PaymentId"] = new AttributeValue { N = payment.PaymentId.ToString() },
            ["LoanId"] = new AttributeValue { N = payment.LoanId.ToString() },
            ["PaymentAmount"] = new AttributeValue { N = payment.PaymentAmount.ToString("F2") },
            ["PaymentDate"] = new AttributeValue { S = payment.PaymentDate.ToString("yyyy-MM-ddTHH:mm:ssZ") },
            ["PaymentMethod"] = new AttributeValue { S = payment.PaymentMethod },
            ["PaymentStatus"] = new AttributeValue { S = payment.PaymentStatus },
            ["TransactionReference"] = new AttributeValue { S = payment.TransactionReference ?? "" },
            ["ProcessedDate"] = new AttributeValue { S = payment.ProcessedDate?.ToString("yyyy-MM-ddTHH:mm:ssZ") ?? "" },
            ["CreatedDate"] = new AttributeValue { S = payment.CreatedDate.ToString("yyyy-MM-ddTHH:mm:ssZ") },
            ["UpdatedDate"] = new AttributeValue { S = payment.UpdatedDate?.ToString("yyyy-MM-ddTHH:mm:ssZ") ?? "" }
        };
    }
}
```

#### Migration Phases
1. **Phase 1**: Create DynamoDB table and GSIs
2. **Phase 2**: Implement dual-write pattern in application
3. **Phase 3**: Bulk migrate existing payment data
4. **Phase 4**: Switch reads to DynamoDB
5. **Phase 5**: Remove PostgreSQL payment queries

### 🎯 Success Criteria

#### Technical Validation
- [ ] **Data Integrity**: 100% of payments migrated without loss
- [ ] **Query Performance**: All queries respond within 100ms
- [ ] **Consistency**: Dual-write maintains data consistency
- [ ] **Scalability**: Handle 10x payment volume without degradation

#### Business Validation  
- [ ] **Cost Reduction**: Achieve 60%+ cost savings for payment operations
- [ ] **Performance**: 70%+ improvement in payment query response times
- [ ] **Reliability**: 99.9% availability for payment operations
- [ ] **Compliance**: Maintain audit trail and data integrity

### 🔧 Risk Mitigation

#### Identified Risks
1. **Data Consistency**: Dual-write complexity
2. **Query Patterns**: New access patterns not anticipated
3. **Performance**: DynamoDB hot partitions
4. **Cost**: Unexpected read/write patterns

#### Mitigation Strategies
1. **Consistency**: Implement compensation patterns and monitoring
2. **Flexibility**: Design GSIs to support multiple query patterns
3. **Distribution**: Use customer ID for even partition distribution
4. **Monitoring**: CloudWatch alarms for cost and performance metrics

### 🚀 Next Steps: Deploy DynamoDB Tables

Both IntegrationLogs and Payments tables are now included in the CloudFormation template:

#### Deploy Both Tables with Single Command
```powershell
# Navigate to scripts folder
cd migration/phase3/03-migration-steps/scripts

# Deploy both DynamoDB tables
./deploy-dynamodb-table-simple.ps1 -Environment dev
```

#### Verify Tables Created
```bash
# Check IntegrationLogs table
aws dynamodb describe-table --table-name "LoanApp-IntegrationLogs-dev"

# Check Payments table  
aws dynamodb describe-table --table-name "LoanApp-Payments-dev"
```

**✅ Checkpoint**: Both tables should show "ACTIVE" status before proceeding to repository implementation.

**Next**: [DynamoDB Table Design](../02-table-design/01-integration-logs-design.md)