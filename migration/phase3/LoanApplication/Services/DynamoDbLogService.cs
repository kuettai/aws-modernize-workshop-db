using Amazon.DynamoDBv2.DataModel;
using Amazon.DynamoDBv2.DocumentModel;
using LoanApplication.Models;

namespace LoanApplication.Services
{
    public class DynamoDbLogService : IDynamoDbLogService
    {
        private readonly DynamoDBContext _dynamoContext;
        private readonly ILogger<DynamoDbLogService> _logger;
        
        public DynamoDbLogService(DynamoDBContext dynamoContext, ILogger<DynamoDbLogService> logger)
        {
            _dynamoContext = dynamoContext;
            _logger = logger;
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
        
        public async Task<IEnumerable<DynamoDbLogEntry>> GetLogsByServiceAndTimeRangeAsync(string serviceName, DateTime startDate, DateTime endDate)
        {
            try
            {
                var results = new List<DynamoDbLogEntry>();
                
                for (var date = startDate.Date; date <= endDate.Date; date = date.AddDays(1))
                {
                    var dateStr = date.ToString("yyyy-MM-dd");
                    var pk = $"{serviceName}-{dateStr}";
                    
                    var queryConfig = new QueryOperationConfig
                    {
                        KeyExpression = new Expression
                        {
                            ExpressionStatement = "PK = :pk",
                            ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                            {
                                { ":pk", pk }
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
    }
}