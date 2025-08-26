# =============================================
# PowerShell Execution Policy Setup Only
# Use this ONLY if you need to enable PowerShell execution policy manually
# =============================================

Write-Host "=== PowerShell Execution Policy Setup ===" -ForegroundColor Cyan
Write-Host "This script only sets PowerShell execution policy" -ForegroundColor Yellow
Write-Host "For complete setup, use: fresh-ec2-deployment.ps1" -ForegroundColor Yellow

try {
    # =============================================
    # Enable PowerShell Execution Policy
    # =============================================
    Write-Host "Configuring PowerShell execution policy..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Write-Host "✅ PowerShell execution policy configured" -ForegroundColor Green

    $Summary = @"

=== EXECUTION POLICY CONFIGURED ===

✅ PowerShell execution policy set to RemoteSigned

NEXT STEP:
Run the complete deployment script:
.\deployment\simple-deployment.ps1 -SQLPassword "WorkshopDB123!"

This will handle all prerequisites, database, and application deployment.

"@

    Write-Host $Summary -ForegroundColor Cyan

} catch {
    Write-Host "❌ PowerShell policy setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
    exit 1
}