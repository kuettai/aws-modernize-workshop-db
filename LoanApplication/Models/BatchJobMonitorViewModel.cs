namespace LoanApplication.Models
{
    public class BatchJobMonitorViewModel
    {
        public string JobName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public int RecordsProcessed { get; set; }
        public string? ErrorMessage { get; set; }
    }
}