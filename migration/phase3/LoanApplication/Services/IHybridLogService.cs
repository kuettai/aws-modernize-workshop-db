using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IHybridLogService
    {
        Task<bool> WriteLogAsync(IntegrationLog logEntry);
        Task<bool> WriteBatchAsync(IEnumerable<IntegrationLog> logEntries);
        Task<IEnumerable<IntegrationLog>> GetLogsByApplicationIdAsync(int applicationId);
        Task<IEnumerable<IntegrationLog>> GetLogsByServiceAndTimeRangeAsync(string serviceName, DateTime startDate, DateTime endDate);
        Task<IEnumerable<IntegrationLog>> GetErrorLogsByDateAsync(DateTime date);
        Task<long> GetLogCountAsync();
        Task<bool> EnableDualWriteAsync();
        Task<bool> SwitchToDynamoDbReadsAsync();
        Task<bool> DisableSqlWritesAsync();
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