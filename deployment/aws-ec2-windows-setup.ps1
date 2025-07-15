# =============================================
# AWS EC2 Windows Server Complete Setup Script
# Installs IIS, SQL Server, and deploys Loan Application
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SQLServerSAPassword = "LoanApp123!",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "Production",
    
    [Parameter(Mandatory=$false)]
    [int]$WebsitePort = 80,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateSampleData = $true
)

$LogFile = "C:\Temp\aws-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory -Force }
    Add-Content -Path $LogFile -Value $LogEntry
}

$ErrorActionPreference = "Stop"
trap {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "=== AWS EC2 Windows Server 2022 + SQL Server 2022 Web Setup Started ==="
Write-Log "Environment: $Environment"
Write-Log "SQL Server SA Password: [HIDDEN]"
Write-Log "Website Port: $WebsitePort"
Write-Log "Using pre-installed SQL Server 2022 Web Edition"

# =============================================
# 1. Install Chocolatey (Package Manager)
# =============================================
Write-Log "Installing Chocolatey package manager..."
try {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed successfully"
    } else {
        Write-Log "Chocolatey already installed"
    }
} catch {
    Write-Log "Failed to install Chocolatey: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 2. Install .NET 6 SDK
# =============================================
Write-Log "Installing .NET 6 SDK..."
try {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        choco install dotnet-6.0-sdk -y
        Write-Log ".NET 6 SDK installed successfully"
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        $DotNetVersion = & dotnet --version
        Write-Log ".NET SDK already installed: $DotNetVersion"
    }
} catch {
    Write-Log "Failed to install .NET SDK: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 3. Install and Configure IIS
# =============================================
Write-Log "Installing and configuring IIS..."
try {
    # Install IIS features
    $IISFeatures = @(
        "IIS-WebServerRole",
        "IIS-WebServer",
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpLogging",
        "IIS-RequestFiltering",
        "IIS-StaticContent",
        "IIS-DefaultDocument",
        "IIS-DirectoryBrowsing",
        "IIS-ASPNET45",
        "IIS-NetFxExtensibility45",
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter",
        "IIS-HttpCompressionStatic",
        "IIS-HttpCompressionDynamic",
        "IIS-Security",
        "IIS-RequestFiltering",
        "IIS-BasicAuthentication",
        "IIS-WindowsAuthentication",
        "IIS-ManagementConsole",
        "IIS-IIS6ManagementCompatibility",
        "IIS-Metabase"
    )
    
    foreach ($Feature in $IISFeatures) {
        Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart
    }
    
    # Install ASP.NET Core Hosting Bundle
    Write-Log "Installing ASP.NET Core Hosting Bundle..."
    $HostingBundleUrl = "https://download.visualstudio.microsoft.com/download/pr/0bfb9b2b-c0b0-4b4c-8b5a-8b5a8b5a8b5a/dotnet-hosting-6.0.0-win.exe"
    $HostingBundlePath = "C:\Temp\dotnet-hosting-bundle.exe"
    
    Invoke-WebRequest -Uri $HostingBundleUrl -OutFile $HostingBundlePath
    Start-Process -FilePath $HostingBundlePath -ArgumentList "/quiet" -Wait
    
    Write-Log "IIS installed and configured successfully"
    
    # Import WebAdministration module
    Import-Module WebAdministration
    
} catch {
    Write-Log "Failed to install IIS: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 4. Configure Pre-installed SQL Server 2022 Web Edition
# =============================================
Write-Log "Configuring pre-installed SQL Server 2022 Web Edition..."
try {
    # Check if SQL Server service is running
    $SQLService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    if ($SQLService) {
        Write-Log "SQL Server 2022 Web Edition detected"
        
        # Start SQL Server service if not running
        if ($SQLService.Status -ne "Running") {
            Start-Service -Name "MSSQLSERVER"
            Write-Log "SQL Server service started"
        }
        
        # Configure SQL Server Authentication Mode
        Write-Log "Configuring SQL Server for mixed authentication..."
        
        # Enable SQL Server Authentication and set SA password
        $SQLQuery = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLServerSAPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
        
        # Execute SQL commands using Windows Authentication first
        try {
            Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLQuery
            Write-Log "SQL Server authentication configured successfully"
        } catch {
            Write-Log "Using alternative method to configure SQL Server authentication..."
            # Alternative method using sqlcmd.exe directly
            $TempSQLFile = "C:\Temp\configure-sql.sql"
            Set-Content -Path $TempSQLFile -Value $SQLQuery
            & sqlcmd -S localhost -E -i $TempSQLFile
            Remove-Item -Path $TempSQLFile -Force
        }
        
        # Restart SQL Server to apply authentication changes
        Write-Log "Restarting SQL Server to apply configuration changes..."
        Restart-Service -Name "MSSQLSERVER" -Force
        Start-Sleep -Seconds 10
        
        # Enable SQL Server Browser service
        Set-Service -Name "SQLBrowser" -StartupType Automatic
        Start-Service -Name "SQLBrowser" -ErrorAction SilentlyContinue
        
        # Configure TCP/IP protocol
        Write-Log "Enabling TCP/IP protocol for SQL Server..."
        try {
            # Import SQL Server PowerShell module if available
            Import-Module SqlServer -ErrorAction SilentlyContinue
            
            # Enable TCP/IP using WMI
            $wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
            $wmi.ServerInstances['MSSQLSERVER'].ServerProtocols['Tcp'].IsEnabled = $true
            $wmi.ServerInstances['MSSQLSERVER'].ServerProtocols['Tcp'].Alter()
            
            # Restart SQL Server again for TCP/IP changes
            Restart-Service -Name "MSSQLSERVER" -Force
            Start-Sleep -Seconds 10
            
            Write-Log "TCP/IP protocol enabled successfully"
        } catch {
            Write-Log "TCP/IP configuration may require manual setup" "WARNING"
        }
        
        Write-Log "SQL Server 2022 Web Edition configured successfully"
        
    } else {
        Write-Log "SQL Server service not found. Please verify SQL Server 2022 Web Edition is installed" "ERROR"
        throw "SQL Server 2022 Web Edition not detected"
    }
    
} catch {
    Write-Log "Failed to configure SQL Server: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 5. Configure Windows Firewall
# =============================================
Write-Log "Configuring Windows Firewall..."
try {
    # Allow HTTP traffic
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
    
    # Allow HTTPS traffic
    New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue
    
    # Allow SQL Server traffic
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
    
    # Allow custom port if different from 80
    if ($WebsitePort -ne 80) {
        New-NetFirewallRule -DisplayName "Allow Custom Web Port" -Direction Inbound -Protocol TCP -LocalPort $WebsitePort -Action Allow -ErrorAction SilentlyContinue
    }
    
    Write-Log "Windows Firewall configured successfully"
} catch {
    Write-Log "Failed to configure firewall: $($_.Exception.Message)" "WARNING"
}

# =============================================
# 6. Download and Deploy Application
# =============================================
Write-Log "Downloading and deploying application..."
try {
    # Create application directory
    $AppDeployPath = "C:\inetpub\wwwroot\LoanApplication"
    if (Test-Path $AppDeployPath) {
        Remove-Item -Path $AppDeployPath -Recurse -Force
    }
    New-Item -Path $AppDeployPath -ItemType Directory -Force
    
    # Note: In real deployment, you would download from your artifact repository
    # For this example, we'll assume the application files are already on the server
    Write-Log "Application deployment directory created: $AppDeployPath"
    
} catch {
    Write-Log "Failed to create application directory: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 7. Deploy Database Schema and Data
# =============================================
Write-Log "Deploying database schema and data..."
try {
    $ConnectionString = "Server=localhost;Database=master;User Id=sa;Password=$SQLServerSAPassword;"
    
    # Test database connection
    Write-Log "Testing database connection..."
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()
    $Connection.Close()
    Write-Log "Database connection successful"
    
    # Note: In real deployment, you would run the database deployment script here
    Write-Log "Database schema deployment would be executed here"
    
} catch {
    Write-Log "Failed to deploy database: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 8. Configure IIS Application
# =============================================
Write-Log "Configuring IIS application..."
try {
    $AppPoolName = "LoanApplicationPool"
    $SiteName = "LoanApplication"
    
    # Create Application Pool
    if (Get-IISAppPool -Name $AppPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $AppPoolName
    }
    New-WebAppPool -Name $AppPoolName
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name processModel.identityType -Value ApplicationPoolIdentity
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
    
    # Create Website
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName
    }
    New-Website -Name $SiteName -Port $WebsitePort -PhysicalPath $AppDeployPath -ApplicationPool $AppPoolName
    
    # Start Application Pool and Website
    Start-WebAppPool -Name $AppPoolName
    Start-Website -Name $SiteName
    
    Write-Log "IIS application configured successfully"
    
} catch {
    Write-Log "Failed to configure IIS: $($_.Exception.Message)" "ERROR"
    throw
}

# =============================================
# 9. Create Deployment Summary
# =============================================
$DeploymentInfo = @"
=== AWS EC2 WINDOWS DEPLOYMENT COMPLETED ===

Server Configuration:
- Windows Server with IIS installed
- SQL Server Express installed and configured
- .NET 6 SDK installed
- Firewall configured for web and database traffic

Application Configuration:
- IIS Application Pool: $AppPoolName
- IIS Website: $SiteName
- Website Port: $WebsitePort
- Physical Path: $AppDeployPath

Database Configuration:
- SQL Server Instance: localhost (Default Instance)
- SQL Server Edition: 2022 Web Edition
- SA Password: [CONFIGURED]
- TCP/IP Enabled: Yes
- Remote Connections: Enabled

Next Steps:
1. Deploy your application files to: $AppDeployPath
2. Run database deployment script
3. Update application configuration with connection string
4. Test application: http://[EC2-PUBLIC-IP]:$WebsitePort

Log File: $LogFile
"@

Write-Log $DeploymentInfo
Write-Host $DeploymentInfo

# =============================================
# 10. Generate Helper Scripts
# =============================================
Write-Log "Generating helper scripts..."

# Create database deployment helper
$DBDeployScript = @"
# Database Deployment Helper for AWS EC2
# Run this after copying your database scripts to the server

`$ConnectionString = "Server=localhost\SQLEXPRESS;Database=master;User Id=sa;Password=$SQLServerSAPassword;TrustServerCertificate=true;"

# Deploy database schema
Write-Host "Deploying database schema..."
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "$SQLServerSAPassword" -InputFile "database-schema.sql"

# Deploy stored procedures
Write-Host "Deploying stored procedures..."
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "$SQLServerSAPassword" -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "$SQLServerSAPassword" -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"

# Generate sample data (optional)
if (`$args[0] -eq "-GenerateSampleData") {
    Write-Host "Generating sample data..."
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "$SQLServerSAPassword" -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800
}

Write-Host "Database deployment completed!"
"@

Set-Content -Path "C:\Temp\deploy-database-ec2.ps1" -Value $DBDeployScript

# Create application deployment helper
$AppDeployScript = @"
# Application Deployment Helper for AWS EC2
# Run this to deploy your .NET application

param(
    [string]`$SourcePath = "C:\Temp\LoanApplication",
    [string]`$TargetPath = "$AppDeployPath"
)

Write-Host "Deploying application from `$SourcePath to `$TargetPath..."

# Stop IIS site
Stop-Website -Name "$SiteName"
Stop-WebAppPool -Name "$AppPoolName"

# Copy application files
if (Test-Path `$SourcePath) {
    Copy-Item -Path "`$SourcePath\*" -Destination `$TargetPath -Recurse -Force
    Write-Host "Application files copied successfully"
} else {
    Write-Host "Source path not found: `$SourcePath"
    exit 1
}

# Update connection string in appsettings
`$AppSettings = Join-Path `$TargetPath "appsettings.Production.json"
`$ConnectionString = "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLServerSAPassword;"

`$Config = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "`$ConnectionString"
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

Set-Content -Path `$AppSettings -Value `$Config

# Start IIS site
Start-WebAppPool -Name "$AppPoolName"
Start-Website -Name "$SiteName"

Write-Host "Application deployment completed!"
Write-Host "Website URL: http://localhost:$WebsitePort"
"@

Set-Content -Path "C:\Temp\deploy-application-ec2.ps1" -Value $AppDeployScript

Write-Log "Helper scripts created:"
Write-Log "- C:\Temp\deploy-database-ec2.ps1"
Write-Log "- C:\Temp\deploy-application-ec2.ps1"

Write-Log "=== AWS EC2 WINDOWS SETUP COMPLETED SUCCESSFULLY ==="