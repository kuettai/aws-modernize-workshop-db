using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IReportingService
    {
        // Daily Application Summary
        Task<List<DailyApplicationSummary>> GetDailyApplicationSummariesAsync(DateTime? startDate = null, DateTime? endDate = null);
        Task<DailyApplicationSummary?> GetDailyApplicationSummaryAsync(DateTime reportDate);

        // Monthly Loan Officer Performance
        Task<List<MonthlyLoanOfficerPerformance>> GetMonthlyLoanOfficerPerformanceAsync(DateTime? startMonth = null, DateTime? endMonth = null);
        Task<List<MonthlyLoanOfficerPerformance>> GetTopPerformingOfficersAsync(DateTime reportMonth, int topCount = 10);

        // Weekly Customer Analytics
        Task<List<WeeklyCustomerAnalytics>> GetWeeklyCustomerAnalyticsAsync(DateTime? startWeek = null, DateTime? endWeek = null);
        Task<List<WeeklyCustomerAnalytics>> GetCustomerAnalyticsBySegmentAsync(string segment, DateTime? startWeek = null, DateTime? endWeek = null);

        // Batch Job Monitoring
        Task<List<BatchJobExecutionLog>> GetBatchJobExecutionsAsync(string? jobName = null, int daysBack = 7, string? status = null);
        Task<List<string>> GetDistinctJobNamesAsync();
        Task<List<string>> GetDistinctJobStatusesAsync();
        Task<Dictionary<string, object>> GetBatchJobSummaryAsync(int daysBack = 7);

        // Dashboard Data
        Task<ReportingDashboardViewModel> GetDashboardDataAsync(ReportingDashboardFilter filter);
        Task<BatchJobMonitorViewModel> GetBatchJobMonitorDataAsync(BatchJobMonitorFilter filter);
    }
}