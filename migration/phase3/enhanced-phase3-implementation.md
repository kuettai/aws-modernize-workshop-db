# Enhanced Phase 3: Multi-Table DynamoDB Migration
## Step 4.7 - IntegrationLogs + Payments Hybrid Architecture

### 🎯 Enhanced Phase 3 Objectives
- Migrate both IntegrationLogs AND Payments tables to DynamoDB
- Implement coordinated dual-write pattern for both tables
- Create unified migration orchestration
- Demonstrate comprehensive hybrid architecture
- Provide production-ready multi-table migration framework

### 📊 Architecture Overview

#### Current State (Phase 2)
```
PostgreSQL Aurora:
├── Applications (Transactional)
├── Customers (Transactional) 
├── Loans (Transactional)
├── LoanOfficers (Transactional)
├── Branches (Transactional)
├── IntegrationLogs (High-volume)
└── Payments (High-volume)
```

#### Enhanced Phase 3 Target State
```
PostgreSQL Aurora (Transactional Data):
├── Applications
├── Customers
├── Loans  
├── LoanOfficers
└── Branches

DynamoDB (High-Volume Operational Data):
├── IntegrationLogs (Time-series logging)
└── Payments (Financial transactions)
```

---

## 🚀 Migration Orchestration Framework

### Master Migration Coordinator
```csharp
// Create: LoanApplication/Services/MultiTableMigrationCoordinator.cs
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;

namespace LoanApplication.Services
{
    public class MultiTableMigrationCoordinator
    {
        private readonly IIntegrationLogService _logService;
        private readonly IPaymentService _paymentService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<MultiTableMigrationCoordinator> _logger;

        public MultiTableMigrationCoordinator(
            IIntegrationLogService logService,
            IPaymentService paymentService,
            IConfiguration configuration,
            ILogger<MultiTableMigrationCoordinator> logger)
        {
            _logService = logService;
            _paymentService = paymentService;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<MigrationPhaseResult> ExecutePhaseTransitionAsync(MigrationPhase targetPhase)
        {
            var result = new MigrationPhaseResult { TargetPhase = targetPhase };
            
            try
            {
                _logger.LogInformation("Starting Phase 3 transition to {Phase}", targetPhase);

                // Validate prerequisites
                await ValidatePrerequisitesAsync(targetPhase);

                // Execute coordinated transition
                switch (targetPhase)
                {
                    case MigrationPhase.DualWrite:
                        result = await EnableDualWriteAsync();
                        break;
                    case MigrationPhase.HybridRead:
                        result = await EnableHybridReadAsync();
                        break;
                    case MigrationPhase.DynamoDBOnly:
                        result = await EnableDynamoDBOnlyAsync();
                        break;
                }

                _logger.LogInformation("Phase 3 transition completed: {Success}", result.Success);
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Phase 3 transition failed");
                result.Success = false;
                result.ErrorMessage = ex.Message;
                return result;
            }
        }

        private async Task<MigrationPhaseResult> EnableDualWriteAsync()
        {
            // Enable dual-write for both tables simultaneously
            var tasks = new[]
            {
                UpdateConfigurationAsync("IntegrationLogSettings:EnableDynamoDBWrites", true),
                UpdateConfigurationAsync("PaymentSettings:EnableDynamoDBWrites", true)
            };

            await Task.WhenAll(tasks);

            // Validate dual-write is working
            var validation = await ValidateDualWriteAsync();
            
            return new MigrationPhaseResult
            {
                TargetPhase = MigrationPhase.DualWrite,
                Success = validation.Success,
                Details = validation.Details
            };
        }

        private async Task<MigrationPhaseResult> EnableHybridReadAsync()
        {
            // Switch reads to DynamoDB for both tables
            var tasks = new[]
            {
                UpdateConfigurationAsync("IntegrationLogSettings:ReadFromDynamoDB", true),
                UpdateConfigurationAsync("PaymentSettings:ReadFromDynamoDB", true)
            };

            await Task.WhenAll(tasks);

            // Validate hybrid reads are working
            var validation = await ValidateHybridReadAsync();
            
            return new MigrationPhaseResult
            {
                TargetPhase = MigrationPhase.HybridRead,
                Success = validation.Success,
                Details = validation.Details
            };
        }
    }
}

public enum MigrationPhase
{
    PostgreSQLOnly,
    DualWrite,
    HybridRead,
    DynamoDBOnly
}

public class MigrationPhaseResult
{
    public MigrationPhase TargetPhase { get; set; }
    public bool Success { get; set; }
    public string ErrorMessage { get; set; }
    public Dictionary<string, object> Details { get; set; } = new();
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
}
```

---

## 🔄 Coordinated Dual-Write Implementation

### Enhanced Configuration Management
```json
// appsettings.json - Enhanced Phase 3 Configuration
{
  "Phase3Settings": {
    "MigrationPhase": "DualWrite",
    "EnableCoordinatedWrites": true,
    "EnablePerformanceMonitoring": true,
    "FailureHandling": "LogAndContinue"
  },
  "IntegrationLogSettings": {
    "EnableDynamoDBWrites": true,
    "ReadFromDynamoDB": false,
    "EnableFallbackReads": true,
    "BatchSize": 25
  },
  "PaymentSettings": {
    "EnableDynamoDBWrites": true,
    "ReadFromDynamoDB": false,
    "EnableFallbackReads": true,
    "BatchSize": 25
  },
  "DynamoDB": {
    "Tables": {
      "IntegrationLogs": "IntegrationLogs",
      "Payments": "Payments"
    },
    "Region": "us-east-1"
  }
}
```

### Coordinated Write Service
```csharp
// LoanApplication/Services/CoordinatedWriteService.cs
public class CoordinatedWriteService
{
    private readonly IIntegrationLogService _logService;
    private readonly IPaymentService _paymentService;
    private readonly ILogger<CoordinatedWriteService> _logger;

    public async Task<CoordinatedWriteResult> ExecuteCoordinatedOperationAsync<T>(
        Func<Task<T>> operation,
        string operationType,
        Dictionary<string, object> context = null)
    {
        var correlationId = Guid.NewGuid().ToString();
        var result = new CoordinatedWriteResult { CorrelationId = correlationId };

        try
        {
            // Log operation start to both systems
            await LogOperationStartAsync(correlationId, operationType, context);

            // Execute the main operation
            var operationResult = await operation();
            result.Success = true;
            result.Result = operationResult;

            // Log operation success
            await LogOperationSuccessAsync(correlationId, operationType, operationResult);

            return result;
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.ErrorMessage = ex.Message;

            // Log operation failure
            await LogOperationFailureAsync(correlationId, operationType, ex);
            
            throw;
        }
    }

    private async Task LogOperationStartAsync(string correlationId, string operationType, Dictionary<string, object> context)
    {
        var logEntry = new IntegrationLogEntry
        {
            CorrelationId = correlationId,
            LogType = "OPERATION_START",
            ServiceName = "CoordinatedWriteService",
            RequestData = JsonSerializer.Serialize(new { OperationType = operationType, Context = context }),
            LogTimestamp = DateTime.UtcNow
        };

        // This will write to both PostgreSQL and DynamoDB if dual-write is enabled
        await _logService.LogAsync(logEntry);
    }
}
```

---

## 📊 Multi-Table Migration Scripts

### Enhanced Migration Console Application
```csharp
// Create: MultiTableMigrationConsole/Program.cs
class Program
{
    static async Task Main(string[] args)
    {
        var host = CreateHostBuilder(args).Build();
        var logger = host.Services.GetRequiredService<ILogger<Program>>();

        try
        {
            logger.LogInformation("=== Enhanced Phase 3: Multi-Table Migration ===");

            var migrationCoordinator = host.Services.GetRequiredService<MultiTableMigrationCoordinator>();
            var integrationLogMigrator = host.Services.GetRequiredService<IntegrationLogMigrator>();
            var paymentMigrator = host.Services.GetRequiredService<PaymentBatchMigrator>();

            // Step 1: Validate both tables are ready
            logger.LogInformation("Step 1: Validating DynamoDB tables...");
            await ValidateTablesAsync(host.Services);

            // Step 2: Execute parallel historical data migration
            logger.LogInformation("Step 2: Starting parallel historical data migration...");
            var migrationTasks = new[]
            {
                MigrateIntegrationLogsAsync(integrationLogMigrator, logger),
                MigratePaymentsAsync(paymentMigrator, logger)
            };

            var migrationResults = await Task.WhenAll(migrationTasks);
            
            // Step 3: Enable coordinated dual-write
            logger.LogInformation("Step 3: Enabling coordinated dual-write...");
            var dualWriteResult = await migrationCoordinator.ExecutePhaseTransitionAsync(MigrationPhase.DualWrite);
            
            if (!dualWriteResult.Success)
            {
                logger.LogError("Dual-write enablement failed: {Error}", dualWriteResult.ErrorMessage);
                return;
            }

            // Step 4: Validate coordinated operations
            logger.LogInformation("Step 4: Validating coordinated operations...");
            await ValidateCoordinatedOperationsAsync(host.Services);

            logger.LogInformation("Enhanced Phase 3 migration completed successfully!");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Enhanced Phase 3 migration failed");
        }
    }

    private static async Task<MigrationResult> MigrateIntegrationLogsAsync(IntegrationLogMigrator migrator, ILogger logger)
    {
        logger.LogInformation("Starting IntegrationLogs migration...");
        var options = new MigrationOptions
        {
            StartDate = DateTime.Parse("2020-01-01"),
            EndDate = DateTime.UtcNow,
            MaxErrors = 100
        };
        
        return await migrator.MigrateLogsAsync(options);
    }

    private static async Task<MigrationResult> MigratePaymentsAsync(PaymentBatchMigrator migrator, ILogger logger)
    {
        logger.LogInformation("Starting Payments migration...");
        var options = new MigrationOptions
        {
            StartDate = DateTime.Parse("2020-01-01"),
            EndDate = DateTime.UtcNow,
            MaxErrors = 100
        };
        
        return await migrator.MigratePaymentsAsync(options);
    }
}
```

### Parallel Migration Monitor
```powershell
# Monitor-MultiTableMigration.ps1
param(
    [string]$IntegrationLogMigrationId,
    [string]$PaymentMigrationId,
    [int]$RefreshIntervalSeconds = 30
)

Write-Host "=== Multi-Table Migration Monitor ===" -ForegroundColor Cyan

do {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Monitor IntegrationLogs migration
    $logState = aws dynamodb get-item `
        --table-name IntegrationLogMigrationState `
        --key "{\"MigrationId\":{\"S\":\"$IntegrationLogMigrationId\"}}" `
        --query 'Item' | ConvertFrom-Json
    
    # Monitor Payments migration
    $paymentState = aws dynamodb get-item `
        --table-name PaymentMigrationState `
        --key "{\"MigrationId\":{\"S\":\"$PaymentMigrationId\"}}" `
        --query 'Item' | ConvertFrom-Json
    
    # Display status
    Write-Host "[$timestamp] Migration Status:" -ForegroundColor Yellow
    
    if ($logState) {
        $logOffset = [int]$logState.LastProcessedOffset.N
        $logStatus = $logState.Status.S
        Write-Host "  IntegrationLogs: $logStatus | Processed: $logOffset" -ForegroundColor Green
    }
    
    if ($paymentState) {
        $paymentOffset = [int]$paymentState.LastProcessedOffset.N
        $paymentStatus = $paymentState.Status.S
        Write-Host "  Payments: $paymentStatus | Processed: $paymentOffset" -ForegroundColor Green
    }
    
    # Check DynamoDB table counts
    $logCount = aws dynamodb scan --table-name IntegrationLogs --select COUNT --query 'Count'
    $paymentCount = aws dynamodb scan --table-name Payments --select COUNT --query 'Count'
    
    Write-Host "  DynamoDB Counts: Logs=$logCount, Payments=$paymentCount" -ForegroundColor Cyan
    
    if ($logStatus -eq "Completed" -and $paymentStatus -eq "Completed") {
        Write-Host "Both migrations completed successfully!" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds $RefreshIntervalSeconds
} while ($true)
```

---

## 🔍 Enhanced Validation Framework

### Multi-Table Validation Service
```csharp
// LoanApplication/Services/MultiTableValidationService.cs
public class MultiTableValidationService
{
    public async Task<MultiTableValidationResult> ValidatePhase3MigrationAsync()
    {
        var result = new MultiTableValidationResult();
        
        // Validate IntegrationLogs migration
        result.IntegrationLogsValidation = await ValidateIntegrationLogsAsync();
        
        // Validate Payments migration
        result.PaymentsValidation = await ValidatePaymentsAsync();
        
        // Validate coordinated operations
        result.CoordinatedOperationsValidation = await ValidateCoordinatedOperationsAsync();
        
        // Overall success
        result.OverallSuccess = result.IntegrationLogsValidation.Success &&
                               result.PaymentsValidation.Success &&
                               result.CoordinatedOperationsValidation.Success;
        
        return result;
    }

    private async Task<TableValidationResult> ValidateIntegrationLogsAsync()
    {
        var result = new TableValidationResult { TableName = "IntegrationLogs" };
        
        try
        {
            // Count validation
            var pgCount = await GetPostgreSQLLogCountAsync();
            var dynamoCount = await GetDynamoDBLogCountAsync();
            
            result.PostgreSQLCount = pgCount;
            result.DynamoDBCount = dynamoCount;
            result.CountMatch = Math.Abs(pgCount - dynamoCount) <= (pgCount * 0.01); // Allow 1% variance
            
            // Sample validation
            result.SampleValidation = await ValidateLogSampleDataAsync(100);
            
            // Performance validation
            result.PerformanceValidation = await ValidateLogQueryPerformanceAsync();
            
            result.Success = result.CountMatch && 
                           result.SampleValidation.SuccessRate >= 0.95 &&
                           result.PerformanceValidation.AverageLatency < 100;
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.ErrorMessage = ex.Message;
        }
        
        return result;
    }

    private async Task<CoordinatedOperationValidationResult> ValidateCoordinatedOperationsAsync()
    {
        var result = new CoordinatedOperationValidationResult();
        
        try
        {
            // Test coordinated write operation
            var testPayment = CreateTestPayment();
            var writeResult = await ExecuteTestCoordinatedWriteAsync(testPayment);
            
            // Verify data appears in both systems
            var pgPayment = await GetPostgreSQLPaymentAsync(testPayment.PaymentId);
            var dynamoPayment = await GetDynamoDBPaymentAsync(testPayment.CustomerId, testPayment.PaymentId);
            var pgLog = await GetPostgreSQLLogAsync(writeResult.CorrelationId);
            var dynamoLog = await GetDynamoDBLogAsync(writeResult.CorrelationId);
            
            result.PaymentDualWriteSuccess = pgPayment != null && dynamoPayment != null;
            result.LogDualWriteSuccess = pgLog != null && dynamoLog != null;
            result.DataConsistency = ValidateDataConsistency(pgPayment, dynamoPayment);
            
            result.Success = result.PaymentDualWriteSuccess && 
                           result.LogDualWriteSuccess && 
                           result.DataConsistency;
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.ErrorMessage = ex.Message;
        }
        
        return result;
    }
}

public class MultiTableValidationResult
{
    public TableValidationResult IntegrationLogsValidation { get; set; }
    public TableValidationResult PaymentsValidation { get; set; }
    public CoordinatedOperationValidationResult CoordinatedOperationsValidation { get; set; }
    public bool OverallSuccess { get; set; }
    public DateTime ValidatedAt { get; set; } = DateTime.UtcNow;
}
```

---

## 📈 Performance Monitoring Dashboard

### Multi-Table Performance Metrics
```csharp
// LoanApplication/Services/Phase3PerformanceMonitor.cs
public class Phase3PerformanceMonitor
{
    public async Task<Phase3PerformanceReport> GeneratePerformanceReportAsync()
    {
        var report = new Phase3PerformanceReport();
        
        // IntegrationLogs performance
        report.IntegrationLogsMetrics = await MeasureIntegrationLogPerformanceAsync();
        
        // Payments performance
        report.PaymentsMetrics = await MeasurePaymentPerformanceAsync();
        
        // Coordinated operations performance
        report.CoordinatedOperationsMetrics = await MeasureCoordinatedOperationPerformanceAsync();
        
        // Cost analysis
        report.CostAnalysis = await CalculateCostSavingsAsync();
        
        return report;
    }

    private async Task<PerformanceMetrics> MeasureIntegrationLogPerformanceAsync()
    {
        var metrics = new PerformanceMetrics { TableName = "IntegrationLogs" };
        
        // Measure PostgreSQL performance
        var pgStartTime = DateTime.UtcNow;
        var pgLogs = await GetRecentLogsFromPostgreSQLAsync(1000);
        var pgDuration = DateTime.UtcNow - pgStartTime;
        
        // Measure DynamoDB performance
        var dynamoStartTime = DateTime.UtcNow;
        var dynamoLogs = await GetRecentLogsFromDynamoDBAsync(1000);
        var dynamoDuration = DateTime.UtcNow - dynamoStartTime;
        
        metrics.PostgreSQLLatency = pgDuration.TotalMilliseconds;
        metrics.DynamoDBLatency = dynamoDuration.TotalMilliseconds;
        metrics.PerformanceImprovement = ((pgDuration.TotalMilliseconds - dynamoDuration.TotalMilliseconds) / pgDuration.TotalMilliseconds) * 100;
        
        return metrics;
    }
}

public class Phase3PerformanceReport
{
    public PerformanceMetrics IntegrationLogsMetrics { get; set; }
    public PerformanceMetrics PaymentsMetrics { get; set; }
    public PerformanceMetrics CoordinatedOperationsMetrics { get; set; }
    public CostAnalysis CostAnalysis { get; set; }
    public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;
}
```

---

## 🎯 Enhanced Phase 3 Success Criteria

### Technical Validation ✅
- [ ] **Dual-Table Migration**: Both IntegrationLogs and Payments migrated successfully
- [ ] **Data Integrity**: 99%+ data consistency between PostgreSQL and DynamoDB
- [ ] **Coordinated Operations**: Dual-write pattern working for both tables
- [ ] **Performance Targets**: DynamoDB queries 50%+ faster than PostgreSQL
- [ ] **Error Handling**: Graceful degradation when either system is unavailable

### Business Validation ✅
- [ ] **Cost Optimization**: 80%+ cost reduction for high-volume operations
- [ ] **Scalability**: Handle 10x traffic increase without performance degradation
- [ ] **Reliability**: 99.9% uptime during migration transition
- [ ] **Compliance**: Maintain audit trail and data retention requirements

### Operational Validation ✅
- [ ] **Monitoring**: Comprehensive dashboards for both table migrations
- [ ] **Alerting**: Proactive notifications for migration issues
- [ ] **Rollback**: Tested procedures to revert to PostgreSQL-only
- [ ] **Documentation**: Complete runbooks for production deployment

---

## 🚀 Production Deployment Checklist

### Pre-Deployment ✅
- [ ] DynamoDB tables created with proper throughput settings
- [ ] IAM roles and policies configured for both tables
- [ ] Migration state tables created
- [ ] Monitoring and alerting configured
- [ ] Rollback procedures tested

### Deployment Phases ✅
- [ ] **Phase 1**: Historical data migration (parallel execution)
- [ ] **Phase 2**: Enable dual-write for both tables
- [ ] **Phase 3**: Switch reads to DynamoDB with fallback
- [ ] **Phase 4**: Monitor and optimize performance
- [ ] **Phase 5**: Cleanup PostgreSQL operational data (optional)

### Post-Deployment ✅
- [ ] Validate all success criteria met
- [ ] Performance monitoring active
- [ ] Cost tracking configured
- [ ] Team training on new architecture completed
- [ ] Documentation updated for operational procedures

**Enhanced Phase 3 provides a complete, production-ready multi-table DynamoDB migration framework with coordinated operations, comprehensive monitoring, and proven patterns for hybrid cloud architectures.**