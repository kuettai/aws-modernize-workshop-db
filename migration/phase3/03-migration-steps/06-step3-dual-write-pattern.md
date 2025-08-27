# Step 3: Dual-Write Pattern Implementation
## Phase 3: DynamoDB Migration - Hybrid Logging Strategy

### 🎯 Objective
Implement dual-write pattern to safely migrate from PostgreSQL to DynamoDB logging while maintaining data consistency and zero downtime.

### 🏗️ Hybrid Service Architecture

#### IHybridLogService Interface
```csharp
using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IHybridLogService
    {
        // Write operations (dual-write during migration)
        Task<bool> WriteLogAsync(IntegrationLog logEntry);
        Task<bool> WriteBatchAsync(IEnumerable<IntegrationLog> logEntries);
        
        // Read operations (configurable source)
        Task<IEnumerable<IntegrationLog>> GetLogsByApplicationIdAsync(int applicationId);
        Task<IEnumerable<IntegrationLog>> GetLogsByServiceAndTimeRangeAsync(
            string serviceName, DateTime startDate, DateTime endDate);
        Task<IEnumerable<IntegrationLog>> GetErrorLogsByDateAsync(DateTime date);
        Task<long> GetLogCountAsync();
        
        // Migration control
        Task<bool> EnableDualWriteAsync();
        Task<bool> SwitchToDynamoDbReadsAsync();
        Task<bool> DisableSqlWritesAsync();
        
        // Validation
        Task<MigrationValidationResult> ValidateDataConsistencyAsync(DateTime startDate, DateTime endDate);
    }
    
    public class MigrationValidationResult
    {
        public bool IsConsistent { get; set; }
        public long SqlRecordCount { get; set; }
        public long DynamoDbRecordCount { get; set; }
        public List<string> Discrepancies { get; set; } = new();
        public TimeSpan ValidationDuration { get; set; }
    }
}
```

### ⚙️ Hybrid Service Implementation

#### HybridLogService.cs
```csharp
using LoanApplication.Data;
using LoanApplication.Models;
using LoanApplication.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace LoanApplication.Services
{
    public class HybridLogService : IHybridLogService
    {
        private readonly LoanApplicationContext _sqlContext;
        private readonly IDynamoDbLogService _dynamoService;
        private readonly ILogger<HybridLogService> _logger;
        private readonly HybridLogConfiguration _config;
        
        public HybridLogService(
            LoanApplicationContext sqlContext,
            IDynamoDbLogService dynamoService,
            IOptions<HybridLogConfiguration> config,
            ILogger<HybridLogService> logger)
        {
            _sqlContext = sqlContext;
            _dynamoService = dynamoService;
            _config = config.Value;
            _logger = logger;
        }
        
        public async Task<bool> WriteLogAsync(IntegrationLog logEntry)
        {
            var sqlSuccess = false;
            var dynamoSuccess = false;
            
            try
            {
                // Always write to SQL during migration period
                if (_config.WritesToSql)
                {
                    _sqlContext.IntegrationLogs.Add(logEntry);
                    await _sqlContext.SaveChangesAsync();
                    sqlSuccess = true;
                    _logger.LogDebug("Successfully wrote log {LogId} to SQL Server", logEntry.LogId);
                }
                
                // Write to DynamoDB if enabled
                if (_config.WritesToDynamoDb)
                {
                    var dynamoLog = DynamoDbLogEntry.FromIntegrationLog(logEntry);
                    dynamoSuccess = await _dynamoService.WriteLogAsync(dynamoLog);
                    
                    if (dynamoSuccess)
                    {
                        _logger.LogDebug("Successfully wrote log {LogId} to DynamoDB", logEntry.LogId);
                    }
                    else
                    {
                        _logger.LogWarning("Failed to write log {LogId} to DynamoDB", logEntry.LogId);
                    }
                }
                
                // Determine overall success based on configuration
                var overallSuccess = _config.RequireBothWrites 
                    ? (sqlSuccess && dynamoSuccess)
                    : (sqlSuccess || dynamoSuccess);
                
                if (!overallSuccess)
                {
                    _logger.LogError("Failed to write log {LogId} to required destinations. SQL: {SqlSuccess}, DynamoDB: {DynamoSuccess}", 
                        logEntry.LogId, sqlSuccess, dynamoSuccess);
                }
                
                return overallSuccess;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during dual-write for log {LogId}", logEntry.LogId);
                return false;
            }
        }
        
        public async Task<bool> WriteBatchAsync(IEnumerable<IntegrationLog> logEntries)
        {
            var sqlSuccess = false;
            var dynamoSuccess = false;
            
            try
            {
                // Batch write to SQL
                if (_config.WritesToSql)
                {
                    _sqlContext.IntegrationLogs.AddRange(logEntries);
                    await _sqlContext.SaveChangesAsync();
                    sqlSuccess = true;
                    _logger.LogDebug("Successfully wrote {Count} logs to SQL Server", logEntries.Count());
                }
                
                // Batch write to DynamoDB
                if (_config.WritesToDynamoDb)
                {
                    var dynamoLogs = logEntries.Select(DynamoDbLogEntry.FromIntegrationLog);
                    dynamoSuccess = await _dynamoService.WriteBatchAsync(dynamoLogs);
                    
                    if (dynamoSuccess)
                    {
                        _logger.LogDebug("Successfully wrote {Count} logs to DynamoDB", logEntries.Count());
                    }
                }
                
                return _config.RequireBothWrites 
                    ? (sqlSuccess && dynamoSuccess)
                    : (sqlSuccess || dynamoSuccess);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during batch dual-write for {Count} logs", logEntries.Count());
                return false;
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetLogsByApplicationIdAsync(int applicationId)
        {
            try
            {
                if (_config.ReadsFromDynamoDb)
                {
                    var dynamoLogs = await _dynamoService.GetLogsByApplicationIdAsync(applicationId);
                    return dynamoLogs.Select(ConvertFromDynamoDb);
                }
                else
                {
                    return await _sqlContext.IntegrationLogs
                        .Where(l => l.ApplicationId == applicationId)
                        .OrderByDescending(l => l.LogTimestamp)
                        .ToListAsync();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting logs by application ID {ApplicationId}", applicationId);
                return Enumerable.Empty<IntegrationLog>();
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetLogsByServiceAndTimeRangeAsync(
            string serviceName, DateTime startDate, DateTime endDate)
        {
            try
            {
                if (_config.ReadsFromDynamoDb)
                {
                    var dynamoLogs = await _dynamoService.GetLogsByServiceAndTimeRangeAsync(serviceName, startDate, endDate);
                    return dynamoLogs.Select(ConvertFromDynamoDb);
                }
                else
                {
                    return await _sqlContext.IntegrationLogs
                        .Where(l => l.ServiceName == serviceName 
                                && l.LogTimestamp >= startDate 
                                && l.LogTimestamp <= endDate)
                        .OrderByDescending(l => l.LogTimestamp)
                        .ToListAsync();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting logs by service and time range");
                return Enumerable.Empty<IntegrationLog>();
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetErrorLogsByDateAsync(DateTime date)
        {
            try
            {
                if (_config.ReadsFromDynamoDb)
                {
                    var dynamoLogs = await _dynamoService.GetErrorLogsByDateAsync(date);
                    return dynamoLogs.Select(ConvertFromDynamoDb);
                }
                else
                {
                    return await _sqlContext.IntegrationLogs
                        .Where(l => !l.IsSuccess && l.LogTimestamp.Date == date.Date)
                        .OrderByDescending(l => l.LogTimestamp)
                        .ToListAsync();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting error logs by date {Date}", date);
                return Enumerable.Empty<IntegrationLog>();
            }
        }
        
        public async Task<long> GetLogCountAsync()
        {
            try
            {
                if (_config.ReadsFromDynamoDb)
                {
                    // DynamoDB count is expensive, use approximation or cached value
                    var today = DateTime.UtcNow.Date;
                    var counts = await _dynamoService.GetLogCountsByDateAsync(today);
                    return counts.Values.Sum();
                }
                else
                {
                    return await _sqlContext.IntegrationLogs.CountAsync();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting log count");
                return 0;
            }
        }
        
        // Migration control methods
        public async Task<bool> EnableDualWriteAsync()
        {
            _config.WritesToDynamoDb = true;
            _config.RequireBothWrites = false; // Start with best-effort
            _logger.LogInformation("Enabled dual-write mode (SQL + DynamoDB)");
            return true;
        }
        
        public async Task<bool> SwitchToDynamoDbReadsAsync()
        {
            _config.ReadsFromDynamoDb = true;
            _logger.LogInformation("Switched to DynamoDB for read operations");
            return true;
        }
        
        public async Task<bool> DisableSqlWritesAsync()
        {
            _config.WritesToSql = false;
            _config.RequireBothWrites = false;
            _logger.LogInformation("Disabled SQL writes - DynamoDB only mode");
            return true;
        }
        
        public async Task<MigrationValidationResult> ValidateDataConsistencyAsync(DateTime startDate, DateTime endDate)
        {
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            var result = new MigrationValidationResult();
            
            try
            {
                // Count records in SQL
                result.SqlRecordCount = await _sqlContext.IntegrationLogs
                    .Where(l => l.LogTimestamp >= startDate && l.LogTimestamp <= endDate)
                    .CountAsync();
                
                // Count records in DynamoDB (approximate)
                var dynamoLogs = new List<DynamoDbLogEntry>();
                var services = new[] { "CreditCheckService", "LoanProcessingService", "DocumentService" };
                
                foreach (var service in services)
                {
                    var serviceLogs = await _dynamoService.GetLogsByServiceAndTimeRangeAsync(service, startDate, endDate);
                    dynamoLogs.AddRange(serviceLogs);
                }
                
                result.DynamoDbRecordCount = dynamoLogs.Count;
                
                // Check consistency
                var tolerance = Math.Max(1, result.SqlRecordCount * 0.01); // 1% tolerance
                result.IsConsistent = Math.Abs(result.SqlRecordCount - result.DynamoDbRecordCount) <= tolerance;
                
                if (!result.IsConsistent)
                {
                    result.Discrepancies.Add($"Record count mismatch: SQL={result.SqlRecordCount}, DynamoDB={result.DynamoDbRecordCount}");
                }
                
                _logger.LogInformation("Data consistency validation: SQL={SqlCount}, DynamoDB={DynamoCount}, Consistent={IsConsistent}",
                    result.SqlRecordCount, result.DynamoDbRecordCount, result.IsConsistent);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during data consistency validation");
                result.Discrepancies.Add($"Validation error: {ex.Message}");
            }
            
            stopwatch.Stop();
            result.ValidationDuration = stopwatch.Elapsed;
            
            return result;
        }
        
        private static IntegrationLog ConvertFromDynamoDb(DynamoDbLogEntry dynamoLog)
        {
            return new IntegrationLog
            {
                LogId = dynamoLog.LogId,
                ApplicationId = dynamoLog.ApplicationId,
                LogType = dynamoLog.LogType,
                ServiceName = dynamoLog.ServiceName,
                RequestData = dynamoLog.RequestData,
                ResponseData = dynamoLog.ResponseData,
                StatusCode = dynamoLog.StatusCode,
                IsSuccess = dynamoLog.IsSuccess,
                ErrorMessage = dynamoLog.ErrorMessage,
                ProcessingTimeMs = dynamoLog.ProcessingTimeMs,
                LogTimestamp = dynamoLog.LogTimestamp,
                CorrelationId = dynamoLog.CorrelationId,
                UserId = dynamoLog.UserId
            };
        }
    }
}
```

### 📋 Configuration Model

#### HybridLogConfiguration.cs
```csharp
namespace LoanApplication.Configuration
{
    public class HybridLogConfiguration
    {
        public const string SectionName = "HybridLogging";
        
        // Write configuration
        public bool WritesToSql { get; set; } = true;
        public bool WritesToDynamoDb { get; set; } = false;
        public bool RequireBothWrites { get; set; } = false;
        
        // Read configuration
        public bool ReadsFromDynamoDb { get; set; } = false;
        
        // Migration phases
        public MigrationPhase CurrentPhase { get; set; } = MigrationPhase.SqlOnly;
        
        // Error handling
        public bool ContinueOnWriteFailure { get; set; } = true;
        public int RetryAttempts { get; set; } = 3;
        public TimeSpan RetryDelay { get; set; } = TimeSpan.FromSeconds(1);
    }
    
    public enum MigrationPhase
    {
        SqlOnly,           // Phase 0: Before migration
        DualWrite,         // Phase 1: Write to both, read from SQL
        DualWriteReadDynamo, // Phase 2: Write to both, read from DynamoDB
        DynamoOnly         // Phase 3: DynamoDB only
    }
}
```

### 🔧 Updated Service Registration

#### ServiceCollectionExtensions.cs (Updated)
```csharp
public static IServiceCollection AddHybridLoggingServices(
    this IServiceCollection services, 
    IConfiguration configuration)
{
    // Add DynamoDB services
    services.AddDynamoDbServices(configuration);
    
    // Configure hybrid logging
    services.Configure<HybridLogConfiguration>(
        configuration.GetSection(HybridLogConfiguration.SectionName));
    
    // Register hybrid service
    services.AddScoped<IHybridLogService, HybridLogService>();
    
    return services;
}
```

### ⚙️ Updated Application Configuration

#### appsettings.json (Updated)
```json
{
  "HybridLogging": {
    "WritesToSql": true,
    "WritesToDynamoDb": false,
    "RequireBothWrites": false,
    "ReadsFromDynamoDb": false,
    "CurrentPhase": "SqlOnly",
    "ContinueOnWriteFailure": true,
    "RetryAttempts": 3,
    "RetryDelay": "00:00:01"
  },
  "DynamoDB": {
    "TableName": "LoanApp-IntegrationLogs-dev",
    "Region": "us-east-1"
  }
}
```

### 🎮 Migration Control Controller

#### MigrationController.cs
```csharp
using LoanApplication.Services;
using Microsoft.AspNetCore.Mvc;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MigrationController : ControllerBase
    {
        private readonly IHybridLogService _hybridLogService;
        private readonly ILogger<MigrationController> _logger;
        
        public MigrationController(IHybridLogService hybridLogService, ILogger<MigrationController> logger)
        {
            _hybridLogService = hybridLogService;
            _logger = logger;
        }
        
        [HttpPost("enable-dual-write")]
        public async Task<IActionResult> EnableDualWrite()
        {
            var success = await _hybridLogService.EnableDualWriteAsync();
            return Ok(new { success, message = "Dual-write mode enabled" });
        }
        
        [HttpPost("switch-to-dynamo-reads")]
        public async Task<IActionResult> SwitchToDynamoReads()
        {
            var success = await _hybridLogService.SwitchToDynamoDbReadsAsync();
            return Ok(new { success, message = "Switched to DynamoDB reads" });
        }
        
        [HttpPost("disable-sql-writes")]
        public async Task<IActionResult> DisableSqlWrites()
        {
            var success = await _hybridLogService.DisableSqlWritesAsync();
            return Ok(new { success, message = "SQL writes disabled" });
        }
        
        [HttpGet("validate-consistency")]
        public async Task<IActionResult> ValidateConsistency(
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            var start = startDate ?? DateTime.UtcNow.AddDays(-1);
            var end = endDate ?? DateTime.UtcNow;
            
            var result = await _hybridLogService.ValidateDataConsistencyAsync(start, end);
            
            return Ok(result);
        }
        
        [HttpPost("test-dual-write")]
        public async Task<IActionResult> TestDualWrite()
        {
            var testLog = new IntegrationLog
            {
                LogType = "TEST",
                ServiceName = "MigrationTestService",
                LogTimestamp = DateTime.UtcNow,
                IsSuccess = true,
                RequestData = "{\"test\": \"dual-write\"}",
                ResponseData = "{\"result\": \"success\"}",
                CorrelationId = Guid.NewGuid().ToString()
            };
            
            var success = await _hybridLogService.WriteLogAsync(testLog);
            
            return Ok(new { success, testLog.LogId, testLog.CorrelationId });
        }
    }
}
```

### 📊 Migration Phase Management

#### Migration Phases Configuration
```json
{
  "MigrationPhases": {
    "Phase0_SqlOnly": {
      "WritesToSql": true,
      "WritesToDynamoDb": false,
      "ReadsFromDynamoDb": false,
      "Description": "Baseline - SQL Server only"
    },
    "Phase1_DualWrite": {
      "WritesToSql": true,
      "WritesToDynamoDb": true,
      "ReadsFromDynamoDb": false,
      "RequireBothWrites": false,
      "Description": "Dual write - SQL primary, DynamoDB secondary"
    },
    "Phase2_DualWriteReadDynamo": {
      "WritesToSql": true,
      "WritesToDynamoDb": true,
      "ReadsFromDynamoDb": true,
      "RequireBothWrites": true,
      "Description": "Dual write with DynamoDB reads"
    },
    "Phase3_DynamoOnly": {
      "WritesToSql": false,
      "WritesToDynamoDb": true,
      "ReadsFromDynamoDb": true,
      "Description": "DynamoDB only - migration complete"
    }
  }
}
```

### 🧪 Testing Strategy

#### Integration Test Example
```csharp
[Test]
public async Task DualWrite_ShouldWriteToBothSystems()
{
    // Arrange
    var config = new HybridLogConfiguration
    {
        WritesToSql = true,
        WritesToDynamoDb = true,
        RequireBothWrites = false
    };
    
    var testLog = new IntegrationLog
    {
        LogType = "TEST",
        ServiceName = "TestService",
        LogTimestamp = DateTime.UtcNow,
        IsSuccess = true
    };
    
    // Act
    var success = await _hybridLogService.WriteLogAsync(testLog);
    
    // Assert
    Assert.IsTrue(success);
    
    // Verify in SQL
    var sqlLog = await _sqlContext.IntegrationLogs
        .FirstOrDefaultAsync(l => l.CorrelationId == testLog.CorrelationId);
    Assert.IsNotNull(sqlLog);
    
    // Verify in DynamoDB
    var dynamoLogs = await _dynamoService.GetLogsByCorrelationIdAsync(testLog.CorrelationId);
    Assert.IsTrue(dynamoLogs.Any());
}
```

### 🚀 Migration Execution Plan

#### Step-by-Step Migration Process
1. **Phase 0**: Baseline (SQL only) - Current state
2. **Phase 1**: Enable dual-write (SQL + DynamoDB writes, SQL reads)
3. **Phase 2**: Switch reads to DynamoDB (SQL + DynamoDB writes, DynamoDB reads)
4. **Phase 3**: Disable SQL writes (DynamoDB only)

#### Rollback Strategy
- Each phase can be reversed by updating configuration
- SQL data remains intact during entire migration
- DynamoDB can be cleared and rebuilt if needed

---

### 💡 Q Developer Integration Points

```
1. "Review this dual-write pattern implementation and suggest improvements for error handling and data consistency."

2. "Analyze the migration phase management and recommend additional safety measures for production deployment."

3. "Examine the validation logic and suggest enhancements for detecting data discrepancies between SQL and DynamoDB."
```

**Next**: [Data Migration Scripts](./07-step4-data-migration.md)