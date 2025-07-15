# =============================================
# Database Deployment Script for Loan Application System
# PowerShell script for automated database setup
# =============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "LoanApplicationDB",
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateSampleData = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation = $false
)

# Script configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptPath
$LogFile = Join-Path $ScriptPath "deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

# Error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Starting database deployment for Loan Application System"
Write-Log "Target Server: $ServerName"
Write-Log "Database Name: $DatabaseName"

# =============================================
# 1. Build Connection String
# =============================================
if ($Username -and $Password) {
    $ConnectionString = "Server=$ServerName;Database=master;User Id=$Username;Password=$Password;TrustServerCertificate=true;"
    $DatabaseConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$Password;TrustServerCertificate=true;"
    Write-Log "Using SQL Server authentication"
} else {
    $ConnectionString = "Server=$ServerName;Database=master;Integrated Security=true;TrustServerCertificate=true;"
    $DatabaseConnectionString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=true;TrustServerCertificate=true;"
    Write-Log "Using Windows authentication"
}

# =============================================
# 2. Test Database Connection
# =============================================
Write-Log "Testing database connection..."
try {
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()
    $Connection.Close()
    Write-Log "Database connection successful"
} catch {
    Write-Log "Failed to connect to database: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 3. Execute Database Schema Script
# =============================================
Write-Log "Creating database schema..."
$SchemaScript = Join-Path $ProjectRoot "database-schema.sql"
if (-not (Test-Path $SchemaScript)) {
    Write-Log "Schema script not found: $SchemaScript" "ERROR"
    throw "Schema script not found"
}

try {
    Invoke-Sqlcmd -ServerInstance $ServerName -InputFile $SchemaScript -ConnectionTimeout 300 -QueryTimeout 600
    Write-Log "Database schema created successfully"
} catch {
    Write-Log "Failed to create database schema: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 4. Execute Stored Procedures Scripts
# =============================================
Write-Log "Creating stored procedures..."

# Simple stored procedures
$SimpleProcsScript = Join-Path $ProjectRoot "stored-procedures-simple.sql"
if (Test-Path $SimpleProcsScript) {
    try {
        Invoke-Sqlcmd -ServerInstance $ServerName -InputFile $SimpleProcsScript -Database $DatabaseName -ConnectionTimeout 300 -QueryTimeout 600
        Write-Log "Simple stored procedures created successfully"
    } catch {
        Write-Log "Failed to create simple stored procedures: $($_.Exception.Message)" "ERROR"
        throw
    }
} else {
    Write-Log "Simple stored procedures script not found" "WARNING"
}

# Complex stored procedure
$ComplexProcScript = Join-Path $ProjectRoot "stored-procedure-complex.sql"
if (Test-Path $ComplexProcScript) {
    try {
        Invoke-Sqlcmd -ServerInstance $ServerName -InputFile $ComplexProcScript -Database $DatabaseName -ConnectionTimeout 300 -QueryTimeout 600
        Write-Log "Complex stored procedure created successfully"
    } catch {
        Write-Log "Failed to create complex stored procedure: $($_.Exception.Message)" "ERROR"
        throw
    }
} else {
    Write-Log "Complex stored procedure script not found" "WARNING"
}

# =============================================
# 5. Generate Sample Data (Optional)
# =============================================
if ($GenerateSampleData) {
    Write-Log "Generating sample data..."
    $SampleDataScript = Join-Path $ProjectRoot "sample-data-generation.sql"
    if (Test-Path $SampleDataScript) {
        try {
            Write-Log "This may take several minutes for large datasets..."
            Invoke-Sqlcmd -ServerInstance $ServerName -InputFile $SampleDataScript -Database $DatabaseName -ConnectionTimeout 600 -QueryTimeout 1800
            Write-Log "Sample data generated successfully"
        } catch {
            Write-Log "Failed to generate sample data: $($_.Exception.Message)" "ERROR"
            throw
        }
    } else {
        Write-Log "Sample data script not found" "WARNING"
    }
}

# =============================================
# 6. Validate Deployment (Optional)
# =============================================
if (-not $SkipValidation) {
    Write-Log "Validating database deployment..."
    
    # Check table existence
    $ValidationQuery = @"
    SELECT 
        TABLE_NAME,
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
    FROM INFORMATION_SCHEMA.TABLES t
    WHERE TABLE_TYPE = 'BASE TABLE' 
        AND TABLE_NAME IN ('Branches', 'LoanOfficers', 'Customers', 'Applications', 'Loans', 'Payments', 'Documents', 'CreditChecks', 'IntegrationLogs', 'AuditTrail')
    ORDER BY TABLE_NAME
"@
    
    try {
        $ValidationResults = Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $ValidationQuery
        Write-Log "Database validation results:"
        foreach ($Result in $ValidationResults) {
            Write-Log "  Table: $($Result.TABLE_NAME), Columns: $($Result.ColumnCount)"
        }
        
        if ($ValidationResults.Count -eq 10) {
            Write-Log "All 10 tables created successfully"
        } else {
            Write-Log "Expected 10 tables, found $($ValidationResults.Count)" "WARNING"
        }
    } catch {
        Write-Log "Validation failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    
    # Check stored procedures
    $ProcValidationQuery = @"
    SELECT 
        ROUTINE_NAME,
        ROUTINE_TYPE
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_TYPE = 'PROCEDURE'
        AND ROUTINE_NAME LIKE 'sp_%'
    ORDER BY ROUTINE_NAME
"@
    
    try {
        $ProcResults = Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $ProcValidationQuery
        Write-Log "Stored procedures validation:"
        foreach ($Proc in $ProcResults) {
            Write-Log "  Procedure: $($Proc.ROUTINE_NAME)"
        }
    } catch {
        Write-Log "Stored procedure validation failed: $($_.Exception.Message)" "WARNING"
    }
}

# =============================================
# 7. Generate Connection String for Application
# =============================================
$AppConnectionString = $DatabaseConnectionString
$ConnectionStringFile = Join-Path $ScriptPath "connection-string.txt"
Set-Content -Path $ConnectionStringFile -Value $AppConnectionString
Write-Log "Connection string saved to: $ConnectionStringFile"

# =============================================
# 8. Deployment Summary
# =============================================
Write-Log "=== DEPLOYMENT SUMMARY ==="
Write-Log "Database Server: $ServerName"
Write-Log "Database Name: $DatabaseName"
Write-Log "Schema: Created"
Write-Log "Stored Procedures: Created"
Write-Log "Sample Data: $(if ($GenerateSampleData) { 'Generated' } else { 'Skipped' })"
Write-Log "Validation: $(if ($SkipValidation) { 'Skipped' } else { 'Completed' })"
Write-Log "Log File: $LogFile"
Write-Log "Connection String File: $ConnectionStringFile"
Write-Log "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="

# Return connection string for use by calling scripts
return $AppConnectionString