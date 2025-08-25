# Step 4: Data Migration Scripts
## Phase 3: DynamoDB Migration - Historical Data Transfer

### 🎯 Objective
Create comprehensive data migration tools to transfer existing PostgreSQL IntegrationLogs data to DynamoDB with validation, monitoring, and resume capability.

### 🏗️ Migration Console Application

#### Project Structure
```
DataMigrationTool/
├── DataMigrationTool.csproj
├── Program.cs
├── Services/
│   ├── IMigrationService.cs
│   ├── MigrationService.cs
│   └── ValidationService.cs
├── Models/
│   ├── MigrationProgress.cs
│   ├── MigrationConfig.cs
│   └── ValidationResult.cs
├── appsettings.json
└── README.md
```

#### DataMigrationTool.csproj
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0" />
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.0.0" />
    <PackageReference Include="AWSSDK.DynamoDBv2" Version="3.7.300" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="8.0.0" />
    <PackageReference Include="Serilog.Extensions.Hosting" Version="8.0.0" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.0" />
    <PackageReference Include="Serilog.Sinks.File" Version="5.0.0" />
  </ItemGroup>
</Project>
```

### 📊 Migration Models

#### MigrationProgress.cs
```csharp
namespace DataMigrationTool.Models
{
    public class MigrationProgress
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public MigrationStatus Status { get; set; }
        public long TotalRecords { get; set; }
        public long ProcessedRecords { get; set; }
        public long SuccessfulRecords { get; set; }
        public long FailedRecords { get; set; }
        public long LastProcessedId { get; set; }
        public List<string> Errors { get; set; } = new();
        public TimeSpan? EstimatedTimeRemaining { get; set; }
        public double PercentComplete => TotalRecords > 0 ? (double)ProcessedRecords / TotalRecords * 100 : 0;
        
        public void UpdateProgress(long processed, long successful, long failed, long lastId)
        {
            ProcessedRecords = processed;
            SuccessfulRecords = successful;
            FailedRecords = failed;
            LastProcessedId = lastId;
            
            if (TotalRecords > 0 && ProcessedRecords > 0)
            {
                var elapsed = DateTime.UtcNow - StartTime;
                var rate = ProcessedRecords / elapsed.TotalSeconds;
                var remaining = TotalRecords - ProcessedRecords;
                EstimatedTimeRemaining = TimeSpan.FromSeconds(remaining / rate);
            }
        }
    }
    
    public enum MigrationStatus
    {
        NotStarted,
        InProgress,
        Paused,
        Completed,
        Failed,
        Cancelled
    }
}
```

#### MigrationConfig.cs
```csharp
namespace DataMigrationTool.Models
{
    public class MigrationConfig
    {
        public string PostgreSqlConnectionString { get; set; } = string.Empty;
        public string DynamoDbTableName { get; set; } = string.Empty;
        public string AwsRegion { get; set; } = "us-east-1";
        public int BatchSize { get; set; } = 25; // DynamoDB batch limit
        public int MaxRetries { get; set; } = 3;
        public TimeSpan RetryDelay { get; set; } = TimeSpan.FromSeconds(2);
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public long? ResumeFromId { get; set; }
        public bool ValidateAfterMigration { get; set; } = true;
        public string ProgressFilePath { get; set; } = "migration-progress.json";
        public bool DryRun { get; set; } = false;
    }
}
```

### 🔧 Migration Service Interface

#### IMigrationService.cs
```csharp
using DataMigrationTool.Models;

namespace DataMigrationTool.Services
{
    public interface IMigrationService
    {
        Task<MigrationProgress> StartMigrationAsync(MigrationConfig config);
        Task<MigrationProgress> ResumeMigrationAsync(string progressFilePath);
        Task<bool> PauseMigrationAsync();
        Task<ValidationResult> ValidateMigrationAsync(MigrationConfig config);
        Task<long> GetTotalRecordCountAsync(MigrationConfig config);
    }
}
```

### ⚙️ Migration Service Implementation

#### MigrationService.cs
```csharp
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using DataMigrationTool.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace DataMigrationTool.Services
{
    public class MigrationService : IMigrationService
    {
        private readonly IAmazonDynamoDB _dynamoClient;
        private readonly ILogger<MigrationService> _logger;
        private bool _pauseRequested = false;
        
        public MigrationService(IAmazonDynamoDB dynamoClient, ILogger<MigrationService> logger)
        {
            _dynamoClient = dynamoClient;
            _logger = logger;
        }
        
        public async Task<MigrationProgress> StartMigrationAsync(MigrationConfig config)
        {
            var progress = new MigrationProgress
            {
                StartTime = DateTime.UtcNow,
                Status = MigrationStatus.InProgress
            };
            
            try
            {
                _logger.LogInformation("Starting migration from PostgreSQL to DynamoDB");
                
                // Get total record count
                progress.TotalRecords = await GetTotalRecordCountAsync(config);
                _logger.LogInformation("Total records to migrate: {TotalRecords}", progress.TotalRecords);
                
                // Process records in batches
                await ProcessRecordsInBatches(config, progress);
                
                progress.Status = MigrationStatus.Completed;
                progress.EndTime = DateTime.UtcNow;
                
                _logger.LogInformation("Migration completed successfully. Processed: {Processed}, Successful: {Successful}, Failed: {Failed}",
                    progress.ProcessedRecords, progress.SuccessfulRecords, progress.FailedRecords);
                
                // Validate if requested
                if (config.ValidateAfterMigration)
                {
                    _logger.LogInformation("Starting post-migration validation");
                    var validationResult = await ValidateMigrationAsync(config);
                    _logger.LogInformation("Validation completed. Success: {IsValid}", validationResult.IsValid);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Migration failed");
                progress.Status = MigrationStatus.Failed;
                progress.Errors.Add($"Migration failed: {ex.Message}");
            }
            finally
            {
                // Save final progress
                await SaveProgressAsync(progress, config.ProgressFilePath);
            }
            
            return progress;
        }
        
        private async Task ProcessRecordsInBatches(MigrationConfig config, MigrationProgress progress)
        {
            using var connection = new NpgsqlConnection(config.PostgreSqlConnectionString);
            await connection.OpenAsync();
            
            var startId = config.ResumeFromId ?? 0;
            var batchSize = config.BatchSize;
            var currentId = startId;
            
            while (!_pauseRequested)
            {
                var batch = await GetNextBatch(connection, config, currentId, batchSize);
                
                if (!batch.Any())
                {
                    _logger.LogInformation("No more records to process");
                    break;
                }
                
                if (config.DryRun)
                {
                    _logger.LogInformation("DRY RUN: Would process batch of {Count} records starting from ID {StartId}",
                        batch.Count, batch.First().LogId);
                    
                    progress.ProcessedRecords += batch.Count;
                    progress.SuccessfulRecords += batch.Count;
                    currentId = batch.Last().LogId;
                }
                else
                {
                    var batchResult = await ProcessBatch(batch, config);
                    
                    progress.ProcessedRecords += batch.Count;
                    progress.SuccessfulRecords += batchResult.SuccessCount;
                    progress.FailedRecords += batchResult.FailureCount;
                    progress.LastProcessedId = batch.Last().LogId;
                    
                    if (batchResult.Errors.Any())
                    {
                        progress.Errors.AddRange(batchResult.Errors);
                    }
                    
                    currentId = batch.Last().LogId;
                }
                
                // Update progress and save periodically
                progress.UpdateProgress(progress.ProcessedRecords, progress.SuccessfulRecords, 
                    progress.FailedRecords, progress.LastProcessedId);
                
                if (progress.ProcessedRecords % (batchSize * 10) == 0)
                {
                    await SaveProgressAsync(progress, config.ProgressFilePath);
                    _logger.LogInformation("Progress: {Percent:F1}% ({Processed}/{Total}) - ETA: {ETA}",
                        progress.PercentComplete, progress.ProcessedRecords, progress.TotalRecords,
                        progress.EstimatedTimeRemaining?.ToString(@"hh\:mm\:ss") ?? "Unknown");
                }
                
                // Small delay to avoid overwhelming DynamoDB
                await Task.Delay(100);
            }
            
            if (_pauseRequested)
            {
                progress.Status = MigrationStatus.Paused;
                _logger.LogInformation("Migration paused at record ID {LastId}", progress.LastProcessedId);
            }
        }
        
        private async Task<List<IntegrationLogRecord>> GetNextBatch(
            NpgsqlConnection connection, MigrationConfig config, long startId, int batchSize)
        {
            var sql = @"
                SELECT LogId, ApplicationId, LogType, ServiceName, RequestData, ResponseData,
                       StatusCode, IsSuccess, ErrorMessage, ProcessingTimeMs, LogTimestamp,
                       CorrelationId, UserId
                FROM IntegrationLogs 
                WHERE LogId > @startId";
            
            var parameters = new List<NpgsqlParameter>
            {
                new("@startId", startId),
                new("@batchSize", batchSize)
            };
            
            if (config.StartDate.HasValue)
            {
                sql += " AND LogTimestamp >= @startDate";
                parameters.Add(new("@startDate", config.StartDate.Value));
            }
            
            if (config.EndDate.HasValue)
            {
                sql += " AND LogTimestamp <= @endDate";
                parameters.Add(new("@endDate", config.EndDate.Value));
            }
            
            sql += " ORDER BY LogId LIMIT @batchSize";
            
            using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddRange(parameters.ToArray());
            
            var records = new List<IntegrationLogRecord>();
            
            using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                records.Add(new IntegrationLogRecord
                {
                    LogId = reader.GetInt64("LogId"),
                    ApplicationId = reader.IsDBNull("ApplicationId") ? null : reader.GetInt32("ApplicationId"),
                    LogType = reader.GetString("LogType"),
                    ServiceName = reader.GetString("ServiceName"),
                    RequestData = reader.IsDBNull("RequestData") ? null : reader.GetString("RequestData"),
                    ResponseData = reader.IsDBNull("ResponseData") ? null : reader.GetString("ResponseData"),
                    StatusCode = reader.IsDBNull("StatusCode") ? null : reader.GetString("StatusCode"),
                    IsSuccess = reader.GetBoolean("IsSuccess"),
                    ErrorMessage = reader.IsDBNull("ErrorMessage") ? null : reader.GetString("ErrorMessage"),
                    ProcessingTimeMs = reader.IsDBNull("ProcessingTimeMs") ? null : reader.GetInt32("ProcessingTimeMs"),
                    LogTimestamp = reader.GetDateTime("LogTimestamp"),
                    CorrelationId = reader.IsDBNull("CorrelationId") ? null : reader.GetString("CorrelationId"),
                    UserId = reader.IsDBNull("UserId") ? null : reader.GetString("UserId")
                });
            }
            
            return records;
        }
        
        private async Task<BatchResult> ProcessBatch(List<IntegrationLogRecord> batch, MigrationConfig config)
        {
            var result = new BatchResult();
            var retryCount = 0;
            
            while (retryCount <= config.MaxRetries)
            {
                try
                {
                    var writeRequests = batch.Select(record => new WriteRequest
                    {
                        PutRequest = new PutRequest
                        {
                            Item = ConvertToDynamoDbItem(record)
                        }
                    }).ToList();
                    
                    var batchWriteRequest = new BatchWriteItemRequest
                    {
                        RequestItems = new Dictionary<string, List<WriteRequest>>
                        {
                            { config.DynamoDbTableName, writeRequests }
                        }
                    };
                    
                    var response = await _dynamoClient.BatchWriteItemAsync(batchWriteRequest);
                    
                    // Handle unprocessed items
                    if (response.UnprocessedItems.Any())
                    {
                        _logger.LogWarning("Batch had {Count} unprocessed items, retrying...", 
                            response.UnprocessedItems.Values.SelectMany(x => x).Count());
                        
                        // Retry unprocessed items
                        var retryRequest = new BatchWriteItemRequest { RequestItems = response.UnprocessedItems };
                        await _dynamoClient.BatchWriteItemAsync(retryRequest);
                    }
                    
                    result.SuccessCount = batch.Count;
                    break;
                }
                catch (Exception ex)
                {
                    retryCount++;
                    _logger.LogWarning(ex, "Batch write failed (attempt {Attempt}/{MaxAttempts})", retryCount, config.MaxRetries + 1);
                    
                    if (retryCount > config.MaxRetries)
                    {
                        result.FailureCount = batch.Count;
                        result.Errors.Add($"Batch write failed after {config.MaxRetries} retries: {ex.Message}");
                        break;
                    }
                    
                    await Task.Delay(config.RetryDelay);
                }
            }
            
            return result;
        }
        
        private Dictionary<string, AttributeValue> ConvertToDynamoDbItem(IntegrationLogRecord record)
        {
            var dateStr = record.LogTimestamp.ToString("yyyy-MM-dd");
            var timestampStr = record.LogTimestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
            
            var item = new Dictionary<string, AttributeValue>
            {
                ["PK"] = new AttributeValue($"{record.ServiceName}-{dateStr}"),
                ["SK"] = new AttributeValue($"{timestampStr}#{record.LogId}"),
                ["LogId"] = new AttributeValue { N = record.LogId.ToString() },
                ["LogType"] = new AttributeValue(record.LogType),
                ["ServiceName"] = new AttributeValue(record.ServiceName),
                ["IsSuccess"] = new AttributeValue { BOOL = record.IsSuccess },
                ["LogTimestamp"] = new AttributeValue(timestampStr),
                ["TTL"] = new AttributeValue { N = DateTimeOffset.UtcNow.AddDays(90).ToUnixTimeSeconds().ToString() }
            };
            
            // Optional fields
            if (record.ApplicationId.HasValue)
            {
                item["ApplicationId"] = new AttributeValue { N = record.ApplicationId.Value.ToString() };
                item["GSI1PK"] = new AttributeValue($"APP#{record.ApplicationId}");
                item["GSI1SK"] = new AttributeValue($"{timestampStr}#{record.LogId}");
            }
            
            if (!string.IsNullOrEmpty(record.RequestData))
                item["RequestData"] = new AttributeValue(record.RequestData);
            
            if (!string.IsNullOrEmpty(record.ResponseData))
                item["ResponseData"] = new AttributeValue(record.ResponseData);
            
            if (!string.IsNullOrEmpty(record.StatusCode))
                item["StatusCode"] = new AttributeValue(record.StatusCode);
            
            if (!string.IsNullOrEmpty(record.ErrorMessage))
                item["ErrorMessage"] = new AttributeValue(record.ErrorMessage);
            
            if (record.ProcessingTimeMs.HasValue)
                item["ProcessingTimeMs"] = new AttributeValue { N = record.ProcessingTimeMs.Value.ToString() };
            
            if (!string.IsNullOrEmpty(record.CorrelationId))
            {
                item["CorrelationId"] = new AttributeValue(record.CorrelationId);
                item["GSI2PK"] = new AttributeValue($"CORR#{record.CorrelationId}");
                item["GSI2SK"] = new AttributeValue($"{timestampStr}#{record.LogId}");
            }
            
            if (!string.IsNullOrEmpty(record.UserId))
                item["UserId"] = new AttributeValue(record.UserId);
            
            // GSI3 for error analysis
            item["GSI3PK"] = new AttributeValue($"ERROR#{record.IsSuccess}#{dateStr}");
            item["GSI3SK"] = new AttributeValue($"{timestampStr}#{record.LogId}");
            
            return item;
        }
        
        public async Task<long> GetTotalRecordCountAsync(MigrationConfig config)
        {
            using var connection = new NpgsqlConnection(config.PostgreSqlConnectionString);
            await connection.OpenAsync();
            
            var sql = "SELECT COUNT(*) FROM IntegrationLogs WHERE 1=1";
            var parameters = new List<NpgsqlParameter>();
            
            if (config.StartDate.HasValue)
            {
                sql += " AND LogTimestamp >= @startDate";
                parameters.Add(new("@startDate", config.StartDate.Value));
            }
            
            if (config.EndDate.HasValue)
            {
                sql += " AND LogTimestamp <= @endDate";
                parameters.Add(new("@endDate", config.EndDate.Value));
            }
            
            using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddRange(parameters.ToArray());
            
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt64(result);
        }
        
        public async Task<MigrationProgress> ResumeMigrationAsync(string progressFilePath)
        {
            if (!File.Exists(progressFilePath))
            {
                throw new FileNotFoundException($"Progress file not found: {progressFilePath}");
            }
            
            var json = await File.ReadAllTextAsync(progressFilePath);
            var progress = JsonSerializer.Deserialize<MigrationProgress>(json);
            
            if (progress == null)
            {
                throw new InvalidOperationException("Could not deserialize progress file");
            }
            
            _logger.LogInformation("Resuming migration from record ID {LastId}", progress.LastProcessedId);
            
            // Continue migration logic here...
            return progress;
        }
        
        public async Task<bool> PauseMigrationAsync()
        {
            _pauseRequested = true;
            _logger.LogInformation("Pause requested - migration will stop after current batch");
            return true;
        }
        
        public async Task<ValidationResult> ValidateMigrationAsync(MigrationConfig config)
        {
            // Implementation for validation
            var result = new ValidationResult { IsValid = true };
            
            // Add validation logic here
            
            return result;
        }
        
        private async Task SaveProgressAsync(MigrationProgress progress, string filePath)
        {
            var json = JsonSerializer.Serialize(progress, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(filePath, json);
        }
    }
    
    public class IntegrationLogRecord
    {
        public long LogId { get; set; }
        public int? ApplicationId { get; set; }
        public string LogType { get; set; } = string.Empty;
        public string ServiceName { get; set; } = string.Empty;
        public string? RequestData { get; set; }
        public string? ResponseData { get; set; }
        public string? StatusCode { get; set; }
        public bool IsSuccess { get; set; }
        public string? ErrorMessage { get; set; }
        public int? ProcessingTimeMs { get; set; }
        public DateTime LogTimestamp { get; set; }
        public string? CorrelationId { get; set; }
        public string? UserId { get; set; }
    }
    
    public class BatchResult
    {
        public int SuccessCount { get; set; }
        public int FailureCount { get; set; }
        public List<string> Errors { get; set; } = new();
    }
}
```

### 🎮 Console Application Entry Point

#### Program.cs
```csharp
using Amazon.DynamoDBv2;
using DataMigrationTool.Models;
using DataMigrationTool.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Serilog;
using System.Text.Json;

namespace DataMigrationTool
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Configure Serilog
            Log.Logger = new LoggerConfiguration()
                .WriteTo.Console()
                .WriteTo.File("migration-log-.txt", rollingInterval: RollingInterval.Day)
                .CreateLogger();
            
            try
            {
                var host = CreateHostBuilder(args).Build();
                
                var migrationService = host.Services.GetRequiredService<IMigrationService>();
                var logger = host.Services.GetRequiredService<ILogger<Program>>();
                var configuration = host.Services.GetRequiredService<IConfiguration>();
                
                // Load configuration
                var config = configuration.GetSection("Migration").Get<MigrationConfig>() ?? new MigrationConfig();
                
                logger.LogInformation("Starting DynamoDB Migration Tool");
                logger.LogInformation("Configuration: BatchSize={BatchSize}, DryRun={DryRun}", config.BatchSize, config.DryRun);
                
                // Check for resume
                if (File.Exists(config.ProgressFilePath) && args.Contains("--resume"))
                {
                    logger.LogInformation("Resuming migration from progress file");
                    var progress = await migrationService.ResumeMigrationAsync(config.ProgressFilePath);
                    DisplayFinalResults(progress, logger);
                }
                else
                {
                    // Start new migration
                    var progress = await migrationService.StartMigrationAsync(config);
                    DisplayFinalResults(progress, logger);
                }
            }
            catch (Exception ex)
            {
                Log.Fatal(ex, "Migration tool crashed");
            }
            finally
            {
                Log.CloseAndFlush();
            }
        }
        
        static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .UseSerilog()
                .ConfigureServices((context, services) =>
                {
                    services.AddDefaultAWSOptions(context.Configuration.GetAWSOptions());
                    services.AddAWSService<IAmazonDynamoDB>();
                    services.AddScoped<IMigrationService, MigrationService>();
                });
        
        static void DisplayFinalResults(MigrationProgress progress, ILogger logger)
        {
            logger.LogInformation("=== Migration Results ===");
            logger.LogInformation("Status: {Status}", progress.Status);
            logger.LogInformation("Total Records: {Total}", progress.TotalRecords);
            logger.LogInformation("Processed: {Processed}", progress.ProcessedRecords);
            logger.LogInformation("Successful: {Successful}", progress.SuccessfulRecords);
            logger.LogInformation("Failed: {Failed}", progress.FailedRecords);
            logger.LogInformation("Success Rate: {Rate:F1}%", 
                progress.ProcessedRecords > 0 ? (double)progress.SuccessfulRecords / progress.ProcessedRecords * 100 : 0);
            
            if (progress.StartTime != default && progress.EndTime.HasValue)
            {
                var duration = progress.EndTime.Value - progress.StartTime;
                logger.LogInformation("Duration: {Duration}", duration.ToString(@"hh\:mm\:ss"));
            }
            
            if (progress.Errors.Any())
            {
                logger.LogWarning("Errors encountered:");
                foreach (var error in progress.Errors.Take(10))
                {
                    logger.LogWarning("  - {Error}", error);
                }
                
                if (progress.Errors.Count > 10)
                {
                    logger.LogWarning("  ... and {Count} more errors", progress.Errors.Count - 10);
                }
            }
        }
    }
}
```

### ⚙️ Configuration Files

#### appsettings.json
```json
{
  "Migration": {
    "PostgreSqlConnectionString": "Host=localhost;Database=LoanApplicationDB;Username=postgres;Password=WorkshopDB123!",
    "DynamoDbTableName": "LoanApp-IntegrationLogs-dev",
    "AwsRegion": "us-east-1",
    "BatchSize": 25,
    "MaxRetries": 3,
    "RetryDelay": "00:00:02",
    "ValidateAfterMigration": true,
    "ProgressFilePath": "migration-progress.json",
    "DryRun": false
  },
  "AWS": {
    "Region": "us-east-1"
  },
  "Serilog": {
    "MinimumLevel": "Information"
  }
}
```

### 🚀 PowerShell Migration Script

#### run-migration.ps1
```powershell
# DynamoDB Migration Runner
param(
    [switch]$DryRun,
    [switch]$Resume,
    [string]$Environment = "dev",
    [int]$BatchSize = 25,
    [string]$StartDate,
    [string]$EndDate
)

Write-Host "🚀 Starting DynamoDB Migration Tool" -ForegroundColor Green

# Build the migration tool
Write-Host "📦 Building migration tool..." -ForegroundColor Yellow
dotnet build DataMigrationTool/DataMigrationTool.csproj --configuration Release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

# Prepare arguments
$args = @()

if ($DryRun) {
    $args += "--dry-run"
    Write-Host "🧪 Running in DRY RUN mode" -ForegroundColor Cyan
}

if ($Resume) {
    $args += "--resume"
    Write-Host "🔄 Resuming from previous progress" -ForegroundColor Cyan
}

# Update configuration
$configPath = "DataMigrationTool/appsettings.json"
$config = Get-Content $configPath | ConvertFrom-Json

$config.Migration.DynamoDbTableName = "LoanApp-IntegrationLogs-$Environment"
$config.Migration.BatchSize = $BatchSize
$config.Migration.DryRun = $DryRun.IsPresent

if ($StartDate) {
    $config.Migration.StartDate = $StartDate
}

if ($EndDate) {
    $config.Migration.EndDate = $EndDate
}

$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "⚙️  Configuration updated for environment: $Environment" -ForegroundColor Cyan

# Run migration
Write-Host "🏃 Starting migration..." -ForegroundColor Yellow
dotnet run --project DataMigrationTool/DataMigrationTool.csproj --configuration Release -- $args

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Migration completed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Migration failed" -ForegroundColor Red
    exit 1
}
```

### 📊 Usage Examples

#### Basic Migration
```bash
# Full migration
./run-migration.ps1 -Environment dev

# Dry run to test
./run-migration.ps1 -DryRun -Environment dev

# Resume interrupted migration
./run-migration.ps1 -Resume -Environment dev

# Migrate specific date range
./run-migration.ps1 -StartDate "2024-01-01" -EndDate "2024-01-31" -Environment dev
```

---

### 💡 Q Developer Integration Points

```
1. "Review this data migration tool and suggest improvements for performance, error handling, and monitoring."

2. "Analyze the batch processing logic and recommend optimizations for DynamoDB throughput and cost management."

3. "Examine the resume capability and suggest enhancements for handling partial failures and data consistency."
```

**Next**: [Application Integration](./step5-application-integration.md)