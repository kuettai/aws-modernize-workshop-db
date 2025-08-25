# Hands-On Lab Instructions
## AWS Database Modernization Workshop

### Lab Structure Overview

Each lab follows the **Discover → Analyze → Implement → Validate** pattern using Q Developer throughout.

---

## Lab 1: Lift and Shift to AWS RDS (90 minutes)

### Lab 1.1: Current State Discovery (20 minutes)

**Objective**: Analyze the baseline application using Q Developer

**Q Developer Prompts**:
```
@q Analyze the LoanApplication database schema and identify the main tables, relationships, and stored procedures
```

**Tasks**:
1. Open `LoanApplication.sln` in Visual Studio
2. Use Q Developer to analyze the database context
3. Document current performance metrics
4. Identify migration dependencies

**Expected Output**: Architecture analysis report with Q Developer insights

### Lab 1.2: RDS Infrastructure Setup (25 minutes)

**Objective**: Deploy AWS RDS SQL Server instance

**Q Developer Prompts**:
```
@q Help me create a CloudFormation template for RDS SQL Server with optimal settings for a loan application workload
```

**Tasks**:
1. Deploy CloudFormation template: `migration/phase1/rds-infrastructure.yaml`
2. Configure security groups and parameter groups
3. Verify RDS instance accessibility

**Validation**:
```bash
aws rds describe-db-instances --db-instance-identifier workshop-sqlserver
```

### Lab 1.3: Database Migration (25 minutes)

**Objective**: Migrate database to RDS using backup/restore

**Q Developer Prompts**:
```
@q Generate a PowerShell script to backup SQL Server database and restore to AWS RDS
```

**Tasks**:
1. Execute backup script: `Scripts/Backup-Database.ps1`
2. Upload backup to S3
3. Restore to RDS using native backup/restore
4. Update connection strings in `appsettings.json`

**Validation**:
```sql
SELECT COUNT(*) FROM LoanApplications; -- Should return 200,000+
EXEC sp_GetLoanSummary @StartDate = '2023-01-01', @EndDate = '2023-12-31';
```

### Lab 1.4: Application Testing (20 minutes)

**Objective**: Verify application functionality with RDS

**Q Developer Prompts**:
```
@q Help me create integration tests to validate the loan application API endpoints after RDS migration
```

**Tasks**:
1. Run application with RDS connection
2. Execute API tests: `dotnet test`
3. Performance comparison with baseline
4. Document any issues encountered

---

## Lab 2: PostgreSQL Modernization (120 minutes)

### Lab 2.1: Schema Conversion Analysis (30 minutes)

**Objective**: Assess T-SQL to PostgreSQL conversion complexity

**Q Developer Prompts**:
```
@q Analyze these T-SQL stored procedures and identify conversion challenges for PostgreSQL migration
```

**Tasks**:
1. Use Q Developer to analyze stored procedures
2. Identify incompatible T-SQL features
3. Plan conversion strategy (convert vs. refactor to C#)
4. Document conversion complexity matrix

### Lab 2.2: Aurora PostgreSQL Setup (20 minutes)

**Objective**: Deploy Aurora PostgreSQL cluster

**Q Developer Prompts**:
```
@q Create Aurora PostgreSQL CloudFormation template with performance optimization for financial applications
```

**Tasks**:
1. Deploy: `migration/phase2/aurora-postgresql.yaml`
2. Configure cluster parameters
3. Install required extensions
4. Verify connectivity

### Lab 2.3: Schema Migration (35 minutes)

**Objective**: Convert schema and migrate data

**Q Developer Prompts**:
```
@q Convert this SQL Server CREATE TABLE statement to PostgreSQL syntax with appropriate data types
```

**Tasks**:
1. Execute schema conversion: `Scripts/Convert-Schema.ps1`
2. Configure DMS replication instance
3. Start data migration task
4. Monitor migration progress

**Validation**:
```sql
-- PostgreSQL validation queries
SELECT COUNT(*) FROM loan_applications;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```

### Lab 2.4: Stored Procedure Refactoring (35 minutes)

**Objective**: Convert stored procedures to application logic

**Q Developer Prompts**:
```
@q Convert this T-SQL stored procedure to C# business logic in a service class
```

**Tasks**:
1. Analyze `sp_CalculateLoanMetrics` with Q Developer
2. Refactor complex logic to `LoanCalculationService.cs`
3. Update Entity Framework models for PostgreSQL
4. Implement new service methods

**Code Example**:
```csharp
// Q Developer will help generate this service class
public class LoanCalculationService
{
    public async Task<LoanMetrics> CalculateMetricsAsync(Guid customerId)
    {
        // Converted stored procedure logic
    }
}
```

---

## Lab 3: DynamoDB Integration (90 minutes)

### Lab 3.1: NoSQL Design Workshop (25 minutes)

**Objective**: Design DynamoDB table for IntegrationLogs

**Q Developer Prompts**:
```
@q Analyze the IntegrationLogs table access patterns and recommend optimal DynamoDB partition and sort key design
```

**Tasks**:
1. Analyze current log query patterns
2. Design partition key: `ServiceName-Date`
3. Design sort key: `LogTimestamp#LogId`
4. Plan Global Secondary Indexes

**Design Output**:
```json
{
  "TableName": "IntegrationLogs",
  "PartitionKey": "ServiceName-Date",
  "SortKey": "LogTimestamp#LogId",
  "GSI1": "StatusCode-LogTimestamp",
  "GSI2": "ServiceName-StatusCode",
  "GSI3": "LogTimestamp-ServiceName"
}
```

### Lab 3.2: Service Layer Implementation (25 minutes)

**Objective**: Implement hybrid logging service

**Q Developer Prompts**:
```
@q Create a C# service class that implements dual-write pattern for PostgreSQL and DynamoDB logging
```

**Tasks**:
1. Deploy DynamoDB table: `migration/phase3/dynamodb-table.yaml`
2. Implement `HybridLoggingService.cs`
3. Configure dependency injection
4. Update controllers to use new service

### Lab 3.3: Data Migration (25 minutes)

**Objective**: Migrate existing logs to DynamoDB

**Q Developer Prompts**:
```
@q Generate a batch migration script to transfer PostgreSQL IntegrationLogs to DynamoDB with proper error handling
```

**Tasks**:
1. Execute migration: `migration/phase3/migrate-logs.exe`
2. Monitor migration progress
3. Validate data integrity
4. Performance comparison testing

### Lab 3.4: Validation Testing (15 minutes)

**Objective**: Verify hybrid architecture functionality

**Q Developer Prompts**:
```
@q Create test cases to validate both PostgreSQL and DynamoDB logging are working correctly
```

**Tasks**:
1. Test dual-write functionality
2. Query performance comparison
3. Cost analysis validation
4. End-to-end application testing

---

## Common Q Developer Patterns

### Code Analysis Pattern
```
@q Analyze this [component] and explain its purpose, dependencies, and potential migration challenges
```

### Conversion Pattern
```
@q Convert this [source technology] code to [target technology] with best practices
```

### Troubleshooting Pattern
```
@q I'm getting this error during [migration phase]: [error message]. Help me diagnose and fix it
```

### Optimization Pattern
```
@q Review this [implementation] and suggest performance optimizations for AWS cloud environment
```

---

## Lab Success Criteria

**Phase 1 Success**:
- [ ] RDS instance deployed and accessible
- [ ] Database migrated with zero data loss
- [ ] Application connects and functions correctly
- [ ] Performance baseline established

**Phase 2 Success**:
- [ ] PostgreSQL schema converted successfully
- [ ] Stored procedures refactored to application logic
- [ ] Entity Framework updated and working
- [ ] All API endpoints functional

**Phase 3 Success**:
- [ ] DynamoDB table designed and deployed
- [ ] Hybrid logging service implemented
- [ ] Data migration completed successfully
- [ ] Performance improvements demonstrated

**Q Developer Proficiency**:
- [ ] Successfully used Q Developer for code analysis
- [ ] Generated migration scripts with AI assistance
- [ ] Troubleshot issues using Q Developer prompts
- [ ] Applied AWS best practices through AI guidance