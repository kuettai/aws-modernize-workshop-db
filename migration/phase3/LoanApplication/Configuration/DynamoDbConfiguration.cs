namespace LoanApplication.Configuration
{
    public class DynamoDbConfiguration
    {
        public const string SectionName = "DynamoDB";
        
        public string TableName { get; set; } = string.Empty;
        public string Region { get; set; } = "ap-southeast-1";
        public bool UseLocalDynamoDB { get; set; } = false;
        public string LocalDynamoDBUrl { get; set; } = "http://localhost:8000";
    }
}