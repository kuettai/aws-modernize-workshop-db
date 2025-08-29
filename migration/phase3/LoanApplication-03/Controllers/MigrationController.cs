using LoanApplication.Services;
using LoanApplication.Models;
using Microsoft.AspNetCore.Mvc;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MigrationController : ControllerBase
    {
        private readonly IHybridLogService _hybridLogService;
        private readonly ILogger<MigrationController> _logger;
        
        public MigrationController(IHybridLogService hybridLogService, ILogger<MigrationController> logger)
        {
            _hybridLogService = hybridLogService;
            _logger = logger;
        }
        
        [HttpPost("enable-dual-write")]
        public async Task<IActionResult> EnableDualWrite()
        {
            var success = await _hybridLogService.EnableDualWriteAsync();
            return Ok(new { success, message = "Dual-write mode enabled" });
        }
        
        [HttpPost("switch-to-dynamo-reads")]
        public async Task<IActionResult> SwitchToDynamoReads()
        {
            var success = await _hybridLogService.SwitchToDynamoDbReadsAsync();
            return Ok(new { success, message = "Switched to DynamoDB reads" });
        }
        
        [HttpPost("disable-sql-writes")]
        public async Task<IActionResult> DisableSqlWrites()
        {
            var success = await _hybridLogService.DisableSqlWritesAsync();
            return Ok(new { success, message = "SQL writes disabled" });
        }
        
        [HttpGet("validate-consistency")]
        public async Task<IActionResult> ValidateConsistency(
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            var start = startDate ?? DateTime.UtcNow.AddDays(-1);
            var end = endDate ?? DateTime.UtcNow;
            
            var result = await _hybridLogService.ValidateDataConsistencyAsync(start, end);
            return Ok(result);
        }
        
        [HttpPost("test-dual-write")]
        public async Task<IActionResult> TestDualWrite()
        {
            var testLog = new IntegrationLog
            {
                LogType = "TEST",
                ServiceName = "MigrationTestService",
                LogTimestamp = DateTime.UtcNow,
                IsSuccess = true,
                RequestData = "{\"test\": \"dual-write\"}",
                ResponseData = "{\"result\": \"success\"}",
                CorrelationId = Guid.NewGuid().ToString()
            };
            
            var success = await _hybridLogService.WriteLogAsync(testLog);
            return Ok(new { success, testLog.LogId, testLog.CorrelationId });
        }
    }
}