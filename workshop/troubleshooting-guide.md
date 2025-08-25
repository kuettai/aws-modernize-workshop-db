# Troubleshooting Guide
## AWS Database Modernization Workshop

### Q Developer Troubleshooting Approach

**Primary Strategy**: Use Q Developer for diagnosis and resolution
```
@q I'm encountering this issue during [phase]: [error description]. Help me diagnose the root cause and provide a solution.
```

---

## Phase 1: RDS Migration Issues

### Issue: RDS Connection Timeout
**Symptoms**: Application cannot connect to RDS instance
**Q Developer Prompt**:
```
@q My .NET application can't connect to AWS RDS SQL Server. The connection string is [connection string]. Help me troubleshoot connectivity issues.
```

**Common Solutions**:
1. **Security Group**: Verify port 1433 is open from application subnet
2. **VPC Configuration**: Ensure RDS is in correct VPC/subnet
3. **Connection String**: Validate server name and credentials

**Validation**:
```bash
telnet your-rds-endpoint.amazonaws.com 1433
aws rds describe-db-instances --db-instance-identifier workshop-sqlserver
```

### Issue: Backup Restore Fails
**Symptoms**: Native backup restore to RDS fails
**Q Developer Prompt**:
```
@q My SQL Server backup restore to RDS is failing with error: [error message]. Help me resolve this backup/restore issue.
```

**Common Solutions**:
1. **S3 Permissions**: Verify RDS has access to S3 bucket
2. **Backup Compatibility**: Ensure backup version compatibility
3. **Option Group**: Check required options are enabled

### Issue: Performance Degradation
**Symptoms**: Queries slower on RDS than on-premises
**Q Developer Prompt**:
```
@q After migrating to RDS, my loan application queries are 30% slower. Help me identify performance optimization opportunities.
```

**Diagnostic Steps**:
1. Compare parameter groups
2. Analyze wait statistics
3. Review instance class sizing
4. Check storage configuration

---

## Phase 2: PostgreSQL Conversion Issues

### Issue: Data Type Conversion Errors
**Symptoms**: Schema conversion fails with data type mismatches
**Q Developer Prompt**:
```
@q I'm getting data type conversion errors when migrating from SQL Server to PostgreSQL. The error is: [error]. Help me resolve the schema conversion.
```

**Common Conversions**:
```sql
-- SQL Server → PostgreSQL
UNIQUEIDENTIFIER → UUID
NVARCHAR(MAX) → TEXT
DATETIME2 → TIMESTAMP
DECIMAL(18,2) → NUMERIC(18,2)
```

### Issue: Stored Procedure Conversion Complexity
**Symptoms**: Complex stored procedure won't convert to PostgreSQL
**Q Developer Prompt**:
```
@q This T-SQL stored procedure uses cursors, temp tables, and dynamic SQL. Help me convert it to PostgreSQL or refactor to C# application logic.
```

**Resolution Strategy**:
1. **Analyze Complexity**: Use Q Developer to assess conversion feasibility
2. **Refactor Decision**: Move complex logic to application layer
3. **Incremental Conversion**: Convert simple procedures first

### Issue: Entity Framework Provider Issues
**Symptoms**: EF Core fails with PostgreSQL provider
**Q Developer Prompt**:
```
@q After switching from SQL Server to PostgreSQL provider in Entity Framework, I'm getting this error: [error]. Help me fix the EF configuration.
```

**Common Fixes**:
```csharp
// Update connection string and provider
services.AddDbContext<LoanContext>(options =>
    options.UseNpgsql(connectionString));
```

### Issue: DMS Replication Lag
**Symptoms**: Data migration taking too long or failing
**Q Developer Prompt**:
```
@q My DMS replication task is running slowly and showing lag. Help me optimize the migration performance.
```

**Optimization Steps**:
1. **Instance Sizing**: Increase replication instance size
2. **Parallel Load**: Enable parallel loading for large tables
3. **Batch Settings**: Optimize batch apply settings
4. **Network**: Verify network bandwidth

---

## Phase 3: DynamoDB Integration Issues

### Issue: Hot Partition Problems
**Symptoms**: DynamoDB throttling errors
**Q Developer Prompt**:
```
@q My DynamoDB table is experiencing throttling. The partition key design is [design]. Help me resolve hot partition issues.
```

**Solutions**:
1. **Partition Key Review**: Add randomization to partition key
2. **Write Sharding**: Implement write sharding pattern
3. **Provisioned Capacity**: Increase write capacity units

### Issue: GSI Design Problems
**Symptoms**: Queries not supported by current GSI design
**Q Developer Prompt**:
```
@q I need to query DynamoDB by [access pattern] but my current GSI design doesn't support it. Help me redesign the indexes.
```

**Design Review**:
```json
{
  "RequiredQueries": [
    "Get logs by service and date range",
    "Get logs by status code",
    "Get logs by timestamp range"
  ],
  "GSIRecommendations": "Q Developer will suggest optimal GSI design"
}
```

### Issue: Dual-Write Consistency
**Symptoms**: Data inconsistency between PostgreSQL and DynamoDB
**Q Developer Prompt**:
```
@q My dual-write pattern is causing data inconsistency between PostgreSQL and DynamoDB. Help me implement proper error handling and consistency checks.
```

**Implementation Pattern**:
```csharp
public async Task LogIntegrationAsync(IntegrationLog log)
{
    try
    {
        // Write to PostgreSQL first (source of truth)
        await _postgresRepository.CreateAsync(log);
        
        // Then write to DynamoDB
        await _dynamoRepository.CreateAsync(log);
    }
    catch (Exception ex)
    {
        // Q Developer will help implement proper error handling
        await HandleDualWriteFailure(log, ex);
    }
}
```

---

## General AWS Issues

### Issue: IAM Permission Denied
**Symptoms**: AWS operations fail with access denied
**Q Developer Prompt**:
```
@q I'm getting IAM permission denied errors when trying to [operation]. Help me identify the required permissions and create the proper IAM policy.
```

**Diagnostic Commands**:
```bash
aws sts get-caller-identity
aws iam simulate-principal-policy --policy-source-arn [user-arn] --action-names [action]
```

### Issue: CloudFormation Stack Failures
**Symptoms**: Infrastructure deployment fails
**Q Developer Prompt**:
```
@q My CloudFormation stack deployment failed with error: [error]. Help me diagnose and fix the template issues.
```

**Troubleshooting Steps**:
1. Check CloudFormation events
2. Validate template syntax
3. Verify resource limits
4. Review IAM permissions

---

## Application-Specific Issues

### Issue: Connection Pool Exhaustion
**Symptoms**: Application throws connection timeout errors
**Q Developer Prompt**:
```
@q My .NET application is experiencing connection pool exhaustion after database migration. Help me optimize connection management.
```

**Solutions**:
```csharp
// Optimize connection string
"Server=endpoint;Database=db;Pooling=true;Min Pool Size=5;Max Pool Size=100;Connection Timeout=30;"
```

### Issue: Performance Regression
**Symptoms**: API response times increased after migration
**Q Developer Prompt**:
```
@q After database migration, my loan application API response times increased by 40%. Help me identify and fix performance bottlenecks.
```

**Analysis Steps**:
1. **Query Analysis**: Compare execution plans
2. **Index Review**: Verify index migration
3. **Connection Optimization**: Review connection pooling
4. **Caching Strategy**: Implement appropriate caching

---

## Emergency Recovery Procedures

### Rollback to Previous Phase
**When to Use**: Critical issues preventing workshop progress

**Phase 1 Rollback**:
```bash
# Restore local SQL Server connection
# Update appsettings.json to local connection string
```

**Phase 2 Rollback**:
```bash
# Switch back to RDS SQL Server
# Revert Entity Framework provider changes
```

**Phase 3 Rollback**:
```bash
# Disable DynamoDB logging
# Use PostgreSQL-only logging service
```

### Data Recovery
**Q Developer Prompt**:
```
@q I need to recover data from [source] to [target] after a failed migration. Help me create a recovery procedure.
```

---

## Prevention Best Practices

### Pre-Migration Validation
- [ ] Test all scripts in development environment
- [ ] Verify backup and restore procedures
- [ ] Validate network connectivity
- [ ] Confirm IAM permissions

### During Migration Monitoring
- [ ] Monitor CloudWatch metrics
- [ ] Track migration progress
- [ ] Validate data integrity at each step
- [ ] Test application functionality continuously

### Post-Migration Verification
- [ ] Run comprehensive test suite
- [ ] Compare performance metrics
- [ ] Verify all features working
- [ ] Document lessons learned

---

**Remember**: Q Developer is your primary troubleshooting assistant. Always start with a detailed prompt describing your issue, error messages, and current configuration.