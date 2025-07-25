# =============================================
# Application Deployment Script for Loan Application System (Windows)
# PowerShell script for .NET application deployment on Windows Server
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "Development",
    
    [Parameter(Mandatory=$false)]
    [string]$ConnectionString = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$IISAppPool = "LoanApplicationPool",
    
    [Parameter(Mandatory=$false)]
    [string]$IISSiteName = "LoanApplication",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help = $false
)

# Configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptPath
$AppDir = Join-Path $ProjectRoot "LoanApplication"
$PublishDir = Join-Path $ScriptPath "publish"
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

# Help function
function Show-Help {
    Write-Host @"
Usage: .\deploy-application.ps1 [OPTIONS]

Deploy the Loan Application System .NET application on Windows Server

OPTIONS:
    -Environment ENV           Target environment (Development, Staging, Production)
    -ConnectionString CS       Database connection string
    -SkipBuild                Skip the build process
    -SkipTests                Skip running tests
    -IISAppPool POOL          IIS Application Pool name (default: LoanApplicationPool)
    -IISSiteName SITE         IIS Site name (default: LoanApplication)
    -Port PORT                Port number (default: 8080)
    -Help                     Show this help message

EXAMPLES:
    .\deploy-application.ps1 -Environment Production -ConnectionString "Server=prod-db;Database=LoanApplicationDB;..."
    .\deploy-application.ps1 -SkipBuild -SkipTests -Port 80
"@
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Log "Starting application deployment for Loan Application System"
Write-Log "Environment: $Environment"
Write-Log "Project Root: $ProjectRoot"
Write-Log "Application Directory: $AppDir"

# =============================================
# 1. Validate Prerequisites
# =============================================
Write-Log "Validating prerequisites..."

# Check if .NET SDK is installed
try {
    $DotNetVersion = & dotnet --version 2>$null
    Write-Log ".NET SDK Version: $DotNetVersion"
} catch {
    Write-Log ".NET SDK is not installed or not in PATH" "ERROR"
    throw
}

# Check if application directory exists
if (-not (Test-Path $AppDir)) {
    Write-Log "Application directory not found: $AppDir" "ERROR"
    throw
}

# Check if project file exists
$ProjectFile = Join-Path $AppDir "LoanApplication.csproj"
if (-not (Test-Path $ProjectFile)) {
    Write-Log "Project file not found: $ProjectFile" "ERROR"
    throw
}

# Check if IIS is available (for production deployment)
if ($Environment -eq "Production") {
    try {
        Import-Module WebAdministration -ErrorAction Stop
        Write-Log "IIS module loaded successfully"
    } catch {
        Write-Log "IIS is not available. Installing IIS features..." "WARNING"
        # Note: In real deployment, you might want to install IIS features automatically
        Write-Log "Please install IIS manually: Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole" "WARNING"
    }
}

# =============================================
# 2. Clean Previous Build
# =============================================
Write-Log "Cleaning previous build artifacts..."
if (Test-Path $PublishDir) {
    Remove-Item -Path $PublishDir -Recurse -Force
}
New-Item -Path $PublishDir -ItemType Directory -Force | Out-Null

Set-Location $AppDir
& dotnet clean --configuration Release
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to clean project" "ERROR"
    throw
}

# =============================================
# 3. Restore NuGet Packages
# =============================================
Write-Log "Restoring NuGet packages..."
& dotnet restore
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to restore NuGet packages" "ERROR"
    throw
}

# =============================================
# 4. Build Application (Optional)
# =============================================
if (-not $SkipBuild) {
    Write-Log "Building application..."
    & dotnet build --configuration Release --no-restore
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to build application" "ERROR"
        throw
    }
    Write-Log "Build completed successfully"
} else {
    Write-Log "Skipping build process"
}

# =============================================
# 5. Run Tests (Optional)
# =============================================
if (-not $SkipTests) {
    Write-Log "Running tests..."
    $TestProject = Join-Path $ProjectRoot "LoanApplication.Tests"
    if (Test-Path $TestProject) {
        Set-Location $TestProject
        & dotnet test --configuration Release --no-build --logger "console;verbosity=minimal"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Tests failed" "ERROR"
            throw
        }
        Write-Log "All tests passed"
    } else {
        Write-Log "Test project not found, skipping tests" "WARNING"
    }
} else {
    Write-Log "Skipping tests"
}

# =============================================
# 6. Update Configuration
# =============================================
Write-Log "Updating application configuration..."

Set-Location $AppDir

# Update appsettings for target environment
$AppSettingsFile = "appsettings.$Environment.json"
if (-not (Test-Path $AppSettingsFile)) {
    Write-Log "Creating $AppSettingsFile"
    Copy-Item "appsettings.json" $AppSettingsFile
}

# Update connection string if provided
if ($ConnectionString) {
    Write-Log "Updating connection string for $Environment environment"
    
    $MockMode = if ($Environment -eq "Development") { "true" } else { "false" }
    
    $ConfigContent = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "$ConnectionString"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "LoanSettings": {
    "MaxDSRRatio": 40.0,
    "MinCreditScore": 600,
    "MaxLoanAmount": 1000000,
    "MinLoanAmount": 1000,
    "DefaultInterestRate": 0.08
  },
  "CreditCheckSettings": {
    "MockMode": $MockMode,
    "DefaultCreditBureau": "Experian",
    "CacheExpiryHours": 24
  }
}
"@
    
    Set-Content -Path $AppSettingsFile -Value $ConfigContent
    Write-Log "Configuration updated successfully"
} else {
    Write-Log "No connection string provided, using default configuration" "WARNING"
}

# =============================================
# 7. Publish Application
# =============================================
Write-Log "Publishing application..."

& dotnet publish --configuration Release --output $PublishDir --no-build --self-contained false
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to publish application" "ERROR"
    throw
}

Write-Log "Application published to: $PublishDir"

# =============================================
# 8. Configure IIS (Production Only)
# =============================================
if ($Environment -eq "Production") {
    Write-Log "Configuring IIS..."
    
    try {
        # Create Application Pool
        if (Get-IISAppPool -Name $IISAppPool -ErrorAction SilentlyContinue) {
            Write-Log "Application pool '$IISAppPool' already exists"
        } else {
            New-WebAppPool -Name $IISAppPool
            Write-Log "Created application pool: $IISAppPool"
        }
        
        # Configure Application Pool
        Set-ItemProperty -Path "IIS:\AppPools\$IISAppPool" -Name processModel.identityType -Value ApplicationPoolIdentity
        Set-ItemProperty -Path "IIS:\AppPools\$IISAppPool" -Name managedRuntimeVersion -Value ""
        Write-Log "Configured application pool settings"
        
        # Create/Update Website
        if (Get-Website -Name $IISSiteName -ErrorAction SilentlyContinue) {
            Write-Log "Website '$IISSiteName' already exists, updating..."
            Set-ItemProperty -Path "IIS:\Sites\$IISSiteName" -Name physicalPath -Value $PublishDir
        } else {
            New-Website -Name $IISSiteName -Port $Port -PhysicalPath $PublishDir -ApplicationPool $IISAppPool
            Write-Log "Created website: $IISSiteName on port $Port"
        }
        
        # Start Application Pool and Website
        Start-WebAppPool -Name $IISAppPool
        Start-Website -Name $IISSiteName
        
        Write-Log "IIS configuration completed successfully"
        
    } catch {
        Write-Log "IIS configuration failed: $($_.Exception.Message)" "ERROR"
        Write-Log "You may need to configure IIS manually" "WARNING"
    }
}

# =============================================
# 9. Create Windows Service (Alternative to IIS)
# =============================================
if ($Environment -ne "Production") {
    Write-Log "Creating Windows Service configuration..."
    
    $ServiceScript = Join-Path $ScriptPath "install-service.ps1"
    $ServiceContent = @"
# Install Loan Application as Windows Service
# Run as Administrator

`$ServiceName = "LoanApplication"
`$ServiceDisplayName = "Loan Application System"
`$ServiceDescription = "Financial Services Loan Application System"
`$ServicePath = "$PublishDir\LoanApplication.exe"

# Stop service if running
if (Get-Service `$ServiceName -ErrorAction SilentlyContinue) {
    Stop-Service `$ServiceName -Force
    & sc.exe delete `$ServiceName
    Write-Host "Removed existing service"
}

# Create new service
& sc.exe create `$ServiceName binPath= `$ServicePath DisplayName= `$ServiceDisplayName
& sc.exe description `$ServiceName `$ServiceDescription
& sc.exe config `$ServiceName start= auto

# Start service
Start-Service `$ServiceName
Write-Host "Service installed and started successfully"
Write-Host "Service Name: `$ServiceName"
Write-Host "Status: " -NoNewline
Get-Service `$ServiceName | Select-Object Status
"@
    
    Set-Content -Path $ServiceScript -Value $ServiceContent
    Write-Log "Windows Service installation script created: $ServiceScript"
}

# =============================================
# 10. Create Deployment Package
# =============================================
Write-Log "Creating deployment package..."

$PackageName = "LoanApplication-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
$PackagePath = Join-Path $ScriptPath $PackageName

# Create ZIP package
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($PublishDir, $PackagePath)

Write-Log "Deployment package created: $PackageName"

# =============================================
# 11. Generate Deployment Summary
# =============================================
$DeploymentSummary = @"
=== DEPLOYMENT SUMMARY ===
Environment: $Environment
Build: $(if (-not $SkipBuild) { "Completed" } else { "Skipped" })
Tests: $(if (-not $SkipTests) { "Passed" } else { "Skipped" })
Publish Directory: $PublishDir
Deployment Package: $PackageName
$(if ($Environment -eq "Production") {
"IIS Application Pool: $IISAppPool
IIS Website: $IISSiteName
Port: $Port"
} else {
"Windows Service Script: install-service.ps1"
})
Log File: $LogFile
=== DEPLOYMENT COMPLETED SUCCESSFULLY ===
"@

Write-Log $DeploymentSummary

# Display next steps
$NextSteps = @"

NEXT STEPS:
$(if ($Environment -eq "Production") {
"1. Verify IIS deployment:
   - Open browser: http://localhost:$Port
   - Check IIS Manager for site status
   
2. Configure SSL certificate (recommended):
   - Bind SSL certificate to website
   - Update application URLs"
} else {
"1. Install as Windows Service (run as Administrator):
   .\install-service.ps1
   
2. Or run directly:
   cd $PublishDir
   .\LoanApplication.exe"
})

3. Verify database connectivity:
   - Test application functionality
   - Check application logs

4. Monitor application:
   - Windows Event Viewer
   - Application logs in publish directory
"@

Write-Host $NextSteps

Write-Log "Deployment script completed successfully"

# Return deployment information
return @{
    Environment = $Environment
    PublishDirectory = $PublishDir
    PackagePath = $PackagePath
    LogFile = $LogFile
}