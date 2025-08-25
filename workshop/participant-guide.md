# Workshop Participant Guide
## AWS Database Modernization with Q Developer

### Quick Start Checklist
- [ ] AWS account with admin access
- [ ] Q Developer extension installed and authenticated
- [ ] .NET 9 SDK installed
- [ ] Workshop repository cloned
- [ ] Baseline application deployed locally

### Workshop Flow

#### Phase 1: RDS Migration (90 min)
**Objective**: Lift-and-shift SQL Server to AWS RDS

**Key Q Developer Prompts**:
```
@q Analyze this SQL Server database and recommend RDS configuration
@q Generate CloudFormation template for RDS with optimal settings
@q Help troubleshoot RDS connection issues
```

**Success Criteria**:
- RDS instance deployed and accessible
- Database migrated with zero data loss
- Application connects successfully

#### Phase 2: PostgreSQL Conversion (120 min)
**Objective**: Modernize to PostgreSQL with stored procedure refactoring

**Key Q Developer Prompts**:
```
@q Convert this T-SQL stored procedure to PostgreSQL or C# service logic
@q Update Entity Framework from SQL Server to PostgreSQL provider
@q Optimize this query for PostgreSQL performance
```

**Success Criteria**:
- Schema converted successfully
- Stored procedures refactored to application logic
- All API endpoints functional

#### Phase 3: DynamoDB Integration (90 min)
**Objective**: Migrate high-volume logs to DynamoDB

**Key Q Developer Prompts**:
```
@q Design DynamoDB table for these log access patterns
@q Implement dual-write pattern for PostgreSQL and DynamoDB
@q Create batch migration script for existing log data
```

**Success Criteria**:
- DynamoDB table designed and deployed
- Hybrid logging service implemented
- 98% cost reduction demonstrated

### Q Developer Best Practices

**Effective Prompting**:
- Be specific about your context and requirements
- Include error messages and current configuration
- Ask for explanations along with code generation
- Iterate and refine based on AI responses

**Common Patterns**:
- Analysis: `@q Analyze this [component] and explain...`
- Conversion: `@q Convert this [source] to [target] with...`
- Troubleshooting: `@q I'm getting this error: [error]. Help me...`
- Optimization: `@q Review this [code] and suggest improvements...`

### Support Resources

**Troubleshooting**: Use Q Developer first, then ask instructors
**Documentation**: All materials in workshop/ folder
**Emergency**: Rollback procedures in troubleshooting guide