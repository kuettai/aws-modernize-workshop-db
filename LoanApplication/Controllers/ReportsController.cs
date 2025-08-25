using LoanApplication.Models;
using LoanApplication.Services;
using Microsoft.AspNetCore.Mvc;

namespace LoanApplication.Controllers
{
    public class ReportsController : Controller
    {
        private readonly IReportingService _reportingService;
        private readonly ILogger<ReportsController> _logger;

        public ReportsController(IReportingService reportingService, ILogger<ReportsController> logger)
        {
            _reportingService = reportingService;
            _logger = logger;
        }

        // Main Dashboard
        public async Task<IActionResult> Dashboard(ReportingDashboardFilter? filter)
        {
            try
            {
                filter ??= new ReportingDashboardFilter();
                var viewModel = await _reportingService.GetDashboardDataAsync(filter);
                return View(viewModel);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading reporting dashboard");
                TempData["ErrorMessage"] = "Error loading dashboard data. Please try again.";
                return View(new ReportingDashboardViewModel());
            }
        }

        // Batch Job Monitor
        public async Task<IActionResult> BatchJobMonitor(BatchJobMonitorFilter? filter)
        {
            try
            {
                filter ??= new BatchJobMonitorFilter();
                var viewModel = await _reportingService.GetBatchJobMonitorDataAsync(filter);
                return View(viewModel);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading batch job monitor");
                TempData["ErrorMessage"] = "Error loading batch job data. Please try again.";
                return View(new BatchJobMonitorViewModel());
            }
        }

        // Daily Application Summary Details
        public async Task<IActionResult> DailyApplicationSummary(DateTime? startDate, DateTime? endDate)
        {
            try
            {
                var summaries = await _reportingService.GetDailyApplicationSummariesAsync(startDate, endDate);
                ViewBag.StartDate = startDate?.ToString("yyyy-MM-dd");
                ViewBag.EndDate = endDate?.ToString("yyyy-MM-dd");
                return View(summaries);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading daily application summary");
                TempData["ErrorMessage"] = "Error loading daily summary data.";
                return View(new List<DailyApplicationSummary>());
            }
        }

        // Monthly Loan Officer Performance Details
        public async Task<IActionResult> MonthlyLoanOfficerPerformance(DateTime? startMonth, DateTime? endMonth)
        {
            try
            {
                var performance = await _reportingService.GetMonthlyLoanOfficerPerformanceAsync(startMonth, endMonth);
                ViewBag.StartMonth = startMonth?.ToString("yyyy-MM");
                ViewBag.EndMonth = endMonth?.ToString("yyyy-MM");
                return View(performance);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading loan officer performance");
                TempData["ErrorMessage"] = "Error loading performance data.";
                return View(new List<MonthlyLoanOfficerPerformance>());
            }
        }

        // Weekly Customer Analytics Details
        public async Task<IActionResult> WeeklyCustomerAnalytics(DateTime? startWeek, DateTime? endWeek, string? segment)
        {
            try
            {
                List<WeeklyCustomerAnalytics> analytics;
                
                if (!string.IsNullOrEmpty(segment))
                {
                    analytics = await _reportingService.GetCustomerAnalyticsBySegmentAsync(segment, startWeek, endWeek);
                }
                else
                {
                    analytics = await _reportingService.GetWeeklyCustomerAnalyticsAsync(startWeek, endWeek);
                }

                ViewBag.StartWeek = startWeek?.ToString("yyyy-MM-dd");
                ViewBag.EndWeek = endWeek?.ToString("yyyy-MM-dd");
                ViewBag.Segment = segment;
                return View(analytics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading customer analytics");
                TempData["ErrorMessage"] = "Error loading analytics data.";
                return View(new List<WeeklyCustomerAnalytics>());
            }
        }

        // API Endpoints for AJAX calls
        [HttpGet]
        public async Task<IActionResult> GetJobNames()
        {
            try
            {
                var jobNames = await _reportingService.GetDistinctJobNamesAsync();
                return Json(jobNames);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting job names");
                return Json(new List<string>());
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetJobStatuses()
        {
            try
            {
                var statuses = await _reportingService.GetDistinctJobStatusesAsync();
                return Json(statuses);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting job statuses");
                return Json(new List<string>());
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetBatchJobSummary(int daysBack = 7)
        {
            try
            {
                var summary = await _reportingService.GetBatchJobSummaryAsync(daysBack);
                return Json(summary);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting batch job summary");
                return Json(new Dictionary<string, object>());
            }
        }

        // Refresh Cache
        [HttpPost]
        public async Task<IActionResult> RefreshCache()
        {
            try
            {
                // Force refresh by calling the methods (cache will be updated)
                await _reportingService.GetDistinctJobNamesAsync();
                await _reportingService.GetDistinctJobStatusesAsync();
                
                TempData["SuccessMessage"] = "Cache refreshed successfully.";
                return Json(new { success = true, message = "Cache refreshed successfully." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error refreshing cache");
                return Json(new { success = false, message = "Error refreshing cache." });
            }
        }

        // Export functionality (basic CSV export)
        public async Task<IActionResult> ExportDailySummary(DateTime? startDate, DateTime? endDate)
        {
            try
            {
                var summaries = await _reportingService.GetDailyApplicationSummariesAsync(startDate, endDate);
                
                var csv = "ReportDate,TotalApplications,ApprovedApplications,RejectedApplications,PendingApplications,ApprovalRate,TotalRequestedAmount,AvgRequestedAmount,AvgProcessingHours\n";
                
                foreach (var summary in summaries)
                {
                    csv += $"{summary.ReportDate:yyyy-MM-dd},{summary.TotalApplications},{summary.ApprovedApplications},{summary.RejectedApplications},{summary.PendingApplications},{summary.ApprovalRate},{summary.TotalRequestedAmount},{summary.AvgRequestedAmount},{summary.AvgProcessingHours}\n";
                }

                var bytes = System.Text.Encoding.UTF8.GetBytes(csv);
                return File(bytes, "text/csv", $"DailyApplicationSummary_{DateTime.Now:yyyyMMdd}.csv");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting daily summary");
                TempData["ErrorMessage"] = "Error exporting data.";
                return RedirectToAction(nameof(DailyApplicationSummary));
            }
        }
    }
}