# Step 6: Migration Completion
## Phase 3: Final Cutover to DynamoDB-Only

### 🎯 Objective
Complete the migration by stopping CDC, switching to DynamoDB-only writes, and validating the final state.

### 🚀 Migration Completion Workflow

#### **Step 1: Validate Migration Readiness (10 minutes)**

**Purpose**: Ensure DMS has fully synchronized and CDC is working correctly

```powershell
# Check DMS task status
aws dms describe-replication-tasks --filters Name=replication-task-id,Values=postgresql-to-dynamodb-dev --query 'ReplicationTasks[0].ReplicationTaskStats'

# Expected Results:
# FullLoadProgressPercent: 100
# CDCLatency: < 5 seconds
# TablesLoaded: 2
# TablesErrored: 0
```

**Test CDC Replication (Critical Step):**

1. **Insert test record via DBeaver:**
```sql
-- Connect to PostgreSQL in DBeaver and run:
INSERT INTO dbo."IntegrationLogs" (
    "LogId", "LogType", "ServiceName", "LogTimestamp", 
    "CorrelationId", "IsSuccess"
) VALUES (
    '-1', 'CDC_TEST', 'MigrationValidation', NOW(), 
    'cdc-test-' || EXTRACT(EPOCH FROM NOW()), true
);

-- Note the LogTimestamp for verification
SELECT "LogId", "LogTimestamp", "CorrelationId" 
FROM dbo."IntegrationLogs" 
WHERE "ServiceName" = 'MigrationValidation' 
ORDER BY "LogTimestamp" DESC LIMIT 1;
```

2. **Wait 10-30 seconds for CDC replication**

3. **Verify record appears in DynamoDB:**
```powershell
# Query DynamoDB for the test record using LogId = -1
aws dynamodb get-item --table-name LoanApp-IntegrationLogs-dev --key file://test-key.json --profile mmws

# Expected Result: Should return the record with LogId = -1 and ServiceName = MigrationValidation
```

4. **Validate overall data consistency:**
```powershell
Invoke-RestMethod -Uri http://localhost:5000/api/MigrationDashboard/validate -Method POST

# Expected Results:
# isConsistent: True
# sqlRecordCount: matches dynamoDbRecordCount
# discrepancies: []
```

**✅ CDC Validation Success Criteria:**
- Test record appears in DynamoDB within 30 seconds
- CorrelationId matches between PostgreSQL and DynamoDB
- Overall data consistency validation passes

#### **Step 2: Stop CDC Replication (2 minutes)**

**Purpose**: Stop ongoing CDC to prepare for final cutover

```powershell
# Navigate to DMS directory
cd migration\phase3\dms

# Stop DMS task
$taskArn = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=postgresql-to-dynamodb-dev --query 'ReplicationTasks[0].ReplicationTaskArn' --output text

aws dms stop-replication-task --replication-task-arn $taskArn

# Monitor until stopped
do {
    $status = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=postgresql-to-dynamodb-dev --query 'ReplicationTasks[0].Status' --output text
    Write-Host "DMS Task Status: $status"
    Start-Sleep -Seconds 5
} while ($status -eq "stopping")

# Expected Result: Status = "stopped"
```

#### **Step 3: Switch to DynamoDB-Only Mode (1 minute)**

**Purpose**: Configure application to write only to DynamoDB

```powershell
# Update application configuration
# In appsettings.json, change:
```

```json
{
  "HybridLogging": {
    "WritesToSql": false,
    "WritesToDynamoDb": true,
    "ReadsFromDynamoDb": true,
    "CurrentPhase": "DynamoOnly"
  }
}
```

```powershell
# Or use the migration control API
Invoke-RestMethod -Uri http://localhost:5000/api/Migration/disable-sql-writes -Method POST

# Expected Result:
# success: True
# message: "PostgreSQL writes disabled - DynamoDB only mode"
```

#### **Step 4: Validate DynamoDB-Only Operation (5 minutes)**

**Purpose**: Ensure application works correctly with DynamoDB only

```powershell
# Test application functionality
Invoke-RestMethod -Uri http://localhost:5000/api/Migration/test-dual-write -Method POST

# Expected Result:
# success: True
# logId: [new log ID]
# writtenTo: "DynamoDB"

# Check migration status
Invoke-RestMethod -Uri http://localhost:5000/api/MigrationDashboard/status

# Expected Result:
# currentPhase: "DynamoOnly"
# configuration.writesToSql: False
# configuration.writesToDynamoDb: True
# configuration.readsFromDynamoDb: True

# Test application pages
# Visit http://localhost:5000/docs - should show DynamoDB-only status
# Visit http://localhost:5000 - should show "Connected to PostgreSQL + DynamoDB (Phase 3: Hybrid Architecture)"
```

#### **Step 5: Performance Validation (5 minutes)**

**Purpose**: Verify performance meets requirements

```powershell
# Run performance tests
for ($i = 1; $i -le 10; $i++) {
    $start = Get-Date
    Invoke-RestMethod -Uri http://localhost:5000/api/Migration/test-dual-write -Method POST | Out-Null
    $duration = (Get-Date) - $start
    Write-Host "Test $i`: $($duration.TotalMilliseconds)ms"
}

# Expected Results:
# Average response time: < 100ms
# All tests successful
# No errors in application logs
```

### 🧹 Optional: Cleanup DMS Resources

**Purpose**: Remove DMS resources to save costs (optional)

```powershell
# Delete DMS task
aws dms delete-replication-task --replication-task-arn $taskArn

# Delete endpoints (optional)
aws dms delete-endpoint --endpoint-arn [source-endpoint-arn]
aws dms delete-endpoint --endpoint-arn [target-endpoint-arn]

# Delete replication instance (optional - will incur costs if kept)
# aws dms delete-replication-instance --replication-instance-arn [instance-arn]
```

### ✅ Migration Completion Checklist

**Pre-Cutover Validation:**
- [ ] DMS task shows 100% completion
- [ ] CDC latency < 5 seconds
- [ ] Data validation passes
- [ ] Application health checks pass

**Cutover Execution:**
- [ ] DMS task stopped successfully
- [ ] Application configuration updated
- [ ] DynamoDB-only mode enabled
- [ ] No PostgreSQL writes occurring

**Post-Cutover Validation:**
- [ ] Application functionality verified
- [ ] Performance meets requirements
- [ ] Error rates within acceptable limits
- [ ] Monitoring dashboards updated

### 🎉 Migration Success Criteria

**Technical Success:**
- ✅ Application runs on DynamoDB only
- ✅ All functionality preserved
- ✅ Performance targets met (< 100ms response time)
- ✅ Zero data loss validated

**Business Success:**
- ✅ No user-facing downtime
- ✅ All features working correctly
- ✅ Monitoring and alerting functional
- ✅ Rollback procedures documented

### 🔄 Rollback Procedure (If Needed)

**Emergency Rollback Steps:**
1. **Re-enable PostgreSQL writes**: Set `WritesToSql: true`
2. **Switch reads back**: Set `ReadsFromDynamoDb: false`
3. **Restart DMS task**: Resume CDC if needed
4. **Validate rollback**: Ensure PostgreSQL mode works

```powershell
# Quick rollback commands
# Update appsettings.json:
# "WritesToSql": true, "ReadsFromDynamoDb": false

# Or use API:
Invoke-RestMethod -Uri http://localhost:5000/api/Migration/enable-sql-writes -Method POST
```

---

### 💡 Q Developer Integration Points

```
1. "Review the migration completion process and suggest additional validation steps to ensure zero-downtime cutover."

2. "Analyze the rollback procedures and recommend improvements for faster recovery in case of issues."

3. "Examine the performance validation approach and suggest comprehensive testing strategies for production environments."
```

**Next**: [Testing and Validation](../05-comparison/01-validation-procedures.md)