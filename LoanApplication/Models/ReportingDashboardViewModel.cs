namespace LoanApplication.Models
{
    public class ReportingDashboardViewModel
    {
        public int TotalApplications { get; set; }
        public int PendingApplications { get; set; }
        public int ApprovedApplications { get; set; }
        public int RejectedApplications { get; set; }
        public decimal TotalLoanAmount { get; set; }
        public List<MonthlyReport> MonthlyReports { get; set; } = new();
    }

    public class MonthlyReport
    {
        public string Month { get; set; } = string.Empty;
        public int ApplicationCount { get; set; }
        public decimal TotalAmount { get; set; }
    }
}