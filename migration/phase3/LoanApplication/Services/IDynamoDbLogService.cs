using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IDynamoDbLogService
    {
        Task<bool> WriteLogAsync(DynamoDbLogEntry logEntry);
        Task<DynamoDbLogEntry?> GetLogByIdAsync(string serviceName, DateTime date, long logId);
        Task<bool> WriteBatchAsync(IEnumerable<DynamoDbLogEntry> logEntries);
        Task<IEnumerable<DynamoDbLogEntry>> GetLogsByServiceAndTimeRangeAsync(string serviceName, DateTime startDate, DateTime endDate);
        Task<IEnumerable<DynamoDbLogEntry>> GetLogsByApplicationIdAsync(int applicationId);
        Task<long> GetLogCountByServiceAsync(string serviceName, DateTime date);
    }
}