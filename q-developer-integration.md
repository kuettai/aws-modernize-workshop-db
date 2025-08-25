# Amazon Q Developer Integration Guide
## AI-Assisted Database Modernization Workshop

### 🎯 Q Developer Integration Objectives
- Leverage AI assistance throughout the migration process
- Accelerate code analysis and conversion tasks
- Provide intelligent troubleshooting and optimization
- Demonstrate modern AI-assisted development workflows

### 🚀 Workshop Setup with Q Developer

#### Prerequisites
- Visual Studio 2022 or VS Code with Q Developer extension
- AWS account with Q Developer access
- Workshop baseline environment deployed

#### Q Developer Setup
```powershell
# Install Q Developer extension in Visual Studio
# 1. Open Visual Studio 2022
# 2. Go to Extensions > Manage Extensions
# 3. Search for "Amazon Q Developer"
# 4. Install and restart Visual Studio

# Configure AWS credentials for Q Developer
aws configure set region us-east-1
aws configure set aws_access_key_id YOUR_ACCESS_KEY
aws configure set aws_secret_access_key YOUR_SECRET_KEY

# Verify Q Developer connection
# Open Visual Studio > View > Other Windows > Amazon Q Developer
```

### 📊 Phase-by-Phase Q Developer Usage

#### Phase 1: SQL Server to RDS Migration

**Q Developer Use Cases:**
1. **Database Schema Analysis Discovery**
   ```
   Step 1 - Initial Assessment Prompt:
   "How should I start analyzing if my SQL Server database is capable of migrating to AWS RDS SQL Server? What information do I need to gather first?"
   
   Expected Q Response: Explains schema extraction, compatibility checks, sizing analysis
   
   Step 2 - Schema Extraction Guidance:
   "Guide me through extracting my SQL Server database schema for analysis. What's the best way to export schema information including tables, stored procedures, and dependencies?"
   
   Expected Q Response: Provides SQL scripts or SSMS steps to export schema
   
   Step 3 - Schema Analysis Prompt:
   "Here is my exported database schema from export-schema.sql. Please analyze this for AWS RDS SQL Server migration readiness. Identify any compatibility issues, optimization opportunities, and migration complexity."
   
   [Paste database schema content]
   
   Expected Q Response: Detailed compatibility analysis, risk assessment, recommendations
   ```

2. **Migration Strategy Discovery**
   ```
   Step 1 - Discovery Prompt:
   "I need to migrate a SQL Server database from on-premises to AWS RDS SQL Server. The database is about 5GB with 200K+ records. What are the recommended migration approaches and their trade-offs?"
   
   Expected Q Response: Explains backup/restore via S3, DMS options, pros/cons
   
   Step 2 - Method Selection Prompt:
   "Based on your recommendations, I want to use the backup and restore method via S3. Walk me through the high-level steps and what AWS services I'll need."
   
   Expected Q Response: Outlines S3 bucket, backup process, RDS restore procedure
   
   Step 3 - Implementation Prompt:
   "Great! Now generate the PowerShell scripts for this backup-to-S3-to-RDS migration approach. Include error handling, progress monitoring, and validation steps."
   
   Alternative Step 3 - CloudShell Prompt:
   "Generate AWS CLI commands that I can run in CloudShell to perform this migration. Include S3 operations and RDS restore commands."
   ```

3. **Performance Baseline Discovery**
   ```
   Step 1 - Understanding Baselines:
   "I'm about to migrate my SQL Server database to RDS. Why is establishing performance baselines important, and what metrics should I capture before migration?"
   
   Expected Q Response: Explains importance of baselines, key metrics (query time, CPU, memory, I/O)
   
   Step 2 - Baseline Strategy:
   "What's the best approach to capture comprehensive performance baselines for a loan application database with high transaction volume? What tools and queries should I use?"
   
   Expected Q Response: Recommends SQL Server DMVs, performance counters, query execution plans
   
   Step 3 - Implementation Request:
   "Generate SQL queries to establish performance baselines for my database migration validation. Focus on query execution time, resource usage, connection metrics, and key business queries for a loan application system."
   
   Expected Q Response: Specific SQL scripts for baseline measurement
   ```

4. **Application Configuration Discovery**
   ```
   Step 1 - Configuration Impact Assessment:
   "After migrating my database to RDS, what changes do I need to make to my .NET application configuration? What are the potential issues I should watch out for?"
   
   Expected Q Response: Explains connection string changes, security considerations, performance implications
   
   Step 2 - Configuration Strategy:
   "My .NET application currently connects to localhost SQL Server. What's the best practice for updating connection strings for RDS? Should I use different configurations for development vs production?"
   
   Expected Q Response: Recommends configuration patterns, environment-specific settings, security best practices
   
   Step 3 - Implementation Request:
   "Here's my current appsettings.json configuration. Update this to connect to AWS RDS SQL Server instead of localhost. Include proper security settings and connection pooling for production use."
   
   [Paste current appsettings.json]
   
   Expected Q Response: Updated configuration with RDS endpoint, security settings, best practices
   ```

#### Phase 2: PostgreSQL Conversion

**Q Developer Use Cases:**
1. **PostgreSQL Migration Assessment Discovery**
   ```
   Step 1 - Migration Strategy Assessment:
   "I have a SQL Server database running on AWS RDS and want to migrate to PostgreSQL Aurora. What are the key considerations and challenges I should expect? What's the recommended approach for this type of migration?"
   
   Expected Q Response: Explains schema conversion challenges, data type differences, stored procedure complexity, application layer changes
   
   Step 2 - Conversion Complexity Analysis:
   "What tools and methods are available for converting SQL Server schemas and stored procedures to PostgreSQL? How should I assess the complexity of my existing T-SQL code before starting the conversion?"
   
   Expected Q Response: Recommends AWS SCT, manual conversion approaches, complexity assessment criteria
   
   Step 3 - Migration Planning Prompt:
   "Here's my current SQL Server database schema and stored procedures. Analyze the conversion complexity and create a migration plan with risk assessment and timeline estimates."
   
   [Paste database-schema.sql and stored procedures]
   
   Expected Q Response: Detailed analysis of conversion challenges, recommended approach, timeline estimates
   ```

2. **Data Type Conversion Discovery**
   ```
   Step 1 - Data Type Impact Assessment:
   "I'm migrating from SQL Server to PostgreSQL. What are the most common data type conversion challenges I should be aware of? Which SQL Server data types don't have direct PostgreSQL equivalents?"
   
   Expected Q Response: Explains major data type differences, potential data loss scenarios, conversion strategies
   
   Step 2 - Schema-Specific Analysis:
   "Analyze my SQL Server schema and identify all data type conversions needed for PostgreSQL. Highlight any potential data loss or precision issues I should address."
   
   Current Schema Data Types:
   - NVARCHAR(MAX) for large text fields
   - DATETIME2 for timestamps
   - UNIQUEIDENTIFIER for GUIDs
   - DECIMAL(12,2) for currency
   - BIT for boolean flags
   - INT IDENTITY for auto-increment
   
   Expected Q Response: Specific PostgreSQL equivalents, migration scripts, potential issues
   
   Step 3 - Conversion Script Generation:
   "Generate the PostgreSQL schema conversion script for my loan application database. Include proper data type mappings, constraints, and indexes. Ensure no data loss during conversion."
   
   Expected Q Response: Complete PostgreSQL DDL script with proper type conversions
   ```

3. **Stored Procedure Conversion Strategy Discovery**
   ```
   Step 1 - Conversion Approach Assessment:
   "I have SQL Server stored procedures that use T-SQL specific features like cursors, temp tables, and dynamic SQL. What are my options for handling these in PostgreSQL? Should I convert them or move the logic elsewhere?"
   
   Expected Q Response: Explains PL/pgSQL conversion vs application layer refactoring, pros/cons of each approach
   
   Step 2 - Simple Procedure Conversion:
   "Here are my three simple stored procedures. Walk me through converting these to PostgreSQL PL/pgSQL. Explain the syntax differences and best practices."
   
   [Paste stored-procedures-simple.sql content]
   
   Expected Q Response: Step-by-step conversion with syntax explanations
   
   Step 3 - Complex Procedure Strategy:
   "This complex stored procedure uses advanced T-SQL features including cursors, CTEs, window functions, and dynamic SQL. Analyze this and recommend the best modernization approach - convert to PL/pgSQL or refactor to C# application logic?"
   
   [Paste stored-procedure-complex.sql content]
   
   Expected Q Response: Analysis of complexity, recommendation with justification, implementation approach
   ```

4. **Entity Framework PostgreSQL Migration Discovery**
   ```
   Step 1 - EF Provider Impact Assessment:
   "My .NET application uses Entity Framework with SQL Server. What changes are needed to switch to PostgreSQL? What are the potential compatibility issues and performance considerations?"
   
   Expected Q Response: Explains NuGet package changes, connection string format, potential EF compatibility issues
   
   Step 2 - Configuration Migration Strategy:
   "What's the best approach for updating my Entity Framework configuration from SQL Server to PostgreSQL? Should I maintain separate configurations for different environments?"
   
   Expected Q Response: Recommends configuration patterns, environment management, migration strategies
   
   Step 3 - Implementation Request:
   "Here's my current Entity Framework DbContext and configuration. Update this to work with PostgreSQL Aurora. Include proper connection string format, provider configuration, and any necessary model changes."
   
   Current Configuration:
   ```csharp
   // From LoanApplication/Data/ApplicationDbContext.cs
   public class ApplicationDbContext : DbContext
   {
       public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }
       
       public DbSet<Customer> Customers { get; set; }
       public DbSet<LoanApplication> LoanApplications { get; set; }
       // ... other DbSets
   }
   ```
   
   Expected Q Response: Updated DbContext with PostgreSQL provider, connection string examples, configuration best practices
   ```

5. **Application Layer Migration Discovery**
   ```
   Step 1 - Code Impact Assessment:
   "After migrating my database from SQL Server to PostgreSQL, what changes will be needed in my .NET application code? What are the common issues developers face during this transition?"
   
   Expected Q Response: Explains LINQ compatibility, SQL syntax differences, performance considerations
   
   Step 2 - Query Optimization Strategy:
   "My application has direct SQL queries and Entity Framework queries. How should I optimize these for PostgreSQL? What PostgreSQL-specific features can improve performance?"
   
   Expected Q Response: PostgreSQL optimization techniques, indexing strategies, query plan analysis
   
   Step 3 - Testing and Validation Approach:
   "What's the best strategy for testing my application after the PostgreSQL migration? How can I ensure data integrity and performance are maintained?"
   
   Expected Q Response: Testing methodologies, validation scripts, performance benchmarking approaches
   ```

6. **Aurora PostgreSQL Optimization Discovery**
   ```
   Step 1 - Aurora-Specific Features:
   "I'm migrating to Aurora PostgreSQL instead of standard RDS PostgreSQL. What Aurora-specific features should I leverage? How do I optimize for Aurora's architecture?"
   
   Expected Q Response: Explains Aurora benefits, read replicas, performance insights, cost optimization
   
   Step 2 - Performance Tuning Strategy:
   "What PostgreSQL and Aurora-specific performance tuning should I implement for a loan application system with high transaction volume? Focus on connection pooling, indexing, and query optimization."
   
   Expected Q Response: Specific tuning recommendations, configuration parameters, monitoring strategies
   
   Step 3 - Monitoring and Maintenance:
   "Set up comprehensive monitoring for my Aurora PostgreSQL database. What metrics should I track, and how do I set up alerting for performance issues?"
   
   Expected Q Response: CloudWatch metrics, Performance Insights setup, alerting configurations
   ```

#### Phase 3: DynamoDB Integration

**Q Developer Use Cases:**
1. **NoSQL Migration Strategy Discovery**
   ```
   Step 1 - NoSQL Suitability Assessment:
   "I have a PostgreSQL table called IntegrationLogs that stores high-volume API call logs. The table grows rapidly and is mainly used for time-based queries and troubleshooting. Should I consider migrating this to DynamoDB? What are the benefits and challenges?"
   
   Expected Q Response: Explains NoSQL benefits for high-volume time-series data, cost implications, access pattern considerations
   
   Step 2 - Migration Strategy Planning:
   "What's the best approach for migrating a high-volume logging table from PostgreSQL to DynamoDB while keeping the rest of my application data in PostgreSQL? How do I handle the hybrid architecture?"
   
   Expected Q Response: Explains hybrid data architecture patterns, migration strategies, application layer considerations
   
   Step 3 - Implementation Roadmap:
   "Create a detailed migration plan for moving my IntegrationLogs table to DynamoDB. Include timeline, risk assessment, rollback strategy, and testing approach."
   
   Current IntegrationLogs Table Structure:
   - LogId (INT IDENTITY) - Primary key
   - ApplicationId (INT) - Foreign key to Applications
   - LogType (NVARCHAR(50)) - API, ERROR, INFO, DEBUG
   - ServiceName (NVARCHAR(100)) - External service called
   - LogTimestamp (DATETIME2) - When log was created
   - RequestData (NVARCHAR(MAX)) - JSON request payload
   - ResponseData (NVARCHAR(MAX)) - JSON response payload
   - ProcessingTimeMs (INT) - Response time in milliseconds
   
   Expected Q Response: Comprehensive migration plan with phases, timelines, and risk mitigation
   ```

2. **DynamoDB Table Design Discovery**
   ```
   Step 1 - Access Pattern Analysis:
   "Help me analyze the access patterns for my logging data to design an optimal DynamoDB table structure. What questions should I ask about how the data is queried and accessed?"
   
   Expected Q Response: Explains importance of access patterns, key design questions, performance considerations
   
   Step 2 - Key Design Strategy:
   "Based on these access patterns for my IntegrationLogs, recommend the optimal partition key and sort key design for DynamoDB:
   
   Common Query Patterns:
   - Get all logs for a specific application in the last 24 hours
   - Get all ERROR logs across all applications in a time range
   - Get all logs for a specific service (e.g., CreditCheckService) in a time range
   - Get logs by LogId for troubleshooting specific requests
   - Get performance metrics (ProcessingTimeMs) for a service over time
   
   Write-heavy workload: ~1000 log entries per minute
   Read patterns: Mostly recent data (last 7 days), occasional historical queries"
   
   Expected Q Response: Recommended partition key/sort key design, GSI recommendations, hot partition avoidance
   
   Step 3 - Table Structure Implementation:
   "Generate the DynamoDB table creation script and GSI design based on your recommendations. Include proper attribute definitions, throughput settings, and cost optimization considerations."
   
   Expected Q Response: Complete DynamoDB table definition with CloudFormation/CDK or AWS CLI commands
   ```

3. **Data Migration Strategy Discovery**
   ```
   Step 1 - Migration Approach Assessment:
   "What are the different approaches for migrating existing PostgreSQL data to DynamoDB? I have about 2 million log records spanning 2 years. What are the pros and cons of each approach?"
   
   Expected Q Response: Explains batch migration, streaming migration, dual-write patterns, AWS DMS limitations for DynamoDB
   
   Step 2 - Migration Tool Selection:
   "Which tools and services should I use for migrating 2 million records from PostgreSQL to DynamoDB? Consider data transformation needs, downtime requirements, and cost factors."
   
   Expected Q Response: Recommends custom migration scripts, AWS Glue, Lambda functions, or other appropriate tools
   
   Step 3 - Migration Script Development:
   "Create a comprehensive C# migration application that:
   - Reads data from PostgreSQL IntegrationLogs table in batches
   - Transforms the data for DynamoDB format
   - Handles DynamoDB batch write operations
   - Includes error handling, retry logic, and progress tracking
   - Supports resume capability if migration fails partway
   
   Include proper logging and validation to ensure data integrity."
   
   Expected Q Response: Complete C# console application with batch processing, error handling, and monitoring
   ```

4. **AWS SDK Integration Discovery**
   ```
   Step 1 - SDK Architecture Planning:
   "I need to integrate DynamoDB into my existing .NET application that currently uses Entity Framework with PostgreSQL. What's the best architectural approach for this hybrid data access pattern?"
   
   Expected Q Response: Explains repository pattern, dependency injection, service layer design for hybrid data access
   
   Step 2 - Implementation Strategy:
   "How should I structure my C# code to handle both PostgreSQL (for business data) and DynamoDB (for logging data)? Show me the recommended patterns for dependency injection and service registration."
   
   Expected Q Response: Code structure recommendations, DI container setup, service registration patterns
   
   Step 3 - Repository Implementation:
   "Create a complete C# repository implementation for DynamoDB logging operations using AWS SDK v3. Include:
   
   Required Operations:
   - InsertLogAsync(logEntry) - Single log insertion
   - InsertLogBatchAsync(logEntries) - Batch insertion for high throughput
   - GetLogsByApplicationAsync(applicationId, startDate, endDate) - Time range queries
   - GetLogsByServiceAsync(serviceName, startDate, endDate) - Service-specific logs
   - GetErrorLogsAsync(startDate, endDate) - Error log filtering
   - GetLogByIdAsync(logId) - Single log retrieval
   
   Include proper error handling, retry policies, and performance optimization."
   
   Expected Q Response: Complete repository class with all CRUD operations, error handling, and AWS SDK best practices
   ```

5. **Application Integration Discovery**
   ```
   Step 1 - Integration Impact Assessment:
   "After moving logging to DynamoDB, what changes are needed in my existing .NET controllers and services? How do I maintain the same logging interface while switching the underlying storage?"
   
   Expected Q Response: Explains interface abstraction, dependency injection updates, minimal code changes approach
   
   Step 2 - Service Layer Design:
   "Design a logging service that can write to DynamoDB but maintains the same interface as my current PostgreSQL-based logging. Show how to handle the transition period where I might need to write to both systems."
   
   Expected Q Response: Service interface design, dual-write pattern implementation, gradual migration approach
   
   Step 3 - Controller Integration:
   "Update my existing .NET controllers to use the new DynamoDB logging service. Here's my current controller code that logs API calls:"
   
   Current Controller Pattern:
   ```csharp
   [HttpPost]
   public async Task<IActionResult> ProcessLoanApplication(LoanApplicationRequest request)
   {
       var logEntry = new IntegrationLog
       {
           ApplicationId = request.ApplicationId,
           LogType = "API",
           ServiceName = "LoanProcessing",
           LogTimestamp = DateTime.UtcNow,
           RequestData = JsonSerializer.Serialize(request)
       };
       
       // Current EF logging
       _context.IntegrationLogs.Add(logEntry);
       await _context.SaveChangesAsync();
       
       // Process loan application...
       var result = await _loanService.ProcessApplication(request);
       
       // Update log with response
       logEntry.ResponseData = JsonSerializer.Serialize(result);
       logEntry.ProcessingTimeMs = (int)(DateTime.UtcNow - logEntry.LogTimestamp).TotalMilliseconds;
       await _context.SaveChangesAsync();
       
       return Ok(result);
   }
   ```
   
   Expected Q Response: Updated controller code using DynamoDB logging service with minimal changes
   ```

6. **Performance Optimization Discovery**
   ```
   Step 1 - Performance Baseline Assessment:
   "How do I establish performance baselines for my current PostgreSQL logging before migrating to DynamoDB? What metrics should I measure to compare performance after migration?"
   
   Expected Q Response: Key performance metrics, benchmarking approaches, measurement tools
   
   Step 2 - DynamoDB Optimization Strategy:
   "What DynamoDB-specific optimizations should I implement for high-volume logging workloads? Consider write throughput, cost optimization, and query performance."
   
   Expected Q Response: Throughput optimization, batch writing strategies, cost management, query optimization
   
   Step 3 - Monitoring and Alerting Setup:
   "Set up comprehensive monitoring for my DynamoDB logging system. Include CloudWatch metrics, alarms for performance issues, and cost monitoring. Generate the CloudFormation template for monitoring setup."
   
   Expected Q Response: Complete monitoring setup with CloudWatch dashboards, alarms, and cost alerts
   ```

7. **Testing and Validation Discovery**
   ```
   Step 1 - Testing Strategy Planning:
   "What testing approach should I use to validate my DynamoDB migration? How do I ensure data integrity and performance meet requirements?"
   
   Expected Q Response: Testing methodologies, data validation approaches, performance testing strategies
   
   Step 2 - Validation Script Development:
   "Create comprehensive validation scripts to verify:
   - Data migration accuracy (record count, data integrity)
   - Query performance comparison (PostgreSQL vs DynamoDB)
   - Application functionality with new logging system
   - Error handling and retry mechanisms"
   
   Expected Q Response: Complete validation scripts with data integrity checks and performance comparisons
   
   Step 3 - Load Testing Implementation:
   "Design and implement load testing for the DynamoDB logging system to ensure it can handle production traffic volumes. Include realistic write patterns and query loads."
   
   Expected Q Response: Load testing scripts and performance benchmarking tools
   ```

### 🔧 Specific Q Developer Prompts Library

#### Phase 1: SQL Server to RDS Analysis Prompts
```
1. "Analyze this .NET application architecture and identify components that need updates for RDS migration."

2. "Review this SQL Server database schema and assess RDS migration readiness. Identify potential issues."

3. "Examine this connection string configuration and update it for AWS RDS SQL Server with security best practices."

4. "Analyze this backup strategy and recommend improvements for RDS automated backups and point-in-time recovery."
```

#### Phase 2: PostgreSQL Conversion Prompts
```
1. "Convert this SQL Server stored procedure to PostgreSQL PL/pgSQL. Maintain the same functionality but use PostgreSQL syntax and best practices."

2. "Transform this T-SQL cursor logic into a PostgreSQL FOR loop or recommend refactoring to C# LINQ equivalent."

3. "Analyze this Entity Framework DbContext and update it from SQL Server to PostgreSQL provider. Include necessary package changes."

4. "Convert this SQL Server MERGE statement to PostgreSQL UPSERT (INSERT ... ON CONFLICT) syntax."

5. "Rewrite this dynamic SQL generation to use PostgreSQL parameterized queries and avoid SQL injection."

6. "Convert this SQL Server error handling (TRY/CATCH) to PostgreSQL exception handling (EXCEPTION WHEN)."

7. "Analyze these SQL Server data types and provide PostgreSQL equivalents with migration considerations:
   - NVARCHAR(MAX) → TEXT
   - DATETIME2 → TIMESTAMP
   - UNIQUEIDENTIFIER → UUID
   - BIT → BOOLEAN
   - INT IDENTITY → SERIAL"

8. "Review this T-SQL stored procedure and rate its PostgreSQL conversion complexity (1-10 scale). Explain the challenges and recommend approach."

9. "Transform this SQL Server temp table logic to PostgreSQL temporary tables or table variables."

10. "Convert this SQL Server window function query to PostgreSQL syntax and optimize for Aurora performance."
```

#### Phase 2: Entity Framework Migration Prompts
```
1. "Update this Entity Framework configuration from Microsoft.EntityFrameworkCore.SqlServer to Npgsql.EntityFrameworkCore.PostgreSQL."

2. "Modify this DbContext OnConfiguring method to use PostgreSQL connection string format for Aurora."

3. "Convert these Entity Framework migrations from SQL Server to PostgreSQL syntax."

4. "Optimize this Entity Framework query for PostgreSQL performance. Suggest indexing strategies."

5. "Update this Entity Framework model configuration to handle PostgreSQL naming conventions (snake_case vs PascalCase)."
```

#### Phase 2: Application Layer Migration Prompts
```
1. "Analyze this .NET controller that uses direct SQL queries and update for PostgreSQL compatibility."

2. "Review this data access layer and identify SQL Server-specific code that needs PostgreSQL conversion."

3. "Update this connection pooling configuration for optimal Aurora PostgreSQL performance."

4. "Convert this .NET application's appsettings.json from SQL Server to Aurora PostgreSQL configuration."

5. "Analyze this LINQ query and ensure it translates properly to PostgreSQL. Suggest optimizations."
```

#### Phase 3: DynamoDB Integration Prompts
```
1. "Analyze my PostgreSQL IntegrationLogs table access patterns and design an optimal DynamoDB table structure with proper partition/sort keys."

2. "Create a C# repository class for DynamoDB logging using AWS SDK v3. Include batch operations, error handling, and retry logic."

3. "Design a hybrid data architecture where business data stays in PostgreSQL but high-volume logs move to DynamoDB. Show the service layer pattern."

4. "Generate a comprehensive data migration script to move 2M+ records from PostgreSQL to DynamoDB with progress tracking and resume capability."

5. "Update my .NET controllers to use DynamoDB logging while maintaining the same interface as the current PostgreSQL-based logging."

6. "Create DynamoDB table design with GSIs for these query patterns: time-range queries, service-specific logs, error filtering, and application-specific logs."

7. "Implement a dual-write logging pattern that writes to both PostgreSQL and DynamoDB during migration transition period."

8. "Generate CloudWatch monitoring setup for DynamoDB logging including performance metrics, cost alerts, and error tracking."

9. "Create comprehensive validation scripts to verify data integrity and performance after PostgreSQL to DynamoDB migration."

10. "Design a DynamoDB backup and archival strategy for long-term log retention with cost optimization."

11. "Implement DynamoDB batch write operations with proper error handling for high-throughput logging scenarios."

12. "Create a DynamoDB query optimization strategy for time-series log data with efficient GSI usage."
```

#### Optimization and Performance Prompts
```
1. "Optimize this PostgreSQL query for Aurora performance. Suggest indexing strategies and query plan analysis."

2. "Review this DynamoDB table design and recommend improvements for cost and performance optimization."

3. "Analyze this .NET data access pattern and suggest optimizations for cloud databases (RDS/Aurora)."

for Aurora PostgreSQL. Consider connection pooling and transaction management."

5. "Review this Aurora PostgreSQL configuration and recommend parameter tuning for a loan application workload."

6. "Analyze this application's database connection pattern and suggest improvements for cloud database performance."
```

#### Troubleshooting and Validation Prompts
```
1. "My PostgreSQL migration is showing performance degradation. Analyze these query execution plans and suggest optimizations."

2. "I'm getting connection timeout errors after migrating to Aurora PostgreSQL. Help diagnose and fix the connection pooling issues."

3. "This Entity Framework query worked in SQL Server but fails in PostgreSQL. Help identify and fix the compatibility issue."

4. "Create a comprehensive testing strategy to validate data integrity after SQL Server to PostgreSQL migration."

5. "Generate performance benchmark queries to compare SQL Server vs PostgreSQL performance for my loan application database."

6. "Help troubleshoot this stored procedure conversion error in PostgreSQL. The T-SQL version worked but PL/pgSQL fails."
```

### 🎓 Workshop Implementation Guide

#### Pre-Workshop Setup
```
1. "I'm preparing a database modernization workshop. Help me create a checklist of prerequisites and setup requirements for participants."

2. "Generate a workshop environment validation script to ensure all AWS services and tools are properly configured before starting."

3. "Create a workshop timeline with estimated duration for each migration phase and Q Developer integration points."
```

#### During Workshop - Instructor Prompts
```
1. "Explain the key differences between relational and NoSQL databases to workshop participants. Use the loan application context for examples."

2. "Walk through the decision-making process for choosing between Aurora PostgreSQL and DynamoDB for different data types in our application."

3. "Demonstrate how to use Q Developer for real-time code analysis during the stored procedure conversion exercise."

4. "Show participants how to validate migration success using Q Developer to generate comparison queries between source and target databases."
```

#### Participant Self-Guided Prompts
```
1. "I'm new to PostgreSQL. Help me understand the key differences from SQL Server that I need to know for this migration workshop."

2. "Guide me through using AWS Schema Conversion Tool (SCT) to assess my database migration complexity."

3. "I'm stuck on converting this T-SQL cursor to PostgreSQL. Can you explain the step-by-step conversion process?"

4. "Help me troubleshoot why my Entity Framework queries are slower after migrating from SQL Server to PostgreSQL."
```

### 🔄 Advanced Q Developer Usage Patterns

#### Iterative Refinement Pattern
```
Step 1: "Analyze this code and identify potential issues"
Step 2: "Based on your analysis, suggest 3 improvement approaches"
Step 3: "Implement the recommended approach with detailed explanation"
Step 4: "Review the implementation and suggest further optimizations"
```

#### Comparative Analysis Pattern
```
Step 1: "Compare these two approaches for [specific task]"
Step 2: "What are the trade-offs between approach A and B?"
Step 3: "Which approach is better for our loan application scenario and why?"
Step 4: "Implement the chosen approach with best practices"
```

#### Problem-Solution-Validation Pattern
```
Step 1: "I'm experiencing [specific problem]. Help me understand the root cause"
Step 2: "What are the possible solutions for this problem?"
Step 3: "Implement the recommended solution"
Step 4: "How can I validate that the solution works correctly?"
```

### 📋 Workshop Success Metrics

#### Technical Completion Metrics
```
1. "Generate a checklist to validate successful completion of Phase 1 (SQL Server to RDS) migration."

2. "Create validation queries to confirm data integrity after Phase 2 (PostgreSQL conversion)."

3. "Design performance benchmarks to measure Phase 3 (DynamoDB integration) success."
```

#### Learning Outcome Validation
```
1. "Create a quiz to test participant understanding of database modernization concepts covered in the workshop."

2. "Generate practical exercises that demonstrate mastery of Q Developer for database migration tasks."

3. "Design a capstone project where participants apply all three migration phases to a new scenario."
```

### 🚀 Post-Workshop Follow-up

#### Continued Learning Prompts
```
1. "I completed the database modernization workshop. What are the next steps to deepen my knowledge of AWS database services?"

2. "How can I apply the migration patterns learned in the workshop to my organization's legacy applications?"

3. "What advanced AWS database features should I explore after mastering the basic migration patterns?"
```

#### Real-World Application
```
1. "Help me create a migration assessment framework for evaluating my organization's databases for AWS modernization."

2. "Generate a business case template for proposing database modernization projects based on the workshop learnings."

3. "Create a risk assessment checklist for production database migrations using the patterns learned in the workshop."
```

---

### 💡 Q Developer Best Practices for Database Modernization

1. **Start with Discovery**: Always begin with "How should I..." or "What are the options for..." questions
2. **Provide Context**: Include relevant code, schema, or configuration details in your prompts
3. **Ask for Alternatives**: Request multiple approaches and trade-off analysis
4. **Validate Understanding**: Ask Q Developer to explain the reasoning behind recommendations
5. **Iterate and Refine**: Use follow-up prompts to improve and optimize solutions
6. **Focus on Best Practices**: Always ask for security, performance, and cost optimization considerations
7. **Test and Validate**: Request validation scripts and testing approaches for all implementations

### 🎯 Workshop Learning Objectives Achievement

By the end of this workshop, participants will have:
- **Mastered AI-Assisted Migration**: Used Q Developer for all phases of database modernization
- **Hands-on Experience**: Migrated a complete application through three database platforms
- **Best Practices Knowledge**: Applied AWS database best practices with AI guidance
- **Problem-Solving Skills**: Learned to troubleshoot migration issues using AI assistance
- **Modern Architecture Understanding**: Designed hybrid data architectures for cloud-native applications for large-scale data migration."
```

#### Troubleshooting Prompts
```
1. "This PostgreSQL migration is failing with [error message]. Diagnose and provide solutions."

2. "The application is experiencing connection timeouts after PostgreSQL migration. Troubleshoot."

3. "DynamoDB queries are slow for time-range searches. Analyze and optimize."

4. "Entity Framework is generating inefficient PostgreSQL queries. How to improve?"
```

### 📋 Workshop Integration Points

#### Pre-Workshop Setup
- **Q Developer Demo**: Show AI-assisted code analysis
- **Prompt Engineering**: Teach effective prompting techniques
- **Integration Setup**: Configure Q Developer in development environment

#### During Migration Phases
- **Live Assistance**: Use Q Developer for real-time problem solving
- **Code Generation**: Generate migration scripts and validation queries
- **Best Practices**: Apply AI-recommended optimization patterns
- **Troubleshooting**: Debug issues with AI assistance

#### Post-Migration Validation
- **Performance Analysis**: Use Q Developer to analyze performance metrics
- **Code Review**: AI-assisted code quality assessment
- **Documentation**: Generate migration documentation and lessons learned

### 🎯 Learning Outcomes with Q Developer

#### Technical Skills
- **AI-Assisted Development**: Learn to effectively use AI for complex migrations
- **Prompt Engineering**: Develop skills in communicating with AI assistants
- **Code Analysis**: Understand how AI can analyze and improve code quality
- **Pattern Recognition**: Learn to identify migration patterns with AI assistance

#### Practical Benefits
- **Faster Migration**: Reduce manual conversion time by 40-60%
- **Higher Quality**: AI-suggested best practices and optimizations
- **Better Troubleshooting**: Intelligent error analysis and solutions
- **Knowledge Transfer**: Learn from AI explanations and recommendations

### 📊 Q Developer Success Metrics

#### Efficiency Gains
- **Code Conversion Speed**: 50% faster stored procedure conversion
- **Error Reduction**: 30% fewer migration errors with AI validation
- **Learning Acceleration**: Faster understanding of PostgreSQL patterns
- **Documentation Quality**: AI-generated documentation and explanations

#### Workshop Engagement
- **Participant Satisfaction**: Higher engagement with AI-assisted learning
- **Skill Development**: Improved AI collaboration skills
- **Problem Solving**: Enhanced troubleshooting capabilities
- **Modern Practices**: Exposure to AI-assisted development workflows

### 🚀 Advanced Q Developer Techniques

#### Context-Aware Prompting
```
"Given this existing .NET loan application with SQL Server backend, I'm migrating to PostgreSQL. The application handles loan applications, customer data, and payment processing. Here's the current stored procedure for loan eligibility assessment: [code]. Convert this to PostgreSQL while maintaining the business logic for DSR calculation and risk assessment."
```

#### Multi-Step Workflows
```
1. "Analyze this database schema for PostgreSQL migration complexity"
2. "Generate the converted PostgreSQL schema"
3. "Create Entity Framework model updates"
4. "Generate validation queries to verify migration"
5. "Suggest performance optimizations for the new schema"
```

#### Integration with AWS Services
```
"I'm using AWS DMS for database migration and Aurora PostgreSQL as target. Help me configure DMS endpoints and create table mappings for this schema: [schema]. Also suggest Aurora-specific optimizations."
```

This Q Developer integration transforms the workshop from a traditional migration exercise into a modern, AI-assisted development experience that participants can apply in their daily work.