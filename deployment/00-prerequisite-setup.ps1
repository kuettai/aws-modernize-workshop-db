# =============================================
# Prerequisite Setup for Fresh EC2 Instance
# Run this FIRST on a fresh Windows Server 2022 + SQL Server 2022
# =============================================

Write-Host "=== AWS Database Modernization Workshop - Prerequisite Setup ===" -ForegroundColor Cyan
Write-Host "This script prepares a fresh EC2 instance for workshop deployment" -ForegroundColor Yellow

try {
    # =============================================
    # 1. Enable PowerShell Execution Policy
    # =============================================
    Write-Host "Step 1: Configuring PowerShell..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Write-Host "✅ PowerShell execution policy configured" -ForegroundColor Green

    # =============================================
    # 2. Install Chocolatey Package Manager
    # =============================================
    Write-Host "Step 2: Installing Chocolatey..." -ForegroundColor Yellow
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "✅ Chocolatey installed" -ForegroundColor Green
    } else {
        Write-Host "✅ Chocolatey already installed" -ForegroundColor Green
    }

    # =============================================
    # 3. Install Git
    # =============================================
    Write-Host "Step 3: Installing Git..." -ForegroundColor Yellow
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        choco install git -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "✅ Git installed" -ForegroundColor Green
    } else {
        Write-Host "✅ Git already installed" -ForegroundColor Green
    }

    # =============================================
    # 4. Create Workshop Directory
    # =============================================
    Write-Host "Step 4: Creating workshop directory..." -ForegroundColor Yellow
    
    New-Item -Path "C:\Workshop" -ItemType Directory -Force
    Set-Location "C:\Workshop"
    Write-Host "✅ Workshop directory created: C:\Workshop" -ForegroundColor Green

    # =============================================
    # 5. Configure SQL Server (Basic)
    # =============================================
    Write-Host "Step 5: Configuring SQL Server..." -ForegroundColor Yellow
    
    try {
        # Enable SA login and mixed mode authentication
        $SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = 'WorkshopDB123!';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
        
        Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig -ErrorAction Stop
        
        # Restart SQL Server service
        Restart-Service -Name "MSSQLSERVER" -Force
        Start-Sleep -Seconds 10
        
        # Test SA connection
        Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Query "SELECT @@VERSION" -QueryTimeout 10
        Write-Host "✅ SQL Server configured with SA authentication" -ForegroundColor Green
        
    } catch {
        Write-Host "⚠️ SQL Server configuration may need manual setup" -ForegroundColor Yellow
        Write-Host "Manual steps: Enable SA login, set password to 'WorkshopDB123!', enable mixed mode" -ForegroundColor Yellow
    }

    # =============================================
    # 6. Summary and Next Steps
    # =============================================
    $Summary = @"

=== PREREQUISITE SETUP COMPLETED ===

✅ PowerShell execution policy configured
✅ Chocolatey package manager installed
✅ Git installed and ready
✅ Workshop directory created: C:\Workshop
✅ SQL Server basic configuration attempted

NEXT STEPS:
1. Clone your workshop repository:
   git clone https://github.com/yourusername/your-repo.git .

2. Run the main deployment script:
   .\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"

CURRENT LOCATION: C:\Workshop
Ready for workshop deployment!

"@

    Write-Host $Summary -ForegroundColor Cyan
    
    # Save summary to file
    Set-Content -Path "C:\Workshop\prerequisite-setup-complete.txt" -Value $Summary
    
    Write-Host "Prerequisites setup completed successfully!" -ForegroundColor Green
    Write-Host "You can now clone your repository and run the deployment scripts." -ForegroundColor Green

} catch {
    Write-Host "❌ Prerequisite setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
    exit 1
}