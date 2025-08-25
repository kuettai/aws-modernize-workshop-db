# Migration Procedures Validation
## Step 4.2: Validate All Migration Procedures

### 🎯 Objective
Systematically validate each migration procedure across all three phases to ensure reliability, accuracy, and repeatability in workshop environments.

### 📋 Migration Validation Framework

#### Phase 1: SQL Server to RDS Validation

##### Infrastructure Validation
```powershell
# validate-phase1-infrastructure.ps1
param(
    [string]$Environment = "test",
    [string]$Region = "us-east-1"
)

Write-Host "🔍 Validating Phase 1 Infrastructure..." -ForegroundColor Green

$validationResults = @{
    RDSInstance = @{ Status = "NotTested"; Details = "" }
    SecurityGroups = @{ Status = "NotTested"; Details = "" }
    ParameterGroups = @{ Status = "NotTested"; Details = "" }
    SubnetGroups = @{ Status = "NotTested"; Details = "" }
    BackupConfiguration = @{ Status = "NotTested"; Details = "" }
}

# Test RDS Instance
try {
    Write-Host "  📊 Checking RDS instance status..."
    $rdsInstance = aws rds describe-db-instances --db-instance-identifier "loanapp-sqlserver-$Environment" --region $Region --output json | ConvertFrom-Json
    
    if ($rdsInstance.DBInstances[0].DBInstanceStatus -eq "available") {
        $validationResults.RDSInstance.Status = "Pass"
        $validationResults.RDSInstance.Details = "Instance available and accessible"
        Write-Host "    ✅ RDS instance is available" -ForegroundColor Green
    } else {
        $validationResults.RDSInstance.Status = "Fail"
        $validationResults.RDSInstance.Details = "Instance status: $($rdsInstance.DBInstances[0].DBInstanceStatus)"
        Write-Host "    ❌ RDS instance not available" -ForegroundColor Red
    }
}
catch {
    $validationResults.RDSInstance.Status = "Error"
    $validationResults.RDSInstance.Details = $_.Exception.Message
    Write-Host "    ❌ Error checking RDS instance: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Security Groups
try {
    Write-Host "  🔒 Validating security groups..."
    $securityGroups = aws ec2 describe-security-groups --group-names "loanapp-rds-sg-$Environment" --region $Region --output json | ConvertFrom-Json
    
    $sqlServerRule = $securityGroups.SecurityGroups[0].IpPermissions | Where-Object { $_.FromPort -eq 1433 }
    if ($sqlServerRule) {
        $validationResults.SecurityGroups.Status = "Pass"
        $validationResults.SecurityGroups.Details = "SQL Server port 1433 accessible"
        Write-Host "    ✅ Security groups configured correctly" -ForegroundColor Green
    } else {
        $validationResults.SecurityGroups.Status = "Fail"
        $validationResults.SecurityGroups.Details = "SQL Server port 1433 not accessible"
        Write-Host "    ❌ Security groups misconfigured" -ForegroundColor Red
    }
}
catch {
    $validationResults.SecurityGroups.Status = "Error"
    $validationResults.SecurityGroups.Details = $_.Exception.Message
    Write-Host "    ❌ Error checking security groups: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Database Connectivity
try {
    Write-Host "  🔌 Testing database connectivity..."
    $endpoint = $rdsInstance.DBInstances[0].Endpoint.Address
    $connectionString = "Server=$endpoint;Database=LoanApplicationDB;User Id=admin;Password=WorkshopDB123!;TrustServerCertificate=true;"
    
    # Test connection using .NET SqlConnection
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    if ($connection.State -eq "Open") {
        $validationResults.Connectivity = @{ Status = "Pass"; Details = "Database connection successful" }
        Write-Host "    ✅ Database connectivity verified" -ForegroundColor Green
        $connection.Close()
    }
}
catch {
    $validationResults.Connectivity = @{ Status = "Error"; Details = $_.Exception.Message }
    Write-Host "    ❌ Database connectivity failed: $($_.Exception.Message)" -ForegroundColor Red
}

return $validationResults
```

##### Data Migration Validation
```powershell
# validate-phase1-migration.ps1
param(
    [string]$SourceServer = "localhost",
    [string]$TargetServer,
    [string]$Database = "LoanApplicationDB"
)

Write-Host "🔍 Validating Phase 1 Data Migration..." -ForegroundColor Green

$migrationValidation = @{
    TableCounts = @{}
    DataIntegrity = @{}
    StoredProcedures = @{}
    Indexes = @{}
}

# Get list of tables to validate
$tables = @("Applications", "Customers", "Loans", "Payments", "Documents", "IntegrationLogs", "CreditChecks", "Branches", "LoanOfficers")

foreach ($table in $tables) {
    try {
        Write-Host "  📊 Validating table: $table"
        
        # Count records in source
        $sourceCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) as RecordCount FROM $table" -ServerInstance $SourceServer -Database $Database
        
        # Count records in target
        $targetCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) as RecordCount FROM $table" -ServerInstance $TargetServer -Database $Database
        
        $migrationValidation.TableCounts[$table] = @{
            Source = $sourceCount.RecordCount
            Target = $targetCount.RecordCount
            Match = ($sourceCount.RecordCount -eq $targetCount.RecordCount)
        }
        
        if ($sourceCount.RecordCount -eq $targetCount.RecordCount) {
            Write-Host "    ✅ $table`: $($sourceCount.RecordCount) records match" -ForegroundColor Green
        } else {
            Write-Host "    ❌ $table`: Source=$($sourceCount.RecordCount), Target=$($targetCount.RecordCount)" -ForegroundColor Red
        }
        
        # Sample data integrity check
        if ($sourceCount.RecordCount -gt 0) {
            $sampleCheck = Invoke-Sqlcmd -Query "
                SELECT TOP 5 * FROM $table ORDER BY 1
            " -ServerInstance $SourceServer -Database $Database
            
            $targetSample = Invoke-Sqlcmd -Query "
                SELECT TOP 5 * FROM $table ORDER BY 1
            " -ServerInstance $TargetServer -Database $Database
            
            # Compare first few records (simplified check)
            $migrationValidation.DataIntegrity[$table] = @{
                SampleMatches = ($sampleCheck.Count -eq $targetSample.Count)
            }
        }
    }
    catch {
        Write-Host "    ❌ Error validating $table`: $($_.Exception.Message)" -ForegroundColor Red
        $migrationValidation.TableCounts[$table] = @{
            Source = -1
            Target = -1
            Match = $false
            Error = $_.Exception.Message
        }
    }
}

# Validate stored procedures
$storedProcedures = @("GetApplicationStatus", "GetCustomerHistory", "UpdateApplicationStatus", "GenerateComprehensiveLoanReport")

foreach ($proc in $storedProcedures) {
    try {
        Write-Host "  🔧 Validating stored procedure: $proc"
        
        # Check if procedure exists in target
        $procExists = Invoke-Sqlcmd -Query "
            SELECT COUNT(*) as ProcCount 
            FROM sys.procedures 
            WHERE name = '$proc'
        " -ServerInstance $TargetServer -Database $Database
        
        $migrationValidation.StoredProcedures[$proc] = @{
            Exists = ($procExists.ProcCount -gt 0)
        }
        
        if ($procExists.ProcCount -gt 0) {
            Write-Host "    ✅ $proc exists in target" -ForegroundColor Green
            
            # Test procedure execution (with safe parameters)
            if ($proc -eq "GetApplicationStatus") {
                $testResult = Invoke-Sqlcmd -Query "EXEC GetApplicationStatus @ApplicationId = 1" -ServerInstance $TargetServer -Database $Database
                $migrationValidation.StoredProcedures[$proc].Executable = ($testResult -ne $null)
            }
        } else {
            Write-Host "    ❌ $proc missing in target" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "    ❌ Error validating $proc`: $($_.Exception.Message)" -ForegroundColor Red
        $migrationValidation.StoredProcedures[$proc] = @{
            Exists = $false
            Error = $_.Exception.Message
        }
    }
}

# Generate validation report
$totalTables = $tables.Count
$matchingTables = ($migrationValidation.TableCounts.Values | Where-Object { $_.Match -eq $true }).Count
$totalProcs = $storedProcedures.Count
$existingProcs = ($migrationValidation.StoredProcedures.Values | Where-Object { $_.Exists -eq $true }).Count

Write-Host "`n📊 Phase 1 Migration Validation Summary:" -ForegroundColor Cyan
Write-Host "Tables: $matchingTables/$totalTables matching" -ForegroundColor $(if ($matchingTables -eq $totalTables) { "Green" } else { "Red" })
Write-Host "Stored Procedures: $existingProcs/$totalProcs migrated" -ForegroundColor $(if ($existingProcs -eq $totalProcs) { "Green" } else { "Red" })

$overallSuccess = ($matchingTables -eq $totalTables) -and ($existingProcs -eq $totalProcs)
Write-Host "Overall Status: $(if ($overallSuccess) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })

return $migrationValidation
```

#### Phase 2: PostgreSQL Migration Validation

##### Schema Conversion Validation
```powershell
# validate-phase2-schema.ps1
param(
    [string]$PostgreSQLServer,
    [string]$Database = "loanapplicationdb",
    [string]$Username = "postgres",
    [string]$Password = "WorkshopDB123!"
)

Write-Host "🔍 Validating Phase 2 Schema Conversion..." -ForegroundColor Green

$schemaValidation = @{
    Tables = @{}
    DataTypes = @{}
    Constraints = @{}
    Indexes = @{}
}

# PostgreSQL connection string
$pgConnectionString = "Host=$PostgreSQLServer;Database=$Database;Username=$Username;Password=$Password"

try {
    # Load Npgsql assembly
    Add-Type -Path "Npgsql.dll" -ErrorAction SilentlyContinue
    
    $connection = New-Object Npgsql.NpgsqlConnection($pgConnectionString)
    $connection.Open()
    
    Write-Host "  ✅ PostgreSQL connection established" -ForegroundColor Green
    
    # Validate table structure
    $expectedTables = @("applications", "customers", "loans", "payments", "documents", "integrationlogs", "creditchecks", "branches", "loanofficers")
    
    foreach ($table in $expectedTables) {
        Write-Host "  📊 Validating table: $table"
        
        $command = $connection.CreateCommand()
        $command.CommandText = @"
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = '$table' 
            ORDER BY ordinal_position
"@
        
        $reader = $command.ExecuteReader()
        $columns = @()
        
        while ($reader.Read()) {
            $columns += @{
                Name = $reader["column_name"]
                DataType = $reader["data_type"]
                IsNullable = $reader["is_nullable"]
                Default = $reader["column_default"]
            }
        }
        $reader.Close()
        
        $schemaValidation.Tables[$table] = @{
            Exists = ($columns.Count -gt 0)
            ColumnCount = $columns.Count
            Columns = $columns
        }
        
        if ($columns.Count -gt 0) {
            Write-Host "    ✅ $table exists with $($columns.Count) columns" -ForegroundColor Green
        } else {
            Write-Host "    ❌ $table not found" -ForegroundColor Red
        }
    }
    
    # Validate data type conversions
    Write-Host "  🔄 Validating data type conversions..."
    
    $dataTypeValidations = @{
        "NVARCHAR to VARCHAR" = "SELECT COUNT(*) FROM information_schema.columns WHERE data_type = 'character varying'"
        "DATETIME2 to TIMESTAMP" = "SELECT COUNT(*) FROM information_schema.columns WHERE data_type = 'timestamp without time zone'"
        "BIT to BOOLEAN" = "SELECT COUNT(*) FROM information_schema.columns WHERE data_type = 'boolean'"
        "INT IDENTITY to SERIAL" = "SELECT COUNT(*) FROM information_schema.columns WHERE column_default LIKE 'nextval%'"
    }
    
    foreach ($validation in $dataTypeValidations.GetEnumerator()) {
        $command = $connection.CreateCommand()
        $command.CommandText = $validation.Value
        $result = $command.ExecuteScalar()
        
        $schemaValidation.DataTypes[$validation.Key] = @{
            Count = $result
            Valid = ($result -gt 0)
        }
        
        Write-Host "    📋 $($validation.Key): $result occurrences" -ForegroundColor Cyan
    }
    
    $connection.Close()
}
catch {
    Write-Host "  ❌ PostgreSQL validation error: $($_.Exception.Message)" -ForegroundColor Red
    $schemaValidation.Error = $_.Exception.Message
}

return $schemaValidation
```

##### Application Integration Validation
```powershell
# validate-phase2-application.ps1
param(
    [string]$ApplicationUrl = "http://localhost:5000"
)

Write-Host "🔍 Validating Phase 2 Application Integration..." -ForegroundColor Green

$appValidation = @{
    Connectivity = @{}
    Functionality = @{}
    Performance = @{}
}

try {
    # Test basic connectivity
    Write-Host "  🌐 Testing application connectivity..."
    $response = Invoke-WebRequest -Uri $ApplicationUrl -TimeoutSec 30
    
    $appValidation.Connectivity.Status = if ($response.StatusCode -eq 200) { "Pass" } else { "Fail" }
    $appValidation.Connectivity.StatusCode = $response.StatusCode
    
    if ($response.StatusCode -eq 200) {
        Write-Host "    ✅ Application accessible" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Application not accessible: $($response.StatusCode)" -ForegroundColor Red
    }
    
    # Test database connectivity through application
    Write-Host "  🗄️ Testing database connectivity through application..."
    $dbTestResponse = Invoke-RestMethod -Uri "$ApplicationUrl/api/MigrationDashboard/health" -TimeoutSec 30
    
    $appValidation.Connectivity.DatabaseHealth = $dbTestResponse.OverallStatus
    
    if ($dbTestResponse.OverallStatus -eq "Healthy") {
        Write-Host "    ✅ Database connectivity healthy" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Database connectivity issues detected" -ForegroundColor Red
    }
    
    # Test core functionality
    Write-Host "  ⚙️ Testing core functionality..."
    
    # Test documentation page
    $docsResponse = Invoke-WebRequest -Uri "$ApplicationUrl/docs" -TimeoutSec 30
    $appValidation.Functionality.DocsPage = ($docsResponse.StatusCode -eq 200)
    
    # Test API endpoints
    $statusResponse = Invoke-RestMethod -Uri "$ApplicationUrl/api/MigrationDashboard/status" -TimeoutSec 30
    $appValidation.Functionality.StatusAPI = ($statusResponse -ne $null)
    
    # Test metrics endpoint
    $metricsResponse = Invoke-RestMethod -Uri "$ApplicationUrl/api/MigrationDashboard/metrics" -TimeoutSec 30
    $appValidation.Functionality.MetricsAPI = ($metricsResponse -ne $null)
    
    Write-Host "    ✅ Core functionality validated" -ForegroundColor Green
    
    # Performance testing
    Write-Host "  ⚡ Testing performance..."
    $performanceTests = @()
    
    for ($i = 1; $i -le 5; $i++) {
        $startTime = Get-Date
        $testResponse = Invoke-RestMethod -Uri "$ApplicationUrl/api/MigrationDashboard/status" -TimeoutSec 30
        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalMilliseconds
        $performanceTests += $responseTime
    }
    
    $avgResponseTime = ($performanceTests | Measure-Object -Average).Average
    $appValidation.Performance.AverageResponseTime = $avgResponseTime
    $appValidation.Performance.AcceptablePerformance = ($avgResponseTime -lt 1000) # Less than 1 second
    
    Write-Host "    📊 Average response time: $([math]::Round($avgResponseTime, 2))ms" -ForegroundColor Cyan
    
    if ($avgResponseTime -lt 1000) {
        Write-Host "    ✅ Performance within acceptable range" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ Performance slower than expected" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ❌ Application validation error: $($_.Exception.Message)" -ForegroundColor Red
    $appValidation.Error = $_.Exception.Message
}

return $appValidation
```

#### Phase 3: DynamoDB Integration Validation

##### DynamoDB Infrastructure Validation
```powershell
# validate-phase3-dynamodb.ps1
param(
    [string]$TableName = "LoanApp-IntegrationLogs-test",
    [string]$Region = "us-east-1"
)

Write-Host "🔍 Validating Phase 3 DynamoDB Infrastructure..." -ForegroundColor Green

$dynamoValidation = @{
    Table = @{}
    GSIs = @{}
    TTL = @{}
    IAM = @{}
}

try {
    # Validate table structure
    Write-Host "  📊 Validating DynamoDB table structure..."
    $tableDescription = aws dynamodb describe-table --table-name $TableName --region $Region --output json | ConvertFrom-Json
    
    if ($tableDescription.Table) {
        $table = $tableDescription.Table
        
        $dynamoValidation.Table = @{
            Status = $table.TableStatus
            BillingMode = $table.BillingModeSummary.BillingMode
            ItemCount = $table.ItemCount
            TableSizeBytes = $table.TableSizeBytes
        }
        
        Write-Host "    ✅ Table exists: $($table.TableName)" -ForegroundColor Green
        Write-Host "    📋 Status: $($table.TableStatus)" -ForegroundColor Cyan
        Write-Host "    💰 Billing: $($table.BillingModeSummary.BillingMode)" -ForegroundColor Cyan
        
        # Validate key schema
        $pkCorrect = $table.KeySchema | Where-Object { $_.AttributeName -eq "PK" -and $_.KeyType -eq "HASH" }
        $skCorrect = $table.KeySchema | Where-Object { $_.AttributeName -eq "SK" -and $_.KeyType -eq "RANGE" }
        
        $dynamoValidation.Table.KeySchemaValid = ($pkCorrect -and $skCorrect)
        
        if ($pkCorrect -and $skCorrect) {
            Write-Host "    ✅ Key schema configured correctly" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Key schema misconfigured" -ForegroundColor Red
        }
        
        # Validate GSIs
        Write-Host "  🔍 Validating Global Secondary Indexes..."
        $expectedGSIs = @("GSI1-ApplicationId-LogTimestamp", "GSI2-CorrelationId-LogTimestamp", "GSI3-ErrorStatus-LogTimestamp")
        
        foreach ($expectedGSI in $expectedGSIs) {
            $gsi = $table.GlobalSecondaryIndexes | Where-Object { $_.IndexName -eq $expectedGSI }
            
            $dynamoValidation.GSIs[$expectedGSI] = @{
                Exists = ($gsi -ne $null)
                Status = if ($gsi) { $gsi.IndexStatus } else { "Missing" }
            }
            
            if ($gsi) {
                Write-Host "    ✅ $expectedGSI`: $($gsi.IndexStatus)" -ForegroundColor Green
            } else {
                Write-Host "    ❌ $expectedGSI`: Missing" -ForegroundColor Red
            }
        }
        
        # Validate TTL
        Write-Host "  ⏰ Validating TTL configuration..."
        $ttlDescription = aws dynamodb describe-time-to-live --table-name $TableName --region $Region --output json | ConvertFrom-Json
        
        $dynamoValidation.TTL = @{
            Enabled = ($ttlDescription.TimeToLiveDescription.TimeToLiveStatus -eq "ENABLED")
            AttributeName = $ttlDescription.TimeToLiveDescription.AttributeName
        }
        
        if ($ttlDescription.TimeToLiveDescription.TimeToLiveStatus -eq "ENABLED") {
            Write-Host "    ✅ TTL enabled on attribute: $($ttlDescription.TimeToLiveDescription.AttributeName)" -ForegroundColor Green
        } else {
            Write-Host "    ❌ TTL not enabled" -ForegroundColor Red
        }
    } else {
        Write-Host "    ❌ Table not found: $TableName" -ForegroundColor Red
        $dynamoValidation.Table.Exists = $false
    }
}
catch {
    Write-Host "  ❌ DynamoDB validation error: $($_.Exception.Message)" -ForegroundColor Red
    $dynamoValidation.Error = $_.Exception.Message
}

# Test basic operations
try {
    Write-Host "  🧪 Testing basic DynamoDB operations..."
    
    # Test write operation
    $testItem = @{
        PK = @{ S = "TestService-$(Get-Date -Format 'yyyy-MM-dd')" }
        SK = @{ S = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')#TEST001" }
        LogId = @{ N = "999999" }
        LogType = @{ S = "VALIDATION_TEST" }
        ServiceName = @{ S = "ValidationService" }
        LogTimestamp = @{ S = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')" }
        IsSuccess = @{ BOOL = $true }
        TTL = @{ N = "$([DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds())" }
    } | ConvertTo-Json -Depth 10
    
    aws dynamodb put-item --table-name $TableName --item $testItem --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ Write operation successful" -ForegroundColor Green
        $dynamoValidation.Operations = @{ Write = "Pass" }
        
        # Test read operation
        $key = @{
            PK = @{ S = "TestService-$(Get-Date -Format 'yyyy-MM-dd')" }
            SK = @{ S = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')#TEST001" }
        } | ConvertTo-Json -Depth 10
        
        $readResult = aws dynamodb get-item --table-name $TableName --key $key --region $Region --output json
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Read operation successful" -ForegroundColor Green
            $dynamoValidation.Operations.Read = "Pass"
        } else {
            Write-Host "    ❌ Read operation failed" -ForegroundColor Red
            $dynamoValidation.Operations.Read = "Fail"
        }
    } else {
        Write-Host "    ❌ Write operation failed" -ForegroundColor Red
        $dynamoValidation.Operations = @{ Write = "Fail" }
    }
}
catch {
    Write-Host "  ❌ Operations test error: $($_.Exception.Message)" -ForegroundColor Red
    $dynamoValidation.Operations = @{ Error = $_.Exception.Message }
}

return $dynamoValidation
```

### 📊 Comprehensive Migration Validation Report

#### generate-migration-validation-report.ps1
```powershell
# Comprehensive migration validation report generator
param(
    [string]$Environment = "test",
    [string]$OutputPath = "migration-validation-report.html"
)

Write-Host "📊 Generating Comprehensive Migration Validation Report..." -ForegroundColor Green

# Run all validation scripts
$phase1Results = & "./validate-phase1-infrastructure.ps1" -Environment $Environment
$phase1Migration = & "./validate-phase1-migration.ps1" -TargetServer "rds-endpoint" 
$phase2Schema = & "./validate-phase2-schema.ps1" -PostgreSQLServer "aurora-endpoint"
$phase2App = & "./validate-phase2-application.ps1"
$phase3Dynamo = & "./validate-phase3-dynamodb.ps1" -TableName "LoanApp-IntegrationLogs-$Environment"

# Generate HTML report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Migration Validation Report - $Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .phase { margin: 20px 0; border: 1px solid #ddd; border-radius: 5px; }
        .phase-header { background-color: #e7f3ff; padding: 15px; font-weight: bold; }
        .phase-content { padding: 15px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 Migration Validation Report</h1>
        <p><strong>Environment:</strong> $Environment</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Report Type:</strong> Comprehensive Migration Validation</p>
    </div>

    <div class="phase">
        <div class="phase-header">Phase 1: SQL Server to RDS Migration</div>
        <div class="phase-content">
            <h3>Infrastructure Validation</h3>
            <table>
                <tr><th>Component</th><th>Status</th><th>Details</th></tr>
"@

# Add Phase 1 results to HTML
foreach ($component in $phase1Results.GetEnumerator()) {
    $statusClass = switch ($component.Value.Status) {
        "Pass" { "pass" }
        "Fail" { "fail" }
        default { "warning" }
    }
    
    $htmlReport += "<tr><td>$($component.Key)</td><td class='$statusClass'>$($component.Value.Status)</td><td>$($component.Value.Details)</td></tr>"
}

$htmlReport += @"
            </table>
            
            <h3>Data Migration Validation</h3>
            <table>
                <tr><th>Table</th><th>Source Count</th><th>Target Count</th><th>Status</th></tr>
"@

# Add migration results
foreach ($table in $phase1Migration.TableCounts.GetEnumerator()) {
    $statusClass = if ($table.Value.Match) { "pass" } else { "fail" }
    $status = if ($table.Value.Match) { "✅ Match" } else { "❌ Mismatch" }
    
    $htmlReport += "<tr><td>$($table.Key)</td><td>$($table.Value.Source)</td><td>$($table.Value.Target)</td><td class='$statusClass'>$status</td></tr>"
}

$htmlReport += @"
            </table>
        </div>
    </div>

    <div class="phase">
        <div class="phase-header">Phase 2: PostgreSQL Migration</div>
        <div class="phase-content">
            <h3>Schema Conversion</h3>
            <table>
                <tr><th>Table</th><th>Exists</th><th>Column Count</th></tr>
"@

# Add Phase 2 schema results
foreach ($table in $phase2Schema.Tables.GetEnumerator()) {
    $statusClass = if ($table.Value.Exists) { "pass" } else { "fail" }
    $status = if ($table.Value.Exists) { "✅ Yes" } else { "❌ No" }
    
    $htmlReport += "<tr><td>$($table.Key)</td><td class='$statusClass'>$status</td><td>$($table.Value.ColumnCount)</td></tr>"
}

$htmlReport += @"
            </table>
            
            <h3>Application Integration</h3>
            <table>
                <tr><th>Component</th><th>Status</th><th>Details</th></tr>
                <tr><td>Application Connectivity</td><td class='$(if ($phase2App.Connectivity.Status -eq "Pass") { "pass" } else { "fail" })'>$($phase2App.Connectivity.Status)</td><td>Status Code: $($phase2App.Connectivity.StatusCode)</td></tr>
                <tr><td>Database Health</td><td class='$(if ($phase2App.Connectivity.DatabaseHealth -eq "Healthy") { "pass" } else { "fail" })'>$($phase2App.Connectivity.DatabaseHealth)</td><td>Through application API</td></tr>
                <tr><td>Average Response Time</td><td class='$(if ($phase2App.Performance.AcceptablePerformance) { "pass" } else { "warning" })'>$([math]::Round($phase2App.Performance.AverageResponseTime, 2))ms</td><td>Target: < 1000ms</td></tr>
            </table>
        </div>
    </div>

    <div class="phase">
        <div class="phase-header">Phase 3: DynamoDB Integration</div>
        <div class="phase-content">
            <h3>DynamoDB Infrastructure</h3>
            <table>
                <tr><th>Component</th><th>Status</th><th>Details</th></tr>
                <tr><td>Table Status</td><td class='$(if ($phase3Dynamo.Table.Status -eq "ACTIVE") { "pass" } else { "fail" })'>$($phase3Dynamo.Table.Status)</td><td>Billing: $($phase3Dynamo.Table.BillingMode)</td></tr>
                <tr><td>Key Schema</td><td class='$(if ($phase3Dynamo.Table.KeySchemaValid) { "pass" } else { "fail" })'>$(if ($phase3Dynamo.Table.KeySchemaValid) { "✅ Valid" } else { "❌ Invalid" })</td><td>PK/SK configuration</td></tr>
                <tr><td>TTL Configuration</td><td class='$(if ($phase3Dynamo.TTL.Enabled) { "pass" } else { "fail" })'>$(if ($phase3Dynamo.TTL.Enabled) { "✅ Enabled" } else { "❌ Disabled" })</td><td>Attribute: $($phase3Dynamo.TTL.AttributeName)</td></tr>
            </table>
            
            <h3>Global Secondary Indexes</h3>
            <table>
                <tr><th>GSI Name</th><th>Status</th></tr>
"@

# Add GSI results
foreach ($gsi in $phase3Dynamo.GSIs.GetEnumerator()) {
    $statusClass = if ($gsi.Value.Exists -and $gsi.Value.Status -eq "ACTIVE") { "pass" } else { "fail" }
    
    $htmlReport += "<tr><td>$($gsi.Key)</td><td class='$statusClass'>$($gsi.Value.Status)</td></tr>"
}

$htmlReport += @"
            </table>
            
            <h3>Basic Operations Test</h3>
            <table>
                <tr><th>Operation</th><th>Status</th></tr>
                <tr><td>Write Test</td><td class='$(if ($phase3Dynamo.Operations.Write -eq "Pass") { "pass" } else { "fail" })'>$($phase3Dynamo.Operations.Write)</td></tr>
                <tr><td>Read Test</td><td class='$(if ($phase3Dynamo.Operations.Read -eq "Pass") { "pass" } else { "fail" })'>$($phase3Dynamo.Operations.Read)</td></tr>
            </table>
        </div>
    </div>

    <div class="phase">
        <div class="phase-header">📊 Overall Assessment</div>
        <div class="phase-content">
"@

# Calculate overall status
$overallIssues = @()

if ($phase1Results.Values | Where-Object { $_.Status -eq "Fail" }) {
    $overallIssues += "Phase 1 infrastructure issues detected"
}

if ($phase1Migration.TableCounts.Values | Where-Object { $_.Match -eq $false }) {
    $overallIssues += "Phase 1 data migration discrepancies"
}

if ($phase2Schema.Tables.Values | Where-Object { $_.Exists -eq $false }) {
    $overallIssues += "Phase 2 schema conversion issues"
}

if ($phase2App.Connectivity.Status -ne "Pass") {
    $overallIssues += "Phase 2 application connectivity issues"
}

if ($phase3Dynamo.Table.Status -ne "ACTIVE") {
    $overallIssues += "Phase 3 DynamoDB table issues"
}

$overallStatus = if ($overallIssues.Count -eq 0) { "✅ PASS" } else { "❌ ISSUES DETECTED" }
$statusClass = if ($overallIssues.Count -eq 0) { "pass" } else { "fail" }

$htmlReport += @"
            <h2 class="$statusClass">$overallStatus</h2>
            
            $(if ($overallIssues.Count -gt 0) {
                "<h3>Issues Detected:</h3><ul>" + 
                ($overallIssues | ForEach-Object { "<li>$_</li>" }) -join "" + 
                "</ul>"
            } else {
                "<p>All migration phases validated successfully. Workshop is ready for deployment.</p>"
            })
            
            <h3>Recommendations:</h3>
            <ul>
                $(if ($overallIssues.Count -eq 0) {
                    "<li>✅ Workshop environment is ready for participant use</li>" +
                    "<li>✅ All migration procedures validated successfully</li>" +
                    "<li>✅ Performance metrics within acceptable ranges</li>"
                } else {
                    "<li>❌ Address identified issues before workshop deployment</li>" +
                    "<li>🔄 Re-run validation after fixes are applied</li>" +
                    "<li>📋 Review detailed error messages in component sections</li>"
                })
            </ul>
        </div>
    </div>

    <div class="phase">
        <div class="phase-header">📋 Next Steps</div>
        <div class="phase-content">
            <ol>
                <li>Review any failed validations and address root causes</li>
                <li>Re-run specific validation scripts for fixed components</li>
                <li>Generate updated validation report</li>
                <li>Proceed with workshop documentation review (Step 4.3)</li>
                <li>Set up feedback collection mechanisms (Step 4.4)</li>
            </ol>
        </div>
    </div>
</body>
</html>
"@

# Save HTML report
$htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "📄 Validation report generated: $OutputPath" -ForegroundColor Green

# Also save JSON data for programmatic access
$validationData = @{
    Environment = $Environment
    GeneratedAt = Get-Date
    Phase1 = @{
        Infrastructure = $phase1Results
        Migration = $phase1Migration
    }
    Phase2 = @{
        Schema = $phase2Schema
        Application = $phase2App
    }
    Phase3 = @{
        DynamoDB = $phase3Dynamo
    }
    OverallStatus = $overallStatus
    Issues = $overallIssues
}

$validationData | ConvertTo-Json -Depth 10 | Out-File -FilePath "migration-validation-data.json" -Encoding UTF8

Write-Host "📊 Validation data saved: migration-validation-data.json" -ForegroundColor Green

return $validationData
```

---

### 💡 Q Developer Integration Points

```
1. "Review these migration validation procedures and suggest additional test cases or validation scenarios that should be included for comprehensive workshop testing."

2. "Analyze the validation scripts and recommend improvements for better error detection, reporting, and automated remediation of common issues."

3. "Examine the validation report format and suggest enhancements for better visualization and actionability of the results for workshop instructors."
```

**Next**: [Documentation Review Procedures](../documentation-review/documentation-completeness-check.md)