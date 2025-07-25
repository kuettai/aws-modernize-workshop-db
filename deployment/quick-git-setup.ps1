# =============================================
# Quick Git Setup for Fresh EC2
# Install Git and clone repository
# =============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$GitRepo
)

Write-Host "=== Installing Git and Cloning Repository ===" -ForegroundColor Cyan

try {
    # Create directories
    New-Item -Path "C:\Workshop" -ItemType Directory -Force
    New-Item -Path "C:\Temp" -ItemType Directory -Force
    
    # Install Chocolatey if not available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Install Git
    Write-Host "Installing Git..." -ForegroundColor Yellow
    choco install git -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Verify Git installation
    git --version
    Write-Host "✅ Git installed successfully" -ForegroundColor Green
    
    # Clone repository
    Write-Host "Cloning repository..." -ForegroundColor Yellow
    cd C:\Workshop
    git clone $GitRepo .
    
    Write-Host "✅ Repository cloned to C:\Workshop" -ForegroundColor Green
    Write-Host "Files in workshop directory:" -ForegroundColor Cyan
    Get-ChildItem C:\Workshop | Select-Object Name, Mode
    
    Write-Host "`nNext step: Run the main deployment script" -ForegroundColor Yellow
    Write-Host ".\deployment\fresh-ec2-deployment.ps1 -SQLPassword 'WorkshopDB123!'" -ForegroundColor White
    
} catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}