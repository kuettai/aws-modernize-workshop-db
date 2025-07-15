# =============================================
# Install .NET 9.0 SDK on Windows Server
# Updated for current LTS version
# =============================================

Write-Host "Installing .NET 9.0 SDK..." -ForegroundColor Yellow

try {
    # Use the official .NET install script (most reliable method)
    Write-Host "Downloading .NET install script..."
    
    # Download the official install script
    $InstallScript = "C:\Temp\dotnet-install.ps1"
    New-Item -Path "C:\Temp" -ItemType Directory -Force -ErrorAction SilentlyContinue
    
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $InstallScript -UseBasicParsing
    
    Write-Host "Installing .NET 9.0 SDK..."
    
    # Install .NET 9.0 SDK
    & $InstallScript -Channel 9.0 -InstallDir "C:\Program Files\dotnet" -Architecture x64
    
    # Update PATH for current session
    $env:Path = "C:\Program Files\dotnet;" + $env:Path
    
    # Update system PATH permanently
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($CurrentPath -notlike "*C:\Program Files\dotnet*") {
        [Environment]::SetEnvironmentVariable("Path", "C:\Program Files\dotnet;" + $CurrentPath, "Machine")
    }
    
    # Verify installation
    Start-Sleep -Seconds 3
    $DotNetVersion = & dotnet --version 2>$null
    
    if ($DotNetVersion) {
        Write-Host "✅ .NET 9.0 SDK installed successfully: $DotNetVersion" -ForegroundColor Green
        
        # Show installed SDKs
        Write-Host "Installed .NET SDKs:" -ForegroundColor Cyan
        & dotnet --list-sdks
        
        Write-Host "Installation completed successfully!" -ForegroundColor Green
    } else {
        throw "dotnet command not found after installation"
    }
    
    # Clean up
    Remove-Item -Path $InstallScript -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "❌ Failed to install .NET 9.0 SDK: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Alternative installation methods:" -ForegroundColor Yellow
    Write-Host "1. Download manually from: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor White
    Write-Host "2. Use Chocolatey: choco install dotnet-9.0-sdk" -ForegroundColor White
    Write-Host "3. Use winget: winget install Microsoft.DotNet.SDK.9" -ForegroundColor White
}