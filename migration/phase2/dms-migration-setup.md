# Phase 2: DMS Migration Setup
## AWS Database Migration Service Configuration for PostgreSQL Migration

### 🎯 DMS Setup Objectives
- Configure DMS replication instance for migration
- Set up source and target endpoints
- Create and execute migration task
- Monitor migration progress and validate results

### 📋 Prerequisites
- Phase 1 completed (RDS SQL Server running)
- Aurora PostgreSQL cluster created and accessible
- Schema conversion completed
- DMS service role configured

### 🚀 DMS Replication Instance Setup

#### Create DMS Replication Instance
```bash
# Create DMS replication instance
aws dms create-replication-instance \
    --replication-instance-identifier workshop-dms-instance \
    --replication-instance-class dms.t3.medium \
    --engine-version 3.5.1 \
    --allocated-storage 20 \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --replication-subnet-group-identifier default-vpc-xxxxxxxxx \
    --publicly-accessible true \
    --multi-az false \
    --tags Key=Workshop,Value=DatabaseModernization Key=Phase,Value=2

# Wait for instance to be available
aws dms wait replication-instance-available \
    --replication-instance-identifier workshop-dms-instance

# Check instance status
aws dms describe-replication-instances \
    --replication-instance-identifier workshop-dms-instance \
    --query 'ReplicationInstances[0].{Status:ReplicationInstanceStatus,Class:ReplicationInstanceClass,Engine:EngineVersion}'
```

#### DMS Security Group Configuration
```bash
# Create security group for DMS
aws ec2 create-security-group \
    --group-name workshop-dms-sg \
    --description "Security group for DMS replication instance" \
    --vpc-id vpc-xxxxxxxxx

# Allow DMS to access source RDS SQL Server
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 1433 \
    --source-group sg-xxxxxxxxx  # DMS security group

# Allow DMS to access target Aurora PostgreSQL
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --source-group sg-xxxxxxxxx  # DMS security group
```

### 🔗 DMS Endpoints Configuration

#### Create Source Endpoint (RDS SQL Server)
```bash
# Create source endpoint for SQL Server
aws dms create-endpoint \
    --endpoint-identifier workshop-source-sqlserver \
    --endpoint-type source \
    --engine-name sqlserver \
    --server-name workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com \
    --port 1433 \
    --database-name LoanApplicationDB \
    --username admin \
    --password WorkshopDB123! \
    --ssl-mode require \
    --tags Key=Workshop,Value=DatabaseModernization Key=Type,Value=Source

# Test source endpoint connection
aws dms test-connection \
    --replication-instance-arn arn:aws:dms:us-east-1:ACCOUNT:rep:workshop-dms-instance \
    --endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-source-sqlserver
```

#### Create Target Endpoint (Aurora PostgreSQL)
```bash
# Create target endpoint for PostgreSQL
aws dms create-endpoint \
    --endpoint-identifier workshop-target-postgresql \
    --endpoint-type target \
    --engine-name postgres \
    --server-name workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com \
    --port 5432 \
    --database-name loanapplicationdb \
    --username postgres \
    --password WorkshopDB123! \
    --ssl-mode require \
    --extra-connection-attributes "heartbeatEnable=true;heartbeatFrequency=1" \
    --tags Key=Workshop,Value=DatabaseModernization Key=Type,Value=Target

# Test target endpoint connection
aws dms test-connection \
    --replication-instance-arn arn:aws:dms:us-east-1:ACCOUNT:rep:workshop-dms-instance \
    --endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-target-postgresql
```

### 📊 Migration Task Configuration

#### Create Migration Task
```bash
# Create migration task configuration
cat > migration-task-settings.json << 'EOF'
{
    "TargetMetadata": {
        "TargetSchema": "",
        "SupportLobs": true,
        "FullLobMode": false,
        "LobChunkSize": 0,
        "LimitedSizeLobMode": true,
        "LobMaxSize": 32,
        "InlineLobMaxSize": 0,
        "LoadMaxFileSize": 0,
        "ParallelLoadThreads": 0,
        "ParallelLoadBufferSize": 0,
        "BatchApplyEnabled": false,
        "TaskRecoveryTableEnabled": false,
        "ParallelApplyThreads": 0,
        "ParallelApplyBufferSize": 0,
        "ParallelApplyQueuesPerThread": 0
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
        ],
        "CloudWatchLogGroup": "dms-tasks-workshop",
        "CloudWatchLogStream": "dms-task-workshop-migration"
    },
    "ControlTablesSettings": {
        "historyTimeslotInMinutes": 5,
        "ControlSchema": "",
        "HistoryTimeslotInMinutes": 5,
        "HistoryTableEnabled": false,
        "SuspendedTablesTableEnabled": false,
        "StatusTableEnabled": false
    },
    "StreamBufferSettings": {
        "StreamBufferCount": 3,
        "StreamBufferSizeInMB": 8,
        "CtrlStreamBufferSizeInMB": 5
    },
    "ErrorBehavior": {
        "DataErrorPolicy": "LOG_ERROR",
        "DataTruncationErrorPolicy": "LOG_ERROR",
        "DataErrorEscalationPolicy": "SUSPEND_TABLE",
        "DataErrorEscalationCount": 0,
        "TableErrorPolicy": "SUSPEND_TABLE",
        "TableErrorEscalationPolicy": "STOP_TASK",
        "TableErrorEscalationCount": 0,
        "RecoverableErrorCount": -1,
        "RecoverableErrorInterval": 5,
        "RecoverableErrorThrottling": true,
        "RecoverableErrorThrottlingMax": 1800,
        "RecoverableErrorStopRetryAfterThrottlingMax": true,
        "ApplyErrorDeletePolicy": "IGNORE_RECORD",
        "ApplyErrorInsertPolicy": "LOG_ERROR",
        "ApplyErrorUpdatePolicy": "LOG_ERROR",
        "ApplyErrorEscalationPolicy": "LOG_ERROR",
        "ApplyErrorEscalationCount": 0,
        "ApplyErrorFailOnTruncationDdl": false,
        "FullLoadIgnoreConflicts": true,
        "FailOnTransactionConsistencyBreached": false,
        "FailOnNoTablesCaptured": true
    }
}
EOF

# Create table mappings
cat > table-mappings.json << 'EOF'
{
    "rules": [
        {
            "rule-type": "selection",
            "rule-id": "1",
            "rule-name": "1",
            "object-locator": {
                "schema-name": "dbo",
                "table-name": "%"
            },
            "rule-action": "include",
            "filters": []
        },
        {
            "rule-type": "transformation",
            "rule-id": "2",
            "rule-name": "2",
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
            "rule-name": "3",
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
            "rule-name": "4",
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

# Create migration task
aws dms create-replication-task \
    --replication-task-identifier workshop-migration-task \
    --source-endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-source-sqlserver \
    --target-endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-target-postgresql \
    --replication-instance-arn arn:aws:dms:us-east-1:ACCOUNT:rep:workshop-dms-instance \
    --migration-type full-load \
    --table-mappings file://table-mappings.json \
    --replication-task-settings file://migration-task-settings.json \
    --tags Key=Workshop,Value=DatabaseModernization Key=Phase,Value=2
```

### 🚀 Execute Migration

#### Start Migration Task
```bash
# Start the migration task
aws dms start-replication-task \
    --replication-task-arn arn:aws:dms:us-east-1:ACCOUNT:task:workshop-migration-task \
    --start-replication-task-type start-replication

# Monitor migration progress
aws dms describe-replication-tasks \
    --replication-task-identifier workshop-migration-task \
    --query 'ReplicationTasks[0].{Status:Status,Progress:ReplicationTaskStats.FullLoadProgressPercent,TablesLoaded:ReplicationTaskStats.TablesLoaded,TablesLoading:ReplicationTaskStats.TablesLoading}'
```

#### Monitor Migration Progress
```powershell
# PowerShell script to monitor migration progress
param([int]$IntervalSeconds = 30)

Write-Host "=== DMS Migration Monitoring ===" -ForegroundColor Cyan

do {
    $taskStatus = aws dms describe-replication-tasks `
        --replication-task-identifier workshop-migration-task `
        --query 'ReplicationTasks[0]' | ConvertFrom-Json
    
    $stats = $taskStatus.ReplicationTaskStats
    
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Status: $($taskStatus.Status)" -ForegroundColor Yellow
    Write-Host "  Progress: $($stats.FullLoadProgressPercent)%" -ForegroundColor Green
    Write-Host "  Tables Loaded: $($stats.TablesLoaded)" -ForegroundColor Green
    Write-Host "  Tables Loading: $($stats.TablesLoading)" -ForegroundColor Green
    Write-Host "  Tables Queued: $($stats.TablesQueued)" -ForegroundColor Green
    Write-Host "  Tables Errored: $($stats.TablesErrored)" -ForegroundColor $(if($stats.TablesErrored -gt 0){"Red"}else{"Green"})
    
    if ($taskStatus.Status -eq "stopped" -or $taskStatus.Status -eq "failed") {
        break
    }
    
    Start-Sleep -Seconds $IntervalSeconds
} while ($true)

Write-Host "Migration task completed with status: $($taskStatus.Status)" -ForegroundColor $(if($taskStatus.Status -eq "stopped"){"Green"}else{"Red"})
```

### 📊 Migration Validation

#### Data Validation Script
```sql
-- Run on both source and target to compare
-- Source (SQL Server)
SELECT 
    'Applications' as TableName, COUNT(*) as RowCount FROM Applications
UNION ALL
SELECT 'Customers', COUNT(*) FROM Customers
UNION ALL
SELECT 'Loans', COUNT(*) FROM Loans
UNION ALL
SELECT 'Payments', COUNT(*) FROM Payments
UNION ALL
SELECT 'Documents', COUNT(*) FROM Documents
UNION ALL
SELECT 'CreditChecks', COUNT(*) FROM CreditChecks
UNION ALL
SELECT 'IntegrationLogs', COUNT(*) FROM IntegrationLogs
UNION ALL
SELECT 'Branches', COUNT(*) FROM Branches
UNION ALL
SELECT 'LoanOfficers', COUNT(*) FROM LoanOfficers
ORDER BY TableName;

-- Target (PostgreSQL) - note lowercase table names
SELECT 
    'applications' as tablename, COUNT(*) as rowcount FROM applications
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'loans', COUNT(*) FROM loans
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'documents', COUNT(*) FROM documents
UNION ALL
SELECT 'creditchecks', COUNT(*) FROM creditchecks
UNION ALL
SELECT 'integrationlogs', COUNT(*) FROM integrationlogs
UNION ALL
SELECT 'branches', COUNT(*) FROM branches
UNION ALL
SELECT 'loanofficers', COUNT(*) FROM loanofficers
ORDER BY tablename;
```

#### Automated Validation Script
```powershell
# Automated data validation
param([string]$SQLPassword = "WorkshopDB123!")

Write-Host "=== DMS Migration Validation ===" -ForegroundColor Cyan

# Source connection (SQL Server)
$SourceConnectionString = "Server=workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com;Database=LoanApplicationDB;User Id=admin;Password=$SQLPassword;Encrypt=true;TrustServerCertificate=true;"

# Target connection (PostgreSQL)
$TargetConnectionString = "Host=workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com;Database=loanapplicationdb;Username=postgres;Password=$SQLPassword;SSL Mode=Require;Trust Server Certificate=true;"

# Install PostgreSQL .NET provider if not present
if (-not (Get-Module -ListAvailable -Name Npgsql)) {
    Install-Package Npgsql -Force -ProviderName NuGet -Scope CurrentUser
}

# Validation queries
$ValidationQueries = @{
    "Applications" = "applications"
    "Customers" = "customers"
    "Loans" = "loans"
    "Payments" = "payments"
    "Documents" = "documents"
    "CreditChecks" = "creditchecks"
    "IntegrationLogs" = "integrationlogs"
    "Branches" = "branches"
    "LoanOfficers" = "loanofficers"
}

$ValidationResults = @()

foreach ($table in $ValidationQueries.Keys) {
    $sourceTable = $table
    $targetTable = $ValidationQueries[$table]
    
    # Get source count
    $sourceCount = Invoke-Sqlcmd -ConnectionString $SourceConnectionString -Query "SELECT COUNT(*) as Count FROM $sourceTable"
    
    # Get target count (using psql command)
    $env:PGPASSWORD = $SQLPassword
    $targetCount = psql -h "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com" -U postgres -d loanapplicationdb -t -c "SELECT COUNT(*) FROM $targetTable;"
    
    $result = [PSCustomObject]@{
        Table = $table
        SourceCount = $sourceCount.Count
        TargetCount = [int]$targetCount.Trim()
        Match = ($sourceCount.Count -eq [int]$targetCount.Trim())
    }
    
    $ValidationResults += $result
}

Write-Host "Validation Results:" -ForegroundColor Yellow
$ValidationResults | Format-Table -AutoSize

$totalTables = $ValidationResults.Count
$matchingTables = ($ValidationResults | Where-Object {$_.Match}).Count

if ($matchingTables -eq $totalTables) {
    Write-Host "✅ All $totalTables tables validated successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ $($totalTables - $matchingTables) tables have mismatched row counts" -ForegroundColor Red
}
```

### 🔧 Troubleshooting Common Issues

#### Connection Issues
```bash
# Check endpoint connectivity
aws dms test-connection \
    --replication-instance-arn arn:aws:dms:us-east-1:ACCOUNT:rep:workshop-dms-instance \
    --endpoint-arn arn:aws:dms:us-east-1:ACCOUNT:endpoint:workshop-source-sqlserver

# Check security group rules
aws ec2 describe-security-groups \
    --group-ids sg-xxxxxxxxx \
    --query 'SecurityGroups[0].IpPermissions'
```

#### Migration Task Errors
```bash
# Get detailed task information
aws dms describe-replication-tasks \
    --replication-task-identifier workshop-migration-task

# Check CloudWatch logs
aws logs describe-log-streams \
    --log-group-name dms-tasks-workshop \
    --order-by LastEventTime \
    --descending

# Get recent log events
aws logs get-log-events \
    --log-group-name dms-tasks-workshop \
    --log-stream-name dms-task-workshop-migration \
    --start-time $(date -d '1 hour ago' +%s)000
```

### 📋 Post-Migration Checklist

#### Data Validation
- [ ] All tables migrated successfully
- [ ] Row counts match between source and target
- [ ] Sample data integrity verified
- [ ] No data truncation or corruption
- [ ] Primary keys and constraints created

#### Performance Validation
- [ ] Query performance acceptable
- [ ] Connection pooling working
- [ ] No timeout errors
- [ ] Memory usage within limits

#### Application Preparation
- [ ] Connection strings updated for PostgreSQL
- [ ] Entity Framework provider changed
- [ ] Stored procedure calls updated
- [ ] Data access code tested

### 🎯 Migration Success Criteria

**Technical Success:**
- ✅ All 9 tables migrated with 100% data integrity
- ✅ Migration completed within 2-hour window
- ✅ No data loss or corruption detected
- ✅ Target database accessible and functional

**Performance Success:**
- ✅ Migration throughput > 1000 rows/second
- ✅ Target database query performance acceptable
- ✅ Connection establishment < 2 seconds
- ✅ No application timeout errors

**Operational Success:**
- ✅ Migration monitoring and logging functional
- ✅ Rollback procedures documented and tested
- ✅ Application integration path clear
- ✅ Stakeholder communication completed

The DMS migration setup is now complete and ready for Phase 2 execution!