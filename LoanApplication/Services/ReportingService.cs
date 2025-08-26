using LoanApplication.Data;
using LoanApplication.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace LoanApplication.Services
{
    public class ReportingService : IReportingService
    {
        private readonly ApplicationDbContextFactory _contextFactory;
        private readonly IMemoryCache _cache;
        private readonly ILogger<ReportingService> _logger;
        private const string JOB_NAMES_CACHE_KEY = "distinct_job_names";
        private const string JOB_STATUSES_CACHE_KEY = "distinct_job_statuses";
        private readonly TimeSpan _cacheExpiration = TimeSpan.FromMinutes(15);

        public ReportingService(ApplicationDbContextFactory contextFactory, IMemoryCache cache, ILogger<ReportingService> logger)
        {
            _contextFactory = contextFactory;
            _cache = cache;
            _logger = logger;
        }

        // Daily Application Summary Methods
        public async Task<List<DailyApplicationSummary>> GetDailyApplicationSummariesAsync(DateTime? startDate = null, DateTime? endDate = null)
        {
            using var context = _contextFactory.CreateReadContext();
            var query = context.Set<DailyApplicationSummary>().AsQueryable();

            if (startDate.HasValue)
                query = query.Where(x => x.ReportDate >= startDate.Value);

            if (endDate.HasValue)
                query = query.Where(x => x.ReportDate <= endDate.Value);

            return await query.OrderByDescending(x => x.ReportDate).ToListAsync();
        }

        public async Task<DailyApplicationSummary?> GetDailyApplicationSummaryAsync(DateTime reportDate)
        {
            using var context = _contextFactory.CreateReadContext();
            return await context.Set<DailyApplicationSummary>()
                .FirstOrDefaultAsync(x => x.ReportDate.Date == reportDate.Date);
        }

        // Monthly Loan Officer Performance Methods
        public async Task<List<MonthlyLoanOfficerPerformance>> GetMonthlyLoanOfficerPerformanceAsync(DateTime? startMonth = null, DateTime? endMonth = null)
        {
            using var context = _contextFactory.CreateReadContext();
            var query = context.Set<MonthlyLoanOfficerPerformance>().AsQueryable();

            if (startMonth.HasValue)
                query = query.Where(x => x.ReportMonth >= startMonth.Value);

            if (endMonth.HasValue)
                query = query.Where(x => x.ReportMonth <= endMonth.Value);

            return await query.OrderByDescending(x => x.ReportMonth)
                             .ThenBy(x => x.Ranking)
                             .ToListAsync();
        }

        public async Task<List<MonthlyLoanOfficerPerformance>> GetTopPerformingOfficersAsync(DateTime reportMonth, int topCount = 10)
        {
            using var context = _contextFactory.CreateReadContext();
            return await context.Set<MonthlyLoanOfficerPerformance>()
                .Where(x => x.ReportMonth.Year == reportMonth.Year && x.ReportMonth.Month == reportMonth.Month)
                .OrderBy(x => x.Ranking)
                .Take(topCount)
                .ToListAsync();
        }

        // Weekly Customer Analytics Methods
        public async Task<List<WeeklyCustomerAnalytics>> GetWeeklyCustomerAnalyticsAsync(DateTime? startWeek = null, DateTime? endWeek = null)
        {
            using var context = _contextFactory.CreateReadContext();
            var query = context.Set<WeeklyCustomerAnalytics>().AsQueryable();

            if (startWeek.HasValue)
                query = query.Where(x => x.ReportWeek >= startWeek.Value);

            if (endWeek.HasValue)
                query = query.Where(x => x.ReportWeek <= endWeek.Value);

            return await query.OrderByDescending(x => x.ReportWeek)
                             .ThenByDescending(x => x.CustomerCount)
                             .ToListAsync();
        }

        public async Task<List<WeeklyCustomerAnalytics>> GetCustomerAnalyticsBySegmentAsync(string segment, DateTime? startWeek = null, DateTime? endWeek = null)
        {
            using var context = _contextFactory.CreateReadContext();
            var query = context.Set<WeeklyCustomerAnalytics>()
                .Where(x => x.CustomerSegment == segment);

            if (startWeek.HasValue)
                query = query.Where(x => x.ReportWeek >= startWeek.Value);

            if (endWeek.HasValue)
                query = query.Where(x => x.ReportWeek <= endWeek.Value);

            return await query.OrderByDescending(x => x.ReportWeek).ToListAsync();
        }

        // Batch Job Monitoring Methods
        public async Task<List<BatchJobExecutionLog>> GetBatchJobExecutionsAsync(string? jobName = null, int daysBack = 7, string? status = null)
        {
            using var context = _contextFactory.CreateReadContext();
            var cutoffDate = DateTime.Now.AddDays(-daysBack);
            var query = context.Set<BatchJobExecutionLog>()
                .Where(x => x.StartTime >= cutoffDate);

            if (!string.IsNullOrEmpty(jobName))
                query = query.Where(x => x.JobName == jobName);

            if (!string.IsNullOrEmpty(status))
                query = query.Where(x => x.Status == status);

            return await query.OrderByDescending(x => x.StartTime).ToListAsync();
        }

        public async Task<List<string>> GetDistinctJobNamesAsync()
        {
            // Check cache first
            if (_cache.TryGetValue(JOB_NAMES_CACHE_KEY, out List<string>? cachedJobNames) && cachedJobNames != null)
            {
                _logger.LogInformation("Retrieved job names from cache");
                return cachedJobNames;
            }

            // Fetch from database using read replica
            using var context = _contextFactory.CreateReadContext();
            var jobNames = await context.Set<BatchJobExecutionLog>()
                .Select(x => x.JobName)
                .Distinct()
                .OrderBy(x => x)
                .ToListAsync();

            // Cache the result
            _cache.Set(JOB_NAMES_CACHE_KEY, jobNames, _cacheExpiration);
            _logger.LogInformation("Cached {Count} distinct job names", jobNames.Count);

            return jobNames;
        }

        public async Task<List<string>> GetDistinctJobStatusesAsync()
        {
            // Check cache first
            if (_cache.TryGetValue(JOB_STATUSES_CACHE_KEY, out List<string>? cachedStatuses) && cachedStatuses != null)
            {
                return cachedStatuses;
            }

            // Fetch from database
            using var context = _contextFactory.CreateReadContext();
            var statuses = await context.Set<BatchJobExecutionLog>()
                .Select(x => x.Status)
                .Distinct()
                .OrderBy(x => x)
                .ToListAsync();

            // Cache the result
            _cache.Set(JOB_STATUSES_CACHE_KEY, statuses, _cacheExpiration);

            return statuses;
        }

        public async Task<Dictionary<string, object>> GetBatchJobSummaryAsync(int daysBack = 7)
        {
            using var context = _contextFactory.CreateReadContext();
            var cutoffDate = DateTime.Now.AddDays(-daysBack);
            
            var summary = await context.Set<BatchJobExecutionLog>()
                .Where(x => x.StartTime >= cutoffDate)
                .GroupBy(x => 1)
                .Select(g => new
                {
                    TotalJobs = g.Count(),
                    CompletedJobs = g.Count(x => x.Status == "Completed"),
                    FailedJobs = g.Count(x => x.Status == "Failed"),
                    RunningJobs = g.Count(x => x.Status == "Running"),
                    AvgDurationSeconds = g.Where(x => x.DurationSeconds.HasValue).Average(x => x.DurationSeconds),
                    TotalRecordsProcessed = g.Sum(x => x.RecordsProcessed)
                })
                .FirstOrDefaultAsync();

            return new Dictionary<string, object>
            {
                ["TotalJobs"] = summary?.TotalJobs ?? 0,
                ["CompletedJobs"] = summary?.CompletedJobs ?? 0,
                ["FailedJobs"] = summary?.FailedJobs ?? 0,
                ["RunningJobs"] = summary?.RunningJobs ?? 0,
                ["SuccessRate"] = summary?.TotalJobs > 0 ? Math.Round((double)(summary.CompletedJobs * 100) / summary.TotalJobs, 2) : 0,
                ["AvgDurationSeconds"] = Math.Round(summary?.AvgDurationSeconds ?? 0, 2),
                ["TotalRecordsProcessed"] = summary?.TotalRecordsProcessed ?? 0
            };
        }

        // Dashboard Data Methods
        public async Task<ReportingDashboardViewModel> GetDashboardDataAsync(ReportingDashboardFilter filter)
        {
            var viewModel = new ReportingDashboardViewModel
            {
                Filter = filter
            };

            // Get recent daily summaries (last 30 days if no filter)
            var dailyStartDate = filter.StartDate ?? DateTime.Now.AddDays(-30);
            var dailyEndDate = filter.EndDate ?? DateTime.Now;
            viewModel.DailySummaries = await GetDailyApplicationSummariesAsync(dailyStartDate, dailyEndDate);

            // Get recent monthly performance (last 6 months if no filter)
            var monthlyStartDate = filter.StartDate ?? DateTime.Now.AddMonths(-6);
            var monthlyEndDate = filter.EndDate ?? DateTime.Now;
            viewModel.MonthlyPerformance = await GetMonthlyLoanOfficerPerformanceAsync(monthlyStartDate, monthlyEndDate);

            // Get recent weekly analytics (last 12 weeks if no filter)
            var weeklyStartDate = filter.StartDate ?? DateTime.Now.AddDays(-84);
            var weeklyEndDate = filter.EndDate ?? DateTime.Now;
            viewModel.WeeklyAnalytics = await GetWeeklyCustomerAnalyticsAsync(weeklyStartDate, weeklyEndDate);

            return viewModel;
        }

        public async Task<BatchJobMonitorViewModel> GetBatchJobMonitorDataAsync(BatchJobMonitorFilter filter)
        {
            var viewModel = new BatchJobMonitorViewModel
            {
                Filter = filter
            };

            // Get job executions
            viewModel.JobExecutions = await GetBatchJobExecutionsAsync(filter.JobName, filter.DaysBack, filter.Status);

            // Get cached dropdown values
            viewModel.AvailableJobNames = await GetDistinctJobNamesAsync();
            viewModel.AvailableStatuses = await GetDistinctJobStatusesAsync();

            // Get summary statistics
            viewModel.Summary = await GetBatchJobSummaryAsync(filter.DaysBack);

            return viewModel;
        }
    }
}