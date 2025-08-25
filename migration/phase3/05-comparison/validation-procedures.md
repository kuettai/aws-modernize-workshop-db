# Validation Procedures
## Phase 3: DynamoDB Migration - Testing and Validation

### 🎯 Objective
Comprehensive validation procedures to ensure successful migration from PostgreSQL to DynamoDB with data integrity, performance verification, and functional testing.

### 🧪 Validation Test Suite

#### ValidationService.cs
```csharp
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using LoanApplication.Data;
using LoanApplication.Services;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;
using System.Text.Json;

namespace LoanApplication.Services
{
    public interface IValidationService
    {
        Task<ValidationReport> RunFullValidationAsync(ValidationConfig config);
        Task<DataIntegrityResult> ValidateDataIntegrityAsync(DateTime startDate, DateTime endDate);
        Task<PerformanceComparisonResult> ComparePerformanceAsync(int sampleSize = 1000);
        Task<FunctionalTestResult> RunFunctionalTestsAsync();
    }
    
    public class ValidationService : IValidationService
    {
        private readonly LoanApplicationContext _sqlContext;
        private readonly IDynamoDbLogService _dynamoService;
        private readonly IAmazonDynamoDB _dynamoClient;
        private readonly ILogger<ValidationService> _logger;
        private readonly string _tableName;
        
        public ValidationService(
            LoanApplicationContext sqlContext,
            IDynamoDbLogService dynamoService,
            IAmazonDynamoDB dynamoClient,
            ILogger<ValidationService> logger,
            IConfiguration configuration)
        {
            _sqlContext = sqlContext;
            _dynamoService = dynamoService;
            _dynamoClient = dynamoClient;
            _logger = logger;
            _tableName = configuration["DynamoDB:TableName"] ?? "LoanApp-IntegrationLogs-dev";
        }
        
        public async Task<ValidationReport> RunFullValidationAsync(ValidationConfig config)
        {
            var report = new ValidationReport
            {
                StartTime = DateTime.UtcNow,
                Configuration = config
            };
            
            try
            {
                _logger.LogInformation("Starting full validation suite");
                
                // 1. Data Integrity Validation
                _logger.LogInformation("Running data integrity validation");
                report.DataIntegrity = await ValidateDataIntegrityAsync(config.StartDate, config.EndDate);
                
                // 2. Performance Comparison
                if (config.IncludePerformanceTests)
                {
                    _logger.LogInformation("Running performance comparison");
                    report.Performance = await ComparePerformanceAsync(config.PerformanceSampleSize);
                }
                
                // 3. Functional Tests
                if (config.IncludeFunctionalTests)
                {
                    _logger.LogInformation("Running functional tests");
                    report.Functional = await RunFunctionalTestsAsync();
                }
                
                // 4. Schema Validation
                _logger.LogInformation("Running schema validation");
                report.Schema = await ValidateSchemaConsistencyAsync();
                
                // 5. Query Pattern Validation
                _logger.LogInformation("Running query pattern validation");
                report.QueryPatterns = await ValidateQueryPatternsAsync();
                
                report.EndTime = DateTime.UtcNow;
                report.Duration = report.EndTime.Value - report.StartTime;
                report.OverallResult = DetermineOverallResult(report);
                
                _logger.LogInformation("Validation completed. Overall result: {Result}", report.OverallResult);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Validation suite failed");
                report.Errors.Add($"Validation suite failed: {ex.Message}");
                report.OverallResult = ValidationResult.Failed;
            }
            
            return report;
        }
        
        public async Task<DataIntegrityResult> ValidateDataIntegrityAsync(DateTime startDate, DateTime endDate)
        {
            var result = new DataIntegrityResult
            {
                StartDate = startDate,
                EndDate = endDate,
                StartTime = DateTime.UtcNow
            };
            
            try
            {
                // Get SQL record count
                result.SqlRecordCount = await _sqlContext.IntegrationLogs
                    .Where(l => l.LogTimestamp >= startDate && l.LogTimestamp <= endDate)
                    .CountAsync();
                
                // Get DynamoDB record count (approximate)
                result.DynamoDbRecordCount = await GetDynamoDbRecordCountAsync(startDate, endDate);
                
                // Calculate variance
                var variance = Math.Abs(result.SqlRecordCount - result.DynamoDbRecordCount);
                var tolerance = Math.Max(1, result.SqlRecordCount * 0.01); // 1% tolerance
                
                result.IsConsistent = variance <= tolerance;
                result.VarianceCount = variance;
                result.VariancePercentage = result.SqlRecordCount > 0 
                    ? (double)variance / result.SqlRecordCount * 100 
                    : 0;
                
                // Sample record validation
                if (result.IsConsistent)
                {
                    result.SampleValidation = await ValidateSampleRecordsAsync(startDate, endDate, 100);
                }
                
                result.EndTime = DateTime.UtcNow;
                result.Duration = result.EndTime.Value - result.StartTime;
                
                _logger.LogInformation("Data integrity validation: SQL={SqlCount}, DynamoDB={DynamoCount}, Consistent={IsConsistent}",
                    result.SqlRecordCount, result.DynamoDbRecordCount, result.IsConsistent);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Data integrity validation failed");
                result.Errors.Add($"Data integrity validation failed: {ex.Message}");
            }
            
            return result;
        }
        
        public async Task<PerformanceComparisonResult> ComparePerformanceAsync(int sampleSize = 1000)
        {
            var result = new PerformanceComparisonResult
            {
                SampleSize = sampleSize,
                StartTime = DateTime.UtcNow
            };
            
            try
            {
                var testApplicationId = await GetRandomApplicationIdAsync();
                var testServiceName = "CreditCheckService";
                var testDate = DateTime.UtcNow.Date;
                
                // Test 1: Single record retrieval by Application ID
                result.SingleRecordRetrieval = await CompareQueryPerformanceAsync(
                    "Single Record by Application ID",
                    async () => await _sqlContext.IntegrationLogs
                        .Where(l => l.ApplicationId == testApplicationId)
                        .FirstOrDefaultAsync(),
                    async () => (await _dynamoService.GetLogsByApplicationIdAsync(testApplicationId)).FirstOrDefault()
                );
                
                // Test 2: Time range query
                var startTime = testDate.AddHours(-1);
                var endTime = testDate;
                
                result.TimeRangeQuery = await CompareQueryPerformanceAsync(
                    "Time Range Query",
                    async () => await _sqlContext.IntegrationLogs
                        .Where(l => l.ServiceName == testServiceName 
                                && l.LogTimestamp >= startTime 
                                && l.LogTimestamp <= endTime)
                        .ToListAsync(),
                    async () => await _dynamoService.GetLogsByServiceAndTimeRangeAsync(testServiceName, startTime, endTime)
                );
                
                // Test 3: Error log retrieval
                result.ErrorLogQuery = await CompareQueryPerformanceAsync(
                    "Error Log Query",
                    async () => await _sqlContext.IntegrationLogs
                        .Where(l => !l.IsSuccess && l.LogTimestamp.Date == testDate)
                        .ToListAsync(),
                    async () => await _dynamoService.GetErrorLogsByDateAsync(testDate)
                );
                
                // Test 4: Count query
                result.CountQuery = await CompareQueryPerformanceAsync(
                    "Count Query",
                    async () => await _sqlContext.IntegrationLogs.CountAsync(),
                    async () => await _dynamoService.GetLogCountByServiceAsync(testServiceName, testDate)
                );
                
                result.EndTime = DateTime.UtcNow;
                result.Duration = result.EndTime.Value - result.StartTime;
                
                _logger.LogInformation("Performance comparison completed");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Performance comparison failed");
                result.Errors.Add($"Performance comparison failed: {ex.Message}");
            }
            
            return result;
        }
        
        public async Task<FunctionalTestResult> RunFunctionalTestsAsync()
        {
            var result = new FunctionalTestResult
            {
                StartTime = DateTime.UtcNow
            };
            
            try
            {
                var tests = new List<FunctionalTest>();
                
                // Test 1: Write and Read Consistency
                tests.Add(await TestWriteReadConsistencyAsync());
                
                // Test 2: Batch Write Operations
                tests.Add(await TestBatchWriteOperationsAsync());
                
                // Test 3: Query Pattern Functionality
                tests.Add(await TestQueryPatternFunctionalityAsync());
                
                // Test 4: Error Handling
                tests.Add(await TestErrorHandlingAsync());
                
                // Test 5: TTL Functionality
                tests.Add(await TestTTLFunctionalityAsync());
                
                result.Tests = tests;
                result.PassedTests = tests.Count(t => t.Passed);
                result.FailedTests = tests.Count(t => !t.Passed);
                result.OverallPassed = result.FailedTests == 0;
                
                result.EndTime = DateTime.UtcNow;
                result.Duration = result.EndTime.Value - result.StartTime;
                
                _logger.LogInformation("Functional tests completed. Passed: {Passed}, Failed: {Failed}",
                    result.PassedTests, result.FailedTests);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Functional tests failed");
                result.Errors.Add($"Functional tests failed: {ex.Message}");
            }
            
            return result;
        }
        
        private async Task<long> GetDynamoDbRecordCountAsync(DateTime startDate, DateTime endDate)
        {
            // DynamoDB doesn't have efficient count operations, so we'll estimate
            // In production, you might maintain count in a separate table or use CloudWatch metrics
            
            var services = new[] { "CreditCheckService", "LoanProcessingService", "DocumentService" };
            long totalCount = 0;
            
            foreach (var service in services)
            {
                var logs = await _dynamoService.GetLogsByServiceAndTimeRangeAsync(service, startDate, endDate);
                totalCount += logs.Count();
            }
            
            return totalCount;
        }
        
        private async Task<SampleValidationResult> ValidateSampleRecordsAsync(DateTime startDate, DateTime endDate, int sampleSize)
        {
            var result = new SampleValidationResult { SampleSize = sampleSize };
            
            try
            {
                // Get random sample from SQL
                var sqlSample = await _sqlContext.IntegrationLogs
                    .Where(l => l.LogTimestamp >= startDate && l.LogTimestamp <= endDate)
                    .OrderBy(l => Guid.NewGuid())
                    .Take(sampleSize)
                    .ToListAsync();
                
                var matchedRecords = 0;
                var discrepancies = new List<string>();
                
                foreach (var sqlRecord in sqlSample)
                {
                    // Try to find matching record in DynamoDB
                    var dynamoRecord = await _dynamoService.GetLogByIdAsync(
                        sqlRecord.ServiceName, 
                        sqlRecord.LogTimestamp, 
                        sqlRecord.LogId);
                    
                    if (dynamoRecord != null)
                    {
                        matchedRecords++;
                        
                        // Validate key fields
                        if (sqlRecord.LogType != dynamoRecord.LogType ||
                            sqlRecord.IsSuccess != dynamoRecord.IsSuccess ||
                            Math.Abs((sqlRecord.LogTimestamp - dynamoRecord.LogTimestamp).TotalSeconds) > 1)
                        {
                            discrepancies.Add($"LogId {sqlRecord.LogId}: Field mismatch detected");
                        }
                    }
                    else
                    {
                        discrepancies.Add($"LogId {sqlRecord.LogId}: Not found in DynamoDB");
                    }
                }
                
                result.MatchedRecords = matchedRecords;
                result.MissingRecords = sampleSize - matchedRecords;
                result.Discrepancies = discrepancies;
                result.MatchPercentage = (double)matchedRecords / sampleSize * 100;
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Sample validation failed: {ex.Message}");
            }
            
            return result;
        }
        
        private async Task<QueryPerformanceResult> CompareQueryPerformanceAsync<T>(
            string testName,
            Func<Task<T>> sqlQuery,
            Func<Task<T>> dynamoQuery)
        {
            var result = new QueryPerformanceResult { TestName = testName };
            
            try
            {
                // Test SQL performance
                var sqlStopwatch = Stopwatch.StartNew();
                var sqlResult = await sqlQuery();
                sqlStopwatch.Stop();
                result.SqlResponseTime = sqlStopwatch.Elapsed;
                
                // Test DynamoDB performance
                var dynamoStopwatch = Stopwatch.StartNew();
                var dynamoResult = await dynamoQuery();
                dynamoStopwatch.Stop();
                result.DynamoDbResponseTime = dynamoStopwatch.Elapsed;
                
                // Calculate improvement
                result.PerformanceImprovement = result.SqlResponseTime > result.DynamoDbResponseTime
                    ? (result.SqlResponseTime.TotalMilliseconds - result.DynamoDbResponseTime.TotalMilliseconds) / result.SqlResponseTime.TotalMilliseconds * 100
                    : -((result.DynamoDbResponseTime.TotalMilliseconds - result.SqlResponseTime.TotalMilliseconds) / result.SqlResponseTime.TotalMilliseconds * 100);
                
                result.Success = true;
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Performance comparison failed: {ex.Message}");
                result.Success = false;
            }
            
            return result;
        }
        
        private async Task<FunctionalTest> TestWriteReadConsistencyAsync()
        {
            var test = new FunctionalTest { Name = "Write-Read Consistency", StartTime = DateTime.UtcNow };
            
            try
            {
                var testLog = new DynamoDbLogEntry
                {
                    LogId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    LogType = "FUNCTIONAL_TEST",
                    ServiceName = "ValidationService",
                    LogTimestamp = DateTime.UtcNow,
                    IsSuccess = true,
                    RequestData = "{\"test\": \"write-read-consistency\"}",
                    CorrelationId = Guid.NewGuid().ToString()
                };
                
                // Write to DynamoDB
                var writeSuccess = await _dynamoService.WriteLogAsync(testLog);
                
                if (!writeSuccess)
                {
                    test.ErrorMessage = "Failed to write test log";
                    test.Passed = false;
                    return test;
                }
                
                // Wait a moment for consistency
                await Task.Delay(1000);
                
                // Read back the record
                var readLog = await _dynamoService.GetLogByIdAsync(
                    testLog.ServiceName, 
                    testLog.LogTimestamp, 
                    testLog.LogId);
                
                if (readLog == null)
                {
                    test.ErrorMessage = "Failed to read back test log";
                    test.Passed = false;
                    return test;
                }
                
                // Validate data consistency
                if (readLog.LogType != testLog.LogType ||
                    readLog.IsSuccess != testLog.IsSuccess ||
                    readLog.CorrelationId != testLog.CorrelationId)
                {
                    test.ErrorMessage = "Data inconsistency detected";
                    test.Passed = false;
                    return test;
                }
                
                test.Passed = true;
                test.Details = "Write-read consistency validated successfully";
            }
            catch (Exception ex)
            {
                test.ErrorMessage = ex.Message;
                test.Passed = false;
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<FunctionalTest> TestBatchWriteOperationsAsync()
        {
            var test = new FunctionalTest { Name = "Batch Write Operations", StartTime = DateTime.UtcNow };
            
            try
            {
                var batchSize = 10;
                var testLogs = new List<DynamoDbLogEntry>();
                
                for (int i = 0; i < batchSize; i++)
                {
                    testLogs.Add(new DynamoDbLogEntry
                    {
                        LogId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + i,
                        LogType = "BATCH_TEST",
                        ServiceName = "ValidationService",
                        LogTimestamp = DateTime.UtcNow.AddMilliseconds(i),
                        IsSuccess = true,
                        RequestData = $"{{\"batch_item\": {i}}}",
                        CorrelationId = Guid.NewGuid().ToString()
                    });
                }
                
                // Batch write
                var batchSuccess = await _dynamoService.WriteBatchAsync(testLogs);
                
                if (!batchSuccess)
                {
                    test.ErrorMessage = "Batch write operation failed";
                    test.Passed = false;
                    return test;
                }
                
                test.Passed = true;
                test.Details = $"Successfully wrote batch of {batchSize} records";
            }
            catch (Exception ex)
            {
                test.ErrorMessage = ex.Message;
                test.Passed = false;
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<FunctionalTest> TestQueryPatternFunctionalityAsync()
        {
            var test = new FunctionalTest { Name = "Query Pattern Functionality", StartTime = DateTime.UtcNow };
            
            try
            {
                var testApplicationId = await GetRandomApplicationIdAsync();
                var today = DateTime.UtcNow.Date;
                
                // Test different query patterns
                var applicationLogs = await _dynamoService.GetLogsByApplicationIdAsync(testApplicationId);
                var serviceLogs = await _dynamoService.GetLogsByServiceAndTimeRangeAsync("CreditCheckService", today, today.AddDays(1));
                var errorLogs = await _dynamoService.GetErrorLogsByDateAsync(today);
                
                test.Passed = true;
                test.Details = $"Query patterns tested: Application logs ({applicationLogs.Count()}), Service logs ({serviceLogs.Count()}), Error logs ({errorLogs.Count()})";
            }
            catch (Exception ex)
            {
                test.ErrorMessage = ex.Message;
                test.Passed = false;
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<FunctionalTest> TestErrorHandlingAsync()
        {
            var test = new FunctionalTest { Name = "Error Handling", StartTime = DateTime.UtcNow };
            
            try
            {
                // Test with invalid data
                var invalidLog = new DynamoDbLogEntry
                {
                    // Missing required fields to trigger error
                    LogId = 0,
                    ServiceName = "",
                    LogTimestamp = DateTime.MinValue
                };
                
                var result = await _dynamoService.WriteLogAsync(invalidLog);
                
                // Should handle error gracefully and return false
                if (result == false)
                {
                    test.Passed = true;
                    test.Details = "Error handling working correctly - invalid data rejected";
                }
                else
                {
                    test.Passed = false;
                    test.ErrorMessage = "Error handling failed - invalid data was accepted";
                }
            }
            catch (Exception ex)
            {
                // Exception handling is also acceptable
                test.Passed = true;
                test.Details = $"Error handling working correctly - exception caught: {ex.GetType().Name}";
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<FunctionalTest> TestTTLFunctionalityAsync()
        {
            var test = new FunctionalTest { Name = "TTL Functionality", StartTime = DateTime.UtcNow };
            
            try
            {
                // Create a test log with short TTL
                var testLog = new DynamoDbLogEntry
                {
                    LogId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    LogType = "TTL_TEST",
                    ServiceName = "ValidationService",
                    LogTimestamp = DateTime.UtcNow,
                    IsSuccess = true,
                    TTL = DateTimeOffset.UtcNow.AddSeconds(30).ToUnixTimeSeconds() // 30 seconds TTL
                };
                
                testLog.GenerateKeys();
                
                var writeSuccess = await _dynamoService.WriteLogAsync(testLog);
                
                if (writeSuccess)
                {
                    test.Passed = true;
                    test.Details = "TTL functionality validated - record created with TTL attribute";
                }
                else
                {
                    test.Passed = false;
                    test.ErrorMessage = "Failed to create record with TTL";
                }
            }
            catch (Exception ex)
            {
                test.ErrorMessage = ex.Message;
                test.Passed = false;
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<SchemaValidationResult> ValidateSchemaConsistencyAsync()
        {
            var result = new SchemaValidationResult { StartTime = DateTime.UtcNow };
            
            try
            {
                // Validate DynamoDB table structure
                var tableDescription = await _dynamoClient.DescribeTableAsync(_tableName);
                var table = tableDescription.Table;
                
                var validations = new List<string>();
                
                // Check primary key
                if (table.KeySchema.Any(k => k.AttributeName == "PK" && k.KeyType == KeyType.HASH) &&
                    table.KeySchema.Any(k => k.AttributeName == "SK" && k.KeyType == KeyType.RANGE))
                {
                    validations.Add("✓ Primary key structure correct");
                }
                else
                {
                    validations.Add("✗ Primary key structure incorrect");
                    result.IsValid = false;
                }
                
                // Check GSIs
                var expectedGSIs = new[] { "GSI1-ApplicationId-LogTimestamp", "GSI2-CorrelationId-LogTimestamp", "GSI3-ErrorStatus-LogTimestamp" };
                foreach (var expectedGSI in expectedGSIs)
                {
                    if (table.GlobalSecondaryIndexes.Any(gsi => gsi.IndexName == expectedGSI))
                    {
                        validations.Add($"✓ GSI {expectedGSI} exists");
                    }
                    else
                    {
                        validations.Add($"✗ GSI {expectedGSI} missing");
                        result.IsValid = false;
                    }
                }
                
                // Check TTL
                var ttlDescription = await _dynamoClient.DescribeTimeToLiveAsync(new DescribeTimeToLiveRequest
                {
                    TableName = _tableName
                });
                
                if (ttlDescription.TimeToLiveDescription.TimeToLiveStatus == TimeToLiveStatus.ENABLED)
                {
                    validations.Add("✓ TTL enabled");
                }
                else
                {
                    validations.Add("✗ TTL not enabled");
                    result.IsValid = false;
                }
                
                result.ValidationDetails = validations;
                result.IsValid = result.IsValid && !validations.Any(v => v.StartsWith("✗"));
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Schema validation failed: {ex.Message}");
                result.IsValid = false;
            }
            
            result.EndTime = DateTime.UtcNow;
            result.Duration = result.EndTime.Value - result.StartTime;
            
            return result;
        }
        
        private async Task<QueryPatternValidationResult> ValidateQueryPatternsAsync()
        {
            var result = new QueryPatternValidationResult { StartTime = DateTime.UtcNow };
            
            try
            {
                var patterns = new List<QueryPatternTest>();
                
                // Test each query pattern
                patterns.Add(await TestQueryPattern("Primary Key Query", async () =>
                {
                    var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
                    var pk = $"CreditCheckService-{today}";
                    
                    var request = new QueryRequest
                    {
                        TableName = _tableName,
                        KeyConditionExpression = "PK = :pk",
                        ExpressionAttributeValues = new Dictionary<string, AttributeValue>
                        {
                            { ":pk", new AttributeValue(pk) }
                        },
                        Limit = 10
                    };
                    
                    var response = await _dynamoClient.QueryAsync(request);
                    return response.Items.Count;
                }));
                
                patterns.Add(await TestQueryPattern("GSI1 Query (Application ID)", async () =>
                {
                    var appId = await GetRandomApplicationIdAsync();
                    
                    var request = new QueryRequest
                    {
                        TableName = _tableName,
                        IndexName = "GSI1-ApplicationId-LogTimestamp",
                        KeyConditionExpression = "GSI1PK = :appId",
                        ExpressionAttributeValues = new Dictionary<string, AttributeValue>
                        {
                            { ":appId", new AttributeValue($"APP#{appId}") }
                        },
                        Limit = 10
                    };
                    
                    var response = await _dynamoClient.QueryAsync(request);
                    return response.Items.Count;
                }));
                
                result.QueryPatterns = patterns;
                result.SuccessfulPatterns = patterns.Count(p => p.Success);
                result.FailedPatterns = patterns.Count(p => !p.Success);
                result.IsValid = result.FailedPatterns == 0;
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Query pattern validation failed: {ex.Message}");
                result.IsValid = false;
            }
            
            result.EndTime = DateTime.UtcNow;
            result.Duration = result.EndTime.Value - result.StartTime;
            
            return result;
        }
        
        private async Task<QueryPatternTest> TestQueryPattern(string patternName, Func<Task<int>> queryFunc)
        {
            var test = new QueryPatternTest { PatternName = patternName, StartTime = DateTime.UtcNow };
            
            try
            {
                var stopwatch = Stopwatch.StartNew();
                var resultCount = await queryFunc();
                stopwatch.Stop();
                
                test.Success = true;
                test.ResultCount = resultCount;
                test.ResponseTime = stopwatch.Elapsed;
                test.Details = $"Query executed successfully, returned {resultCount} items in {stopwatch.ElapsedMilliseconds}ms";
            }
            catch (Exception ex)
            {
                test.Success = false;
                test.ErrorMessage = ex.Message;
            }
            
            test.EndTime = DateTime.UtcNow;
            test.Duration = test.EndTime.Value - test.StartTime;
            
            return test;
        }
        
        private async Task<int> GetRandomApplicationIdAsync()
        {
            var randomApp = await _sqlContext.Applications
                .OrderBy(a => Guid.NewGuid())
                .FirstOrDefaultAsync();
            
            return randomApp?.ApplicationId ?? 1;
        }
        
        private ValidationResult DetermineOverallResult(ValidationReport report)
        {
            if (report.Errors.Any())
                return ValidationResult.Failed;
            
            if (report.DataIntegrity?.IsConsistent == false)
                return ValidationResult.Failed;
            
            if (report.Functional?.OverallPassed == false)
                return ValidationResult.Failed;
            
            if (report.Schema?.IsValid == false)
                return ValidationResult.Failed;
            
            if (report.QueryPatterns?.IsValid == false)
                return ValidationResult.Failed;
            
            return ValidationResult.Passed;
        }
    }
}
```

### 📊 Validation Models

#### ValidationModels.cs
```csharp
namespace LoanApplication.Services
{
    public class ValidationReport
    {
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public ValidationConfig Configuration { get; set; } = new();
        public ValidationResult OverallResult { get; set; }
        public List<string> Errors { get; set; } = new();
        
        public DataIntegrityResult? DataIntegrity { get; set; }
        public PerformanceComparisonResult? Performance { get; set; }
        public FunctionalTestResult? Functional { get; set; }
        public SchemaValidationResult? Schema { get; set; }
        public QueryPatternValidationResult? QueryPatterns { get; set; }
    }
    
    public class ValidationConfig
    {
        public DateTime StartDate { get; set; } = DateTime.UtcNow.AddDays(-1);
        public DateTime EndDate { get; set; } = DateTime.UtcNow;
        public bool IncludePerformanceTests { get; set; } = true;
        public bool IncludeFunctionalTests { get; set; } = true;
        public int PerformanceSampleSize { get; set; } = 1000;
        public double TolerancePercentage { get; set; } = 1.0; // 1% tolerance
    }
    
    public class DataIntegrityResult
    {
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public long SqlRecordCount { get; set; }
        public long DynamoDbRecordCount { get; set; }
        public bool IsConsistent { get; set; }
        public long VarianceCount { get; set; }
        public double VariancePercentage { get; set; }
        public SampleValidationResult? SampleValidation { get; set; }
        public List<string> Errors { get; set; } = new();
    }
    
    public class SampleValidationResult
    {
        public int SampleSize { get; set; }
        public int MatchedRecords { get; set; }
        public int MissingRecords { get; set; }
        public double MatchPercentage { get; set; }
        public List<string> Discrepancies { get; set; } = new();
        public List<string> Errors { get; set; } = new();
    }
    
    public class PerformanceComparisonResult
    {
        public int SampleSize { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public List<string> Errors { get; set; } = new();
        
        public QueryPerformanceResult? SingleRecordRetrieval { get; set; }
        public QueryPerformanceResult? TimeRangeQuery { get; set; }
        public QueryPerformanceResult? ErrorLogQuery { get; set; }
        public QueryPerformanceResult? CountQuery { get; set; }
    }
    
    public class QueryPerformanceResult
    {
        public string TestName { get; set; } = string.Empty;
        public TimeSpan SqlResponseTime { get; set; }
        public TimeSpan DynamoDbResponseTime { get; set; }
        public double PerformanceImprovement { get; set; } // Percentage
        public bool Success { get; set; }
        public List<string> Errors { get; set; } = new();
    }
    
    public class FunctionalTestResult
    {
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public List<FunctionalTest> Tests { get; set; } = new();
        public int PassedTests { get; set; }
        public int FailedTests { get; set; }
        public bool OverallPassed { get; set; }
        public List<string> Errors { get; set; } = new();
    }
    
    public class FunctionalTest
    {
        public string Name { get; set; } = string.Empty;
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public bool Passed { get; set; }
        public string? Details { get; set; }
        public string? ErrorMessage { get; set; }
    }
    
    public class SchemaValidationResult
    {
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public bool IsValid { get; set; } = true;
        public List<string> ValidationDetails { get; set; } = new();
        public List<string> Errors { get; set; } = new();
    }
    
    public class QueryPatternValidationResult
    {
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public bool IsValid { get; set; }
        public List<QueryPatternTest> QueryPatterns { get; set; } = new();
        public int SuccessfulPatterns { get; set; }
        public int FailedPatterns { get; set; }
        public List<string> Errors { get; set; } = new();
    }
    
    public class QueryPatternTest
    {
        public string PatternName { get; set; } = string.Empty;
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public bool Success { get; set; }
        public int ResultCount { get; set; }
        public TimeSpan ResponseTime { get; set; }
        public string? Details { get; set; }
        public string? ErrorMessage { get; set; }
    }
    
    public enum ValidationResult
    {
        Passed,
        Failed,
        Warning
    }
}
```

### 🎮 Validation Controller

#### ValidationController.cs
```csharp
using LoanApplication.Services;
using Microsoft.AspNetCore.Mvc;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ValidationController : ControllerBase
    {
        private readonly IValidationService _validationService;
        private readonly ILogger<ValidationController> _logger;
        
        public ValidationController(IValidationService validationService, ILogger<ValidationController> logger)
        {
            _validationService = validationService;
            _logger = logger;
        }
        
        [HttpPost("full-validation")]
        public async Task<IActionResult> RunFullValidation([FromBody] ValidationConfig? config = null)
        {
            try
            {
                config ??= new ValidationConfig();
                
                _logger.LogInformation("Starting full validation suite");
                var report = await _validationService.RunFullValidationAsync(config);
                
                return Ok(report);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Full validation failed");
                return StatusCode(500, new { Error = "Validation failed", Details = ex.Message });
            }
        }
        
        [HttpPost("data-integrity")]
        public async Task<IActionResult> ValidateDataIntegrity(
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            try
            {
                var start = startDate ?? DateTime.UtcNow.AddDays(-1);
                var end = endDate ?? DateTime.UtcNow;
                
                var result = await _validationService.ValidateDataIntegrityAsync(start, end);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Data integrity validation failed");
                return StatusCode(500, new { Error = "Data integrity validation failed", Details = ex.Message });
            }
        }
        
        [HttpPost("performance-comparison")]
        public async Task<IActionResult> ComparePerformance([FromQuery] int sampleSize = 1000)
        {
            try
            {
                var result = await _validationService.ComparePerformanceAsync(sampleSize);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Performance comparison failed");
                return StatusCode(500, new { Error = "Performance comparison failed", Details = ex.Message });
            }
        }
        
        [HttpPost("functional-tests")]
        public async Task<IActionResult> RunFunctionalTests()
        {
            try
            {
                var result = await _validationService.RunFunctionalTestsAsync();
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Functional tests failed");
                return StatusCode(500, new { Error = "Functional tests failed", Details = ex.Message });
            }
        }
    }
}
```

### 🚀 PowerShell Validation Script

#### run-validation.ps1
```powershell
# DynamoDB Migration Validation Script
param(
    [string]$Environment = "dev",
    [string]$BaseUrl = "https://localhost:7001",
    [switch]$FullValidation,
    [switch]$DataIntegrityOnly,
    [switch]$PerformanceOnly,
    [switch]$FunctionalOnly,
    [string]$StartDate,
    [string]$EndDate,
    [string]$OutputFile = "validation-report.json"
)

Write-Host "🔍 Starting DynamoDB Migration Validation" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan

# Function to make API calls
function Invoke-ValidationAPI {
    param(
        [string]$Endpoint,
        [hashtable]$Body = @{},
        [string]$Method = "POST"
    )
    
    try {
        $uri = "$BaseUrl/api/Validation/$Endpoint"
        
        if ($Method -eq "POST" -and $Body.Count -gt 0) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Body $jsonBody -ContentType "application/json"
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method $Method
        }
        
        return $response
    }
    catch {
        Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Build validation configuration
$config = @{
    StartDate = if ($StartDate) { $StartDate } else { (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ssZ") }
    EndDate = if ($EndDate) { $EndDate } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
    IncludePerformanceTests = $true
    IncludeFunctionalTests = $true
    PerformanceSampleSize = 1000
    TolerancePercentage = 1.0
}

$results = @{}

if ($FullValidation) {
    Write-Host "🧪 Running full validation suite..." -ForegroundColor Yellow
    $results.FullValidation = Invoke-ValidationAPI -Endpoint "full-validation" -Body $config
    
    if ($results.FullValidation) {
        Write-Host "✅ Full validation completed" -ForegroundColor Green
        Write-Host "Overall Result: $($results.FullValidation.OverallResult)" -ForegroundColor $(if ($results.FullValidation.OverallResult -eq "Passed") { "Green" } else { "Red" })
    }
}

if ($DataIntegrityOnly -or !$FullValidation) {
    Write-Host "📊 Running data integrity validation..." -ForegroundColor Yellow
    $queryParams = "?startDate=$($config.StartDate)&endDate=$($config.EndDate)"
    $results.DataIntegrity = Invoke-ValidationAPI -Endpoint "data-integrity$queryParams"
    
    if ($results.DataIntegrity) {
        Write-Host "✅ Data integrity validation completed" -ForegroundColor Green
        Write-Host "SQL Records: $($results.DataIntegrity.SqlRecordCount)" -ForegroundColor Cyan
        Write-Host "DynamoDB Records: $($results.DataIntegrity.DynamoDbRecordCount)" -ForegroundColor Cyan
        Write-Host "Consistent: $($results.DataIntegrity.IsConsistent)" -ForegroundColor $(if ($results.DataIntegrity.IsConsistent) { "Green" } else { "Red" })
    }
}

if ($PerformanceOnly -or !$FullValidation) {
    Write-Host "⚡ Running performance comparison..." -ForegroundColor Yellow
    $results.Performance = Invoke-ValidationAPI -Endpoint "performance-comparison?sampleSize=1000"
    
    if ($results.Performance) {
        Write-Host "✅ Performance comparison completed" -ForegroundColor Green
        
        if ($results.Performance.SingleRecordRetrieval) {
            $improvement = [math]::Round($results.Performance.SingleRecordRetrieval.PerformanceImprovement, 2)
            Write-Host "Single Record Query: $improvement% improvement" -ForegroundColor Cyan
        }
    }
}

if ($FunctionalOnly -or !$FullValidation) {
    Write-Host "🔧 Running functional tests..." -ForegroundColor Yellow
    $results.Functional = Invoke-ValidationAPI -Endpoint "functional-tests"
    
    if ($results.Functional) {
        Write-Host "✅ Functional tests completed" -ForegroundColor Green
        Write-Host "Passed: $($results.Functional.PassedTests)" -ForegroundColor Green
        Write-Host "Failed: $($results.Functional.FailedTests)" -ForegroundColor $(if ($results.Functional.FailedTests -eq 0) { "Green" } else { "Red" })
    }
}

# Save results to file
if ($results.Count -gt 0) {
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "📄 Results saved to: $OutputFile" -ForegroundColor Cyan
}

# Summary
Write-Host "`n📋 Validation Summary:" -ForegroundColor Green

if ($results.FullValidation) {
    $overall = $results.FullValidation.OverallResult
    Write-Host "Overall Result: $overall" -ForegroundColor $(if ($overall -eq "Passed") { "Green" } else { "Red" })
    
    if ($results.FullValidation.Errors.Count -gt 0) {
        Write-Host "Errors:" -ForegroundColor Red
        foreach ($error in $results.FullValidation.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    }
}

Write-Host "✨ Validation completed" -ForegroundColor Green
```

---

### 💡 Q Developer Integration Points

```
1. "Review this comprehensive validation suite and suggest additional test cases or validation scenarios for DynamoDB migration."

2. "Analyze the performance comparison methodology and recommend improvements for more accurate benchmarking between SQL and DynamoDB."

3. "Examine the functional tests and suggest additional edge cases or error scenarios that should be tested during migration validation."
```

**Validation Complete!** This comprehensive validation suite provides thorough testing of data integrity, performance, functionality, schema consistency, and query patterns for the DynamoDB migration.