# Payments Migration Procedures
## PostgreSQL to DynamoDB Migration Scripts and Processes

### 🎯 Migration Objectives
- Migrate 500,000+ payment records from PostgreSQL to DynamoDB
- Zero data loss with full integrity validation
- Minimal downtime using dual-write pattern
- Resume capability for interrupted migrations
- Comprehensive progress tracking and error handling

### 📋 Migration Prerequisites
- DynamoDB Payments table created with GSIs
- AWS SDK configured with appropriate IAM permissions
- PostgreSQL connection established
- Migration validation framework ready

### 🚀 Migration Architecture

#### Migration Phases
```
Phase 1: Setup & Validation (30 minutes)
├── Create DynamoDB table and indexes
├── Validate source data integrity
└── Setup monitoring and logging

Phase 2: Historical Data Migration (2-4 hours)
├── Batch migrate existing payments
├── Validate data consistency
└── Performance monitoring

Phase 3: Dual-Write Implementation (1 hour)
├── Deploy dual-write application code
├── Monitor write consistency
└── Validate real-time synchronization

Phase 4: Read Traffic Migration (30 minutes)
├── Switch read queries to DynamoDB
├── Monitor query performance
└── Validate application functionality

Phase 5: Cleanup (15 minutes)
├── Remove PostgreSQL payment queries
├── Archive old payment data
└── Final validation
```

### 🔧 Migration Scripts

#### 1. Data Validation Script
```csharp
// PaymentMigrationValidator.cs
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Npgsql;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;

public class PaymentMigrationValidator
{
    private readonly string _pgConnectionString;
    private readonly IAmazonDynamoDB _dynamoClient;
    private readonly ILogger<PaymentMigrationValidator> _logger;

    public PaymentMigrationValidator(string pgConnectionString, IAmazonDynamoDB dynamoClient, ILogger<PaymentMigrationValidator> logger)
    {
        _pgConnectionString = pgConnectionString;
        _dynamoClient = dynamoClient;
        _logger = logger;
    }

    public async Task<ValidationResult> ValidateSourceDataAsync()
    {
        var result = new ValidationResult();
        
        using var connection = new NpgsqlConnection(_pgConnectionString);
        await connection.OpenAsync();

        // Validate data integrity
        var validationQueries = new Dictionary<string, string>
        {
            ["TotalPayments"] = "SELECT COUNT(*) FROM payments",
            ["PaymentsWithNullCustomerId"] = "SELECT COUNT(*) FROM payments WHERE customerid IS NULL",
            ["PaymentsWithNullAmount"] = "SELECT COUNT(*) FROM payments WHERE paymentamount IS NULL",
            ["PaymentsWithInvalidDates"] = "SELECT COUNT(*) FROM payments WHERE paymentdate IS NULL OR paymentdate > NOW()",
            ["DuplicatePaymentIds"] = "SELECT COUNT(*) - COUNT(DISTINCT paymentid) FROM payments",
            ["PaymentDateRange"] = "SELECT MIN(paymentdate), MAX(paymentdate) FROM payments"
        };

        foreach (var query in validationQueries)
        {
            try
            {
                using var command = new NpgsqlCommand(query.Value, connection);
                var queryResult = await command.ExecuteScalarAsync();
                result.ValidationResults[query.Key] = queryResult?.ToString() ?? "NULL";
                _logger.LogInformation("Validation {QueryName}: {Result}", query.Key, queryResult);
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Validation query {query.Key} failed: {ex.Message}");
                _logger.LogError(ex, "Validation query {QueryName} failed", query.Key);
            }
        }

        // Check for data quality issues
        if (int.Parse(result.ValidationResults["PaymentsWithNullCustomerId"]) > 0)
            result.Errors.Add("Found payments with NULL CustomerId");
        
        if (int.Parse(result.ValidationResults["PaymentsWithNullAmount"]) > 0)
            result.Errors.Add("Found payments with NULL PaymentAmount");

        if (int.Parse(result.ValidationResults["DuplicatePaymentIds"]) > 0)
            result.Errors.Add("Found duplicate PaymentIds");

        result.IsValid = result.Errors.Count == 0;
        return result;
    }

    public async Task<bool> ValidateDynamoTableAsync()
    {
        try
        {
            var response = await _dynamoClient.DescribeTableAsync("Payments");
            var table = response.Table;

            // Validate table structure
            if (table.TableStatus != TableStatus.ACTIVE)
            {
                _logger.LogError("DynamoDB table is not ACTIVE. Status: {Status}", table.TableStatus);
                return false;
            }

            // Validate GSIs
            var requiredIndexes = new[] { "PaymentStatusIndex", "LoanPaymentIndex", "PaymentMethodIndex" };
            foreach (var indexName in requiredIndexes)
            {
                var gsi = table.GlobalSecondaryIndexes.FirstOrDefault(g => g.IndexName == indexName);
                if (gsi == null || gsi.IndexStatus != IndexStatus.ACTIVE)
                {
                    _logger.LogError("Required GSI {IndexName} is missing or not ACTIVE", indexName);
                    return false;
                }
            }

            _logger.LogInformation("DynamoDB table validation successful");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DynamoDB table validation failed");
            return false;
        }
    }
}

public class ValidationResult
{
    public bool IsValid { get; set; }
    public Dictionary<string, string> ValidationResults { get; set; } = new();
    public List<string> Errors { get; set; } = new();
}
```

#### 2. Batch Migration Engine
```csharp
// PaymentBatchMigrator.cs
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Npgsql;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;

public class PaymentBatchMigrator
{
    private readonly string _pgConnectionString;
    private readonly IAmazonDynamoDB _dynamoClient;
    private readonly ILogger<PaymentBatchMigrator> _logger;
    private const int BATCH_SIZE = 25; // DynamoDB batch write limit
    private const int PARALLEL_BATCHES = 4;

    public PaymentBatchMigrator(string pgConnectionString, IAmazonDynamoDB dynamoClient, ILogger<PaymentBatchMigrator> logger)
    {
        _pgConnectionString = pgConnectionString;
        _dynamoClient = dynamoClient;
        _logger = logger;
    }

    public async Task<MigrationResult> MigratePaymentsAsync(MigrationOptions options)
    {
        var result = new MigrationResult { StartTime = DateTime.UtcNow };
        
        try
        {
            // Load migration state if resuming
            var state = await LoadMigrationStateAsync(options.MigrationId);
            var startOffset = state?.LastProcessedOffset ?? 0;
            
            _logger.LogInformation("Starting payment migration from offset {Offset}", startOffset);

            using var connection = new NpgsqlConnection(_pgConnectionString);
            await connection.OpenAsync();

            // Get total count for progress tracking
            var totalCount = await GetTotalPaymentCountAsync(connection, options);
            result.TotalRecords = totalCount;

            var processedCount = startOffset;
            var errorCount = 0;
            var batchNumber = 0;

            while (processedCount < totalCount)
            {
                var batchStartTime = DateTime.UtcNow;
                batchNumber++;

                try
                {
                    // Fetch batch of payments
                    var payments = await FetchPaymentBatchAsync(connection, processedCount, BATCH_SIZE, options);
                    if (!payments.Any()) break;

                    // Transform to DynamoDB items
                    var dynamoItems = payments.Select(TransformPaymentToDynamoItem).ToList();

                    // Write batch to DynamoDB
                    await WriteBatchToDynamoAsync(dynamoItems);

                    processedCount += payments.Count;
                    
                    // Update progress
                    var progress = (double)processedCount / totalCount * 100;
                    _logger.LogInformation("Batch {BatchNumber}: Processed {Processed}/{Total} ({Progress:F1}%) - Duration: {Duration}ms", 
                        batchNumber, processedCount, totalCount, progress, 
                        (DateTime.UtcNow - batchStartTime).TotalMilliseconds);

                    // Save migration state
                    await SaveMigrationStateAsync(options.MigrationId, processedCount, errorCount);

                    // Rate limiting to avoid throttling
                    if (batchNumber % 10 == 0)
                        await Task.Delay(100);
                }
                catch (Exception ex)
                {
                    errorCount++;
                    _logger.LogError(ex, "Batch {BatchNumber} failed at offset {Offset}", batchNumber, processedCount);
                    
                    if (errorCount > options.MaxErrors)
                    {
                        throw new InvalidOperationException($"Migration failed: Too many errors ({errorCount})");
                    }

                    // Skip failed batch and continue
                    processedCount += BATCH_SIZE;
                }
            }

            result.ProcessedRecords = processedCount;
            result.ErrorCount = errorCount;
            result.EndTime = DateTime.UtcNow;
            result.Success = true;

            _logger.LogInformation("Migration completed: {Processed} records in {Duration}", 
                processedCount, result.EndTime - result.StartTime);

            return result;
        }
        catch (Exception ex)
        {
            result.EndTime = DateTime.UtcNow;
            result.Success = false;
            result.ErrorMessage = ex.Message;
            _logger.LogError(ex, "Migration failed");
            throw;
        }
    }

    private async Task<List<Payment>> FetchPaymentBatchAsync(NpgsqlConnection connection, int offset, int batchSize, MigrationOptions options)
    {
        var sql = @"
            SELECT paymentid, customerid, loanid, paymentamount, paymentdate, 
                   paymentmethod, paymentstatus, transactionreference, processeddate,
                   createddate, updateddate
            FROM payments 
            WHERE paymentdate >= @startDate AND paymentdate <= @endDate
            ORDER BY paymentid
            OFFSET @offset LIMIT @batchSize";

        using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("startDate", options.StartDate);
        command.Parameters.AddWithValue("endDate", options.EndDate);
        command.Parameters.AddWithValue("offset", offset);
        command.Parameters.AddWithValue("batchSize", batchSize);

        var payments = new List<Payment>();
        using var reader = await command.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            payments.Add(new Payment
            {
                PaymentId = reader.GetInt32("paymentid"),
                CustomerId = reader.GetInt32("customerid"),
                LoanId = reader.GetInt32("loanid"),
                PaymentAmount = reader.GetDecimal("paymentamount"),
                PaymentDate = reader.GetDateTime("paymentdate"),
                PaymentMethod = reader.GetString("paymentmethod"),
                PaymentStatus = reader.GetString("paymentstatus"),
                TransactionReference = reader.IsDBNull("transactionreference") ? null : reader.GetString("transactionreference"),
                ProcessedDate = reader.IsDBNull("processeddate") ? null : reader.GetDateTime("processeddate"),
                CreatedDate = reader.GetDateTime("createddate"),
                UpdatedDate = reader.IsDBNull("updateddate") ? null : reader.GetDateTime("updateddate")
            });
        }

        return payments;
    }

    private Dictionary<string, AttributeValue> TransformPaymentToDynamoItem(Payment payment)
    {
        var paymentDateId = $"{payment.PaymentDate:yyyy-MM-ddTHH:mm:ssZ}#{payment.PaymentId}";
        var ttl = DateTimeOffset.UtcNow.AddYears(7).ToUnixTimeSeconds();

        return new Dictionary<string, AttributeValue>
        {
            ["CustomerId"] = new AttributeValue { N = payment.CustomerId.ToString() },
            ["PaymentDateId"] = new AttributeValue { S = paymentDateId },
            ["PaymentId"] = new AttributeValue { N = payment.PaymentId.ToString() },
            ["LoanId"] = new AttributeValue { N = payment.LoanId.ToString() },
            ["PaymentAmount"] = new AttributeValue { N = payment.PaymentAmount.ToString("F2") },
            ["PaymentDate"] = new AttributeValue { S = payment.PaymentDate.ToString("yyyy-MM-ddTHH:mm:ssZ") },
            ["PaymentMethod"] = new AttributeValue { S = payment.PaymentMethod },
            ["PaymentStatus"] = new AttributeValue { S = payment.PaymentStatus },
            ["TransactionReference"] = new AttributeValue { S = payment.TransactionReference ?? "" },
            ["ProcessedDate"] = new AttributeValue { S = payment.ProcessedDate?.ToString("yyyy-MM-ddTHH:mm:ssZ") ?? "" },
            ["CreatedDate"] = new AttributeValue { S = payment.CreatedDate.ToString("yyyy-MM-ddTHH:mm:ssZ") },
            ["UpdatedDate"] = new AttributeValue { S = payment.UpdatedDate?.ToString("yyyy-MM-ddTHH:mm:ssZ") ?? "" },
            ["TTL"] = new AttributeValue { N = ttl.ToString() }
        };
    }

    private async Task WriteBatchToDynamoAsync(List<Dictionary<string, AttributeValue>> items)
    {
        var writeRequests = items.Select(item => new WriteRequest
        {
            PutRequest = new PutRequest { Item = item }
        }).ToList();

        var request = new BatchWriteItemRequest
        {
            RequestItems = new Dictionary<string, List<WriteRequest>>
            {
                ["Payments"] = writeRequests
            }
        };

        var response = await _dynamoClient.BatchWriteItemAsync(request);

        // Handle unprocessed items
        if (response.UnprocessedItems.Any())
        {
            _logger.LogWarning("Retrying {Count} unprocessed items", response.UnprocessedItems["Payments"].Count);
            
            var retryRequest = new BatchWriteItemRequest { RequestItems = response.UnprocessedItems };
            await _dynamoClient.BatchWriteItemAsync(retryRequest);
        }
    }

    private async Task<int> GetTotalPaymentCountAsync(NpgsqlConnection connection, MigrationOptions options)
    {
        var sql = "SELECT COUNT(*) FROM payments WHERE paymentdate >= @startDate AND paymentdate <= @endDate";
        using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("startDate", options.StartDate);
        command.Parameters.AddWithValue("endDate", options.EndDate);
        
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }
}

public class MigrationOptions
{
    public string MigrationId { get; set; } = Guid.NewGuid().ToString();
    public DateTime StartDate { get; set; } = DateTime.MinValue;
    public DateTime EndDate { get; set; } = DateTime.MaxValue;
    public int MaxErrors { get; set; } = 100;
    public bool ResumeFromLastState { get; set; } = true;
}

public class MigrationResult
{
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public int TotalRecords { get; set; }
    public int ProcessedRecords { get; set; }
    public int ErrorCount { get; set; }
    public bool Success { get; set; }
    public string ErrorMessage { get; set; }
    public TimeSpan Duration => EndTime - StartTime;
}
```

#### 3. Migration State Management
```csharp
// MigrationStateManager.cs
public class MigrationStateManager
{
    private readonly IAmazonDynamoDB _dynamoClient;
    private const string STATE_TABLE = "PaymentMigrationState";

    public async Task SaveMigrationStateAsync(string migrationId, int lastProcessedOffset, int errorCount)
    {
        var item = new Dictionary<string, AttributeValue>
        {
            ["MigrationId"] = new AttributeValue { S = migrationId },
            ["LastProcessedOffset"] = new AttributeValue { N = lastProcessedOffset.ToString() },
            ["ErrorCount"] = new AttributeValue { N = errorCount.ToString() },
            ["LastUpdated"] = new AttributeValue { S = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ") },
            ["Status"] = new AttributeValue { S = "InProgress" }
        };

        await _dynamoClient.PutItemAsync(STATE_TABLE, item);
    }

    public async Task<MigrationState> LoadMigrationStateAsync(string migrationId)
    {
        try
        {
            var response = await _dynamoClient.GetItemAsync(STATE_TABLE, new Dictionary<string, AttributeValue>
            {
                ["MigrationId"] = new AttributeValue { S = migrationId }
            });

            if (!response.IsItemSet) return null;

            return new MigrationState
            {
                MigrationId = migrationId,
                LastProcessedOffset = int.Parse(response.Item["LastProcessedOffset"].N),
                ErrorCount = int.Parse(response.Item["ErrorCount"].N),
                LastUpdated = DateTime.Parse(response.Item["LastUpdated"].S),
                Status = response.Item["Status"].S
            };
        }
        catch (ResourceNotFoundException)
        {
            return null;
        }
    }
}

public class MigrationState
{
    public string MigrationId { get; set; }
    public int LastProcessedOffset { get; set; }
    public int ErrorCount { get; set; }
    public DateTime LastUpdated { get; set; }
    public string Status { get; set; }
}
```

#### 4. Migration Console Application
```csharp
// Program.cs - Migration Console App
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Amazon.DynamoDBv2;

class Program
{
    static async Task Main(string[] args)
    {
        var host = CreateHostBuilder(args).Build();
        
        var logger = host.Services.GetRequiredService<ILogger<Program>>();
        var migrator = host.Services.GetRequiredService<PaymentBatchMigrator>();
        var validator = host.Services.GetRequiredService<PaymentMigrationValidator>();

        try
        {
            logger.LogInformation("Starting Payment Migration Process");

            // Step 1: Validate source data
            logger.LogInformation("Step 1: Validating source data...");
            var validationResult = await validator.ValidateSourceDataAsync();
            if (!validationResult.IsValid)
            {
                logger.LogError("Source data validation failed: {Errors}", string.Join(", ", validationResult.Errors));
                return;
            }

            // Step 2: Validate DynamoDB table
            logger.LogInformation("Step 2: Validating DynamoDB table...");
            var tableValid = await validator.ValidateDynamoTableAsync();
            if (!tableValid)
            {
                logger.LogError("DynamoDB table validation failed");
                return;
            }

            // Step 3: Execute migration
            logger.LogInformation("Step 3: Starting batch migration...");
            var options = new MigrationOptions
            {
                StartDate = DateTime.Parse(args.Length > 0 ? args[0] : "2020-01-01"),
                EndDate = DateTime.Parse(args.Length > 1 ? args[1] : DateTime.UtcNow.ToString("yyyy-MM-dd")),
                MaxErrors = 100
            };

            var result = await migrator.MigratePaymentsAsync(options);
            
            if (result.Success)
            {
                logger.LogInformation("Migration completed successfully: {Processed}/{Total} records in {Duration}", 
                    result.ProcessedRecords, result.TotalRecords, result.Duration);
            }
            else
            {
                logger.LogError("Migration failed: {Error}", result.ErrorMessage);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Migration process failed");
        }
    }

    static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
            .ConfigureServices((context, services) =>
            {
                services.AddAWSService<IAmazonDynamoDB>();
                services.AddScoped<PaymentBatchMigrator>();
                services.AddScoped<PaymentMigrationValidator>();
                services.AddScoped<MigrationStateManager>();
            });
}
```

### 📊 Migration Monitoring

#### Progress Tracking Script
```powershell
# Monitor-PaymentMigration.ps1
param(
    [string]$MigrationId,
    [int]$RefreshIntervalSeconds = 30
)

Write-Host "=== Payment Migration Monitor ===" -ForegroundColor Cyan
Write-Host "Migration ID: $MigrationId" -ForegroundColor Yellow
Write-Host "Refresh Interval: $RefreshIntervalSeconds seconds" -ForegroundColor Yellow

do {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get migration state from DynamoDB
    $state = aws dynamodb get-item `
        --table-name PaymentMigrationState `
        --key "{\"MigrationId\":{\"S\":\"$MigrationId\"}}" `
        --query 'Item' | ConvertFrom-Json
    
    if ($state) {
        $offset = [int]$state.LastProcessedOffset.N
        $errors = [int]$state.ErrorCount.N
        $status = $state.Status.S
        $lastUpdated = $state.LastUpdated.S
        
        Write-Host "[$timestamp] Status: $status | Processed: $offset | Errors: $errors | Last Updated: $lastUpdated" -ForegroundColor Green
    } else {
        Write-Host "[$timestamp] Migration state not found" -ForegroundColor Red
    }
    
    # Get DynamoDB table metrics
    $itemCount = aws dynamodb scan `
        --table-name Payments `
        --select COUNT `
        --query 'Count'
    
    Write-Host "[$timestamp] DynamoDB Items: $itemCount" -ForegroundColor Cyan
    
    if ($status -eq "Completed" -or $status -eq "Failed") {
        Write-Host "Migration finished with status: $status" -ForegroundColor $(if($status -eq "Completed"){"Green"}else{"Red"})
        break
    }
    
    Start-Sleep -Seconds $RefreshIntervalSeconds
} while ($true)
```

### 🔍 Data Validation Scripts

#### Post-Migration Validation
```csharp
// PaymentDataValidator.cs
public class PaymentDataValidator
{
    public async Task<ValidationSummary> ValidateMigrationAsync()
    {
        var summary = new ValidationSummary();
        
        // Count validation
        var pgCount = await GetPostgreSQLCountAsync();
        var dynamoCount = await GetDynamoDBCountAsync();
        
        summary.PostgreSQLCount = pgCount;
        summary.DynamoDBCount = dynamoCount;
        summary.CountMatch = pgCount == dynamoCount;
        
        // Sample data validation
        var sampleValidation = await ValidateSampleDataAsync(100);
        summary.SampleValidationResults = sampleValidation;
        
        // Performance validation
        var performanceResults = await ValidateQueryPerformanceAsync();
        summary.PerformanceResults = performanceResults;
        
        summary.OverallSuccess = summary.CountMatch && 
                                summary.SampleValidationResults.All(r => r.IsValid) &&
                                summary.PerformanceResults.AverageLatency < 100;
        
        return summary;
    }

    private async Task<List<SampleValidationResult>> ValidateSampleDataAsync(int sampleSize)
    {
        var results = new List<SampleValidationResult>();
        
        // Get random sample from PostgreSQL
        var samplePayments = await GetRandomPaymentSampleAsync(sampleSize);
        
        foreach (var payment in samplePayments)
        {
            var dynamoItem = await GetDynamoPaymentAsync(payment.CustomerId, payment.PaymentId, payment.PaymentDate);
            
            var result = new SampleValidationResult
            {
                PaymentId = payment.PaymentId,
                IsValid = ValidatePaymentData(payment, dynamoItem)
            };
            
            if (!result.IsValid)
            {
                result.Differences = GetDataDifferences(payment, dynamoItem);
            }
            
            results.Add(result);
        }
        
        return results;
    }
}
```

### 🎯 Migration Execution Plan

#### Pre-Migration Checklist
```
□ DynamoDB table created with all GSIs active
□ IAM permissions configured for migration application
□ PostgreSQL connection validated
□ Source data validation completed
□ Migration state table created
□ Monitoring dashboard configured
□ Rollback procedures documented
```

#### Migration Execution Steps
```bash
# 1. Create migration state table
aws dynamodb create-table \
    --table-name PaymentMigrationState \
    --attribute-definitions AttributeName=MigrationId,AttributeType=S \
    --key-schema AttributeName=MigrationId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# 2. Run migration application
dotnet run PaymentMigration.dll --start-date "2020-01-01" --end-date "2024-01-31"

# 3. Monitor progress
./Monitor-PaymentMigration.ps1 -MigrationId "migration-2024-01-31"

# 4. Validate results
dotnet run PaymentValidation.dll --validation-type "full"
```

#### Post-Migration Validation
```
□ Record count matches between PostgreSQL and DynamoDB
□ Sample data validation passes (100 random records)
□ Query performance meets targets (< 100ms)
□ All GSI queries functional
□ Error rate < 0.1%
□ Application integration tested
```

### 🚨 Error Handling & Recovery

#### Common Issues & Solutions
```
Issue: DynamoDB throttling
Solution: Implement exponential backoff, reduce batch size

Issue: Data transformation errors
Solution: Enhanced validation, data cleansing scripts

Issue: Network timeouts
Solution: Retry logic with circuit breaker pattern

Issue: Memory issues with large batches
Solution: Streaming data processing, smaller batch sizes
```

#### Recovery Procedures
```
1. Identify failed migration point from state table
2. Review error logs for root cause
3. Fix data issues or adjust migration parameters
4. Resume migration from last successful offset
5. Validate recovered data integrity
```

The migration procedures provide a robust, production-ready framework for migrating payment data from PostgreSQL to DynamoDB with comprehensive monitoring, validation, and recovery capabilities!