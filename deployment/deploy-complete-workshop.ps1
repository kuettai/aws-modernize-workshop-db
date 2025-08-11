# =============================================
# Complete Workshop Deployment Script
# AWS Database Modernization Workshop - Clean Deployment
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SQLPassword = "WorkshopDB123!"
)

$LogFile = "C:\Workshop\complete-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARNING"){"Yellow"} else{"Green"})
    if (-not (Test-Path "C:\Workshop")) { New-Item -Path "C:\Workshop" -ItemType Directory -Force }
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Host "=== AWS Database Modernization Workshop - Complete Deployment ===" -ForegroundColor Cyan

try {
    # =============================================
    # 1. Configure SQL Server
    # =============================================
    Write-Log "Step 1: Configuring SQL Server..."
    
    $SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 10
    
    # Test connection
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query "SELECT @@VERSION" -QueryTimeout 10
    Write-Log "SQL Server configured successfully"
    
    # =============================================
    # 2. Install Prerequisites
    # =============================================
    Write-Log "Step 2: Installing prerequisites..."
    
    # Install Chocolatey if not available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Install .NET 9.0 SDK and hosting
    choco install dotnet-9.0-sdk dotnet-9.0-windowshosting -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Configure IIS
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart -ErrorAction SilentlyContinue
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    Write-Log "Prerequisites installed successfully"
    
    # =============================================
    # 3. Deploy Database
    # =============================================
    Write-Log "Step 3: Deploying database..."
    
    # Clear and recreate database
    $ClearDB = @"
USE master;
ALTER DATABASE LoanApplicationDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE IF EXISTS LoanApplicationDB;
CREATE DATABASE LoanApplicationDB;
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query $ClearDB
    
    # Deploy schema and procedures
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -InputFile "database-schema.sql"
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800
    
    Write-Log "Database deployed successfully"
    
    # =============================================
    # 4. Build and Deploy Application
    # =============================================
    Write-Log "Step 4: Building and deploying application..."
    
    # Build application
    cd LoanApplication
    dotnet clean
    dotnet restore
    dotnet build --configuration Release
    
    # Publish application
    dotnet publish --configuration Release --output "..\deployment\publish-final" --self-contained false
    
    cd ..
    
    # Stop IIS to release file locks
    iisreset /stop
    Start-Sleep -Seconds 5
    
    # Copy application files
    if (Test-Path "C:\inetpub\wwwroot\LoanApplication") {
        Remove-Item -Path "C:\inetpub\wwwroot\LoanApplication" -Recurse -Force
    }
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication" -ItemType Directory -Force
    Copy-Item -Path "deployment\publish-final\*" -Destination "C:\inetpub\wwwroot\LoanApplication\" -Recurse -Force
    
    # Create correct connection string with proper format
    $appSettings = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLPassword;Encrypt=false;TrustServerCertificate=true;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  },
  "AllowedHosts": "*"
}
"@
    
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $appSettings
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.json" -Value $appSettings
    
    # Create web.config
    $webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\LoanApplication.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="InProcess" />
  </system.webServer>
</configuration>
"@
    
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\web.config" -Value $webConfig
    
    # Create logs directory
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication\logs" -ItemType Directory -Force
    
    Write-Log "Application files deployed successfully"
    
    # =============================================
    # 5. Configure IIS
    # =============================================
    Write-Log "Step 5: Configuring IIS..."
    
    # Start IIS
    iisreset /start
    Start-Sleep -Seconds 10
    
    Import-Module WebAdministration
    
    # Configure Default Web Site
    if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site" -Name physicalPath -Value "C:\inetpub\wwwroot\LoanApplication"
    } else {
        New-Website -Name "Default Web Site" -Port 80 -PhysicalPath "C:\inetpub\wwwroot\LoanApplication" -ApplicationPool "DefaultAppPool"
    }
    
    # Configure application pool for .NET 9
    Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value ""
    
    # Start website
    Start-Website -Name "Default Web Site"
    
    Write-Log "IIS configured successfully"
    
    # =============================================
    # 6. Configure Firewall
    # =============================================
    Write-Log "Step 6: Configuring firewall..."
    
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
    
    Write-Log "Firewall configured successfully"
    
    # =============================================
    # 7. Verify Deployment
    # =============================================
    Write-Log "Step 7: Verifying deployment..."
    
    Start-Sleep -Seconds 10
    
    # Test database
    $dbTest = Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -Query "SELECT COUNT(*) as Count FROM Applications"
    Write-Log "Database test: $($dbTest.Count) applications found"
    
    # Test web application
    try {
        $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
        Write-Log "Web application test: Status $($response.StatusCode)"
        
        if ($response.Content -like "*Loan Application System*") {
            Write-Log "✅ Application is working correctly!"
        }
    } catch {
        Write-Log "Web application test failed: $($_.Exception.Message)" "WARNING"
    }
    
    # =============================================
    # 8. Generate Summary
    # =============================================
    $Summary = @"

=== DEPLOYMENT COMPLETED SUCCESSFULLY ===

Environment Details:
- SQL Server: localhost (SQL Server 2022 Web Edition)
- Database: LoanApplicationDB
- SA Password: $SQLPassword
- Web Application: http://localhost
- Application Path: C:\inetpub\wwwroot\LoanApplication

Database Statistics:
- Applications: $($dbTest.Count)
- Ready for workshop phases

Available Endpoints:
- Home: http://localhost
- Applications API: http://localhost/api/applications
- Customers API: http://localhost/api/customers
- Documentation: http://localhost/docs

Workshop Phases Ready:
✅ Phase 1: SQL Server → AWS RDS SQL Server
✅ Phase 2: RDS SQL Server → Aurora PostgreSQL  
✅ Phase 3: IntegrationLogs → DynamoDB

Log File: $LogFile
=== WORKSHOP ENVIRONMENT READY ===
"@
    
    Write-Host $Summary -ForegroundColor Green
    Set-Content -Path "C:\Workshop\deployment-summary.txt" -Value $Summary
    
    Write-Log "Complete deployment finished successfully!"
    Start-Process "http://localhost"
    
} catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Check the log file for details: $LogFile" -ForegroundColor Red
    exit 1
}