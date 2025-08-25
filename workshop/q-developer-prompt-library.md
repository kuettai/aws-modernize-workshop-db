# Q Developer Prompt Library
## Database Modernization Workshop

### Phase 1: RDS Migration Prompts

#### Discovery & Analysis
```
@q Analyze this SQL Server database schema and identify migration readiness for AWS RDS
@q What are the key considerations for migrating a financial services database to RDS?
@q Help me establish performance baselines before migrating to RDS SQL Server
```

#### Implementation
```
@q Generate CloudFormation template for RDS SQL Server with optimal settings for loan application workload
@q Create PowerShell script for SQL Server backup and S3 upload with error handling
@q Update this .NET connection string configuration for AWS RDS with security best practices
```

#### Validation
```
@q Generate validation queries to verify data integrity after RDS migration
@q Create performance comparison scripts between on-premises and RDS SQL Server
@q Help troubleshoot RDS connection timeout issues in .NET application
```

### Phase 2: PostgreSQL Conversion Prompts

#### Schema Conversion
```
@q Convert this SQL Server table definition to PostgreSQL with proper data type mappings
@q Analyze this T-SQL stored procedure and recommend PostgreSQL conversion strategy
@q Transform these SQL Server indexes to PostgreSQL equivalents with performance optimization
```

#### Stored Procedure Migration
```
@q Convert this T-SQL stored procedure to PostgreSQL PL/pgSQL maintaining business logic
@q This stored procedure uses cursors and temp tables - should I convert or refactor to C#?
@q Rewrite this dynamic SQL generation for PostgreSQL with parameterized queries
```

#### Application Updates
```
@q Update Entity Framework configuration from SQL Server to PostgreSQL provider
@q Convert this .NET data access layer for Aurora PostgreSQL compatibility
@q Optimize this LINQ query for PostgreSQL performance with proper indexing
```

### Phase 3: DynamoDB Integration Prompts

#### NoSQL Design
```
@q Analyze these IntegrationLogs access patterns and design optimal DynamoDB table structure
@q Design DynamoDB GSIs for time-range queries, service filtering, and error log access
@q Recommend partition key strategy to avoid hot partitions in high-volume logging
```

#### Implementation
```
@q Create C# repository class for DynamoDB logging using AWS SDK v3 with batch operations
@q Implement dual-write pattern for PostgreSQL and DynamoDB during migration transition
@q Generate data migration script to move 2M+ records from PostgreSQL to DynamoDB
```

#### Optimization
```
@q Set up CloudWatch monitoring for DynamoDB logging with cost and performance alerts
@q Create comprehensive validation scripts for PostgreSQL to DynamoDB migration
@q Design DynamoDB backup and archival strategy for long-term log retention
```

### Troubleshooting Prompts

#### Common Issues
```
@q My PostgreSQL migration shows performance degradation - analyze and optimize
@q Getting Entity Framework errors after PostgreSQL conversion - help diagnose
@q DynamoDB queries are slow for time-range searches - optimize table design
@q Application connection timeouts after Aurora migration - troubleshoot pooling
```

#### Error Resolution
```
@q This stored procedure conversion fails in PostgreSQL with error: [error message]
@q Entity Framework migration generates incorrect PostgreSQL syntax - fix the issue
@q DynamoDB batch write operations are throttling - optimize throughput settings
```

### Best Practices Prompts

#### Security & Performance
```
@q Review this database configuration for AWS security best practices
@q Optimize this Aurora PostgreSQL setup for financial services compliance
@q Implement proper error handling and retry logic for DynamoDB operations
```

#### Cost Optimization
```
@q Analyze this database usage pattern and recommend cost optimization strategies
@q Compare costs between RDS SQL Server, Aurora PostgreSQL, and DynamoDB for this workload
@q Design cost-effective backup and retention strategy for hybrid database architecture
```