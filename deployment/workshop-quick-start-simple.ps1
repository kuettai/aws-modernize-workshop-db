# =============================================
# Workshop Quick Start Script - Simplified Version
# For AWS EC2 Windows Server 2022 + SQL Server 2022 Web Edition
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SQLServerSAPassword = "WorkshopDB123!"
)

Write-Host "=== AWS Database Modernization Workshop - Quick Start ===" -ForegroundColor Cyan

try {
    # =============================================
    # 1. Configure SQL Server 2022 Web Edition
    # =============================================
    Write-Host "Step 1: Configuring SQL Server..." -ForegroundColor Yellow
    
    # Enable SA account and set password
    $SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLServerSAPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig
    
    # Restart SQL Server
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 10
    
    # Test SA login
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLServerSAPassword -Query "SELECT 'Success' as Result"
    Write-Host "✅ SQL Server configured successfully!" -ForegroundColor Green
    
    # =============================================
    # 2. Check .NET Installation
    # =============================================
    Write-Host "Step 2: Checking .NET installation..." -ForegroundColor Yellow
    
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $DotNetVersion = & dotnet --version
        Write-Host "✅ .NET SDK found: $DotNetVersion" -ForegroundColor Green
    } else {
        Write-Host "⚠️  .NET SDK not found. Please install manually:" -ForegroundColor Yellow
        Write-Host "   Download from: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor White
        Write-Host "   Or run: .\deployment\install-dotnet9-sdk.ps1" -ForegroundColor White
    }
    
    # =============================================
    # 3. Configure IIS (Basic)
    # =============================================
    Write-Host "Step 3: Configuring IIS..." -ForegroundColor Yellow
    
    # Enable basic IIS features
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart -ErrorAction SilentlyContinue
    
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    Write-Host "✅ IIS basic configuration completed" -ForegroundColor Green
    
    # =============================================
    # 4. Create Workshop Database
    # =============================================
    Write-Host "Step 4: Creating workshop database..." -ForegroundColor Yellow
    
    $CreateDB = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LoanApplicationDB')
BEGIN
    CREATE DATABASE LoanApplicationDB;
    PRINT 'Database created successfully';
END
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLServerSAPassword -Query $CreateDB
    Write-Host "✅ Workshop database ready" -ForegroundColor Green
    
    # =============================================
    # 5. Configure Firewall
    # =============================================
    Write-Host "Step 5: Configuring firewall..." -ForegroundColor Yellow
    
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
    Write-Host "✅ Firewall configured" -ForegroundColor Green
    
    # =============================================
    # 6. Display Results
    # =============================================
    $Results = @"

=== WORKSHOP SETUP COMPLETED ===

SQL Server Configuration:
✅ Server: localhost
✅ Edition: SQL Server 2022 Web Edition  
✅ SA Password: $SQLServerSAPassword
✅ Database: LoanApplicationDB created

Connection String:
Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLServerSAPassword;

Next Steps:
1. Deploy your database schema
2. Deploy your .NET application
3. Start the workshop!

"@
    
    Write-Host $Results -ForegroundColor Green
    
    # Save connection info
    New-Item -Path "C:\Workshop" -ItemType Directory -Force -ErrorAction SilentlyContinue
    Set-Content -Path "C:\Workshop\connection-info.txt" -Value $Results
    
} catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check the error and try again" -ForegroundColor Yellow
    exit 1
}