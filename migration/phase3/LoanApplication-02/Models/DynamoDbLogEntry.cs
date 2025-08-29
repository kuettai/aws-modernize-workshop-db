using Amazon.DynamoDBv2.DataModel;

namespace LoanApplication.Models
{
    [DynamoDBTable("LoanApp-IntegrationLogs-dev")]
    public class DynamoDbLogEntry
    {
        [DynamoDBHashKey("LogId")]
        public long LogId { get; set; }
        
        [DynamoDBRangeKey("LogTimestamp")]
        public string LogTimestamp { get; set; } = string.Empty;
        
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
        
        [DynamoDBProperty("CorrelationId")]
        public string? CorrelationId { get; set; }
        
        [DynamoDBProperty("UserId")]
        public string? UserId { get; set; }
        
        [DynamoDBProperty("TTL")]
        public long TTL { get; set; }

        public void GenerateKeys()
        {
            TTL = DateTimeOffset.UtcNow.AddDays(90).ToUnixTimeSeconds();
        }
        
        public static DynamoDbLogEntry FromIntegrationLog(IntegrationLog sqlLog)
        {
            var dynamoLog = new DynamoDbLogEntry
            {
                LogId = sqlLog.LogId,
                LogTimestamp = sqlLog.LogTimestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
                ApplicationId = sqlLog.ApplicationId,
                LogType = sqlLog.LogType,
                ServiceName = sqlLog.ServiceName,
                RequestData = sqlLog.RequestData,
                ResponseData = sqlLog.ResponseData,
                StatusCode = sqlLog.StatusCode,
                IsSuccess = sqlLog.IsSuccess,
                ErrorMessage = sqlLog.ErrorMessage,
                ProcessingTimeMs = sqlLog.ProcessingTimeMs,
                CorrelationId = sqlLog.CorrelationId,
                UserId = sqlLog.UserId
            };
            
            dynamoLog.GenerateKeys();
            return dynamoLog;
        }
    }
}