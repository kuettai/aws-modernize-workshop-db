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
1. **T-SQL to PostgreSQL Conversion**
   ```
   Q Prompt: "Convert this SQL Server stored procedure to PostgreSQL PL/pgSQL. Maintain the same functionality but use PostgreSQL syntax and best practices."
   
   [Paste stored procedure code]
   ```

2. **Entity Framework Provider Update**
   ```
   Q Prompt: "Update this Entity Framework DbContext from SQL Server to PostgreSQL. Show the necessary package changes, connection string format, and any code modifications needed."
   
   [Paste DbContext code]
   ```

3. **Data Type Mapping Analysis**
   ```
   Q Prompt: "Analyze these SQL Server data types and provide PostgreSQL equivalents. Highlight any potential data loss or precision issues."
   
   SQL Server Types:
   - NVARCHAR(MAX)
   - DATETIME2
   - UNIQUEIDENTIFIER
   - DECIMAL(12,2)
   - BIT
   ```

4. **Complex Procedure Refactoring**
   ```
   Q Prompt: "This complex SQL Server stored procedure uses cursors, temp tables, and dynamic SQL. Recommend whether to convert to PostgreSQL or refactor into C# application logic. If refactoring, show the C# implementation."
   
   [Paste complex stored procedure]
   ```

#### Phase 3: DynamoDB Integration

**Q Developer Use Cases:**
1. **NoSQL Data Model Design**
   ```
   Q Prompt: "Design a DynamoDB table structure for this high-volume logging data. Recommend partition key, sort key, and access patterns for time-series queries."
   
   Current SQL Table:
   - LogId (INT IDENTITY)
   - ApplicationId (INT)
   - LogType (NVARCHAR(50))
   - ServiceName (NVARCHAR(100))
   - LogTimestamp (DATETIME2)
   - RequestData (NVARCHAR(MAX))
   - ResponseData (NVARCHAR(MAX))
   ```

2. **AWS SDK Integration**
   ```
   Q Prompt: "Create a C# repository class for DynamoDB integration. Include methods for inserting logs, querying by time range, and querying by service name. Use AWS SDK v3."
   ```

3. **Hybrid Data Access Pattern**
   ```
   Q Prompt: "Design a hybrid data access pattern where core business data stays in PostgreSQL but logging data moves to DynamoDB. Show the repository pattern implementation."
   ```

4. **Migration Script for DynamoDB**
   ```
   Q Prompt: "Create a C# console application to migrate data from PostgreSQL IntegrationLogs table to DynamoDB. Include batch processing, error handling, and progress reporting."
   ```

### 🔧 Specific Q Developer Prompts Library

#### Code Analysis Prompts
```
1. "Analyze this .NET application architecture and identify components that need updates for PostgreSQL migration."

2. "Review this T-SQL stored procedure and rate its complexity for PostgreSQL conversion (1-10 scale). Explain the challenges."

3. "Examine this Entity Framework model and suggest optimizations for Aurora PostgreSQL performance."

4. "Analyze this connection pooling configuration and recommend settings for RDS PostgreSQL."
```

#### Conversion Prompts
```
1. "Convert this SQL Server MERGE statement to PostgreSQL UPSERT syntax."

2. "Transform this T-SQL cursor logic into a PostgreSQL FOR loop or C# LINQ equivalent."

3. "Rewrite this dynamic SQL generation to use parameterized queries in PostgreSQL."

4. "Convert this SQL Server error handling (TRY/CATCH) to PostgreSQL exception handling."
```

#### Optimization Prompts
```
1. "Optimize this PostgreSQL query for better performance. Suggest indexing strategies."

2. "Review this DynamoDB table design and recommend improvements for cost and performance."

3. "Analyze this .NET data access pattern and suggest optimizations for cloud databases."

4. "Optimize this batch processing logic for large-scale data migration."
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