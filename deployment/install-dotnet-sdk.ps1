# =============================================
# Install .NET 6 SDK on Windows Server
# =============================================

Write-Host "Installing .NET 6 SDK..." -ForegroundColor Yellow

try {
    # Method 1: Direct download (most reliable)
    $DotNetUrl = "https://download.visualstudio.microsoft.com/download/pr/5226a5fa-8c0b-474f-b79a-8984ad7c5beb/3113ccbf789c9fd29972835f0f334b7a/dotnet-sdk-6.0.428-win-x64.exe"
    $DotNetPath = "C:\Temp\dotnet-sdk-6.0.exe"
    
    # Create temp directory
    New-Item -Path "C:\Temp" -ItemType Directory -Force -ErrorAction SilentlyContinue
    
    Write-Host "Downloading .NET 6 SDK..."
    Invoke-WebRequest -Uri $DotNetUrl -OutFile $DotNetPath -UseBasicParsing
    
    Write-Host "Installing .NET 6 SDK (this may take a few minutes)..."
    Start-Process -FilePath $DotNetPath -ArgumentList "/quiet" -Wait
    
    # Update PATH for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Verify installation
    Start-Sleep -Seconds 5
    $DotNetVersion = & dotnet --version 2>$null
    
    if ($DotNetVersion) {
        Write-Host "✅ .NET 6 SDK installed successfully: $DotNetVersion" -ForegroundColor Green
        Write-Host "You may need to restart PowerShell or refresh PATH" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Installation completed but dotnet command not found in PATH" -ForegroundColor Yellow
        Write-Host "Please restart PowerShell and try again" -ForegroundColor Yellow
    }
    
    # Clean up
    Remove-Item -Path $DotNetPath -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "❌ Failed to install .NET SDK: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please download manually from: https://dotnet.microsoft.com/download/dotnet/6.0" -ForegroundColor Yellow
}