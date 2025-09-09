# 4. Post Migration Validation using GenAI

This section demonstrates how to leverage Amazon Q Developer Pro to automate and enhance post-migration validation, making the process more efficient and comprehensive.

## Overview

Using GenAI for post-migration validation provides:
- Automated validation script generation
- Intelligent comparison and analysis
- Comprehensive validation coverage
- Reusable validation templates
- Smart anomaly detection

## GenAI-Powered Validation Approach

### Step 1: Generate Validation Queries using Amazon Q Developer Pro

**1.1 Open Amazon Q Developer Pro**

1. **Open Visual Studio Code** with Amazon Q Developer Pro plugin installed
2. **Open Amazon Q Developer Pro**:
   - Press **Ctrl+Shift+P** (or **Cmd+Shift+P** on Mac)
   - Type "Amazon Q: Open Chat" and select it
   - Or click the Amazon Q icon in the sidebar

**1.2 Generate Comprehensive Validation SQL File**

Use this prompt in Amazon Q chat:
```
I need to perform comprehensive post-migration validation for a SQL Server database migrated from EC2 to Amazon RDS. Please generate SQL validation queries step by step for my review.

Generate queries for:
1. Database structure extraction (tables, columns, data types, constraints)
2. Row count validation for all tables
3. Data integrity checks (primary keys, foreign keys, indexes)
4. Performance baseline queries
5. Security validation (users, roles, permissions)
6. Include server identification (RDS has 'rdsadmin' database)

Requirements:
- Target database: LoanApplicationDB
- Show me each query one by one for verification
- Each query should be clearly commented with its purpose
- Make queries suitable for both source (EC2) and target (RDS) execution

Please write the queries into a SQL file with name 'migration_validation_queries.sql'.
```

### Step 2: Execute Validation Queries

**2.1 Execute on SOURCE Database (EC2)**

1. **Connect to SOURCE EC2 SQL Server** using SSMS
2. **Open** the `migration_validation_queries.sql` file
3. **Execute each query one by one** and save results as CSV:
   - Query 1 (Database Structure) → Save as: `01_source_database_structure.csv`
   - Query 2 (Row Counts) → Save as: `02_source_row_counts.csv`
   - Query 3 (Data Integrity) → Save as: `03_source_data_integrity.csv`
   - Query 4 (Performance Baseline) → Save as: `04_source_performance.csv`
   - Query 5 (Security Info) → Save as: `05_source_security.csv`

**2.2 Execute on TARGET Database (RDS)**

1. **Connect to TARGET RDS SQL Server** using SSMS
2. **Execute the same queries** from `migration_validation_queries.sql`
3. **Save results as CSV** with target naming:
   - Query 1 (Database Structure) → Save as: `01_target_database_structure.csv`
   - Query 2 (Row Counts) → Save as: `02_target_row_counts.csv`
   - Query 3 (Data Integrity) → Save as: `03_target_data_integrity.csv`
   - Query 4 (Performance Baseline) → Save as: `04_target_performance.csv`
   - Query 5 (Security Info) → Save as: `05_target_security.csv`

**2.3 Troubleshooting Query Issues (Optional)**

If you encounter errors while executing any query, use Amazon Q Developer Pro to fix them:

1. **Copy the error message** from SSMS
2. **Return to Amazon Q chat** and use this prompt:
```
I'm getting the following error when executing one of the migration validation queries:

Error: [Paste your error message here]

Query that failed:
[Paste the problematic query here]

Please help me fix this query to work with my SQL Server version and database configuration.
```

3. **Apply the suggested fix** and re-execute the query
4. **Continue with the remaining queries**

**2.4 Organize Validation Files**

1. **Create a folder** named `validation_results`
2. **Move all CSV files** into this folder
3. You should now have 10 CSV files for comparison analysis

### Step 3: Analyze Results with Amazon Q

**3.1 Analyse Validation Files**

1. **Open VS Code** and navigate to **File** > **Open Folder**
2. **Select the `validation_results` folder** to open it in VS Code
3. **Open Amazon Q Developer Pro** and use this prompt:
```
I have completed a SQL Server database migration from EC2 (self-managed) to Amazon RDS and need to perform comprehensive post-migration validation. I have executed validation queries on both the source EC2 database and target RDS database to compare their structures, data, and configurations.

Please analyze these validation results and perform a detailed comparison between source and target to determine if the migration was successful:

@01_source_database_structure.csv @01_target_database_structure.csv
@02_source_row_counts.csv @02_target_row_counts.csv
@03_source_data_integrity.csv @03_target_data_integrity.csv
@04_source_performance.csv @04_target_performance.csv
@05_source_security.csv @05_target_security.csv

Please provide a comprehensive migration validation report covering:
1. Database structure comparison - Are all tables, columns, and data types identical?
2. Data migration validation - Do row counts match exactly between source and target?
3. Constraint and index validation - Are all primary keys, foreign keys, and indexes properly migrated?
4. Security configuration - Are users, roles, and permissions correctly transferred?
5. Overall migration assessment - Is the migration considered successful and ready for production?
6. Any issues found and recommended remediation steps
```

**3.2 Review Migration Validation Report**

1. **Read the comprehensive report** generated by Amazon Q Developer Pro
2. **Check each validation area**:
   - ✅ **Database Structure**: All tables, columns, data types match
   - ✅ **Data Migration**: Row counts are identical between source and target
   - ✅ **Constraints & Indexes**: All primary keys, foreign keys, indexes migrated
   - ✅ **Security Configuration**: Users, roles, permissions transferred correctly
   - ✅ **No Critical Issues**: No blocking problems identified

3. **Determine Migration Status**:
   - **✅ SUCCESSFUL**: All validation checks pass → Migration is ready for production
   - **⚠️ ISSUES FOUND**: Some discrepancies identified → Proceed to Step 4 for resolution
   - **❌ FAILED**: Critical issues found → Review migration process and retry

4. **Document the results** for your migration records

### Step 4: Amazon Q-Powered Issue Resolution (Optional)

**If issues are found during validation**, continue in Amazon Q chat:
```
I found the following issues during my database migration validation:

[Describe the issues found or attach error files]

Please provide:
1. Root cause analysis for each issue
2. Step-by-step resolution procedures
3. SQL scripts to fix the problems
4. Prevention strategies for future migrations
5. Verification queries to confirm fixes
```

## Benefits of Amazon Q Developer Pro Validation

- **File Integration**: Direct CSV file analysis without copy/paste
- **AWS-Optimized**: Tailored recommendations for RDS SQL Server
- **IDE Integration**: Seamless workflow within VS Code
- **Context Awareness**: Understands AWS migration patterns and best practices
- **Intelligent Analysis**: Smart interpretation of database structure and performance metrics
- **Conversation History**: Maintain context across multiple validation steps

## Potential Use Cases for Amazon Q Developer Pro in Database Migration

Once Amazon Q Developer Pro validation confirms migration success, you can leverage it for:
- Generate CloudWatch monitoring queries for ongoing database health
- Ask Amazon Q for RDS-specific performance optimization recommendations
- Create automated validation scripts for future migrations
- Document lessons learned and best practices using Amazon Q's capabilities
- Generate disaster recovery and backup validation procedures
- Create database maintenance and optimization scripts

## Next Steps

Congratulations! You have successfully completed the SQL Server EC2 to RDS migration validation using Amazon Q Developer Pro.

**Continue to the next workshop section:**

[**Phase 2: Migrate SQL Server to PostgreSQL →**](../phase2/README.md)

In the next phase, you will learn how to:
- Migrate from SQL Server to PostgreSQL using AWS Database Migration Service (DMS)
- Use Amazon Q Developer Pro for schema conversion and validation
- Handle data type mappings and compatibility issues
- Perform cross-platform database migration validation



---
[← Back to Database Migration](03-database-migration.md) | [Back to Overview](README.md)