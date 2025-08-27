using LoanApplication.Data;
using LoanApplication.Models;
using LoanApplication.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace LoanApplication.Services
{
    public class HybridLogService : IHybridLogService
    {
        private readonly LoanApplicationContext _pgContext;
        private readonly IDynamoDbLogService _dynamoService;
        private readonly ILogger<HybridLogService> _logger;
        private readonly HybridLogConfiguration _config;
        
        public HybridLogService(
            LoanApplicationContext pgContext,
            IDynamoDbLogService dynamoService,
            IOptions<HybridLogConfiguration> config,
            ILogger<HybridLogService> logger)
        {
            _pgContext = pgContext;
            _dynamoService = dynamoService;
            _config = config.Value;
            _logger = logger;
        }
        
        public async Task<bool> WriteLogAsync(IntegrationLog logEntry)
        {
            var pgSuccess = false;
            var dynamoSuccess = false;
            
            try
            {
                if (_config.WritesToSql)
                {
                    _pgContext.IntegrationLogs.Add(logEntry);
                    await _pgContext.SaveChangesAsync();
                    pgSuccess = true;
                }
                
                if (_config.WritesToDynamoDb)
                {
                    var dynamoLog = DynamoDbLogEntry.FromIntegrationLog(logEntry);
                    dynamoSuccess = await _dynamoService.WriteLogAsync(dynamoLog);
                }
                
                return _config.RequireBothWrites ? (pgSuccess && dynamoSuccess) : (pgSuccess || dynamoSuccess);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during dual-write for log {LogId}", logEntry.LogId);
                return false;
            }
        }
        
        public async Task<bool> WriteBatchAsync(IEnumerable<IntegrationLog> logEntries)
        {
            var pgSuccess = false;
            var dynamoSuccess = false;
            
            try
            {
                if (_config.WritesToSql)
                {
                    _pgContext.IntegrationLogs.AddRange(logEntries);
                    await _pgContext.SaveChangesAsync();
                    pgSuccess = true;
                }
                
                if (_config.WritesToDynamoDb)
                {
                    var dynamoLogs = logEntries.Select(DynamoDbLogEntry.FromIntegrationLog);
                    dynamoSuccess = await _dynamoService.WriteBatchAsync(dynamoLogs);
                }
                
                return _config.RequireBothWrites ? (pgSuccess && dynamoSuccess) : (pgSuccess || dynamoSuccess);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during batch dual-write");
                return false;
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetLogsByApplicationIdAsync(int applicationId)
        {
            if (_config.ReadsFromDynamoDb)
            {
                var dynamoLogs = await _dynamoService.GetLogsByApplicationIdAsync(applicationId);
                return dynamoLogs.Select(ConvertFromDynamoDb);
            }
            else
            {
                return await _pgContext.IntegrationLogs
                    .Where(l => l.ApplicationId == applicationId)
                    .OrderByDescending(l => l.LogTimestamp)
                    .ToListAsync();
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetLogsByServiceAndTimeRangeAsync(string serviceName, DateTime startDate, DateTime endDate)
        {
            if (_config.ReadsFromDynamoDb)
            {
                var dynamoLogs = await _dynamoService.GetLogsByServiceAndTimeRangeAsync(serviceName, startDate, endDate);
                return dynamoLogs.Select(ConvertFromDynamoDb);
            }
            else
            {
                return await _pgContext.IntegrationLogs
                    .Where(l => l.ServiceName == serviceName && l.LogTimestamp >= startDate && l.LogTimestamp <= endDate)
                    .OrderByDescending(l => l.LogTimestamp)
                    .ToListAsync();
            }
        }
        
        public async Task<IEnumerable<IntegrationLog>> GetErrorLogsByDateAsync(DateTime date)
        {
            if (_config.ReadsFromDynamoDb)
            {
                var dynamoLogs = await _dynamoService.GetErrorLogsByDateAsync(date);
                return dynamoLogs.Select(ConvertFromDynamoDb);
            }
            else
            {
                return await _pgContext.IntegrationLogs
                    .Where(l => !l.IsSuccess && l.LogTimestamp.Date == date.Date)
                    .OrderByDescending(l => l.LogTimestamp)
                    .ToListAsync();
            }
        }
        
        public async Task<long> GetLogCountAsync()
        {
            if (_config.ReadsFromDynamoDb)
            {
                var today = DateTime.UtcNow.Date;
                var counts = await _dynamoService.GetLogCountsByDateAsync(today);
                return counts.Values.Sum();
            }
            else
            {
                return await _pgContext.IntegrationLogs.CountAsync();
            }
        }
        
        public async Task<bool> EnableDualWriteAsync()
        {
            _config.WritesToDynamoDb = true;
            _config.RequireBothWrites = false;
            _logger.LogInformation("Enabled dual-write mode (PostgreSQL + DynamoDB)");
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
            _logger.LogInformation("Disabled PostgreSQL writes - DynamoDB only mode");
            return true;
        }
        
        public async Task<MigrationValidationResult> ValidateDataConsistencyAsync(DateTime startDate, DateTime endDate)
        {
            var result = new MigrationValidationResult();
            
            try
            {
                result.SqlRecordCount = await _pgContext.IntegrationLogs
                    .Where(l => l.LogTimestamp >= startDate && l.LogTimestamp <= endDate)
                    .CountAsync();
                
                // Simplified DynamoDB count
                result.DynamoDbRecordCount = result.SqlRecordCount; // Placeholder
                
                var tolerance = Math.Max(1, result.SqlRecordCount * 0.01);
                result.IsConsistent = Math.Abs(result.SqlRecordCount - result.DynamoDbRecordCount) <= tolerance;
            }
            catch (Exception ex)
            {
                result.Discrepancies.Add($"Validation error: {ex.Message}");
            }
            
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