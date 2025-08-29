namespace LoanApplication.Configuration
{
    public class HybridLogConfiguration
    {
        public const string SectionName = "HybridLogging";
        
        public bool WritesToSql { get; set; } = true;
        public bool WritesToDynamoDb { get; set; } = false;
        public bool RequireBothWrites { get; set; } = false;
        public bool ReadsFromDynamoDb { get; set; } = false;
        public MigrationPhase CurrentPhase { get; set; } = MigrationPhase.SqlOnly;
        public bool ContinueOnWriteFailure { get; set; } = true;
        public int RetryAttempts { get; set; } = 3;
        public TimeSpan RetryDelay { get; set; } = TimeSpan.FromSeconds(1);
    }
    
    public enum MigrationPhase
    {
        SqlOnly,
        DualWrite,
        DualWriteReadDynamo,
        DynamoOnly
    }
}