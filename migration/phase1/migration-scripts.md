# Phase 1: Migration Scripts and Procedures
## SQL Server to AWS RDS SQL Server Database Migration

### 🎯 Migration Objectives
- Migrate LoanApplicationDB from on-premises to RDS SQL Server
- Maintain data integrity and application functionality
- Minimize downtime and ensure rollback capability
- Validate migration success with comprehensive testing

### 📋 Migration Prerequisites
- RDS SQL Server instance created and accessible
- Source database backup completed
- Network connectivity established
- Application downtime window scheduled

### 🔄 Migration Methods

#### Method 1: Backup and Restore (Recommended)
**Advantages:**
- Fastest for databases < 100GB
- Maintains all database objects
- Minimal complexity
- Built-in validation

#### Method 2: AWS DMS (Alternative)
**Use when:**
- Minimal downtime required
- Large databases (> 100GB)
- Ongoing replication needed

### 📦 Backup and Restore Migration

#### Step 1: Create Source Database Backup
```powershell
# Create backup script
$BackupScript = @"
-- Create full backup of LoanApplicationDB
BACKUP DATABASE [LoanApplicationDB] 
TO DISK = 'C:\Workshop\Backups\LoanApplicationDB_Migration.bak'
WITH 
    FORMAT,
    COMPRESSION,
    CHECKSUM,
    STATS = 10,
    NAME = 'LoanApplicationDB Migration Backup'
"@

# Execute backup
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Query $BackupScript -QueryTimeout 1800

# Verify backup
$VerifyScript = @"
RESTORE VERIFYONLY 
FROM DISK = 'C:\Workshop\Backups\LoanApplicationDB_Migration.bak'
WITH CHECKSUM
"@

Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Query $VerifyScript
Write-Host "✅ Backup created and verified successfully"
```

#### Step 2: Upload Backup to S3
```powershell
# Install AWS PowerShell module if not present
if (-not (Get-Module -ListAvailable -Name AWS.Tools.S3)) {
    Install-Module AWS.Tools.S3 -Force -AllowClobber
}

# Upload backup to S3
$BucketName = "workshop-db-migration-backups"
$BackupFile = "C:\Workshop\Backups\LoanApplicationDB_Migration.bak"
$S3Key = "sqlserver-backups/LoanApplicationDB_Migration.bak"

# Create S3 bucket if it doesn't exist
try {
    Get-S3Bucket -BucketName $BucketName -ErrorAction Stop
} catch {
    New-S3Bucket -BucketName $BucketName -Region us-east-1
    Write-Host "✅ S3 bucket created: $BucketName"
}

# Upload backup file
Write-S3Object -BucketName $BucketName -File $BackupFile -Key $S3Key
Write-Host "✅ Backup uploaded to S3: s3://$BucketName/$S3Key"
```

#### Step 3: Restore Database to RDS
```powershell
# RDS restore script
$RDSEndpoint = "workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com"
$RDSConnectionString = "Server=$RDSEndpoint;Database=master;User Id=admin;Password=WorkshopDB123!;Encrypt=true;TrustServerCertificate=true;"

# Create restore command
$RestoreScript = @"
-- Restore database from S3 backup
exec msdb.dbo.rds_restore_database 
    @restore_db_name='LoanApplicationDB',
    @s3_arn_to_restore_from='arn:aws:s3:::$BucketName/$S3Key'
"@

# Execute restore
Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Query $RestoreScript -QueryTimeout 3600

# Monitor restore progress
$MonitorScript = @"
-- Check restore status
exec msdb.dbo.rds_task_status @db_name='LoanApplicationDB'
"@

do {
    Start-Sleep -Seconds 30
    $status = Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Query $MonitorScript
    Write-Host "Restore Status: $($status.lifecycle), $($status.task_info)"
} while ($status.lifecycle -eq "IN_PROGRESS")

if ($status.lifecycle -eq "SUCCESS") {
    Write-Host "✅ Database restore completed successfully"
} else {
    Write-Host "❌ Database restore failed: $($status.task_info)" -ForegroundColor Red
}
```

### 🔧 Alternative: Native Backup/Restore Method

#### For Smaller Databases (< 1GB)
```powershell
# Direct restore method (if S3 method not available)
$BackupPath = "C:\Workshop\Backups\LoanApplicationDB_Migration.bak"
$RDSConnectionString = "Server=$RDSEndpoint;Database=master;User Id=admin;Password=WorkshopDB123!;Encrypt=true;TrustServerCertificate=true;"

# Copy backup file to accessible location and restore
$DirectRestoreScript = @"
-- Note: This method requires the backup file to be accessible to RDS
-- Alternative approach using SQLCMD and BCP for data migration
USE master;
CREATE DATABASE [LoanApplicationDB];
"@

Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Query $DirectRestoreScript
```

### 📊 Data Migration Validation

#### Step 1: Row Count Validation
```powershell
# Create validation script
$ValidationScript = @"
-- Compare row counts between source and target
SELECT 'Applications' as TableName, COUNT(*) as RowCount FROM Applications
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
ORDER BY TableName
"@

# Get source counts
Write-Host "Source Database Row Counts:" -ForegroundColor Yellow
$sourceCounts = Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -Query $ValidationScript
$sourceCounts | Format-Table

# Get target counts
Write-Host "Target Database Row Counts:" -ForegroundColor Yellow
$targetCounts = Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Database "LoanApplicationDB" -Query $ValidationScript
$targetCounts | Format-Table

# Compare counts
$validation = $true
for ($i = 0; $i -lt $sourceCounts.Count; $i++) {
    if ($sourceCounts[$i].RowCount -ne $targetCounts[$i].RowCount) {
        Write-Host "❌ Row count mismatch for $($sourceCounts[$i].TableName): Source=$($sourceCounts[$i].RowCount), Target=$($targetCounts[$i].RowCount)" -ForegroundColor Red
        $validation = $false
    }
}

if ($validation) {
    Write-Host "✅ All row counts match - Data migration successful" -ForegroundColor Green
}
```

#### Step 2: Data Integrity Validation
```powershell
# Sample data validation
$IntegrityScript = @"
-- Validate key business data
SELECT TOP 5 
    a.ApplicationId,
    a.ApplicationNumber,
    c.FirstName + ' ' + c.LastName as CustomerName,
    a.RequestedAmount,
    a.ApplicationStatus
FROM Applications a
INNER JOIN Customers c ON a.CustomerId = c.CustomerId
ORDER BY a.ApplicationId

-- Validate stored procedures exist
SELECT name, type_desc 
FROM sys.objects 
WHERE type = 'P' AND is_ms_shipped = 0
ORDER BY name
"@

Write-Host "Sample Data Validation:" -ForegroundColor Yellow
$sampleData = Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Database "LoanApplicationDB" -Query $IntegrityScript
$sampleData | Format-Table
```

#### Step 3: Stored Procedure Validation
```powershell
# Test stored procedures
$ProcedureTests = @(
    @{
        Name = "sp_GetApplicationsByStatus"
        Query = "EXEC sp_GetApplicationsByStatus @Status = 'Approved'"
    },
    @{
        Name = "sp_GetCustomerLoanHistory"
        Query = "EXEC sp_GetCustomerLoanHistory @CustomerId = 1"
    },
    @{
        Name = "sp_UpdateApplicationStatus"
        Query = "EXEC sp_UpdateApplicationStatus @ApplicationId = 1, @NewStatus = 'Under Review', @Reason = 'Migration Test'"
    }
)

Write-Host "Stored Procedure Validation:" -ForegroundColor Yellow
foreach ($test in $ProcedureTests) {
    try {
        $result = Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Database "LoanApplicationDB" -Query $test.Query -QueryTimeout 30
        Write-Host "✅ $($test.Name) - Executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($test.Name) - Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### 🔄 Application Configuration Update

#### Update Connection String
```powershell
# Update application configuration
$NewConnectionString = "Server=$RDSEndpoint;Database=LoanApplicationDB;User Id=admin;Password=WorkshopDB123!;Encrypt=true;TrustServerCertificate=true;"

$AppSettings = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "$NewConnectionString"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

# Update application settings
Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $AppSettings

# Restart IIS to pick up new connection string
iisreset

Write-Host "✅ Application configuration updated for RDS"
```

### 🧪 End-to-End Testing

#### Application Functionality Test
```powershell
# Test application endpoints
$TestEndpoints = @(
    "http://localhost",
    "http://localhost/api/applications/count",
    "http://localhost/api/customers/count",
    "http://localhost/api/applications",
    "http://localhost/api/customers"
)

Write-Host "Application Functionality Testing:" -ForegroundColor Yellow
foreach ($endpoint in $TestEndpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 30
        Write-Host "✅ $endpoint - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $endpoint - Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### 📊 Performance Comparison

#### Baseline Performance Test
```powershell
# Performance test script
$PerformanceTest = @"
-- Test query performance
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Test 1: Simple SELECT
SELECT COUNT(*) FROM Applications;

-- Test 2: JOIN query
SELECT TOP 100 
    a.ApplicationNumber,
    c.FirstName + ' ' + c.LastName as CustomerName,
    a.RequestedAmount
FROM Applications a
INNER JOIN Customers c ON a.CustomerId = c.CustomerId
ORDER BY a.ApplicationId;

-- Test 3: Complex aggregation
SELECT 
    a.ApplicationStatus,
    COUNT(*) as Count,
    AVG(a.RequestedAmount) as AvgAmount
FROM Applications a
GROUP BY a.ApplicationStatus;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
"@

Write-Host "Performance Test Results:" -ForegroundColor Yellow
Invoke-Sqlcmd -ConnectionString $RDSConnectionString -Database "LoanApplicationDB" -Query $PerformanceTest
```

### 🔙 Rollback Procedures

#### Emergency Rollback Plan
```powershell
# Rollback script (if needed)
$RollbackScript = @"
# 1. Update application to use original connection string
$OriginalConnectionString = "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=WorkshopDB123!;Encrypt=false;TrustServerCertificate=true;"

$OriginalAppSettings = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "$OriginalConnectionString"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $OriginalAppSettings
iisreset

Write-Host "✅ Rollback completed - Application using original database"
"@

# Save rollback script for emergency use
Set-Content -Path "C:\Workshop\rollback-phase1.ps1" -Value $RollbackScript
```

### 📋 Migration Completion Checklist

#### Technical Validation
- [ ] Database restore completed successfully
- [ ] All tables have correct row counts
- [ ] Stored procedures execute without errors
- [ ] Application connects to RDS successfully
- [ ] All API endpoints return expected data
- [ ] Performance meets baseline requirements

#### Operational Validation
- [ ] RDS monitoring enabled and functioning
- [ ] Backup retention policy configured
- [ ] Security groups properly configured
- [ ] CloudWatch alarms created
- [ ] Application logs show no connection errors

#### Documentation
- [ ] Migration steps documented
- [ ] New connection string recorded
- [ ] Rollback procedures tested
- [ ] Performance baseline established
- [ ] Cost tracking enabled

### 🎯 Migration Success Criteria

**Functional Success:**
- ✅ Application fully functional on RDS
- ✅ All data migrated with 100% integrity
- ✅ Stored procedures working correctly
- ✅ API endpoints responding normally

**Performance Success:**
- ✅ Query response times within 10% of baseline
- ✅ Application startup time < 30 seconds
- ✅ No timeout errors or connection issues

**Operational Success:**
- ✅ Monitoring and alerting configured
- ✅ Backup and recovery procedures tested
- ✅ Security properly configured
- ✅ Cost tracking enabled

Phase 1 migration is now complete! The application is successfully running on AWS RDS SQL Server with full functionality maintained.