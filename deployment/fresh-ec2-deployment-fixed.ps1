# =============================================
# Fresh EC2 Complete Workshop Deployment
# AWS Database Modernization Workshop
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SQLPassword = "WorkshopDB123!",
    
    [Parameter(Mandatory=$false)]
    [string]$GitRepo = "https://github.com/kuettai/aws-modernize-workshop-db.git"
)

Write-Host "=== AWS Database Modernization Workshop - Fresh EC2 Deployment ===" -ForegroundColor Cyan

try {
    # =============================================
    # 1. Create Directories and Configure SQL Server
    # =============================================
    Write-Host "Step 1: Setting up environment..." -ForegroundColor Yellow
    
    New-Item -Path "C:\Workshop" -ItemType Directory -Force
    New-Item -Path "C:\Temp" -ItemType Directory -Force
    
    # Configure SQL Server
    $SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 15
    
    # Test connection
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query "SELECT @@VERSION" -QueryTimeout 10
    Write-Host "✅ SQL Server configured" -ForegroundColor Green
    
    # =============================================
    # 2. Install Prerequisites
    # =============================================
    Write-Host "Step 2: Installing prerequisites..." -ForegroundColor Yellow
    
    # Install Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Configure IIS FIRST (required for ASP.NET Core hosting bundle)
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent -All -NoRestart
    Import-Module WebAdministration
    
    # Install Git and .NET 9.0 SDK
    choco install git dotnet-9.0-sdk -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Install ASP.NET Core Hosting Bundle AFTER IIS
    choco install dotnet-9.0-windowshosting -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "✅ Prerequisites installed" -ForegroundColor Green
    
    # =============================================
    # 3. Clone Repository (or use local files)
    # =============================================
    Write-Host "Step 3: Getting application files..." -ForegroundColor Yellow
    
    cd C:\Workshop
    
    if ($GitRepo -ne "local") {
        try {
            git clone $GitRepo .
            Write-Host "✅ Repository cloned" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Git clone failed, assuming local files" -ForegroundColor Yellow
        }
    }
    
    # =============================================
    # 4. Deploy Database
    # =============================================
    Write-Host "Step 4: Deploying database..." -ForegroundColor Yellow
    
    # Clear and recreate database
    Write-Host "  4.1 Recreating database..." -ForegroundColor Cyan
    $ClearDB = @"
USE master;
ALTER DATABASE LoanApplicationDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE IF EXISTS LoanApplicationDB;
CREATE DATABASE LoanApplicationDB;
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query $ClearDB -ErrorAction SilentlyContinue
    Write-Host "    ✅ Database recreated" -ForegroundColor Green
    
    # Deploy schema
    Write-Host "  4.2 Creating database schema (16 tables)..." -ForegroundColor Cyan
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -InputFile "database-schema.sql"
    Write-Host "    ✅ Schema created" -ForegroundColor Green
    
    # Deploy simple procedures
    Write-Host "  4.3 Creating simple stored procedures (3 procedures)..." -ForegroundColor Cyan
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
    Write-Host "    ✅ Simple procedures created" -ForegroundColor Green
    
    # Deploy complex procedure
    Write-Host "  4.4 Creating complex stored procedure (200+ lines)..." -ForegroundColor Cyan
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"
    Write-Host "    ✅ Complex procedure created" -ForegroundColor Green
    
    # Generate sample data
    Write-Host "  4.5 Generating sample data (200K+ records, ~10-15 minutes)..." -ForegroundColor Cyan
    $dataStart = Get-Date
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800
    $dataEnd = Get-Date
    $dataDuration = ($dataEnd - $dataStart).TotalMinutes
    Write-Host "    ✅ Sample data generated in $([math]::Round($dataDuration, 1)) minutes" -ForegroundColor Green
    
    # Verify data counts
    Write-Host "  4.6 Verifying data integrity..." -ForegroundColor Cyan
    $counts = @{}
    $tables = @('Applications', 'Customers', 'Payments', 'IntegrationLogs')
    foreach ($table in $tables) {
        $result = Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -Query "SELECT COUNT(*) as Count FROM $table"
        $counts[$table] = $result.Count
        Write-Host "    📊 $table - $($result.Count) records" -ForegroundColor White
    }
    Write-Host "    ✅ Data verification complete" -ForegroundColor Green
    
    Write-Host "✅ Database deployed successfully" -ForegroundColor Green
    
    # =============================================
    # 5. Build and Deploy Application
    # =============================================
    Write-Host "Step 5: Building application..." -ForegroundColor Yellow
    
    cd LoanApplication
    dotnet clean
    dotnet restore
    dotnet build --configuration Release
    dotnet publish --configuration Release --output "..\deployment\publish" --self-contained false
    
    cd ..
    
    # Stop IIS
    iisreset /stop
    Start-Sleep -Seconds 5
    
    # Deploy application files
    if (Test-Path "C:\inetpub\wwwroot\LoanApplication") {
        Remove-Item -Path "C:\inetpub\wwwroot\LoanApplication" -Recurse -Force
    }
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication" -ItemType Directory -Force
    Copy-Item -Path "deployment\publish\*" -Destination "C:\inetpub\wwwroot\LoanApplication\" -Recurse -Force
    
    # Create connection string
    $appSettingsContent = '{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=' + $SQLPassword + ';Encrypt=false;TrustServerCertificate=true;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}'
    
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $appSettingsContent
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.json" -Value $appSettingsContent
    
    # Create web.config
    $webConfigContent = '<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\LoanApplication.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="InProcess" />
  </system.webServer>
</configuration>'
    
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\web.config" -Value $webConfigContent
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication\logs" -ItemType Directory -Force
    
    Write-Host "✅ Application deployed" -ForegroundColor Green
    
    # =============================================
    # 6. Configure IIS
    # =============================================
    Write-Host "Step 6: Configuring IIS..." -ForegroundColor Yellow
    
    iisreset /start
    Start-Sleep -Seconds 15
    
    Import-Module WebAdministration
    
    # Configure Default Web Site
    if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site" -Name physicalPath -Value "C:\inetpub\wwwroot\LoanApplication"
    } else {
        New-Website -Name "Default Web Site" -Port 80 -PhysicalPath "C:\inetpub\wwwroot\LoanApplication" -ApplicationPool "DefaultAppPool"
    }
    
    Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value ""
    Start-Website -Name "Default Web Site"
    
    Write-Host "✅ IIS configured" -ForegroundColor Green
    
    # =============================================
    # 7. Configure Firewall
    # =============================================
    Write-Host "Step 7: Configuring firewall..." -ForegroundColor Yellow
    
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
    
    Write-Host "✅ Firewall configured" -ForegroundColor Green
    
    # =============================================
    # 8. Verify Deployment
    # =============================================
    Write-Host "Step 8: Verifying deployment..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 10
    
    # Test database
    $dbTest = Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -Query "SELECT COUNT(*) as Count FROM Applications"
    Write-Host "Database: $($dbTest.Count) applications" -ForegroundColor Green
    
    # Test endpoints
    $endpoints = @(
        "http://localhost",
        "http://localhost/api/applications/count"
    )
    
    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10
            Write-Host "✅ $endpoint - Status: $($response.StatusCode)" -ForegroundColor Green
        } catch {
            Write-Host "❌ $endpoint - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Access your application at: http://localhost" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}