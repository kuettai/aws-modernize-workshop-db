# =============================================
# Configure SQL Server SA Password on AWS EC2 AMI
# For Windows Server 2022 + SQL Server 2022 Web Edition
# =============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$NewSAPassword
)

Write-Host "Configuring SQL Server SA password..." -ForegroundColor Yellow

try {
    # Step 1: Enable SA account and set password using Windows Authentication
    Write-Host "Step 1: Enabling SA account and setting password..."
    
    $SQLCommands = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$NewSAPassword';
PRINT 'SA account enabled and password set successfully';
"@
    
    # Execute using Windows Authentication (Administrator account)
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $SQLCommands
    
    # Step 2: Enable Mixed Authentication Mode
    Write-Host "Step 2: Enabling mixed authentication mode..."
    
    $AuthCommand = @"
EXEC xp_instance_regwrite 
    N'HKEY_LOCAL_MACHINE', 
    N'Software\Microsoft\MSSQLServer\MSSQLServer', 
    N'LoginMode', 
    REG_DWORD, 
    2;
PRINT 'Mixed authentication mode enabled';
"@
    
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $AuthCommand
    
    # Step 3: Restart SQL Server service to apply changes
    Write-Host "Step 3: Restarting SQL Server service..."
    Restart-Service -Name "MSSQLSERVER" -Force
    Start-Sleep -Seconds 10
    
    # Step 4: Test the new SA login
    Write-Host "Step 4: Testing SA login..."
    $TestQuery = "SELECT 'SA Login Successful' as Result, @@VERSION as SQLVersion;"
    $TestResult = Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password $NewSAPassword -Query $TestQuery
    
    Write-Host "✅ SQL Server SA password configured successfully!" -ForegroundColor Green
    Write-Host "SA Password: $NewSAPassword" -ForegroundColor Green
    Write-Host "Connection String: Server=localhost;User Id=sa;Password=$NewSAPassword;" -ForegroundColor Cyan
    
    # Save connection info to file
    $ConnectionInfo = @"
SQL Server Configuration Complete
================================
Server: localhost
Instance: Default (MSSQLSERVER)
Edition: SQL Server 2022 Web Edition
Authentication: Mixed Mode
SA Password: $NewSAPassword

Connection Strings:
- Windows Auth: Server=localhost;Integrated Security=true;
- SQL Auth: Server=localhost;User Id=sa;Password=$NewSAPassword;

Configuration Date: $(Get-Date)
"@
    
    Set-Content -Path "C:\sql-config.txt" -Value $ConnectionInfo
    Write-Host "Connection information saved to: C:\sql-config.txt" -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Error configuring SQL Server: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Trying alternative method..." -ForegroundColor Yellow
    
    # Alternative method using sqlcmd.exe directly
    try {
        $TempSQLFile = "C:\temp-sql-config.sql"
        $SQLContent = @"
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = '$NewSAPassword';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
"@
        Set-Content -Path $TempSQLFile -Value $SQLContent
        
        # Execute using sqlcmd.exe with Windows Authentication
        & sqlcmd -S localhost -E -i $TempSQLFile
        
        # Restart SQL Server
        Restart-Service -Name "MSSQLSERVER" -Force
        Start-Sleep -Seconds 10
        
        # Test connection
        & sqlcmd -S localhost -U sa -P $NewSAPassword -Q "SELECT 'Success' as Result"
        
        Remove-Item -Path $TempSQLFile -Force
        Write-Host "✅ SQL Server configured using alternative method!" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to configure SQL Server: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}