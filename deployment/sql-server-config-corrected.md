# SQL Server Configuration - Corrected Commands

## Method 2: Manual Configuration (Corrected)
```powershell
# 1. Open PowerShell as Administrator
# 2. Run these commands one by one:

# Enable SA account and set password
Invoke-Sqlcmd -ServerInstance "localhost" -Query "ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD = 'YourPassword123!';"

# Enable mixed authentication
Invoke-Sqlcmd -ServerInstance "localhost" -Query "EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;"

# Restart SQL Server
Restart-Service -Name "MSSQLSERVER" -Force

# Test connection
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "YourPassword123!" -Query "SELECT @@VERSION"
```

## Corrected Connection Strings
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=YourPassword123!;"
  }
}
```

## For Application Deployment
```powershell
# Deploy with corrected connection string
.\deploy-application.ps1 -Environment Production -ConnectionString "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=YourPassword123!;"
```

## Key Points
- Remove `-TrustServerCertificate` parameter for local connections on the AMI
- Use simple connection strings without certificate trust settings
- The AMI's SQL Server is pre-configured for local connections without SSL requirements