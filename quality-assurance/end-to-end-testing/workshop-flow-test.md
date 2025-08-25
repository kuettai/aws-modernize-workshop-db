# End-to-End Workshop Flow Testing
## Step 4.1: Complete Workshop Flow Validation

### 🎯 Objective
Validate the complete workshop experience from initial setup through all three migration phases, ensuring all components work together seamlessly.

### 📋 Test Execution Checklist

#### Pre-Workshop Setup Validation
- [ ] **Environment Prerequisites**
  - [ ] AWS CLI configured and working
  - [ ] .NET 8.0 SDK installed and functional
  - [ ] PowerShell 5.1+ available
  - [ ] Visual Studio/VS Code with Q Developer extension
  - [ ] Git repository access and clone capability

- [ ] **AWS Account Preparation**
  - [ ] IAM permissions for RDS, DynamoDB, CloudFormation
  - [ ] VPC and security groups configured
  - [ ] EC2 instance launch capability
  - [ ] S3 bucket access for backups

#### Phase 0: Baseline Environment Setup
- [ ] **Application Deployment**
  - [ ] Execute `fresh-ec2-deployment.ps1` successfully
  - [ ] SQL Server 2022 installation completes
  - [ ] Database schema creation succeeds
  - [ ] Sample data generation (200K+ records) completes
  - [ ] .NET application builds and runs
  - [ ] All 4 stored procedures execute correctly
  - [ ] Web interface accessible and functional

- [ ] **Baseline Validation**
  - [ ] Documentation page loads at `/docs`
  - [ ] Database statistics display correctly
  - [ ] All navigation links work
  - [ ] Sample loan application workflow functions
  - [ ] Integration logging captures API calls

#### Phase 1: SQL Server to RDS Migration
- [ ] **RDS Setup**
  - [ ] CloudFormation stack deploys successfully
  - [ ] RDS SQL Server instance becomes available
  - [ ] Security groups allow application connectivity
  - [ ] Parameter groups configured correctly

- [ ] **Migration Execution**
  - [ ] Database backup to S3 succeeds
  - [ ] RDS restore from S3 backup completes
  - [ ] Data integrity validation passes
  - [ ] Application connects to RDS successfully
  - [ ] All stored procedures work on RDS
  - [ ] Performance baseline established

- [ ] **Validation Tests**
  - [ ] Record counts match between source and target
  - [ ] Sample queries return identical results
  - [ ] Application functionality unchanged
  - [ ] Performance metrics within acceptable range

#### Phase 2: RDS to PostgreSQL Migration
- [ ] **Aurora PostgreSQL Setup**
  - [ ] Aurora cluster deployment succeeds
  - [ ] Parameter groups configured for PostgreSQL
  - [ ] Security groups updated for new endpoint
  - [ ] Monitoring and logging enabled

- [ ] **Schema Conversion**
  - [ ] AWS SCT assessment completes
  - [ ] Schema conversion scripts generated
  - [ ] PostgreSQL schema creation succeeds
  - [ ] Data type mappings validated

- [ ] **Stored Procedure Migration**
  - [ ] Simple procedures converted to PL/pgSQL
  - [ ] Complex procedure refactored to C# application logic
  - [ ] All business logic functionality preserved
  - [ ] Performance impact assessed

- [ ] **Data Migration via DMS**
  - [ ] DMS replication instance created
  - [ ] Source and target endpoints configured
  - [ ] Full load migration completes successfully
  - [ ] CDC (if enabled) captures ongoing changes
  - [ ] Data validation confirms integrity

- [ ] **Application Updates**
  - [ ] Entity Framework provider updated to PostgreSQL
  - [ ] Connection strings updated
  - [ ] Application builds without errors
  - [ ] All CRUD operations function correctly
  - [ ] LINQ queries translate properly to PostgreSQL

#### Phase 3: DynamoDB Integration
- [ ] **DynamoDB Infrastructure**
  - [ ] CloudFormation template deploys successfully
  - [ ] DynamoDB table created with correct structure
  - [ ] GSIs configured and active
  - [ ] TTL enabled and functioning
  - [ ] IAM roles and policies applied correctly

- [ ] **Service Layer Implementation**
  - [ ] DynamoDB service classes compile successfully
  - [ ] Dependency injection configured correctly
  - [ ] Hybrid logging service functions properly
  - [ ] Configuration management works across environments

- [ ] **Migration Phases**
  - [ ] **Phase 1**: Dual-write mode enables successfully
  - [ ] **Phase 2**: Read operations switch to DynamoDB
  - [ ] **Phase 3**: SQL writes disabled, DynamoDB-only mode
  - [ ] Each phase transition works without data loss

- [ ] **Data Migration**
  - [ ] Historical data migration tool executes successfully
  - [ ] Batch processing handles large datasets
  - [ ] Resume capability works after interruption
  - [ ] Progress tracking and logging function correctly

- [ ] **Validation Framework**
  - [ ] Data integrity validation passes
  - [ ] Performance comparison shows improvements
  - [ ] Functional tests all pass
  - [ ] Schema validation confirms correct structure

### 🧪 Automated Test Suite

#### test-workshop-flow.ps1
```powershell
# Complete Workshop Flow Test Automation
param(
    [string]$Environment = "test",
    [string]$Region = "us-east-1",
    [switch]$SkipPhase1,
    [switch]$SkipPhase2,
    [switch]$SkipPhase3,
    [switch]$CleanupAfter
)

Write-Host "🧪 Starting Complete Workshop Flow Test" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan

$testResults = @{
    Phase0 = @{ Status = "NotStarted"; Duration = $null; Errors = @() }
    Phase1 = @{ Status = "NotStarted"; Duration = $null; Errors = @() }
    Phase2 = @{ Status = "NotStarted"; Duration = $null; Errors = @() }
    Phase3 = @{ Status = "NotStarted"; Duration = $null; Errors = @() }
    Overall = @{ Status = "NotStarted"; StartTime = Get-Date; EndTime = $null }
}

function Test-Phase {
    param(
        [string]$PhaseName,
        [scriptblock]$TestScript
    )
    
    Write-Host "🔍 Testing $PhaseName..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    try {
        & $TestScript
        $testResults[$PhaseName].Status = "Passed"
        Write-Host "✅ $PhaseName completed successfully" -ForegroundColor Green
    }
    catch {
        $testResults[$PhaseName].Status = "Failed"
        $testResults[$PhaseName].Errors += $_.Exception.Message
        Write-Host "❌ $PhaseName failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $testResults[$PhaseName].Duration = (Get-Date) - $startTime
    }
}

# Phase 0: Baseline Environment
Test-Phase "Phase0" {
    Write-Host "  📦 Deploying baseline environment..."
    
    # Test deployment script
    $deployResult = & "./deployment/fresh-ec2-deployment.ps1" -Environment $Environment
    if ($LASTEXITCODE -ne 0) {
        throw "Baseline deployment failed"
    }
    
    # Test application accessibility
    Write-Host "  🌐 Testing application accessibility..."
    Start-Sleep -Seconds 30  # Allow application to start
    
    $response = Invoke-WebRequest -Uri "http://localhost:5000" -TimeoutSec 30
    if ($response.StatusCode -ne 200) {
        throw "Application not accessible"
    }
    
    # Test database connectivity
    Write-Host "  🗄️ Testing database connectivity..."
    $connectionTest = Invoke-Sqlcmd -Query "SELECT COUNT(*) FROM Applications" -ServerInstance "localhost" -Database "LoanApplicationDB"
    if (-not $connectionTest) {
        throw "Database connectivity failed"
    }
    
    Write-Host "  ✅ Baseline environment validated"
}

# Phase 1: SQL Server to RDS
if (-not $SkipPhase1) {
    Test-Phase "Phase1" {
        Write-Host "  🚀 Testing RDS migration..."
        
        # Deploy RDS infrastructure
        & "./migration/phase1/scripts/deploy-rds.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "RDS deployment failed"
        }
        
        # Test migration scripts
        & "./migration/phase1/scripts/migrate-to-rds.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "RDS migration failed"
        }
        
        # Validate data integrity
        & "./migration/phase1/scripts/validate-migration.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "RDS validation failed"
        }
        
        Write-Host "  ✅ Phase 1 migration validated"
    }
}

# Phase 2: RDS to PostgreSQL
if (-not $SkipPhase2) {
    Test-Phase "Phase2" {
        Write-Host "  🐘 Testing PostgreSQL migration..."
        
        # Deploy Aurora PostgreSQL
        & "./migration/phase2/scripts/deploy-aurora-postgresql.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "Aurora PostgreSQL deployment failed"
        }
        
        # Test schema conversion
        & "./migration/phase2/scripts/convert-schema.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "Schema conversion failed"
        }
        
        # Test DMS migration
        & "./migration/phase2/scripts/setup-dms-migration.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "DMS migration failed"
        }
        
        # Update application
        & "./migration/phase2/scripts/update-application.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "Application update failed"
        }
        
        Write-Host "  ✅ Phase 2 migration validated"
    }
}

# Phase 3: DynamoDB Integration
if (-not $SkipPhase3) {
    Test-Phase "Phase3" {
        Write-Host "  ⚡ Testing DynamoDB integration..."
        
        # Deploy DynamoDB infrastructure
        & "./migration/phase3/03-migration-steps/scripts/deploy-dynamodb-table.ps1" -Environment $Environment
        if ($LASTEXITCODE -ne 0) {
            throw "DynamoDB deployment failed"
        }
        
        # Test dual-write implementation
        Write-Host "  🔄 Testing dual-write pattern..."
        $dualWriteTest = Invoke-RestMethod -Uri "http://localhost:5000/api/Migration/test-dual-write" -Method POST
        if (-not $dualWriteTest.success) {
            throw "Dual-write test failed"
        }
        
        # Test data migration
        & "./migration/phase3/03-migration-steps/scripts/run-migration.ps1" -Environment $Environment -DryRun
        if ($LASTEXITCODE -ne 0) {
            throw "Data migration test failed"
        }
        
        # Test validation framework
        & "./migration/phase3/05-comparison/run-validation.ps1" -Environment $Environment -DataIntegrityOnly
        if ($LASTEXITCODE -ne 0) {
            throw "Validation framework test failed"
        }
        
        Write-Host "  ✅ Phase 3 migration validated"
    }
}

# Generate test report
$testResults.Overall.EndTime = Get-Date
$testResults.Overall.Duration = $testResults.Overall.EndTime - $testResults.Overall.StartTime

$overallStatus = if (($testResults.Values | Where-Object { $_.Status -eq "Failed" }).Count -eq 0) { "Passed" } else { "Failed" }
$testResults.Overall.Status = $overallStatus

Write-Host "`n📊 Test Results Summary:" -ForegroundColor Cyan
Write-Host "Overall Status: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "Passed") { "Green" } else { "Red" })
Write-Host "Total Duration: $($testResults.Overall.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

foreach ($phase in @("Phase0", "Phase1", "Phase2", "Phase3")) {
    $result = $testResults[$phase]
    if ($result.Status -ne "NotStarted") {
        $color = switch ($result.Status) {
            "Passed" { "Green" }
            "Failed" { "Red" }
            default { "Yellow" }
        }
        Write-Host "$phase`: $($result.Status) ($($result.Duration.ToString('mm\:ss')))" -ForegroundColor $color
        
        if ($result.Errors.Count -gt 0) {
            foreach ($error in $result.Errors) {
                Write-Host "  ❌ $error" -ForegroundColor Red
            }
        }
    }
}

# Save detailed results
$testResults | ConvertTo-Json -Depth 10 | Out-File "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Cleanup if requested
if ($CleanupAfter -and $overallStatus -eq "Passed") {
    Write-Host "`n🧹 Cleaning up test resources..." -ForegroundColor Yellow
    # Add cleanup logic here
}

if ($overallStatus -eq "Failed") {
    exit 1
}

Write-Host "`n🎉 Workshop flow test completed successfully!" -ForegroundColor Green
```

### 📊 Performance Benchmarks

#### Expected Performance Metrics
| Phase | Component | Metric | Target | Acceptable Range |
|-------|-----------|--------|--------|------------------|
| **Phase 0** | Application Start | Time to Ready | < 2 minutes | 1-3 minutes |
| **Phase 0** | Database Setup | Schema + Data | < 5 minutes | 3-8 minutes |
| **Phase 1** | RDS Migration | Full Migration | < 15 minutes | 10-25 minutes |
| **Phase 2** | PostgreSQL Migration | Schema + Data | < 20 minutes | 15-35 minutes |
| **Phase 3** | DynamoDB Setup | Infrastructure | < 5 minutes | 3-10 minutes |
| **Phase 3** | Data Migration | 200K+ Records | < 10 minutes | 5-20 minutes |

#### Load Testing Scenarios
```powershell
# Load test script for workshop validation
function Test-WorkshopLoad {
    param(
        [int]$ConcurrentUsers = 10,
        [int]$TestDurationMinutes = 5
    )
    
    Write-Host "🔥 Starting load test: $ConcurrentUsers users for $TestDurationMinutes minutes"
    
    # Simulate concurrent workshop participants
    $jobs = @()
    for ($i = 1; $i -le $ConcurrentUsers; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($UserId)
            
            # Simulate typical workshop actions
            $baseUrl = "http://localhost:5000"
            $endTime = (Get-Date).AddMinutes($using:TestDurationMinutes)
            
            while ((Get-Date) -lt $endTime) {
                try {
                    # Browse documentation
                    Invoke-WebRequest -Uri "$baseUrl/docs" -TimeoutSec 10 | Out-Null
                    
                    # Check application status
                    Invoke-WebRequest -Uri "$baseUrl/api/MigrationDashboard/status" -TimeoutSec 10 | Out-Null
                    
                    # Test logging functionality
                    Invoke-RestMethod -Uri "$baseUrl/api/Migration/test-dual-write" -Method POST -TimeoutSec 10 | Out-Null
                    
                    Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 5)
                }
                catch {
                    Write-Warning "User $UserId encountered error: $($_.Exception.Message)"
                }
            }
        } -ArgumentList $i
    }
    
    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    
    Write-Host "✅ Load test completed"
}
```

### 🔍 Error Scenarios Testing

#### Common Failure Points
1. **Network Connectivity Issues**
   - AWS service timeouts
   - Database connection failures
   - Application startup problems

2. **Permission and Security Issues**
   - IAM role misconfigurations
   - Security group restrictions
   - Database authentication failures

3. **Resource Constraints**
   - Insufficient EC2 instance capacity
   - Database storage limitations
   - DynamoDB throttling

4. **Data Integrity Issues**
   - Migration data corruption
   - Incomplete data transfers
   - Schema conversion errors

#### Error Recovery Testing
```powershell
# Test error recovery scenarios
function Test-ErrorRecovery {
    Write-Host "🚨 Testing error recovery scenarios..."
    
    # Test 1: Database connection failure recovery
    Write-Host "  Testing database connection recovery..."
    # Simulate connection failure and recovery
    
    # Test 2: Migration interruption recovery
    Write-Host "  Testing migration interruption recovery..."
    # Test resume capability
    
    # Test 3: Application crash recovery
    Write-Host "  Testing application crash recovery..."
    # Test application restart and state recovery
    
    Write-Host "✅ Error recovery tests completed"
}
```

### 📋 Test Execution Log Template

#### Workshop Flow Test Log
```
Date: _______________
Tester: _____________
Environment: ________

Phase 0 - Baseline Setup:
□ Deployment script execution: _____ minutes
□ Application accessibility: PASS/FAIL
□ Database connectivity: PASS/FAIL
□ Sample data validation: PASS/FAIL
Notes: _________________________________

Phase 1 - RDS Migration:
□ Infrastructure deployment: _____ minutes
□ Data migration: _____ minutes
□ Validation tests: PASS/FAIL
□ Performance within range: PASS/FAIL
Notes: _________________________________

Phase 2 - PostgreSQL Migration:
□ Aurora deployment: _____ minutes
□ Schema conversion: _____ minutes
□ DMS migration: _____ minutes
□ Application updates: PASS/FAIL
Notes: _________________________________

Phase 3 - DynamoDB Integration:
□ DynamoDB deployment: _____ minutes
□ Service layer integration: PASS/FAIL
□ Data migration: _____ minutes
□ Validation framework: PASS/FAIL
Notes: _________________________________

Overall Assessment:
□ All phases completed successfully: PASS/FAIL
□ Performance within acceptable ranges: PASS/FAIL
□ Documentation accuracy verified: PASS/FAIL
□ Q Developer integration functional: PASS/FAIL

Total Workshop Duration: _____ hours
Recommendation: APPROVE/NEEDS_WORK/REJECT
```

---

### 💡 Q Developer Integration Points

```
1. "Review this end-to-end testing strategy and suggest additional test scenarios or validation points for the database modernization workshop."

2. "Analyze the automated test suite and recommend improvements for better error detection and reporting during workshop validation."

3. "Examine the performance benchmarks and suggest realistic targets based on typical AWS service performance characteristics."
```

**Next**: [Migration Validation Procedures](../migration-validation/migration-procedures-validation.md)