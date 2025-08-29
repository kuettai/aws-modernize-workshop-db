using Microsoft.AspNetCore.Mvc;
using LoanApplication.Data;
using LoanApplication.Services;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Controllers
{
    public class DocsController : Controller
    {
        private readonly LoanApplicationContext _context;
        private readonly IHybridLogService _hybridLogService;
        private readonly ILogger<DocsController> _logger;

        public DocsController(
            LoanApplicationContext context, 
            IHybridLogService hybridLogService,
            ILogger<DocsController> logger)
        {
            _context = context;
            _hybridLogService = hybridLogService;
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            try
            {
                // Get live database statistics
                var stats = new
                {
                    // Core business data (still from PostgreSQL)
                    Applications = await _context.Applications.CountAsync(),
                    Customers = await _context.Customers.CountAsync(),
                    Loans = await _context.Loans.CountAsync(),
                    Payments = await _context.Payments.CountAsync(),
                    Documents = await _context.Documents.CountAsync(),
                    CreditChecks = await _context.CreditChecks.CountAsync(),
                    Branches = await _context.Branches.CountAsync(),
                    LoanOfficers = await _context.LoanOfficers.CountAsync(),
                    
                    // Logging data (from hybrid service - could be SQL or DynamoDB)
                    IntegrationLogs = await _hybridLogService.GetLogCountAsync(),
                    
                    // Migration status
                    MigrationPhase = GetCurrentMigrationPhase(),
                    LastUpdated = DateTime.Now
                };

                ViewBag.DatabaseStats = stats;
                return View();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading documentation statistics");
                ViewBag.DatabaseStats = new { Error = "Unable to load statistics" };
                return View();
            }
        }

        [HttpGet]
        public async Task<IActionResult> LoggingStats()
        {
            try
            {
                var today = DateTime.UtcNow.Date;
                var yesterday = today.AddDays(-1);

                var stats = new
                {
                    TotalLogs = await _hybridLogService.GetLogCountAsync(),
                    TodayErrors = (await _hybridLogService.GetErrorLogsByDateAsync(today)).Count(),
                    YesterdayErrors = (await _hybridLogService.GetErrorLogsByDateAsync(yesterday)).Count(),
                    MigrationPhase = GetCurrentMigrationPhase(),
                    DataSources = GetActiveDataSources()
                };

                return Json(stats);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading logging statistics");
                return Json(new { Error = ex.Message });
            }
        }

        [HttpGet]
        public async Task<IActionResult> ApplicationLogs(int applicationId)
        {
            try
            {
                var logs = await _hybridLogService.GetLogsByApplicationIdAsync(applicationId);

                var logData = logs.Select(log => new
                {
                    log.LogId,
                    log.LogType,
                    log.ServiceName,
                    log.LogTimestamp,
                    log.IsSuccess,
                    log.ProcessingTimeMs,
                    log.StatusCode,
                    log.CorrelationId
                }).OrderByDescending(l => l.LogTimestamp);

                return Json(logData);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading application logs for {ApplicationId}", applicationId);
                return Json(new { Error = ex.Message });
            }
        }

        public IActionResult Architecture()
        {
            return View();
        }

        public IActionResult Database()
        {
            return View();
        }

        public IActionResult Migration()
        {
            return View();
        }

        private string GetCurrentMigrationPhase()
        {
            // This would be read from configuration or database
            return "Phase 3: DynamoDB Integration";
        }

        private object GetActiveDataSources()
        {
            return new
            {
                BusinessData = "PostgreSQL",
                LoggingData = "Hybrid (SQL + DynamoDB)",
                ReadsFrom = "DynamoDB",
                WritesTo = "Both"
            };
        }
    }
}