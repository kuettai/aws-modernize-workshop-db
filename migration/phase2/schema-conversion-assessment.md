# Phase 2: Schema Conversion Assessment
## RDS SQL Server to Aurora PostgreSQL Migration

### 🎯 Assessment Objectives
- Analyze SQL Server schema for PostgreSQL compatibility
- Identify conversion challenges and required changes
- Plan stored procedure migration strategy
- Estimate conversion effort and timeline

### 📊 Schema Analysis

#### Data Type Mapping Assessment
| SQL Server Type | PostgreSQL Equivalent | Conversion Notes |
|-----------------|----------------------|------------------|
| `NVARCHAR(MAX)` | `TEXT` | Direct mapping |
| `NVARCHAR(50)` | `VARCHAR(50)` | Length preserved |
| `INT IDENTITY` | `SERIAL` or `GENERATED` | Auto-increment |
| `DATETIME2` | `TIMESTAMP` | Precision handling |
| `DECIMAL(12,2)` | `NUMERIC(12,2)` | Direct mapping |
| `BIT` | `BOOLEAN` | Direct mapping |
| `UNIQUEIDENTIFIER` | `UUID` | Requires extension |
| `VARBINARY(MAX)` | `BYTEA` | Binary data |

#### Table Conversion Analysis
```sql
-- Current SQL Server schema analysis
SELECT 
    t.TABLE_NAME,
    COUNT(c.COLUMN_NAME) as ColumnCount,
    STRING_AGG(
        CASE 
            WHEN c.DATA_TYPE IN ('nvarchar', 'varchar') THEN 'TEXT_COLUMN'
            WHEN c.DATA_TYPE IN ('int', 'bigint') THEN 'INTEGER_COLUMN'
            WHEN c.DATA_TYPE = 'datetime2' THEN 'TIMESTAMP_COLUMN'
            WHEN c.DATA_TYPE = 'decimal' THEN 'NUMERIC_COLUMN'
            WHEN c.DATA_TYPE = 'bit' THEN 'BOOLEAN_COLUMN'
            WHEN c.DATA_TYPE = 'uniqueidentifier' THEN 'UUID_COLUMN'
            ELSE 'OTHER_COLUMN'
        END, ','
    ) as ColumnTypes
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
GROUP BY t.TABLE_NAME
ORDER BY t.TABLE_NAME
```

### 🔍 Conversion Complexity Assessment

#### Low Complexity Tables (Direct Conversion)
- **Branches**: Standard data types, simple structure
- **Customers**: Mostly VARCHAR and NUMERIC types
- **LoanOfficers**: Simple reference table

#### Medium Complexity Tables
- **Applications**: DATETIME2 → TIMESTAMP conversion
- **Loans**: DECIMAL precision handling
- **Payments**: Date/time calculations

#### High Complexity Tables
- **IntegrationLogs**: Large TEXT fields, JSON data
- **Documents**: VARBINARY data handling
- **CreditChecks**: Complex data structures

### 🔧 Stored Procedure Conversion Analysis

#### Simple Procedures Conversion
```sql
-- Example: sp_GetApplicationsByStatus
-- SQL Server Version:
CREATE PROCEDURE sp_GetApplicationsByStatus
    @Status NVARCHAR(50)
AS
BEGIN
    SELECT ApplicationId, ApplicationNumber, RequestedAmount, ApplicationStatus
    FROM Applications 
    WHERE ApplicationStatus = @Status AND IsActive = 1
    ORDER BY SubmissionDate DESC
END

-- PostgreSQL Version:
CREATE OR REPLACE FUNCTION sp_GetApplicationsByStatus(
    p_status VARCHAR(50)
)
RETURNS TABLE (
    application_id INTEGER,
    application_number VARCHAR(50),
    requested_amount NUMERIC(12,2),
    application_status VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT a.applicationid, a.applicationnumber, a.requestedamount, a.applicationstatus
    FROM applications a
    WHERE a.applicationstatus = p_status AND a.isactive = true
    ORDER BY a.submissiondate DESC;
END;
$$;
```

#### Complex Procedure Challenges
**sp_ComprehensiveLoanEligibilityAssessment** conversion issues:

| SQL Server Feature | PostgreSQL Alternative | Complexity |
|-------------------|----------------------|------------|
| `DECLARE @var` | `DECLARE var` | Low |
| `SET @var = value` | `var := value` | Low |
| `CURSOR` | `FOR ... IN` loop | Medium |
| `TEMP TABLE (#temp)` | `TEMPORARY TABLE` | Medium |
| `RAISERROR` | `RAISE EXCEPTION` | Medium |
| `@@FETCH_STATUS` | Loop control logic | High |
| `NEWID()` | `gen_random_uuid()` | Low |
| `GETDATE()` | `NOW()` | Low |
| `STRING_AGG` | `string_agg()` | Low |
| Dynamic SQL | `EXECUTE` | Medium |

### 📋 AWS DMS Schema Conversion

#### DMS Fleet Advisor Setup
```bash
# Create DMS Fleet Advisor collector
aws dms create-fleet-advisor-collector \
    --collector-name workshop-fleet-advisor \
    --description "Fleet Advisor for workshop database assessment" \
    --service-access-role-arn arn:aws:iam::ACCOUNT:role/dms-fleet-advisor-role \
    --s3-bucket-name workshop-fleet-advisor-bucket

# Download and install Fleet Advisor collector on source server
# https://docs.aws.amazon.com/dms/latest/userguide/fleet-advisor-collector.html
```

#### DMS Schema Conversion Project
```bash
# Create schema conversion project in DMS
aws dms create-migration-project \
    --migration-project-name workshop-schema-conversion \
    --source-data-provider-descriptors '{
        "DataProviderIdentifier": "workshop-sqlserver-provider",
        "DataProviderName": "workshop-sqlserver",
        "Engine": "sqlserver",
        "Settings": {
            "ServerName": "workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com",
            "Port": 1433,
            "DatabaseName": "LoanApplicationDB",
            "Username": "admin",
            "SslMode": "require"
        }
    }' \
    --target-data-provider-descriptors '{
        "DataProviderIdentifier": "workshop-postgresql-provider",
        "DataProviderName": "workshop-postgresql",
        "Engine": "postgres",
        "Settings": {
            "ServerName": "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com",
            "Port": 5432,
            "DatabaseName": "loanapplicationdb",
            "Username": "postgres",
            "SslMode": "require"
        }
    }'

# Start schema conversion assessment
aws dms start-schema-conversion \
    --migration-project-identifier workshop-schema-conversion
```

#### DMS Schema Conversion Report
```bash
# Get schema conversion assessment results
aws dms describe-schema-conversions \
    --migration-project-identifier workshop-schema-conversion

# Download detailed conversion report
aws dms get-schema-conversion-report \
    --migration-project-identifier workshop-schema-conversion \
    --output-format JSON
```

#### Assessment Report Template
```
DMS SCHEMA CONVERSION ASSESSMENT
================================

Database: LoanApplicationDB
Source: SQL Server 2022 Web Edition
Target: Aurora PostgreSQL 15.x

CONVERSION SUMMARY:
- Tables: 10 (8 automatic, 2 manual)
- Views: 0
- Stored Procedures: 4 (1 automatic, 3 manual)
- Functions: 0
- Triggers: 0

COMPLEXITY BREAKDOWN:
- Simple: 70% (automatic conversion)
- Medium: 25% (minor manual changes)
- Complex: 5% (significant refactoring)

ESTIMATED EFFORT:
- Schema Conversion: 4-6 hours
- Stored Procedure Conversion: 8-12 hours
- Testing and Validation: 4-6 hours
- Total: 16-24 hours

FLEET ADVISOR INSIGHTS:
- Database utilization patterns
- Performance bottlenecks identified
- Migration readiness score: 85%
```

### 🔄 Conversion Strategy

#### Phase 2A: Schema Conversion
1. **Set up DMS Fleet Advisor**
2. **Create DMS schema conversion project**
3. **Run automated schema analysis**
4. **Review conversion recommendations**
5. **Generate PostgreSQL schema**
6. **Manual adjustments for complex objects**
7. **Deploy converted schema to Aurora**

#### Phase 2B: Data Migration
1. **Set up AWS DMS replication instance**
2. **Create source and target endpoints**
3. **Configure migration task**
4. **Execute full load migration**
5. **Validate data integrity**

#### Phase 2C: Application Updates
1. **Update Entity Framework provider**
2. **Modify connection strings**
3. **Update data access code**
4. **Convert stored procedure calls**
5. **Test application functionality**

### ⚠️ Conversion Challenges

#### High-Risk Items
- **Complex Stored Procedure**: Requires complete rewrite
- **IDENTITY Columns**: Different syntax in PostgreSQL
- **Date/Time Functions**: Function name changes
- **Error Handling**: Different exception model
- **Cursor Logic**: Needs loop restructuring

#### Medium-Risk Items
- **Data Type Precision**: DECIMAL vs NUMERIC
- **String Functions**: Case sensitivity differences
- **NULL Handling**: Subtle behavior differences
- **Transaction Isolation**: Different default levels

#### Application Code Changes Required
```csharp
// SQL Server Entity Framework
services.AddDbContext<LoanApplicationContext>(options =>
    options.UseSqlServer(connectionString));

// PostgreSQL Entity Framework
services.AddDbContext<LoanApplicationContext>(options =>
    options.UseNpgsql(connectionString));
```

### 📊 Conversion Effort Estimation

#### Time Estimates by Component
| Component | Complexity | Estimated Hours |
|-----------|------------|----------------|
| Schema Conversion | Medium | 6 hours |
| Simple Procedures (3) | Low | 4 hours |
| Complex Procedure (1) | High | 12 hours |
| Application Updates | Medium | 8 hours |
| Testing & Validation | Medium | 6 hours |
| **Total** | | **36 hours** |

#### Resource Requirements
- **Database Developer**: PostgreSQL expertise
- **Application Developer**: .NET Core + PostgreSQL
- **AWS Engineer**: DMS and Aurora setup
- **QA Tester**: End-to-end validation

### 🎯 Success Criteria

#### Schema Conversion Success
- All tables created in PostgreSQL
- All constraints and indexes migrated
- Data types properly mapped
- Foreign key relationships maintained

#### Data Migration Success
- 100% data integrity maintained
- All row counts match source
- No data corruption or loss
- Performance within acceptable range

#### Application Integration Success
- All API endpoints functional
- Stored procedures working (converted or replaced)
- No application errors or timeouts
- User functionality preserved

### 📋 Pre-Conversion Checklist

#### Technical Preparation
- [ ] AWS SCT installed and configured
- [ ] Aurora PostgreSQL cluster planned
- [ ] DMS replication instance sized
- [ ] Application code review completed
- [ ] Test environment prepared

#### Schema Analysis
- [ ] All data types mapped
- [ ] Stored procedures analyzed
- [ ] Conversion complexity assessed
- [ ] Manual conversion tasks identified
- [ ] Testing strategy defined

#### Risk Mitigation
- [ ] Rollback procedures documented
- [ ] Performance baseline established
- [ ] Data validation scripts prepared
- [ ] Application testing plan created
- [ ] Stakeholder communication plan ready

### 🔄 Assessment Automation Script

```powershell
# Phase 2 Assessment Automation
param([string]$SQLPassword = "WorkshopDB123!")

Write-Host "=== Phase 2: PostgreSQL Conversion Assessment ===" -ForegroundColor Cyan

# Analyze current schema complexity
$SchemaAnalysis = @"
SELECT 
    'Tables' as ObjectType,
    COUNT(*) as Count,
    'Medium' as ConversionComplexity
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT 
    'Stored Procedures',
    COUNT(*),
    CASE 
        WHEN COUNT(*) <= 3 THEN 'High'
        ELSE 'Very High'
    END
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_TYPE = 'PROCEDURE'

UNION ALL

SELECT 
    'Data Types',
    COUNT(DISTINCT DATA_TYPE),
    CASE 
        WHEN COUNT(DISTINCT DATA_TYPE) <= 10 THEN 'Low'
        ELSE 'Medium'
    END
FROM INFORMATION_SCHEMA.COLUMNS
"@

$RDSConnectionString = "Server=workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com;Database=LoanApplicationDB;User Id=admin;Password=$SQLPassword;Encrypt=true;TrustServerCertificate=true;"

Write-Host "Schema Conversion Assessment:" -ForegroundColor Yellow
$assessment = Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Query $SchemaAnalysis
$assessment | Format-Table

Write-Host "✅ Assessment Complete - Ready for PostgreSQL Conversion" -ForegroundColor Green
Write-Host "Estimated Effort: 36 hours over 4-5 days" -ForegroundColor Yellow
Write-Host "Next Step: Set up Aurora PostgreSQL cluster" -ForegroundColor Cyan
```

This assessment provides the foundation for Phase 2 PostgreSQL conversion planning and execution.