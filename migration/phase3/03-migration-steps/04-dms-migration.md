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

```
1. "Review this DMS configuration and suggest optimizations for PostgreSQL to DynamoDB migration performance."

2. "Analyze the table mapping rules and recommend improvements for data transformation and key generation."
```

**Next**: [Application Integration](./05-application-integration.md)