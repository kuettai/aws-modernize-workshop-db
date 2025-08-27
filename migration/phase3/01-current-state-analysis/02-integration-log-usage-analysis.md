# Integration Log Usage Analysis
## Phase 3: DynamoDB Migration - Access Pattern Analysis

### 🎯 Objective
Analyze how IntegrationLog is currently used in the application to design optimal DynamoDB access patterns.

### 📊 Current Usage Analysis

#### 1. Direct Database Access Patterns

**Statistics Dashboard (DocsController.cs)**
```csharp
// Current implementation
IntegrationLogs = await _context.IntegrationLogs.CountAsync(),

// Likely expanded queries (not yet implemented):
// - Count by LogType (API, ERROR, INFO, DEBUG)
// - Count by ServiceName 
// - Count by time period (last 24h, 7d, 30d)
// - Average ProcessingTimeMs by service
```

**Inferred Query Patterns from Schema:**
```sql
-- Time-based queries (most common for logging)
SELECT * FROM IntegrationLogs 
WHERE LogTimestamp >= DATEADD(hour, -24, GETDATE())
ORDER BY LogTimestamp DESC;

-- Application-specific logging
SELECT * FROM IntegrationLogs 
WHERE ApplicationId = @appId 
ORDER BY LogTimestamp DESC;

-- Service performance analysis
SELECT ServiceName, AVG(ProcessingTimeMs), COUNT(*) 
FROM IntegrationLogs 
WHERE LogTimestamp >= DATEADD(day, -7, GETDATE())
GROUP BY ServiceName;

-- Error investigation
SELECT * FROM IntegrationLogs 
WHERE IsSuccess = 0 
AND LogTimestamp >= DATEADD(hour, -1, GETDATE())
ORDER BY LogTimestamp DESC;

-- Correlation tracking
SELECT * FROM IntegrationLogs 
WHERE CorrelationId = @correlationId 
ORDER BY LogTimestamp;
```

### 🔍 Access Pattern Analysis for DynamoDB Design

#### Primary Access Patterns (80% of queries)
1. **Time-Range Queries** (Most frequent)
   - Get logs from last 1 hour, 24 hours, 7 days
   - Usually with additional filters (service, application, error status)

2. **Service-Specific Queries**
   - Get all logs for CreditCheckService in time range
   - Performance analysis per service

3. **Application Journey Tracking**
   - Get all logs for specific ApplicationId
   - Follow loan application processing flow

#### Secondary Access Patterns (20% of queries)
4. **Error Investigation**
   - Get all failed requests in time period
   - Filter by error type or service

5. **Correlation Tracking**
   - Follow request flow using CorrelationId
   - Distributed tracing scenarios

6. **Performance Monitoring**
   - Aggregate ProcessingTimeMs by service/time
   - Identify slow services

### 🏗️ Recommended DynamoDB Table Design

#### Primary Table: `LoanApp-IntegrationLogs`

**Partition Key**: `ServiceName-Date` (e.g., "CreditCheckService-2024-01-15")
**Sort Key**: `LogTimestamp#LogId` (e.g., "2024-01-15T10:30:00Z#12345")

**Attributes**:
```json
{
  "PK": "CreditCheckService-2024-01-15",
  "SK": "2024-01-15T10:30:00.123Z#12345",
  "LogId": 12345,
  "ApplicationId": 1001,
  "LogType": "API",
  "ServiceName": "CreditCheckService",
  "RequestData": "{...json...}",
  "ResponseData": "{...json...}",
  "StatusCode": "200",
  "IsSuccess": true,
  "ProcessingTimeMs": 245,
  "LogTimestamp": "2024-01-15T10:30:00.123Z",
  "CorrelationId": "abc-123-def",
  "UserId": "user123",
  "TTL": 1736956200
}
```

#### Global Secondary Indexes (GSIs)

**GSI1: Application-Based Access**
- **PK**: `ApplicationId`
- **SK**: `LogTimestamp#LogId`
- Use case: Get all logs for specific loan application

**GSI2: Correlation Tracking**
- **PK**: `CorrelationId`
- **SK**: `LogTimestamp#LogId`
- Use case: Distributed tracing and request flow analysis

**GSI3: Error Analysis**
- **PK**: `IsSuccess-Date` (e.g., "false-2024-01-15")
- **SK**: `LogTimestamp#LogId`
- Use case: Error investigation and monitoring

### 📈 Query Examples with DynamoDB

#### 1. Time-Range Query by Service
```csharp
// Get CreditCheckService logs from last 24 hours
var request = new QueryRequest
{
    TableName = "LoanApp-IntegrationLogs",
    KeyConditionExpression = "PK = :pk AND SK BETWEEN :start AND :end",
    ExpressionAttributeValues = new Dictionary<string, AttributeValue>
    {
        {":pk", new AttributeValue("CreditCheckService-2024-01-15")},
        {":start", new AttributeValue("2024-01-15T00:00:00Z")},
        {":end", new AttributeValue("2024-01-15T23:59:59Z")}
    }
};
```

#### 2. Application Journey Tracking
```csharp
// Get all logs for ApplicationId 1001 using GSI1
var request = new QueryRequest
{
    TableName = "LoanApp-IntegrationLogs",
    IndexName = "GSI1-ApplicationId-LogTimestamp",
    KeyConditionExpression = "ApplicationId = :appId",
    ExpressionAttributeValues = new Dictionary<string, AttributeValue>
    {
        {":appId", new AttributeValue {N = "1001"}}
    }
};
```

#### 3. Error Investigation
```csharp
// Get all errors from today using GSI3
var request = new QueryRequest
{
    TableName = "LoanApp-IntegrationLogs",
    IndexName = "GSI3-IsSuccess-LogTimestamp",
    KeyConditionExpression = "IsSuccess-Date = :errorDate",
    ExpressionAttributeValues = new Dictionary<string, AttributeValue>
    {
        {":errorDate", new AttributeValue("false-2024-01-15")}
    }
};
```

### 💰 Cost and Performance Considerations

#### Write Patterns
- **High volume**: ~1000 writes/minute during peak hours
- **Batch writes**: Use BatchWriteItem for efficiency
- **Auto-scaling**: Configure based on traffic patterns

#### Read Patterns
- **Hot data**: Last 7 days (frequent access)
- **Warm data**: 8-30 days (occasional access)
- **Cold data**: >30 days (archive or delete with TTL)

#### TTL Strategy
```csharp
// Set TTL for automatic cleanup after 90 days
var ttlTimestamp = DateTimeOffset.UtcNow.AddDays(90).ToUnixTimeSeconds();
item["TTL"] = new AttributeValue { N = ttlTimestamp.ToString() };
```

### 🔄 Migration Strategy Impact

#### Dual-Write Period Considerations
During migration, write to both systems:
```csharp
// Write to SQL Server (existing)
await _context.IntegrationLogs.AddAsync(sqlLog);
await _context.SaveChangesAsync();

// Write to DynamoDB (new)
await _dynamoDbService.WriteLogAsync(dynamoLog);
```

#### Query Migration Strategy
1. **Phase 1**: Read from SQL, write to both
2. **Phase 2**: Read from DynamoDB, write to both
3. **Phase 3**: Read and write only to DynamoDB

### 📋 Validation Requirements

#### Data Integrity Checks
- Record count validation between systems
- Spot checks on critical fields (timestamps, IDs)
- Performance comparison (query response times)

#### Functional Testing
- Verify all query patterns work with DynamoDB
- Test error handling and retry logic
- Validate monitoring and alerting

### 🚀 Implementation Roadmap

1. **Create DynamoDB table and GSIs**
2. **Implement DynamoDB service layer**
3. **Add dual-write capability**
4. **Migrate historical data**
5. **Switch read operations**
6. **Remove SQL logging code**

---

### 💡 Q Developer Integration Points

```
1. "Based on this access pattern analysis, validate the DynamoDB table design and suggest optimizations for cost and performance."

2. "Review these query patterns and recommend the most efficient DynamoDB query strategies using partition keys and GSIs."

3. "Analyze the migration strategy and suggest improvements for the dual-write period to ensure data consistency."
```

**Next**: [DynamoDB Table Design](../03-migration-steps/step1-dynamodb-design.md)