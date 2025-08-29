# Step 4: DMS Migration - PostgreSQL to DynamoDB
## Phase 3: Full Load + CDC Migration using AWS Database Migration Service

### 🎯 Objective
Use AWS DMS to migrate existing PostgreSQL data (IntegrationLogs + Payments) to DynamoDB with FULL LOAD + CDC for real-time synchronization during the migration period.

### 📚 Learning Examples

#### Example 1: DMS Task Configuration (FULL LOAD + CDC)
```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-integration-logs",
      "object-locator": {
        "schema-name": "dbo",
        "table-name": "IntegrationLogs"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "selection",
      "rule-id": "2", 
      "rule-name": "include-payments",
      "object-locator": {
        "schema-name": "dbo",
        "table-name": "Payments"
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

### 🤖 Generate Table Mappings with Q Developer

Now use this Q Developer prompt with your actual schema results:

```
@q "Analyze the DynamoDB table schemas and PostgreSQL source tables to generate correct DMS table mappings:

DynamoDB Tables:
- LoanApp-IntegrationLogs-dev: PK (string), SK (string) + GSI1-ApplicationId-LogTimestamp, GSI2-CorrelationId-LogTimestamp, GSI3-ErrorStatus-LogTimestamp
- LoanApp-Payments-dev: PaymentId (number, hash only)

PostgreSQL Source Tables:
[Paste your SQL query results here]

Generate the complete table-mappings.json with proper attribute mappings for both tables."
```

**Replace the existing table-mappings.json file with Q Developer's generated version**

### 🚀 Run DMS Migration (FULL LOAD + CDC)

```powershell
# Navigate to DMS configuration directory
cd migration\phase3\dms

# Create DMS replication task with FULL LOAD + CDC
./create-dms-task.ps1 -ReplicationInstanceId "your-replication-instance-id" -PostgreSQLHost "your-aurora-endpoint" -Environment dev -MigrationType "full-load-and-cdc"

# Monitor migration progress (Full Load phase)
aws dms describe-replication-tasks --filters Name=replication-task-id,Values=your-task-id --query 'ReplicationTasks[0].ReplicationTaskStats'

# Expected Results:
# FullLoadProgressPercent: 100
# TablesLoaded: 2 (IntegrationLogs + Payments)
# TablesLoading: 0
# CDCLatency: < 10 seconds

# Validate migration counts
aws dynamodb scan --table-name LoanApp-IntegrationLogs-dev --select COUNT
aws dynamodb scan --table-name LoanApp-Payments-dev --select COUNT

# Test CDC by making changes to PostgreSQL
psql -h your-aurora-endpoint -d LoanApplication -c "INSERT INTO dbo.\"IntegrationLogs\" (LogType, ServiceName, LogTimestamp) VALUES ('TEST', 'CDCTest', NOW());"

# Verify CDC replication (should appear in DynamoDB within seconds)
aws dynamodb scan --table-name LoanApp-IntegrationLogs-dev --filter-expression "ServiceName = :svc" --expression-attribute-values '{":svc":{"S":"CDCTest"}}'
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