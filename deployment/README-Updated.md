# AWS Database Modernization Workshop - Updated Deployment Guide

## Complete Workshop Deployment

### Prerequisites
- AWS EC2 Windows Server 2022 with SQL Server 2022 Web Edition
- Administrator access via RDP
- Internet connectivity for package downloads

### One-Command Deployment

```powershell
# Run the complete deployment script
.\deployment\deploy-complete-workshop.ps1 -SQLPassword "WorkshopDB123!"
```

### Manual Step-by-Step Deployment

#### Step 1: Configure SQL Server
```powershell
$SQLPassword = "WorkshopDB123!"

# Configure SQL Server authentication
$SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@

Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig
Restart-Service -Name "MSSQLSERVER" -Force
```

#### Step 2: Install Prerequisites
```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install .NET 9.0 and IIS components
choco install dotnet-9.0-sdk dotnet-9.0-windowshosting -y
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart
```

#### Step 3: Deploy Database
```powershell
# Deploy database schema and data
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -InputFile "database-schema.sql"
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLPassword -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800
```

#### Step 4: Build and Deploy Application
```powershell
# Build application
cd LoanApplication
dotnet clean
dotnet restore
dotnet build --configuration Release
dotnet publish --configuration Release --output "..\deployment\publish-final" --self-contained false

# Deploy to IIS
iisreset /stop
Copy-Item -Path "..\deployment\publish-final\*" -Destination "C:\inetpub\wwwroot\LoanApplication\" -Recurse -Force

# Configure connection string
$appSettings = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLPassword;Encrypt=false;TrustServerCertificate=true;"
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

Set-Content -Path "C:\inetpub\wwwroot\LoanApplication\appsettings.Production.json" -Value $appSettings
```

#### Step 5: Configure IIS
```powershell
# Start IIS and configure website
iisreset /start
Import-Module WebAdministration

# Configure Default Web Site
Set-ItemProperty -Path "IIS:\Sites\Default Web Site" -Name physicalPath -Value "C:\inetpub\wwwroot\LoanApplication"
Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value ""
Start-Website -Name "Default Web Site"
```

### Verification

#### Test Database Connection
```powershell
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -Query "SELECT COUNT(*) FROM Applications"
```

#### Test Web Application
```
Open browser: http://localhost
Expected: Loan Application System homepage with database statistics
```

#### Test API Endpoints
```
http://localhost/api/applications/count
http://localhost/api/customers/count
http://localhost/api/applications
```

### Key Fixes Applied

1. **Correct SQL Password**: `WorkshopDB123!` (not `YourPassword123!`)
2. **Connection String Format**: Added `Encrypt=false;TrustServerCertificate=true;`
3. **IIS Configuration**: Uses `DefaultAppPool` with proper .NET 9 settings
4. **File Deployment**: Stops IIS before copying files to avoid locks
5. **Controllers**: Properly included in build and deployment
6. **Views**: MVC views properly deployed for home page

### Workshop Environment Ready

After successful deployment:
- ✅ SQL Server 2022 Web Edition configured
- ✅ Database with 149K+ integration logs, 9K+ applications
- ✅ .NET 9.0 application running on IIS
- ✅ API endpoints functional
- ✅ Ready for 3-phase migration workshop

### Troubleshooting

#### Common Issues
- **500 Error**: Check connection string format
- **404 Error**: Verify controllers are deployed
- **503 Error**: Check application pool status
- **File Lock Error**: Stop IIS before copying files

#### Log Locations
- Application logs: `C:\inetpub\wwwroot\LoanApplication\logs\`
- IIS logs: `C:\inetpub\logs\LogFiles\W3SVC1\`
- Deployment log: `C:\Workshop\complete-deployment-*.log`