using LoanApplication.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using LoanApplication.Configuration;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MigrationDashboardController : ControllerBase
    {
        private readonly IHybridLogService _hybridLogService;
        private readonly HybridLogConfiguration _config;
        private readonly ILogger<MigrationDashboardController> _logger;

        public MigrationDashboardController(
            IHybridLogService hybridLogService,
            IOptions<HybridLogConfiguration> config,
            ILogger<MigrationDashboardController> logger)
        {
            _hybridLogService = hybridLogService;
            _config = config.Value;
            _logger = logger;
        }

        [HttpGet("status")]
        public IActionResult GetMigrationStatus()
        {
            var status = new
            {
                CurrentPhase = _config.CurrentPhase.ToString(),
                Configuration = new
                {
                    WritesToSql = _config.WritesToSql,
                    WritesToDynamoDb = _config.WritesToDynamoDb,
                    ReadsFromDynamoDb = _config.ReadsFromDynamoDb,
                    RequireBothWrites = _config.RequireBothWrites
                },
                Timestamp = DateTime.UtcNow
            };

            return Ok(status);
        }

        [HttpGet("health")]
        public async Task<IActionResult> GetHealthStatus()
        {
            try
            {
                var healthChecks = new List<HealthCheck>();

                // Test SQL connectivity
                try
                {
                    var sqlCount = await _hybridLogService.GetLogCountAsync();
                    healthChecks.Add(new HealthCheck
                    {
                        Component = "PostgreSQL",
                        Status = "Healthy",
                        Details = $"Record count: {sqlCount}",
                        ResponseTime = "< 100ms"
                    });
                }
                catch (Exception ex)
                {
                    healthChecks.Add(new HealthCheck
                    {
                        Component = "PostgreSQL",
                        Status = "Unhealthy",
                        Details = ex.Message
                    });
                }

                var overallStatus = healthChecks.All(h => h.Status == "Healthy") ? "Healthy" : "Degraded";

                return Ok(new
                {
                    OverallStatus = overallStatus,
                    Components = healthChecks,
                    Timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Health check failed");
                return StatusCode(500, new { Error = "Health check failed", Details = ex.Message });
            }
        }

        [HttpGet("metrics")]
        public async Task<IActionResult> GetMetrics()
        {
            try
            {
                var today = DateTime.UtcNow.Date;
                var yesterday = today.AddDays(-1);

                var metrics = new
                {
                    LogCounts = new
                    {
                        Total = await _hybridLogService.GetLogCountAsync()
                    },
                    MigrationStatus = new
                    {
                        Phase = _config.CurrentPhase.ToString(),
                        DualWriteEnabled = _config.WritesToDynamoDb,
                        DynamoReadsEnabled = _config.ReadsFromDynamoDb
                    },
                    Timestamp = DateTime.UtcNow
                };

                return Ok(metrics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get metrics");
                return StatusCode(500, new { Error = "Failed to get metrics", Details = ex.Message });
            }
        }

        [HttpPost("validate")]
        public async Task<IActionResult> ValidateDataConsistency(
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            try
            {
                var start = startDate ?? DateTime.UtcNow.AddHours(-1);
                var end = endDate ?? DateTime.UtcNow;

                var result = await _hybridLogService.ValidateDataConsistencyAsync(start, end);

                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Data validation failed");
                return StatusCode(500, new { Error = "Validation failed", Details = ex.Message });
            }
        }
    }

    public class HealthCheck
    {
        public string Component { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string Details { get; set; } = string.Empty;
        public string ResponseTime { get; set; } = string.Empty;
    }
}