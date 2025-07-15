# AWS EC2 Windows Server Deployment Guide
## Complete Setup for Loan Application System

This guide provides step-by-step instructions for deploying the Loan Application System on AWS EC2 Windows Server with SQL Server.

## Prerequisites

### AWS Requirements
- AWS Account with EC2 access
- Key Pair for RDP access
- Security Group configured for web and database traffic

### Local Requirements
- RDP client for Windows connection
- Application deployment package

## Step-by-Step Deployment

### 1. Launch AWS EC2 Windows Instance

#### EC2 Instance Configuration
```
Instance Type: t3.medium or larger (minimum 4GB RAM)
AMI: Windows Server 2019/2022 Base
Storage: 30GB+ EBS volume
Security Group: Allow RDP (3389), HTTP (80), HTTPS (443), SQL Server (1433)
Key Pair: Your existing key pair for RDP access
```

#### Security Group Rules
```
Type        Protocol    Port Range    Source
RDP         TCP         3389          Your IP/0.0.0.0/0
HTTP        TCP         80            0.0.0.0/0
HTTPS       TCP         443           0.0.0.0/0
SQL Server  TCP         1433          Your IP/VPC CIDR
Custom      TCP         8080          0.0.0.0/0 (if using custom port)
```

### 2. Connect to EC2 Instance

#### Get Windows Password
1. Select your EC2 instance in AWS Console
2. Click "Connect" → "RDP client"
3. Click "Get password"
4. Upload your private key file (.pem)
5. Click "Decrypt password"

#### RDP Connection
```
Server: [EC2-PUBLIC-IP]
Username: Administrator
Password: [Decrypted password from AWS]
```

### 3. Run Automated Setup Script

#### Copy Setup Script to Server
1. Copy `aws-ec2-windows-setup.ps1` to the EC2 instance
2. Place it in `C:\Temp\` directory

#### Execute Setup Script
```powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Run the complete setup
C:\Temp\aws-ec2-windows-setup.ps1

# Or with custom parameters
C:\Temp\aws-ec2-windows-setup.ps1 -SQLServerSAPassword "YourStrongPassword123!" -WebsitePort 80 -Environment Production
```

#### What the Script Does
- ✅ Installs Chocolatey package manager
- ✅ Installs .NET 6 SDK
- ✅ Installs and configures IIS with ASP.NET Core hosting
- ✅ Installs SQL Server Express
- ✅ Configures SQL Server for remote connections
- ✅ Sets up Windows Firewall rules
- ✅ Creates IIS application pool and website
- ✅ Generates helper deployment scripts

### 4. Deploy Database

#### Copy Database Scripts
Upload these files to `C:\Temp\`:
- `database-schema.sql`
- `stored-procedures-simple.sql`
- `stored-procedure-complex.sql`
- `sample-data-generation.sql` (optional)

#### Run Database Deployment
```powershell
# Deploy database schema and stored procedures
C:\Temp\deploy-database-ec2.ps1

# Deploy with sample data
C:\Temp\deploy-database-ec2.ps1 -GenerateSampleData
```

### 5. Deploy Application

#### Prepare Application Package
On your local machine:
```powershell
# Build and package the application
.\deploy-application.ps1 -Environment Production -SkipTests

# This creates a deployment package (ZIP file)
```

#### Upload and Deploy Application
1. Copy the deployment package to EC2: `C:\Temp\LoanApplication.zip`
2. Extract to `C:\Temp\LoanApplication\`
3. Run deployment script:

```powershell
# Deploy application to IIS
C:\Temp\deploy-application-ec2.ps1 -SourcePath "C:\Temp\LoanApplication" -TargetPath "C:\inetpub\wwwroot\LoanApplication"
```

### 6. Verify Deployment

#### Test Database Connection
```powershell
# Test SQL Server connection
sqlcmd -S localhost\SQLEXPRESS -U sa -P "YourPassword"
SELECT @@VERSION;
GO
```

#### Test Web Application
```
# Open browser and navigate to:
http://[EC2-PUBLIC-IP]
# or
http://[EC2-PUBLIC-IP]:8080
```

#### Check IIS Configuration
1. Open IIS Manager
2. Verify "LoanApplication" website is running
3. Check "LoanApplicationPool" application pool status

## Manual Configuration Steps (if needed)

### IIS Manual Setup
```powershell
# Install IIS features
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All

# Create Application Pool
New-WebAppPool -Name "LoanApplicationPool"
Set-ItemProperty -Path "IIS:\AppPools\LoanApplicationPool" -Name managedRuntimeVersion -Value ""

# Create Website
New-Website -Name "LoanApplication" -Port 80 -PhysicalPath "C:\inetpub\wwwroot\LoanApplication" -ApplicationPool "LoanApplicationPool"
```

### SQL Server Manual Setup
```powershell
# Download SQL Server Express
$url = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
Invoke-WebRequest -Uri $url -OutFile "C:\Temp\SQLEXPR_x64_ENU.exe"

# Install SQL Server Express
C:\Temp\SQLEXPR_x64_ENU.exe /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=SQLEXPRESS /SECURITYMODE=SQL /SAPWD="YourPassword" /IACCEPTSQLSERVERLICENSETERMS /QUIET
```

## Configuration Files

### Connection String
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=LoanApplicationDB;User Id=sa;Password=YourPassword;TrustServerCertificate=true;"
  }
}
```

### IIS web.config (Auto-generated)
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\LoanApplication.dll" stdoutLogEnabled="false" stdoutLogFile=".\logs\stdout" />
  </system.webServer>
</configuration>
```

## Troubleshooting

### Common Issues

#### Application Won't Start
```powershell
# Check IIS application pool status
Get-IISAppPool -Name "LoanApplicationPool"

# Check Windows Event Logs
Get-EventLog -LogName Application -Source "IIS*" -Newest 10

# Check application logs
Get-Content "C:\inetpub\wwwroot\LoanApplication\logs\*.log"
```

#### Database Connection Issues
```powershell
# Check SQL Server service status
Get-Service -Name "MSSQL$SQLEXPRESS"

# Test connection
sqlcmd -S localhost\SQLEXPRESS -U sa -P "YourPassword"

# Check SQL Server error logs
Get-Content "C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\Log\ERRORLOG"
```

#### Firewall Issues
```powershell
# Check firewall rules
Get-NetFirewallRule -DisplayName "*HTTP*" | Select-Object DisplayName, Enabled, Direction

# Add firewall rules if missing
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
```

### Performance Optimization

#### IIS Optimization
```powershell
# Configure application pool for production
Set-ItemProperty -Path "IIS:\AppPools\LoanApplicationPool" -Name processModel.idleTimeout -Value "00:00:00"
Set-ItemProperty -Path "IIS:\AppPools\LoanApplicationPool" -Name recycling.periodicRestart.time -Value "00:00:00"
```

#### SQL Server Optimization
```sql
-- Configure SQL Server memory
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 2048; -- 2GB
RECONFIGURE;
```

## Security Considerations

### Production Security Checklist
- [ ] Change default SQL Server SA password
- [ ] Configure SSL certificate for HTTPS
- [ ] Restrict SQL Server access to application only
- [ ] Enable Windows Updates
- [ ] Configure backup strategy
- [ ] Set up monitoring and logging
- [ ] Review security group rules
- [ ] Enable AWS CloudTrail logging

### Backup Strategy
```powershell
# Database backup script
sqlcmd -S localhost -U sa -P "YourPassword" -Q "BACKUP DATABASE LoanApplicationDB TO DISK = 'C:\Backup\LoanApplicationDB.bak'"

# Application backup
Copy-Item -Path "C:\inetpub\wwwroot\LoanApplication" -Destination "C:\Backup\Application" -Recurse
```

## Cost Optimization

### EC2 Instance Sizing
- **Development**: t3.small (2 vCPU, 2GB RAM)
- **Testing**: t3.medium (2 vCPU, 4GB RAM)
- **Production**: t3.large+ (2+ vCPU, 8+ GB RAM)

### Storage Optimization
- Use GP3 EBS volumes for better price/performance
- Enable EBS encryption
- Set up automated snapshots

This deployment guide provides a complete solution for running the Loan Application System on AWS EC2 Windows Server with SQL Server, suitable for workshop demonstrations and production deployments.