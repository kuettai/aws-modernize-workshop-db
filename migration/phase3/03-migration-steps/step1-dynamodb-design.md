# Step 1: DynamoDB Table Design
## Phase 3: DynamoDB Migration - Table Structure Design

### 🎯 Objective
Design optimal DynamoDB table structure based on access pattern analysis from the current SQL Server IntegrationLogs implementation.

### 📊 Design Principles

#### NoSQL Design Approach
- **Single Table Design**: One table with multiple access patterns via GSIs
- **Denormalization**: Store related data together to minimize queries
- **Access Pattern Driven**: Design keys based on how data will be queried
- **Cost Optimization**: Balance performance with read/write capacity costs

### 🏗️ Primary Table Design

#### Table Name: `LoanApp-IntegrationLogs-{Environment}`

**Primary Key Structure:**
```
Partition Key (PK): ServiceName-Date     # e.g., "CreditCheckService-2024-01-15"
Sort Key (SK): LogTimestamp#LogId        # e.g., "2024-01-15T10:30:00.123Z#12345"
```

**Why this design?**
- **Even distribution**: Different services spread load across partitions
- **Time-based sorting**: Most recent logs appear first in queries
- **Unique identification**: LogId ensures uniqueness within same timestamp

#### Complete Item Structure
```json
{
  "PK": "CreditCheckService-2024-01-15",
  "SK": "2024-01-15T10:30:00.123Z#12345",
  "LogId": 12345,
  "ApplicationId": 1001,
  "LogType": "API",
  "ServiceName": "CreditCheckService",
  "RequestData": "{\"customerId\": 1001, \"creditScore\": 750}",
  "ResponseData": "{\"approved\": true, \"limit\": 50000}",
  "StatusCode": "200",
  "IsSuccess": true,
  "ErrorMessage": null,
  "ProcessingTimeMs": 245,
  "LogTimestamp": "2024-01-15T10:30:00.123Z",
  "CorrelationId": "abc-123-def-456",
  "UserId": "user123",
  "TTL": 1736956200,
  "GSI1PK": "APP#1001",
  "GSI1SK": "2024-01-15T10:30:00.123Z#12345",
  "GSI2PK": "CORR#abc-123-def-456",
  "GSI2SK": "2024-01-15T10:30:00.123Z#12345",
  "GSI3PK": "ERROR#false#2024-01-15",
  "GSI3SK": "2024-01-15T10:30:00.123Z#12345"
}
```

### 🔍 Global Secondary Indexes (GSIs)

#### GSI1: Application-Based Access
```
Name: GSI1-ApplicationId-LogTimestamp
Partition Key: GSI1PK (ApplicationId with prefix)
Sort Key: GSI1SK (LogTimestamp#LogId)
Projection: ALL
```

**Use Cases:**
- Get all logs for specific loan application
- Track application processing journey
- Debug application-specific issues

**Query Example:**
```csharp
// Get all logs for ApplicationId 1001
KeyConditionExpression = "GSI1PK = :pk",
ExpressionAttributeValues = {
    {":pk", new AttributeValue("APP#1001")}
}
```

#### GSI2: Correlation Tracking
```
Name: GSI2-CorrelationId-LogTimestamp  
Partition Key: GSI2PK (CorrelationId with prefix)
Sort Key: GSI2SK (LogTimestamp#LogId)
Projection: ALL
```

**Use Cases:**
- Distributed tracing across services
- Follow request flow through system
- Performance analysis of complete workflows

**Query Example:**
```csharp
// Track request flow using correlation ID
KeyConditionExpression = "GSI2PK = :pk",
ExpressionAttributeValues = {
    {":pk", new AttributeValue("CORR#abc-123-def-456")}
}
```

#### GSI3: Error Analysis
```
Name: GSI3-ErrorStatus-LogTimestamp
Partition Key: GSI3PK (IsSuccess#Date combination)
Sort Key: GSI3SK (LogTimestamp#LogId)  
Projection: ALL
```

**Use Cases:**
- Monitor error rates by day
- Investigate recent failures
- Generate error reports

**Query Example:**
```csharp
// Get all errors from specific date
KeyConditionExpression = "GSI3PK = :pk",
ExpressionAttributeValues = {
    {":pk", new AttributeValue("ERROR#true#2024-01-15")}
}
```

### 📈 CloudFormation Template

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'DynamoDB table for IntegrationLogs migration'

Parameters:
  Environment:
    Type: String
    Default: 'dev'
    AllowedValues: ['dev', 'test', 'prod']

Resources:
  IntegrationLogsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub 'LoanApp-IntegrationLogs-${Environment}'
      BillingMode: PAY_PER_REQUEST  # Start with on-demand, switch to provisioned if needed
      
      AttributeDefinitions:
        - AttributeName: PK
          AttributeType: S
        - AttributeName: SK
          AttributeType: S
        - AttributeName: GSI1PK
          AttributeType: S
        - AttributeName: GSI1SK
          AttributeType: S
        - AttributeName: GSI2PK
          AttributeType: S
        - AttributeName: GSI2SK
          AttributeType: S
        - AttributeName: GSI3PK
          AttributeType: S
        - AttributeName: GSI3SK
          AttributeType: S
      
      KeySchema:
        - AttributeName: PK
          KeyType: HASH
        - AttributeName: SK
          KeyType: RANGE
      
      GlobalSecondaryIndexes:
        - IndexName: GSI1-ApplicationId-LogTimestamp
          KeySchema:
            - AttributeName: GSI1PK
              KeyType: HASH
            - AttributeName: GSI1SK
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
        
        - IndexName: GSI2-CorrelationId-LogTimestamp
          KeySchema:
            - AttributeName: GSI2PK
              KeyType: HASH
            - AttributeName: GSI2SK
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
        
        - IndexName: GSI3-ErrorStatus-LogTimestamp
          KeySchema:
            - AttributeName: GSI3PK
              KeyType: HASH
            - AttributeName: GSI3SK
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      
      TimeToLiveSpecification:
        AttributeName: TTL
        Enabled: true
      
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Application
          Value: LoanApplication
        - Key: Component
          Value: IntegrationLogs

Outputs:
  TableName:
    Description: 'DynamoDB table name'
    Value: !Ref IntegrationLogsTable
    Export:
      Name: !Sub '${AWS::StackName}-TableName'
  
  TableArn:
    Description: 'DynamoDB table ARN'
    Value: !GetAtt IntegrationLogsTable.Arn
    Export:
      Name: !Sub '${AWS::StackName}-TableArn'
```

### 🔧 Deployment Script

```powershell
# deploy-dynamodb-table.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [string]$Region = "us-east-1",
    [string]$StackName = "loanapp-dynamodb-logs"
)

Write-Host "Deploying DynamoDB table for environment: $Environment" -ForegroundColor Green

# Deploy CloudFormation stack
aws cloudformation deploy `
    --template-file "dynamodb-table.yaml" `
    --stack-name "$StackName-$Environment" `
    --parameter-overrides Environment=$Environment `
    --region $Region `
    --capabilities CAPABILITY_IAM

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DynamoDB table deployed successfully" -ForegroundColor Green
    
    # Get table details
    $tableName = aws cloudformation describe-stacks `
        --stack-name "$StackName-$Environment" `
        --region $Region `
        --query "Stacks[0].Outputs[?OutputKey=='TableName'].OutputValue" `
        --output text
    
    Write-Host "📊 Table Name: $tableName" -ForegroundColor Cyan
    
    # Verify table status
    aws dynamodb describe-table --table-name $tableName --region $Region --query "Table.TableStatus"
} else {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}
```

### 📊 Capacity Planning

#### Initial Sizing Estimates
Based on loan application usage:
- **Write Capacity**: 1000 writes/minute peak = ~17 WCU
- **Read Capacity**: 500 reads/minute = ~8 RCU per GSI
- **Storage**: ~1KB per item, 200K items = 200MB initially

#### Auto-Scaling Configuration
```yaml
# Add to CloudFormation template for production
AutoScalingSettings:
  TargetTrackingScalingPolicies:
    - TargetValue: 70.0
      ScaleInCooldown: 60
      ScaleOutCooldown: 60
      MetricType: DynamoDBReadCapacityUtilization
```

### 🔍 Data Modeling Validation

#### Sample Queries to Test Design

**1. Recent logs by service:**
```
PK = "CreditCheckService-2024-01-15" 
AND SK BETWEEN "2024-01-15T10:00:00Z" AND "2024-01-15T11:00:00Z"
```

**2. Application journey:**
```
GSI1: GSI1PK = "APP#1001"
```

**3. Error investigation:**
```
GSI3: GSI3PK = "ERROR#true#2024-01-15"
```

**4. Correlation tracking:**
```
GSI2: GSI2PK = "CORR#abc-123-def-456"
```

### 💡 Design Trade-offs

#### Advantages
- **Fast time-based queries** with proper partitioning
- **Multiple access patterns** supported efficiently
- **Automatic scaling** with on-demand billing
- **Built-in TTL** for data lifecycle management

#### Considerations
- **GSI costs** - 3 GSIs increase storage and throughput costs
- **Item size limits** - Large JSON payloads may hit 400KB limit
- **Query flexibility** - Less flexible than SQL for ad-hoc queries

### 🚀 Next Steps
1. **Deploy table** using CloudFormation template
2. **Test queries** with sample data
3. **Implement service layer** for DynamoDB operations
4. **Create migration scripts** for data transfer

---

### 💡 Q Developer Integration Points

```
1. "Review this DynamoDB table design and suggest optimizations for the loan application logging use case."

2. "Analyze the GSI design and recommend improvements for cost optimization while maintaining query performance."

3. "Validate this CloudFormation template and suggest additional configurations for production deployment."
```

**Next**: [Create New Services](./step2-create-new-services.md)