# Step 4: DMS Migration - PostgreSQL to DynamoDB
## Phase 3: Historical Data Transfer using AWS Database Migration Service

### 🎯 Objective
Use AWS DMS to migrate existing PostgreSQL IntegrationLogs data to DynamoDB with proper transformations and validation.

### 📚 Learning Examples

#### Example 1: Basic DMS Task Configuration
```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "1",
      "object-locator": {
        "schema-name": "public",
        "table-name": "IntegrationLogs"
      },
      "rule-action": "include"
    }
  ]
}
```

#### Example 2: DynamoDB Target Mapping
```json
{
  "rules": [
    {
      "rule-type": "object-mapping",
      "rule-id": "2",
      "rule-name": "TransformIntegrationLogs",
      "rule-target": "table",
      "object-locator": {
        "schema-name": "public",
        "table-name": "IntegrationLogs"
      },
      "target-table-name": "LoanApp-IntegrationLogs-dev",
      "mapping-parameters": {
        "partition-key-name": "PK",
        "sort-key-name": "SK"
      }
    }
  ]
}
```

### 🔍 Discovery Phase: Analyze Your Schema

Before running the migration, use Q Developer to analyze your specific table structures:

```powershell
# Get DynamoDB table schemas
aws dynamodb describe-table --table-name LoanApp-IntegrationLogs-dev --query 'Table.KeySchema'
aws dynamodb describe-table --table-name LoanApp-Payments-dev --query 'Table.KeySchema'

# Check PostgreSQL source structure (run in DBeaver)
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_schema = 'dbo' AND table_name = 'IntegrationLogs'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_schema = 'dbo' AND table_name = 'Payments'
ORDER BY ordinal_position;

# Check record counts
SELECT COUNT(*) as integration_logs_count FROM dbo."IntegrationLogs";
SELECT COUNT(*) as payments_count FROM dbo."Payments";
```

**Use the Q Developer prompts above to generate your custom table-mappings.json**

### 🚀 Run DMS Migration

```powershell
# Navigate to DMS configuration directory
cd migration\phase3\dms

# Create DMS replication task (provide your replication instance ID and Aurora endpoint)
./create-dms-task.ps1 -ReplicationInstanceId "your-replication-instance-id" -PostgreSQLHost "your-aurora-endpoint" -Environment dev

# Monitor migration progress
aws dms describe-replication-tasks --filters Name=replication-task-id,Values=your-task-id

# Validate migration
aws dynamodb scan --table-name LoanApp-IntegrationLogs-dev --select COUNT
```

---

### 💡 Q Developer Integration Points

#### Step 1: Analyze Target DynamoDB Schema
```
@q "Analyze the DynamoDB table schemas and PostgreSQL source tables to generate correct DMS table mappings:

DynamoDB Tables:
- LoanApp-IntegrationLogs-dev: PK (string), SK (string) + GSI1-ApplicationId-LogTimestamp, GSI2-CorrelationId-LogTimestamp, GSI3-ErrorStatus-LogTimestamp
- LoanApp-Payments-dev: PaymentId (number, hash only)

PostgreSQL Source Tables:
- dbo.IntegrationLogs: LogId (int), LogTimestamp (timestamp), ApplicationId (int), CorrelationId (string), ErrorStatus (string)
- dbo.Payments: PaymentId (int), CustomerId (int), PaymentDate (timestamp), PaymentAmount (decimal)

Generate the complete table-mappings.json with proper attribute mappings for both tables."
```

#### Step 2: Optimize Migration Performance
```
@q "Review this DMS configuration and suggest optimizations for PostgreSQL to DynamoDB migration performance:
- Source: Aurora PostgreSQL with 100K+ IntegrationLogs records
- Target: DynamoDB with provisioned throughput
- Migration type: Full load only

Recommend task-settings.json optimizations for batch size, parallel load, and error handling."
```

#### Step 3: Validate Mapping Rules
```
@q "Analyze these DMS table mapping rules and recommend improvements for data transformation and key generation:

[Paste your table-mappings.json content here]

Ensure proper GSI attribute population and optimal key distribution for DynamoDB best practices."
```

**Next**: [Application Integration](./05-application-integration.md)