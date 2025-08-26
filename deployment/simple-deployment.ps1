param(
    [string]$SQLPassword = "WorkshopDB123!",
    [string]$GitRepo = "https://github.com/kuettai/aws-modernize-workshop-db.git"
)

Write-Host "=== Workshop Deployment ===" -ForegroundColor Cyan

try {
    # 1. Setup SQL Server
    Write-Host "Step 1: Configuring SQL Server..." -ForegroundColor Yellow
    
    $sqlCmd = "USE master; ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD = '$SQLPassword'; EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;"
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $sqlCmd
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 15
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query "SELECT @@VERSION" -QueryTimeout 10
    Write-Host "SQL Server configured" -ForegroundColor Green
    
    # 2. Install Prerequisites
    Write-Host "Step 2: Installing prerequisites..." -ForegroundColor Yellow
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent -All -NoRestart
    
    choco install git dotnet-9.0-sdk dotnet-9.0-windowshosting -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Prerequisites installed" -ForegroundColor Green
    
    # 3. Clone Repository
    Write-Host "Step 3: Cloning repository..." -ForegroundColor Yellow
    
    # Ensure we're in C:\Workshop
    Set-Location "C:\Workshop"
    
    if ($GitRepo -ne "local") {
        try {
            git clone $GitRepo .
            Write-Host "Repository cloned successfully" -ForegroundColor Green
        } catch {
            Write-Host "Git clone failed, assuming local files" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Using local files" -ForegroundColor Green
    }
    
    # Verify files exist
    Write-Host "Checking for required files..." -ForegroundColor Cyan
    $requiredFiles = @("database-schema.sql", "LoanApplication")
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "  Found: $file" -ForegroundColor Green
        } else {
            Write-Host "  Missing: $file" -ForegroundColor Red
        }
    }
    
    # 4. Deploy Database
    Write-Host "Step 4: Deploying database..." -ForegroundColor Yellow
    
    $clearDb = "USE master; DROP DATABASE IF EXISTS LoanApplicationDB; CREATE DATABASE LoanApplicationDB;"
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Query $clearDb -ErrorAction SilentlyContinue
    
    if (Test-Path "database-schema.sql") {
        Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -InputFile "database-schema.sql"
        Write-Host "Database schema created" -ForegroundColor Green
    }
    
    if (Test-Path "stored-procedures-simple.sql") {
        Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
        Write-Host "Simple procedures created" -ForegroundColor Green
    }
    
    if (Test-Path "stored-procedure-complex.sql") {
        Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"
        Write-Host "Complex procedure created" -ForegroundColor Green
    }
    
    if (Test-Path "sample-data-generation.sql") {
        Write-Host "Generating sample data (this may take 10-15 minutes)..." -ForegroundColor Yellow
        Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800
        Write-Host "Sample data generated" -ForegroundColor Green
    }
    
    # 5. Build Application
    Write-Host "Step 5: Building application..." -ForegroundColor Yellow
    
    if (Test-Path "LoanApplication") {
        cd LoanApplication
        dotnet clean
        dotnet restore
        dotnet build --configuration Release
        dotnet publish --configuration Release --output "..\publish" --self-contained false
        cd ..
        Write-Host "Application built" -ForegroundColor Green
    }
    
    # 6. Deploy to IIS
    Write-Host "Step 6: Deploying to IIS..." -ForegroundColor Yellow
    
    iisreset /stop
    Start-Sleep -Seconds 5
    
    if (Test-Path "C:\inetpub\wwwroot\LoanApplication") {
        Remove-Item -Path "C:\inetpub\wwwroot\LoanApplication" -Recurse -Force
    }
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication" -ItemType Directory -Force
    
    if (Test-Path "publish") {
        Copy-Item -Path "publish\*" -Destination "C:\inetpub\wwwroot\LoanApplication\" -Recurse -Force
    }
    
    # Create appsettings.json
    $connString = "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLPassword;Encrypt=false;TrustServerCertificate=true;"
    $appSettings = @{
        ConnectionStrings = @{
            DefaultConnection = $connString
        }
        Logging = @{
            LogLevel = @{
                Default = "Information"
                "Microsoft.AspNetCore" = "Warning"
            }
        }
        AllowedHosts = "*"
    }
    
    $appSettingsJson = $appSettings | ConvertTo-Json -Depth 10
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.json" -Value $appSettingsJson
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $appSettingsJson
    
    # Create web.config
    $webConfigXml = '<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\LoanApplication.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="InProcess" />
  </system.webServer>
</configuration>'
    
    Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\web.config" -Value $webConfigXml
    New-Item -Path "C:\inetpub\wwwroot\LoanApplication\logs" -ItemType Directory -Force
    
    # Configure IIS
    iisreset /start
    Start-Sleep -Seconds 10
    
    Import-Module WebAdministration
    
    if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site" -Name physicalPath -Value "C:\inetpub\wwwroot\LoanApplication"
    } else {
        New-Website -Name "Default Web Site" -Port 80 -PhysicalPath "C:\inetpub\wwwroot\LoanApplication" -ApplicationPool "DefaultAppPool"
    }
    
    Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value ""
    Start-Website -Name "Default Web Site"
    
    Write-Host "IIS configured" -ForegroundColor Green
    
    # 7. Test
    Write-Host "Step 7: Testing..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 10
        Write-Host "SUCCESS: Application accessible at http://localhost" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not test http://localhost - $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "Deployment completed!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}