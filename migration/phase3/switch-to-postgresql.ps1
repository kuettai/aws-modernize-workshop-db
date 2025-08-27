# Switch Phase 3 Application from MSSQL to PostgreSQL
param(
    [string]$PostgreSQLPassword = "WorkshopDB123!",
    [string]$PostgreSQLHost = "localhost",
    [string]$PostgreSQLPort = "5432",
    [string]$DatabaseName = "LoanApplicationDB"
)

Write-Host "🔄 Switching Phase 3 Application to PostgreSQL" -ForegroundColor Cyan

try {
    # 1. Update appsettings.json with PostgreSQL connection
    Write-Host "Step 1: Updating appsettings.json..." -ForegroundColor Yellow
    
    $appSettingsPath = "LoanApplication\appsettings.json"
    
    if (Test-Path $appSettingsPath) {
        $appSettings = Get-Content $appSettingsPath | ConvertFrom-Json
        
        # Update connection string to PostgreSQL
        $pgConnectionString = "Host=$PostgreSQLHost;Database=$DatabaseName;Username=postgres;Password=$PostgreSQLPassword;Port=$PostgreSQLPort"
        $appSettings.ConnectionStrings.DefaultConnection = $pgConnectionString
        
        # Ensure DynamoDB settings exist
        if (-not $appSettings.PaymentSettings) {
            $appSettings | Add-Member -Type NoteProperty -Name "PaymentSettings" -Value @{
                EnableDynamoDBWrites = $true
                ReadFromDynamoDB = $false
            }
        }
        
        if (-not $appSettings.AWS) {
            $appSettings | Add-Member -Type NoteProperty -Name "AWS" -Value @{
                Region = "ap-southeast-1"
                DynamoDB = @{
                    TableName = "LoanApp-IntegrationLogs-dev"
                    PaymentsTableName = "LoanApp-Payments-dev"
                }
            }
        }
        
        $appSettings | ConvertTo-Json -Depth 10 | Set-Content $appSettingsPath
        Write-Host "  ✅ Updated appsettings.json with PostgreSQL connection" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  appsettings.json not found, creating new one..." -ForegroundColor Yellow
        
        $newAppSettings = @{
            ConnectionStrings = @{
                DefaultConnection = "Host=$PostgreSQLHost;Database=$DatabaseName;Username=postgres;Password=$PostgreSQLPassword;Port=$PostgreSQLPort"
            }
            PaymentSettings = @{
                EnableDynamoDBWrites = $true
                ReadFromDynamoDB = $false
            }
            AWS = @{
                Region = "ap-southeast-1"
                DynamoDB = @{
                    TableName = "LoanApp-IntegrationLogs-dev"
                    PaymentsTableName = "LoanApp-Payments-dev"
                }
            }
            Logging = @{
                LogLevel = @{
                    Default = "Information"
                    "Microsoft.AspNetCore" = "Warning"
                }
            }
            AllowedHosts = "*"
        }
        
        $newAppSettings | ConvertTo-Json -Depth 10 | Set-Content $appSettingsPath
        Write-Host "  ✅ Created new appsettings.json with PostgreSQL" -ForegroundColor Green
    }
    
    # 2. Update project file to use PostgreSQL packages
    Write-Host "Step 2: Updating project packages..." -ForegroundColor Yellow
    
    $projectPath = "LoanApplication\LoanApplication.csproj"
    
    if (Test-Path $projectPath) {
        # Add PostgreSQL package if not exists
        cd LoanApplication
        
        # Remove SQL Server packages and add PostgreSQL
        dotnet remove package Microsoft.EntityFrameworkCore.SqlServer -ErrorAction SilentlyContinue
        dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.0.0
        dotnet add package AWSSDK.DynamoDBv2 --version 3.7.300
        dotnet add package AWSSDK.Extensions.NETCore.Setup --version 3.7.300
        
        cd ..
        Write-Host "  ✅ Updated NuGet packages for PostgreSQL and DynamoDB" -ForegroundColor Green
    }
    
    # 3. Test PostgreSQL connection
    Write-Host "Step 3: Testing PostgreSQL connection..." -ForegroundColor Yellow
    
    try {
        # Simple connection test using .NET
        $testScript = @"
using Npgsql;
using System;

try {
    var connectionString = "Host=$PostgreSQLHost;Database=$DatabaseName;Username=postgres;Password=$PostgreSQLPassword;Port=$PostgreSQLPort";
    using var connection = new NpgsqlConnection(connectionString);
    connection.Open();
    
    using var command = new NpgsqlCommand("SELECT version()", connection);
    var version = command.ExecuteScalar();
    
    Console.WriteLine("PostgreSQL Connection Successful!");
    Console.WriteLine("Version: " + version);
} catch (Exception ex) {
    Console.WriteLine("Connection Failed: " + ex.Message);
    Environment.Exit(1);
}
"@
        
        $testScript | Out-File -FilePath "test-pg-connection.cs" -Encoding UTF8
        
        # Try to compile and run the test (requires .NET SDK)
        if (Get-Command dotnet -ErrorAction SilentlyContinue) {
            Write-Host "  🧪 Running PostgreSQL connection test..." -ForegroundColor Cyan
            
            # Create a simple test project
            dotnet new console -n PgTest -o temp_pg_test --force
            cd temp_pg_test
            dotnet add package Npgsql --version 8.0.0
            
            $testScript | Out-File -FilePath "Program.cs" -Encoding UTF8
            
            $testResult = dotnet run 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ PostgreSQL connection test passed" -ForegroundColor Green
                Write-Host "  $testResult" -ForegroundColor Gray
            } else {
                Write-Host "  ❌ PostgreSQL connection test failed" -ForegroundColor Red
                Write-Host "  $testResult" -ForegroundColor Red
                Write-Host "  Please ensure PostgreSQL is running and credentials are correct" -ForegroundColor Yellow
            }
            
            cd ..
            Remove-Item -Path "temp_pg_test" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "  ⚠️  .NET SDK not found, skipping connection test" -ForegroundColor Yellow
        }
        
        Remove-Item -Path "test-pg-connection.cs" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "  ⚠️  Could not test PostgreSQL connection: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # 4. Display next steps
    Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Ensure PostgreSQL is running on $PostgreSQLHost`:$PostgreSQLPort" -ForegroundColor White
    Write-Host "2. Ensure database '$DatabaseName' exists with Phase 2 schema and data" -ForegroundColor White
    Write-Host "3. Run: cd LoanApplication && dotnet build" -ForegroundColor White
    Write-Host "4. Run: cd LoanApplication && dotnet run" -ForegroundColor White
    Write-Host "5. Test endpoints to verify PostgreSQL + DynamoDB hybrid setup" -ForegroundColor White
    
    Write-Host "`n✅ Phase 3 application configured for PostgreSQL + DynamoDB hybrid architecture" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error during PostgreSQL switch: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}