using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    // Daily Application Summary Model
    public class DailyApplicationSummary
    {
        public int SummaryId { get; set; }
        public DateTime ReportDate { get; set; }
        public int TotalApplications { get; set; }
        public int ApprovedApplications { get; set; }
        public int RejectedApplications { get; set; }
        public int PendingApplications { get; set; }
        public decimal ApprovalRate { get; set; }
        public decimal TotalRequestedAmount { get; set; }
        public decimal AvgRequestedAmount { get; set; }
        public decimal? AvgProcessingHours { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    // Monthly Loan Officer Performance Model
    public class MonthlyLoanOfficerPerformance
    {
        public int PerformanceId { get; set; }
        public DateTime ReportMonth { get; set; }
        public int LoanOfficerId { get; set; }
        public string LoanOfficerName { get; set; } = string.Empty;
        public string BranchName { get; set; } = string.Empty;
        public int TotalApplications { get; set; }
        public int ApprovedApplications { get; set; }
        public decimal ApprovalRate { get; set; }
        public decimal TotalLoanAmount { get; set; }
        public decimal AvgLoanAmount { get; set; }
        public decimal? AvgProcessingDays { get; set; }
        public int? Ranking { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    // Weekly Customer Analytics Model
    public class WeeklyCustomerAnalytics
    {
        public int AnalyticsId { get; set; }
        public DateTime ReportWeek { get; set; }
        public string CustomerSegment { get; set; } = string.Empty;
        public int CustomerCount { get; set; }
        public int TotalApplications { get; set; }
        public decimal ApprovalRate { get; set; }
        public int? AvgCreditScore { get; set; }
        public decimal? AvgMonthlyIncome { get; set; }
        public decimal? AvgLoanAmount { get; set; }
        public decimal TotalPaymentsMade { get; set; }
        public decimal? AvgPaymentAmount { get; set; }
        public decimal DefaultRate { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    // Batch Job Execution Log Model
    public class BatchJobExecutionLog
    {
        public long ExecutionId { get; set; }
        public string JobName { get; set; } = string.Empty;
        public string JobType { get; set; } = string.Empty;
        public DateTime ReportPeriod { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public int? DurationSeconds { get; set; }
        public string Status { get; set; } = string.Empty;
        public int RecordsProcessed { get; set; }
        public int RecordsInserted { get; set; }
        public int RecordsUpdated { get; set; }
        public string? ErrorMessage { get; set; }
        public string ServerName { get; set; } = string.Empty;
        public string DatabaseName { get; set; } = string.Empty;
        public string ExecutedBy { get; set; } = string.Empty;
        public DateTime CreatedDate { get; set; }
    }

    // Dashboard Filter Models
    public class ReportingDashboardFilter
    {
        [Display(Name = "Start Date")]
        public DateTime? StartDate { get; set; }

        [Display(Name = "End Date")]
        public DateTime? EndDate { get; set; }

        [Display(Name = "Report Type")]
        public string? ReportType { get; set; }
    }

    public class BatchJobMonitorFilter
    {
        [Display(Name = "Job Name")]
        public string? JobName { get; set; }

        [Display(Name = "Days Back")]
        [Range(1, 365, ErrorMessage = "Days back must be between 1 and 365")]
        public int DaysBack { get; set; } = 7;

        [Display(Name = "Status")]
        public string? Status { get; set; }
    }

    // Dashboard View Models
    public class ReportingDashboardViewModel
    {
        public List<DailyApplicationSummary> DailySummaries { get; set; } = new();
        public List<MonthlyLoanOfficerPerformance> MonthlyPerformance { get; set; } = new();
        public List<WeeklyCustomerAnalytics> WeeklyAnalytics { get; set; } = new();
        public ReportingDashboardFilter Filter { get; set; } = new();
    }

    public class BatchJobMonitorViewModel
    {
        public List<BatchJobExecutionLog> JobExecutions { get; set; } = new();
        public List<string> AvailableJobNames { get; set; } = new();
        public List<string> AvailableStatuses { get; set; } = new();
        public BatchJobMonitorFilter Filter { get; set; } = new();
        public Dictionary<string, object> Summary { get; set; } = new();
    }
}