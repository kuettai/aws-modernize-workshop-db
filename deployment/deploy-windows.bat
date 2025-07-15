@echo off
REM =============================================
REM Windows Batch Script for Loan Application Deployment
REM Simple wrapper for PowerShell deployment script
REM =============================================

echo Starting Loan Application Deployment...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not available
    echo Please install PowerShell or run the deployment manually
    pause
    exit /b 1
)

REM Set execution policy for current session
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"

REM Check command line arguments and run appropriate deployment
if "%1"=="" (
    echo Running with default settings...
    powershell -File "%~dp0deploy-application.ps1"
) else if "%1"=="help" (
    powershell -File "%~dp0deploy-application.ps1" -Help
) else if "%1"=="prod" (
    echo Deploying to Production environment...
    powershell -File "%~dp0deploy-application.ps1" -Environment Production -Port 80
) else if "%1"=="dev" (
    echo Deploying to Development environment...
    powershell -File "%~dp0deploy-application.ps1" -Environment Development -SkipTests
) else (
    echo Running with custom parameters: %*
    powershell -File "%~dp0deploy-application.ps1" %*
)

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Deployment failed. Check the log file for details.
    pause
    exit /b 1
)

echo.
echo Deployment completed successfully!
echo Check the deployment log for detailed information.
pause