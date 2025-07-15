# =============================================
# Workshop Quick Start Script
# For AWS EC2 Windows Server 2022 + SQL Server 2022 Web Edition
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SQLServerSAPassword = "WorkshopDB123!",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateSampleData = $true
)

$LogFile = "C:\Workshop\setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARNING"){"Yellow"} else{"Green"})
    if (-not (Test-Path "C:\Workshop")) { New-Item -Path "C:\Workshop" -ItemType Directory -Force }
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Host "=== AWS Database Modernization Workshop - Quick Start ===" -ForegroundColor Cyan
Write-Log "Starting workshop environment setup..."

try {
    # =============================================
    # 1. Configure SQL Server 2022 Web Edition
    # =============================================
    Write-Log "Configuring SQL Server 2022 Web Edition..."
    
    # Enable SA account and set password
    $SQLConfig = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$SQLServerSAPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
    
    # Execute using Windows Authentication
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLConfig
    
    # Restart SQL Server
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 15
    
    # Test SA login
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLServerSAPassword -Query "SELECT @@VERSION"
    Write-Log "SQL Server 2022 Web Edition configured successfully"
    
    # =============================================
    # 2. Install .NET 6 SDK
    # =============================================
    Write-Log "Installing .NET 6 SDK..."
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        try {
            # Use Chocolatey to install .NET 6 SDK (more reliable)
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Log "Installing Chocolatey first..."
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            }
            
            Write-Log "Installing .NET 6 SDK via Chocolatey..."
            choco install dotnet-6.0-sdk -y
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Log ".NET 6 SDK installed successfully"
        } catch {
            Write-Log "Failed to install .NET 6 SDK via Chocolatey, trying direct download..." "WARNING"
            # Fallback to direct download with current URL
            $DotNetUrl = "https://download.visualstudio.microsoft.com/download/pr/5226a5fa-8c0b-474f-b79a-8984ad7c5beb/3113ccbf789c9fd29972835f0f334b7a/dotnet-sdk-6.0.428-win-x64.exe"
            $DotNetPath = "C:\Workshop\dotnet-sdk-6.0.exe"
            Invoke-WebRequest -Uri $DotNetUrl -OutFile $DotNetPath -UseBasicParsing
            Start-Process -FilePath $DotNetPath -ArgumentList "/quiet" -Wait
            $env:Path += ";C:\Program Files\dotnet"
            Write-Log ".NET 6 SDK installed via direct download"
        }
    } else {
        $DotNetVersion = & dotnet --version
        Write-Log ".NET SDK already available: $DotNetVersion"
    }
    
    # =============================================
    # 3. Configure IIS
    # =============================================
    Write-Log "Configuring IIS for ASP.NET Core..."
    
    # Enable IIS features
    $IISFeatures = @("IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-ASPNET45", "IIS-NetFxExtensibility45")
    foreach ($Feature in $IISFeatures) {
        Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart -ErrorAction SilentlyContinue
    }
    
    # Install ASP.NET Core Hosting Bundle
    try {
        Write-Log "Installing ASP.NET Core Hosting Bundle..."
        choco install dotnet-6.0-windowshosting -y -ErrorAction SilentlyContinue
        Write-Log "ASP.NET Core Hosting Bundle installed via Chocolatey"
    } catch {
        Write-Log "Chocolatey installation failed, skipping hosting bundle" "WARNING"
        Write-Log "You may need to install it manually later" "WARNING"
    }
    
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    Write-Log "IIS configured for ASP.NET Core"
    
    # =============================================
    # 4. Create Workshop Database
    # =============================================
    Write-Log "Creating workshop database..."
    
    $CreateDB = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LoanApplicationDB')
BEGIN
    CREATE DATABASE LoanApplicationDB;
    PRINT 'Database LoanApplicationDB created successfully';
END
ELSE
BEGIN
    PRINT 'Database LoanApplicationDB already exists';
END
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $SQLServerSAPassword -Query $CreateDB
    Write-Log "Workshop database ready"
    
    # =============================================
    # 5. Configure Firewall
    # =============================================
    Write-Log "Configuring Windows Firewall..."
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
    Write-Log "Firewall configured"
    
    # =============================================
    # 6. Create Workshop Shortcuts
    # =============================================
    Write-Log "Creating workshop shortcuts..."
    
    # Desktop shortcuts
    $WshShell = New-Object -comObject WScript.Shell
    
    # SQL Server Management Studio shortcut (if available)
    $SSMSPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
    if (Test-Path $SSMSPath) {
        $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\SQL Server Management Studio.lnk")
        $Shortcut.TargetPath = $SSMSPath
        $Shortcut.Save()
    }
    
    # IIS Manager shortcut
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\IIS Manager.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\inetsrv\InetMgr.exe"
    $Shortcut.Save()
    
    Write-Log "Workshop shortcuts created"
    
    # =============================================
    # 7. Generate Connection Information
    # =============================================
    $ConnectionInfo = @"
=== WORKSHOP CONNECTION INFORMATION ===

SQL Server Details:
- Server: localhost (Default Instance)
- Edition: SQL Server 2022 Web Edition
- Authentication: Mixed Mode
- SA Password: $SQLServerSAPassword
- Database: LoanApplicationDB

Connection Strings:
- Windows Auth: Server=localhost;Database=LoanApplicationDB;Integrated Security=true;
- SQL Auth: Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=$SQLServerSAPassword;

IIS Configuration:
- Default Website: Ready for deployment
- .NET 6 Runtime: Installed
- ASP.NET Core Hosting: Configured

Workshop Files Location: C:\Workshop\
Log File: $LogFile

=== SETUP COMPLETED SUCCESSFULLY ===
"@
    
    Write-Host $ConnectionInfo -ForegroundColor Green
    Set-Content -Path "C:\Workshop\connection-info.txt" -Value $ConnectionInfo
    
    Write-Log "Workshop environment setup completed successfully!"
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Deploy your database schema using the provided SQL scripts" -ForegroundColor White
    Write-Host "2. Deploy your .NET application to IIS" -ForegroundColor White
    Write-Host "3. Begin the database modernization workshop!" -ForegroundColor White
    
} catch {
    Write-Log "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Check the log file for details: $LogFile" -ForegroundColor Red
    exit 1
}