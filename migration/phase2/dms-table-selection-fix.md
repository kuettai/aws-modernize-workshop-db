# DMS Table Selection Pattern Fix

## Problem
DMS Task Error: "No tables were found at task initialization"
Current selection rule: `schema name is like 'Loan%' and table name is like '%'`

## Root Cause
The schema name pattern `'Loan%'` doesn't match the actual database schema name.

## Solution

### Correct Table Selection Rules

#### For SQL Server Source (Current Database)
```json
{
    "rules": [
        {
            "rule-type": "selection",
            "rule-id": "1",
            "rule-name": "select-all-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "include"
        }
    ]
}
```

#### Alternative: Specific Table Selection
```json
{
    "rules": [
        {
            "rule-type": "selection",
            "rule-id": "1",
            "rule-name": "select-loan-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Applications"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "2",
            "rule-name": "select-customer-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Customers"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "3",
            "rule-name": "select-loan-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Loans"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "4",
            "rule-name": "select-payment-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Payments"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "5",
            "rule-name": "select-branch-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Branches"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "6",
            "rule-name": "select-loanofficer-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "LoanOfficers"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "7",
            "rule-name": "select-document-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "Documents"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "8",
            "rule-name": "select-creditcheck-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "CreditChecks"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "selection",
            "rule-id": "9",
            "rule-name": "select-integration-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "IntegrationLogs"
            },
            "rule-action": "include"
        }
    ]
}
```

### Schema Transformation Rules
Add these transformation rules to convert schema names:

```json
{
    "rules": [
        {
            "rule-type": "selection",
            "rule-id": "1",
            "rule-name": "select-all-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "transformation",
            "rule-id": "2",
            "rule-name": "convert-schema-name",
            "rule-target": "schema",
            "object-locator": {
                "schema-name": "dbo"
            },
            "rule-action": "rename",
            "value": "public"
        },
        {
            "rule-type": "transformation",
            "rule-id": "3",
            "rule-name": "convert-table-names-lowercase",
            "rule-target": "table",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "convert-lowercase"
        },
        {
            "rule-type": "transformation",
            "rule-id": "4",
            "rule-name": "convert-column-names-lowercase",
            "rule-target": "column",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%",
                "column-name": "%"
            },
            "rule-action": "convert-lowercase"
        }
    ]
}
```

## Quick Fix Commands

### 1. Update DMS Task Table Mappings
```bash
# Create corrected table mappings file
cat > table-mappings-corrected.json << 'EOF'
{
    "rules": [
        {
            "rule-type": "selection",
            "rule-id": "1",
            "rule-name": "select-all-dbo-tables",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "include"
        },
        {
            "rule-type": "transformation",
            "rule-id": "2",
            "rule-name": "convert-schema-to-public",
            "rule-target": "schema",
            "object-locator": {
                "schema-name": "dbo"
            },
            "rule-action": "rename",
            "value": "public"
        },
        {
            "rule-type": "transformation",
            "rule-id": "3",
            "rule-name": "convert-tables-lowercase",
            "rule-target": "table",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "convert-lowercase"
        },
        {
            "rule-type": "transformation",
            "rule-id": "4",
            "rule-name": "convert-columns-lowercase",
            "rule-target": "column",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%",
                "column-name": "%"
            },
            "rule-action": "convert-lowercase"
        }
    ]
}
EOF

# Update DMS task with corrected mappings
aws dms modify-replication-task \
    --replication-task-arn arn:aws:dms:us-east-1:ACCOUNT:task:workshop-migration-task \
    --table-mappings file://table-mappings-corrected.json \
    --profile mmws
```

### 2. Alternative: Set FailOnNoTablesCaptured to false
```bash
# Create task settings with FailOnNoTablesCaptured = false
cat > task-settings-updated.json << 'EOF'
{
    "TargetMetadata": {
        "TargetSchema": "",
        "SupportLobs": true,
        "FullLobMode": false,
        "LobChunkSize": 0,
        "LimitedSizeLobMode": true,
        "LobMaxSize": 32
    },
    "FullLoadSettings": {
        "TargetTablePrepMode": "DROP_AND_CREATE",
        "CreatePkAfterFullLoad": false,
        "StopTaskCachedChangesApplied": false,
        "StopTaskCachedChangesNotApplied": false,
        "MaxFullLoadSubTasks": 8,
        "TransactionConsistencyTimeout": 600,
        "CommitRate": 10000
    },
    "ErrorBehavior": {
        "DataErrorPolicy": "LOG_ERROR",
        "DataTruncationErrorPolicy": "LOG_ERROR",
        "DataErrorEscalationPolicy": "SUSPEND_TABLE",
        "TableErrorPolicy": "SUSPEND_TABLE",
        "TableErrorEscalationPolicy": "STOP_TASK",
        "RecoverableErrorCount": -1,
        "RecoverableErrorInterval": 5,
        "ApplyErrorDeletePolicy": "IGNORE_RECORD",
        "ApplyErrorInsertPolicy": "LOG_ERROR",
        "ApplyErrorUpdatePolicy": "LOG_ERROR",
        "FailOnTransactionConsistencyBreached": false,
        "FailOnNoTablesCaptured": false
    },
    "Logging": {
        "EnableLogging": true,
        "LogComponents": [
            {
                "Id": "TRANSFORMATION",
                "Severity": "LOGGER_SEVERITY_DEFAULT"
            },
            {
                "Id": "SOURCE_UNLOAD",
                "Severity": "LOGGER_SEVERITY_DEFAULT"
            },
            {
                "Id": "TARGET_LOAD",
                "Severity": "LOGGER_SEVERITY_DEFAULT"
            }
        ]
    }
}
EOF

# Update task settings
aws dms modify-replication-task \
    --replication-task-arn arn:aws:dms:us-east-1:ACCOUNT:task:workshop-migration-task \
    --replication-task-settings file://task-settings-updated.json \
    --profile mmws
```

### 3. Verify Source Database Schema
```bash
# Check actual schema names in source database
aws dms test-connection \
    --replication-instance-arn arn:aws:dms:us-east-1:ACCOUNT:rep:workshop-dms-instance \
    --endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-source-sqlserver \
    --profile mmws

# Or connect directly to verify
sqlcmd -S localhost -U sa -P WorkshopDB123! -Q "SELECT DISTINCT TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
```

## Recommended Solution

**Use the first option** with corrected table mappings:
1. Schema name should be `"dbo"` (not `"Loan%"`)
2. Include transformation rules for PostgreSQL compatibility
3. Convert table/column names to lowercase

This will properly select all tables from the `dbo` schema and transform them for PostgreSQL compatibility.