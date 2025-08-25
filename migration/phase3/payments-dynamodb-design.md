# DynamoDB Payments Table Design
## Optimal NoSQL Structure for High-Volume Payment Data

### 🎯 Design Objectives
- Optimize for customer payment history queries (40% of traffic)
- Support payment status monitoring (25% of traffic)
- Enable efficient loan payment tracking (20% of traffic)
- Minimize costs while maintaining performance
- Support future scaling requirements

### 🏗️ Primary Table Structure

#### Table Definition
```json
{
  "TableName": "Payments",
  "BillingMode": "PAY_PER_REQUEST",
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
    },
    {
      "AttributeName": "PaymentMethod",
      "AttributeType": "S"
    }
  ]
}
```

#### Sort Key Design Strategy
```
PaymentDateId Format: "YYYY-MM-DDTHH:mm:ssZ#PaymentId"
Examples:
- "2024-01-15T10:30:00Z#12345"
- "2024-01-15T14:22:15Z#12346"
- "2024-01-16T09:15:30Z#12347"

Benefits:
✅ Natural chronological ordering (newest first when queried DESC)
✅ Unique identifier combination prevents duplicates
✅ Efficient range queries by date
✅ Supports pagination with LastEvaluatedKey
✅ Human-readable for debugging
```

### 📊 Global Secondary Indexes (GSI)

#### GSI 1: Payment Status Index
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
  },
  "BillingMode": "PAY_PER_REQUEST"
}
```

**Use Cases:**
- Get all pending payments: `PaymentStatus = "Pending"`
- Get failed payments in date range: `PaymentStatus = "Failed" AND PaymentDate BETWEEN start AND end`
- Monitor payment processing status across all customers

#### GSI 2: Loan Payment Index
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
  },
  "BillingMode": "PAY_PER_REQUEST"
}
```

**Use Cases:**
- Get all payments for specific loan: `LoanId = 12345`
- Get recent payments for loan: `LoanId = 12345 AND PaymentDateId >= "2024-01-01"`
- Track loan payment history chronologically

#### GSI 3: Payment Method Analysis Index
```json
{
  "IndexName": "PaymentMethodIndex",
  "KeySchema": [
    {
      "AttributeName": "PaymentMethod",
      "KeyType": "HASH"
    },
    {
      "AttributeName": "PaymentDate",
      "KeyType": "RANGE"
    }
  ],
  "Projection": {
    "ProjectionType": "INCLUDE",
    "NonKeyAttributes": ["PaymentAmount", "PaymentStatus", "CustomerId"]
  },
  "BillingMode": "PAY_PER_REQUEST"
}
```

**Use Cases:**
- Analyze payment methods: `PaymentMethod = "CreditCard"`
- Payment method trends over time
- Method-specific failure analysis

### 🗂️ Item Structure

#### Complete Item Example
```json
{
  "CustomerId": {"N": "12345"},
  "PaymentDateId": {"S": "2024-01-15T10:30:00Z#67890"},
  "PaymentId": {"N": "67890"},
  "LoanId": {"N": "54321"},
  "PaymentAmount": {"N": "1250.00"},
  "PaymentDate": {"S": "2024-01-15T10:30:00Z"},
  "PaymentMethod": {"S": "BankTransfer"},
  "PaymentStatus": {"S": "Completed"},
  "TransactionReference": {"S": "TXN-2024-0115-001"},
  "ProcessedDate": {"S": "2024-01-15T10:32:15Z"},
  "ProcessingTimeMs": {"N": "2150"},
  "CreatedDate": {"S": "2024-01-15T10:30:00Z"},
  "UpdatedDate": {"S": "2024-01-15T10:32:15Z"},
  "TTL": {"N": "1735689000"}
}
```

#### Data Type Mappings
```
PostgreSQL → DynamoDB
INT → N (Number)
DECIMAL(18,2) → N (Number as string: "1250.00")
DATETIME2 → S (ISO 8601 string: "2024-01-15T10:30:00Z")
VARCHAR/NVARCHAR → S (String)
```

### 🔍 Query Patterns Implementation

#### Pattern 1: Customer Payment History (40% of queries)
```javascript
// Get all payments for customer, newest first
const params = {
  TableName: 'Payments',
  KeyConditionExpression: 'CustomerId = :customerId',
  ExpressionAttributeValues: {
    ':customerId': { N: '12345' }
  },
  ScanIndexForward: false, // DESC order
  Limit: 50
};
```

#### Pattern 2: Payment Status Monitoring (25% of queries)
```javascript
// Get all pending payments from last 7 days
const params = {
  TableName: 'Payments',
  IndexName: 'PaymentStatusIndex',
  KeyConditionExpression: 'PaymentStatus = :status AND PaymentDate >= :startDate',
  ExpressionAttributeValues: {
    ':status': { S: 'Pending' },
    ':startDate': { S: '2024-01-08T00:00:00Z' }
  }
};
```

#### Pattern 3: Loan Payment Tracking (20% of queries)
```javascript
// Get all payments for specific loan
const params = {
  TableName: 'Payments',
  IndexName: 'LoanPaymentIndex',
  KeyConditionExpression: 'LoanId = :loanId',
  ExpressionAttributeValues: {
    ':loanId': { N: '54321' }
  },
  ScanIndexForward: false
};
```

#### Pattern 4: Recent Customer Payments (15% of queries)
```javascript
// Get customer payments from last 30 days
const params = {
  TableName: 'Payments',
  KeyConditionExpression: 'CustomerId = :customerId AND PaymentDateId >= :startDate',
  ExpressionAttributeValues: {
    ':customerId': { N: '12345' },
    ':startDate': { S: '2024-01-01T00:00:00Z#0' }
  },
  ScanIndexForward: false
};
```

### 📈 Performance Optimization

#### Hot Partition Avoidance
```
✅ CustomerId as partition key provides good distribution
✅ 50,000+ customers spread load evenly
✅ No single customer dominates traffic
✅ Time-based sort key prevents hot spots
```

#### Query Efficiency
```
Primary Table Queries:
- Customer payment history: Single partition read
- Date range for customer: Range query on sort key
- Single payment lookup: Point query

GSI Queries:
- Payment status: Distributed across status values
- Loan payments: Distributed across loan IDs
- Payment methods: Distributed across method types
```

#### Throughput Considerations
```
Expected Load:
- Writes: ~1,000 payments/hour (peak)
- Reads: ~5,000 queries/hour (peak)
- Storage: ~500KB per 1,000 payments

Pay-per-request Benefits:
✅ No capacity planning required
✅ Automatic scaling for traffic spikes
✅ Cost-effective for variable workloads
✅ No throttling during peak periods
```

### 💰 Cost Analysis

#### Storage Costs (Monthly)
```
Item Size Calculation:
- Base attributes: ~200 bytes per payment
- 500,000 payments = ~100MB
- DynamoDB storage: $0.25/GB/month
- Monthly storage cost: ~$0.025

GSI Storage:
- 3 GSIs × 100MB = 300MB additional
- GSI storage cost: ~$0.075
- Total storage: ~$0.10/month
```

#### Request Costs (Monthly)
```
Write Requests:
- 50,000 payments/month
- $1.25 per million writes
- Write cost: ~$0.06/month

Read Requests:
- 150,000 reads/month (3:1 read/write ratio)
- $0.25 per million reads
- Read cost: ~$0.04/month

Total Monthly Cost: ~$0.20
```

#### Cost Comparison
```
Component          | PostgreSQL | DynamoDB | Savings
-------------------|------------|----------|--------
Storage (500K)     | $12        | $0.10    | 99.2%
Operations         | $25        | $0.10    | 99.6%
Maintenance        | $15        | $0        | 100%
Total Monthly      | $52        | $0.20    | 99.6%
```

### 🔧 Data Lifecycle Management

#### TTL Configuration
```json
{
  "TimeToLiveSpecification": {
    "AttributeName": "TTL",
    "Enabled": true
  }
}
```

#### TTL Strategy
```javascript
// Set TTL for 7 years (regulatory requirement)
const ttlTimestamp = Math.floor(Date.now() / 1000) + (7 * 365 * 24 * 60 * 60);

const item = {
  // ... other attributes
  TTL: { N: ttlTimestamp.toString() }
};
```

### 🛡️ Security Considerations

#### IAM Policy Template
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:region:account:table/Payments",
        "arn:aws:dynamodb:region:account:table/Payments/index/*"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${aws:userid}"]
        }
      }
    }
  ]
}
```

#### Encryption Settings
```json
{
  "SSESpecification": {
    "Enabled": true,
    "SSEType": "KMS",
    "KMSMasterKeyId": "alias/dynamodb-payments-key"
  }
}
```

### 📊 Monitoring and Alerting

#### Key Metrics to Monitor
```
Performance Metrics:
- SuccessfulRequestLatency
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- ThrottledRequests

Business Metrics:
- Payment processing volume
- Failed payment rate
- Average payment amount
- Payment method distribution
```

#### CloudWatch Alarms
```json
{
  "AlarmName": "Payments-HighLatency",
  "MetricName": "SuccessfulRequestLatency",
  "Threshold": 100,
  "ComparisonOperator": "GreaterThanThreshold",
  "EvaluationPeriods": 2,
  "Period": 300
}
```

### 🎯 Success Criteria

#### Performance Targets
- [ ] **Query Latency**: < 50ms for 95% of requests
- [ ] **Throughput**: Handle 10x current payment volume
- [ ] **Availability**: 99.9% uptime
- [ ] **Consistency**: Zero data loss during migration

#### Cost Targets
- [ ] **Storage Cost**: < $1/month for 500K payments
- [ ] **Request Cost**: < $5/month for current traffic
- [ ] **Total Savings**: > 90% vs PostgreSQL
- [ ] **Scalability**: Linear cost scaling with volume

#### Operational Targets
- [ ] **Monitoring**: Complete CloudWatch dashboard
- [ ] **Alerting**: Proactive issue detection
- [ ] **Backup**: Point-in-time recovery enabled
- [ ] **Security**: Encryption at rest and in transit

The DynamoDB Payments table design is optimized for performance, cost-effectiveness, and scalability!