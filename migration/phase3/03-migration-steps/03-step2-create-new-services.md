# Step 2: Create New DynamoDB Services
## Phase 3: DynamoDB Migration - Service Layer Implementation

### 🎯 Objective
Create new service layer for DynamoDB operations while maintaining existing SQL Server logging functionality during the migration period.

### 🏗️ Service Architecture

#### New Components to Add
```
LoanApplication/
├── Models/
│   └── DynamoDbLogEntry.cs          # New DynamoDB model
├── Services/
│   ├── IDynamoDbLogService.cs       # New interface
│   ├── DynamoDbLogService.cs        # New implementation
│   └── IHybridLogService.cs         # Dual-write service
├── Configuration/
│   └── DynamoDbConfiguration.cs     # Configuration model
└── Extensions/
    └── ServiceCollectionExtensions.cs # DI registration
```

### 📊 DynamoDB Model Implementation

#### DynamoDbLogEntry.cs
```csharp
using Amazon.DynamoDBv2.DataModel;
using System.Text.Json;

namespace LoanApplication.Models
{
    [DynamoDBTable("LoanApp-IntegrationLogs-dev")] // Will be configured via appsettings
    public class DynamoDbLogEntry
    {
        [DynamoDBHashKey("PK")]
        public string PartitionKey { get; set; } = string.Empty;
        
        [DynamoDBRangeKey("SK")]
        public string SortKey { get; set; } = string.Empty;
        
        [DynamoDBProperty("LogId")]
        public long LogId { get; set; }
        
        [DynamoDBProperty("ApplicationId")]
        public int? ApplicationId { get; set; }
        
        [DynamoDBProperty("LogType")]
        public string LogType { get; set; } = string.Empty;
        
        [DynamoDBProperty("ServiceName")]
        public string ServiceName { get; set; } = string.Empty;
        
        [DynamoDBProperty("RequestData")]
        public string? RequestData { get; set; }
        
        [DynamoDBProperty("ResponseData")]
        public string? ResponseData { get; set; }
        
        [DynamoDBProperty("StatusCode")]
        public string? StatusCode { get; set; }
        
        [DynamoDBProperty("IsSuccess")]
        public bool IsSuccess { get; set; }
        
        [DynamoDBProperty("ErrorMessage")]
        public string? ErrorMessage { get; set; }
        
        [DynamoDBProperty("ProcessingTimeMs")]
        public int? ProcessingTimeMs { get; set; }
        
        [DynamoDBProperty("LogTimestamp")]
        public DateTime LogTimestamp { get; set; }
        
        [DynamoDBProperty("CorrelationId")]
        public string? CorrelationId { get; set; }
        
        [DynamoDBProperty("UserId")]
        public string? UserId { get; set; }
        
        [DynamoDBProperty("TTL")]
        public long TTL { get; set; }
        
        // GSI Keys
        [DynamoDBProperty("GSI1PK")]
        public string? GSI1PartitionKey { get; set; }
        
        [DynamoDBProperty("GSI1SK")]
        public string? GSI1SortKey { get; set; }
        
        [DynamoDBProperty("GSI2PK")]
        public string? GSI2PartitionKey { get; set; }
        
        [DynamoDBProperty("GSI2SK")]
        public string? GSI2SortKey { get; set; }
        
        [DynamoDBProperty("GSI3PK")]
        public string? GSI3PartitionKey { get; set; }
        
        [DynamoDBProperty("GSI3SK")]
        public string? GSI3SortKey { get; set; }
        
        // Helper methods for key generation
        public void GenerateKeys()
        {
            var dateStr = LogTimestamp.ToString("yyyy-MM-dd");
            var timestampStr = LogTimestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
            
            // Primary key
            PartitionKey = $"{ServiceName}-{dateStr}";
            SortKey = $"{timestampStr}#{LogId}";
            
            // GSI keys
            if (ApplicationId.HasValue)
            {
                GSI1PartitionKey = $"APP#{ApplicationId}";
                GSI1SortKey = SortKey;
            }
            
            if (!string.IsNullOrEmpty(CorrelationId))
            {
                GSI2PartitionKey = $"CORR#{CorrelationId}";
                GSI2SortKey = SortKey;
            }
            
            GSI3PartitionKey = $"ERROR#{IsSuccess}#{dateStr}";
            GSI3SortKey = SortKey;
            
            // Set TTL (90 days from now)
            TTL = DateTimeOffset.UtcNow.AddDays(90).ToUnixTimeSeconds();
        }
        
        // Convert from SQL Server model
        public static DynamoDbLogEntry FromIntegrationLog(IntegrationLog sqlLog)
        {
            var dynamoLog = new DynamoDbLogEntry
            {
                LogId = sqlLog.LogId,
                ApplicationId = sqlLog.ApplicationId,
                LogType = sqlLog.LogType,
                ServiceName = sqlLog.ServiceName,
                RequestData = sqlLog.RequestData,
                ResponseData = sqlLog.ResponseData,
                StatusCode = sqlLog.StatusCode,
                IsSuccess = sqlLog.IsSuccess,
                ErrorMessage = sqlLog.ErrorMessage,
                ProcessingTimeMs = sqlLog.ProcessingTimeMs,
                LogTimestamp = sqlLog.LogTimestamp,
                CorrelationId = sqlLog.CorrelationId,
                UserId = sqlLog.UserId
            };
            
            dynamoLog.GenerateKeys();
            return dynamoLog;
        }
    }
}
```

### 🔧 Service Interface

#### IDynamoDbLogService.cs
```csharp
using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IDynamoDbLogService
    {
        // Single operations
        Task<bool> WriteLogAsync(DynamoDbLogEntry logEntry);
        Task<DynamoDbLogEntry?> GetLogByIdAsync(string serviceName, DateTime date, long logId);
        
        // Batch operations
        Task<bool> WriteBatchAsync(IEnumerable<DynamoDbLogEntry> logEntries);
        
        // Query operations
        Task<IEnumerable<DynamoDbLogEntry>> GetLogsByServiceAndTimeRangeAsync(
            string serviceName, DateTime startDate, DateTime endDate);
        
        Task<IEnumerable<DynamoDbLogEntry>> GetLogsByApplicationIdAsync(int applicationId);
        
        Task<IEnumerable<DynamoDbLogEntry>> GetLogsByCorrelationIdAsync(string correlationId);
        
        Task<IEnumerable<DynamoDbLogEntry>> GetErrorLogsByDateAsync(DateTime date);
        
        // Statistics
        Task<long> GetLogCountByServiceAsync(string serviceName, DateTime date);
        Task<Dictionary<string, long>> GetLogCountsByDateAsync(DateTime date);
    }
}
```

### ⚙️ Service Implementation

#### DynamoDbLogService.cs
```csharp
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using Amazon.DynamoDBv2.DocumentModel;
using LoanApplication.Models;
using LoanApplication.Services;
using Microsoft.Extensions.Options;

namespace LoanApplication.Services
{
    public class DynamoDbLogService : IDynamoDbLogService
    {
        private readonly DynamoDBContext _dynamoContext;
        private readonly IAmazonDynamoDB _dynamoClient;
        private readonly ILogger<DynamoDbLogService> _logger;
        private readonly string _tableName;
        
        public DynamoDbLogService(
            DynamoDBContext dynamoContext,
            IAmazonDynamoDB dynamoClient,
            IOptions<DynamoDbConfiguration> config,
            ILogger<DynamoDbLogService> logger)
        {
            _dynamoContext = dynamoContext;
            _dynamoClient = dynamoClient;
            _logger = logger;
            _tableName = config.Value.TableName;
        }
        
        public async Task<bool> WriteLogAsync(DynamoDbLogEntry logEntry)
        {
            try
            {
                logEntry.GenerateKeys();
                await _dynamoContext.SaveAsync(logEntry);
                
                _logger.LogDebug("Successfully wrote log entry {LogId} to DynamoDB", logEntry.LogId);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to write log entry {LogId} to DynamoDB", logEntry.LogId);
                return false;
            }
        }
        
        public async Task<bool> WriteBatchAsync(IEnumerable<DynamoDbLogEntry> logEntries)
        {
            try
            {
                var batchWrite = _dynamoContext.CreateBatchWrite<DynamoDbLogEntry>();
                
                foreach (var entry in logEntries)
                {
                    entry.GenerateKeys();
                    batchWrite.AddPutItem(entry);
                }
                
                await batchWrite.ExecuteAsync();
                
                _logger.LogDebug("Successfully wrote {Count} log entries to DynamoDB", logEntries.Count());
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to write batch of {Count} log entries to DynamoDB", logEntries.Count());
                return false;
            }
        }
        
        public async Task<DynamoDbLogEntry?> GetLogByIdAsync(string serviceName, DateTime date, long logId)
        {
            try
            {
                var dateStr = date.ToString("yyyy-MM-dd");
                var pk = $"{serviceName}-{dateStr}";
                
                // We need to query by PK and filter by LogId since we don't have exact SK
                var queryConfig = new QueryOperationConfig
                {
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "PK = :pk",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":pk", pk }
                        }
                    },
                    FilterExpression = new Expression
                    {
                        ExpressionStatement = "LogId = :logId",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":logId", logId }
                        }
                    }
                };
                
                var search = _dynamoContext.FromQueryAsync<DynamoDbLogEntry>(queryConfig);
                var results = await search.GetRemainingAsync();
                
                return results.FirstOrDefault();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get log by ID {LogId}", logId);
                return null;
            }
        }
        
        public async Task<IEnumerable<DynamoDbLogEntry>> GetLogsByServiceAndTimeRangeAsync(
            string serviceName, DateTime startDate, DateTime endDate)
        {
            try
            {
                var results = new List<DynamoDbLogEntry>();
                
                // Query each day in the range (DynamoDB partition key includes date)
                for (var date = startDate.Date; date <= endDate.Date; date = date.AddDays(1))
                {
                    var dateStr = date.ToString("yyyy-MM-dd");
                    var pk = $"{serviceName}-{dateStr}";
                    
                    var queryConfig = new QueryOperationConfig
                    {
                        KeyExpression = new Expression
                        {
                            ExpressionStatement = "PK = :pk AND SK BETWEEN :start AND :end",
                            ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                            {
                                { ":pk", pk },
                                { ":start", startDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ") },
                                { ":end", endDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
                            }
                        }
                    };
                    
                    var search = _dynamoContext.FromQueryAsync<DynamoDbLogEntry>(queryConfig);
                    var dayResults = await search.GetRemainingAsync();
                    results.AddRange(dayResults);
                }
                
                return results.OrderByDescending(x => x.LogTimestamp);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get logs by service and time range");
                return Enumerable.Empty<DynamoDbLogEntry>();
            }
        }
        
        public async Task<IEnumerable<DynamoDbLogEntry>> GetLogsByApplicationIdAsync(int applicationId)
        {
            try
            {
                var queryConfig = new QueryOperationConfig
                {
                    IndexName = "GSI1-ApplicationId-LogTimestamp",
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "GSI1PK = :appId",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":appId", $"APP#{applicationId}" }
                        }
                    }
                };
                
                var search = _dynamoContext.FromQueryAsync<DynamoDbLogEntry>(queryConfig);
                return await search.GetRemainingAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get logs by application ID {ApplicationId}", applicationId);
                return Enumerable.Empty<DynamoDbLogEntry>();
            }
        }
        
        public async Task<IEnumerable<DynamoDbLogEntry>> GetLogsByCorrelationIdAsync(string correlationId)
        {
            try
            {
                var queryConfig = new QueryOperationConfig
                {
                    IndexName = "GSI2-CorrelationId-LogTimestamp",
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "GSI2PK = :corrId",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":corrId", $"CORR#{correlationId}" }
                        }
                    }
                };
                
                var search = _dynamoContext.FromQueryAsync<DynamoDbLogEntry>(queryConfig);
                return await search.GetRemainingAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get logs by correlation ID {CorrelationId}", correlationId);
                return Enumerable.Empty<DynamoDbLogEntry>();
            }
        }
        
        public async Task<IEnumerable<DynamoDbLogEntry>> GetErrorLogsByDateAsync(DateTime date)
        {
            try
            {
                var dateStr = date.ToString("yyyy-MM-dd");
                
                var queryConfig = new QueryOperationConfig
                {
                    IndexName = "GSI3-ErrorStatus-LogTimestamp",
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "GSI3PK = :errorKey",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":errorKey", $"ERROR#false#{dateStr}" }
                        }
                    }
                };
                
                var search = _dynamoContext.FromQueryAsync<DynamoDbLogEntry>(queryConfig);
                return await search.GetRemainingAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get error logs by date {Date}", date);
                return Enumerable.Empty<DynamoDbLogEntry>();
            }
        }
        
        public async Task<long> GetLogCountByServiceAsync(string serviceName, DateTime date)
        {
            try
            {
                var logs = await GetLogsByServiceAndTimeRangeAsync(serviceName, date.Date, date.Date.AddDays(1).AddTicks(-1));
                return logs.Count();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get log count by service {ServiceName}", serviceName);
                return 0;
            }
        }
        
        public async Task<Dictionary<string, long>> GetLogCountsByDateAsync(DateTime date)
        {
            try
            {
                // This would require scanning multiple partitions
                // In production, consider maintaining separate aggregation table
                var results = new Dictionary<string, long>();
                
                // For workshop purposes, return sample data
                // In real implementation, use DynamoDB Streams + Lambda for aggregation
                results["CreditCheckService"] = await GetLogCountByServiceAsync("CreditCheckService", date);
                results["LoanProcessingService"] = await GetLogCountByServiceAsync("LoanProcessingService", date);
                results["DocumentService"] = await GetLogCountByServiceAsync("DocumentService", date);
                
                return results;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get log counts by date {Date}", date);
                return new Dictionary<string, long>();
            }
        }
    }
}
```

### 📋 Configuration Model

#### DynamoDbConfiguration.cs
```csharp
namespace LoanApplication.Configuration
{
    public class DynamoDbConfiguration
    {
        public const string SectionName = "DynamoDB";
        
        public string TableName { get; set; } = string.Empty;
        public string Region { get; set; } = "us-east-1";
        public string? AccessKey { get; set; }
        public string? SecretKey { get; set; }
        public bool UseLocalDynamoDB { get; set; } = false;
        public string LocalDynamoDBUrl { get; set; } = "http://localhost:8000";
    }
}
```

### 🔧 Dependency Injection Setup

#### ServiceCollectionExtensions.cs
```csharp
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using LoanApplication.Configuration;
using LoanApplication.Services;

namespace LoanApplication.Extensions
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddDynamoDbServices(
            this IServiceCollection services, 
            IConfiguration configuration)
        {
            // Configure DynamoDB settings
            services.Configure<DynamoDbConfiguration>(
                configuration.GetSection(DynamoDbConfiguration.SectionName));
            
            var dynamoConfig = configuration
                .GetSection(DynamoDbConfiguration.SectionName)
                .Get<DynamoDbConfiguration>() ?? new DynamoDbConfiguration();
            
            // Register DynamoDB client
            if (dynamoConfig.UseLocalDynamoDB)
            {
                services.AddSingleton<IAmazonDynamoDB>(provider =>
                {
                    var clientConfig = new AmazonDynamoDBConfig
                    {
                        ServiceURL = dynamoConfig.LocalDynamoDBUrl
                    };
                    return new AmazonDynamoDBClient(clientConfig);
                });
            }
            else
            {
                services.AddDefaultAWSOptions(configuration.GetAWSOptions());
                services.AddAWSService<IAmazonDynamoDB>();
            }
            
            // Register DynamoDB context
            services.AddSingleton<DynamoDBContext>(provider =>
            {
                var client = provider.GetRequiredService<IAmazonDynamoDB>();
                var contextConfig = new DynamoDBContextConfig
                {
                    TableNamePrefix = string.Empty // Table name includes environment
                };
                return new DynamoDBContext(client, contextConfig);
            });
            
            // Register services
            services.AddScoped<IDynamoDbLogService, DynamoDbLogService>();
            
            return services;
        }
    }
}
```

### ⚙️ Application Configuration Updates

#### appsettings.json additions
```json
{
  "DynamoDB": {
    "TableName": "LoanApp-IntegrationLogs-dev",
    "Region": "us-east-1",
    "UseLocalDynamoDB": false,
    "LocalDynamoDBUrl": "http://localhost:8000"
  },
  "AWS": {
    "Region": "us-east-1"
  }
}
```

#### Program.cs updates
```csharp
using LoanApplication.Extensions;

// Add after existing services
builder.Services.AddDynamoDbServices(builder.Configuration);

// Add AWS configuration
builder.Services.AddDefaultAWSOptions(builder.Configuration.GetAWSOptions());
```

### 🧪 Testing the Service

#### Basic Test Implementation
```csharp
// Test in controller or create unit tests
public async Task<IActionResult> TestDynamoDb()
{
    var testLog = new DynamoDbLogEntry
    {
        LogId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
        LogType = "TEST",
        ServiceName = "TestService",
        LogTimestamp = DateTime.UtcNow,
        IsSuccess = true,
        RequestData = "{\"test\": \"data\"}",
        ResponseData = "{\"result\": \"success\"}"
    };
    
    var success = await _dynamoDbLogService.WriteLogAsync(testLog);
    
    if (success)
    {
        var retrieved = await _dynamoDbLogService.GetLogByIdAsync(
            testLog.ServiceName, 
            testLog.LogTimestamp, 
            testLog.LogId);
        
        return Ok(new { written = testLog, retrieved });
    }
    
    return BadRequest("Failed to write test log");
}
```

### 🚀 Next Steps
1. **Add NuGet packages** for AWS SDK
2. **Update Program.cs** with DI registration
3. **Test service** with sample data
4. **Implement dual-write pattern** for migration

---

### 💡 Q Developer Integration Points

```
1. "Review this DynamoDB service implementation and suggest improvements for error handling and performance optimization."

2. "Analyze the dependency injection setup and recommend best practices for AWS SDK configuration in .NET applications."

3. "Examine the query patterns and suggest optimizations for DynamoDB GSI usage and cost management."
```

**Next**: [Dual-Write Pattern Implementation](./step3-dual-write-pattern.md)