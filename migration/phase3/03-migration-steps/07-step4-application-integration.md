# Step 4: Application Integration
## Phase 3: DynamoDB Migration - Complete Application Updates

### 🎯 Objective
Update the loan application to use the hybrid logging service and complete the migration to DynamoDB with proper monitoring and validation.

### 🔧 Updated Controller Implementation

#### DocsController.cs (Updated for Hybrid Logging)
```csharp
using LoanApplication.Data;
using LoanApplication.Services;
using Microsoft.AspNetCore.Mvc;
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
                
                return View(stats);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading documentation statistics");
                return View(new { Error = "Unable to load statistics" });
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
        
        private string GetCurrentMigrationPhase()
        {
            // This would be read from configuration or database
            return "Phase 2: Dual-Write with DynamoDB Reads";
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
```

### 🏗️ Enhanced Service Layer with Logging

#### CreditCheckService.cs (Updated with Hybrid Logging)
```csharp
using LoanApplication.Models;
using LoanApplication.Services;
using System.Text.Json;

namespace LoanApplication.Services
{
    public class CreditCheckService : ICreditCheckService
    {
        private readonly IHybridLogService _logService;
        private readonly ILogger<CreditCheckService> _logger;
        
        public CreditCheckService(IHybridLogService logService, ILogger<CreditCheckService> logger)
        {
            _logService = logService;
            _logger = logger;
        }
        
        public async Task<CreditCheckResult> CheckCreditAsync(int customerId, decimal loanAmount)
        {
            var correlationId = Guid.NewGuid().ToString();
            var startTime = DateTime.UtcNow;
            
            // Log request
            var requestLog = new IntegrationLog
            {
                LogType = "API",
                ServiceName = "CreditCheckService",
                LogTimestamp = startTime,
                RequestData = JsonSerializer.Serialize(new { customerId, loanAmount }),
                CorrelationId = correlationId,
                UserId = "system" // In real app, get from context
            };
            
            try
            {
                _logger.LogInformation("Starting credit check for customer {CustomerId}, amount {Amount}", 
                    customerId, loanAmount);
                
                // Simulate credit check processing
                await Task.Delay(Random.Shared.Next(100, 500)); // Simulate API call time
                
                var creditScore = Random.Shared.Next(300, 850);
                var isApproved = creditScore >= 650 && loanAmount <= 100000;
                
                var result = new CreditCheckResult
                {
                    CustomerId = customerId,
                    CreditScore = creditScore,
                    IsApproved = isApproved,
                    MaxLoanAmount = isApproved ? loanAmount * 1.2m : 0,
                    CheckDate = DateTime.UtcNow,
                    CorrelationId = correlationId
                };
                
                // Log successful response
                var processingTime = (int)(DateTime.UtcNow - startTime).TotalMilliseconds;
                requestLog.ResponseData = JsonSerializer.Serialize(result);
                requestLog.IsSuccess = true;
                requestLog.StatusCode = "200";
                requestLog.ProcessingTimeMs = processingTime;
                
                await _logService.WriteLogAsync(requestLog);
                
                _logger.LogInformation("Credit check completed for customer {CustomerId}. Score: {Score}, Approved: {Approved}", 
                    customerId, creditScore, isApproved);
                
                return result;
            }
            catch (Exception ex)
            {
                // Log error
                var processingTime = (int)(DateTime.UtcNow - startTime).TotalMilliseconds;
                requestLog.IsSuccess = false;
                requestLog.StatusCode = "500";
                requestLog.ErrorMessage = ex.Message;
                requestLog.ProcessingTimeMs = processingTime;
                
                await _logService.WriteLogAsync(requestLog);
                
                _logger.LogError(ex, "Credit check failed for customer {CustomerId}", customerId);
                throw;
            }
        }
    }
    
    public class CreditCheckResult
    {
        public int CustomerId { get; set; }
        public int CreditScore { get; set; }
        public bool IsApproved { get; set; }
        public decimal MaxLoanAmount { get; set; }
        public DateTime CheckDate { get; set; }
        public string CorrelationId { get; set; } = string.Empty;
    }
}
```

### 📊 Migration Monitoring Dashboard

#### MigrationDashboardController.cs
```csharp
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
                
                // Test DynamoDB connectivity
                try
                {
                    var testLog = new IntegrationLog
                    {
                        LogType = "HEALTH_CHECK",
                        ServiceName = "HealthCheckService",
                        LogTimestamp = DateTime.UtcNow,
                        IsSuccess = true,
                        RequestData = "{\"type\": \"health_check\"}",
                        CorrelationId = Guid.NewGuid().ToString()
                    };
                    
                    var success = await _hybridLogService.WriteLogAsync(testLog);
                    
                    healthChecks.Add(new HealthCheck
                    {
                        Component = "DynamoDB",
                        Status = success ? "Healthy" : "Degraded",
                        Details = success ? "Write test successful" : "Write test failed",
                        ResponseTime = "< 200ms"
                    });
                }
                catch (Exception ex)
                {
                    healthChecks.Add(new HealthCheck
                    {
                        Component = "DynamoDB",
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
                        Total = await _hybridLogService.GetLogCountAsync(),
                        TodayErrors = (await _hybridLogService.GetErrorLogsByDateAsync(today)).Count(),
                        YesterdayErrors = (await _hybridLogService.GetErrorLogsByDateAsync(yesterday)).Count()
                    },
                    MigrationStatus = new
                    {
                        Phase = _config.CurrentPhase.ToString(),
                        DualWriteEnabled = _config.WritesToDynamoDb,
                        DynamoReadsEnabled = _config.ReadsFromDynamoDb
                    },
                    Performance = new
                    {
                        AvgResponseTime = "245ms", // Would calculate from actual logs
                        ErrorRate = "0.5%",        // Would calculate from actual logs
                        Throughput = "150 req/min" // Would calculate from actual logs
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
```

### 🎨 Updated Views for Migration Status

#### Views/Docs/Index.cshtml (Updated)
```html
@model dynamic

<div class="container-fluid">
    <div class="row">
        <div class="col-12">
            <h1>📊 Database Modernization Workshop - Documentation</h1>
            <p class="lead">Interactive documentation and statistics for the loan application system</p>
        </div>
    </div>
    
    <!-- Migration Status Card -->
    <div class="row mb-4">
        <div class="col-12">
            <div class="card border-info">
                <div class="card-header bg-info text-white">
                    <h5><i class="fas fa-exchange-alt"></i> Migration Status - Phase 3: DynamoDB Integration</h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-3">
                            <div class="text-center">
                                <h6>Current Phase</h6>
                                <span class="badge badge-primary badge-lg" id="migration-phase">Loading...</span>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="text-center">
                                <h6>Data Sources</h6>
                                <small id="data-sources">Loading...</small>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="text-center">
                                <h6>Health Status</h6>
                                <span class="badge badge-success" id="health-status">Healthy</span>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="text-center">
                                <h6>Actions</h6>
                                <button class="btn btn-sm btn-outline-primary" onclick="validateMigration()">Validate</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Existing statistics cards -->
    <div class="row">
        <!-- Business Data Statistics -->
        <div class="col-md-6">
            <div class="card">
                <div class="card-header">
                    <h5><i class="fas fa-database"></i> Business Data (PostgreSQL)</h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number">@Model.Applications</span>
                                <span class="stat-label">Applications</span>
                            </div>
                        </div>
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number">@Model.Customers</span>
                                <span class="stat-label">Customers</span>
                            </div>
                        </div>
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number">@Model.Loans</span>
                                <span class="stat-label">Loans</span>
                            </div>
                        </div>
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number">@Model.Payments</span>
                                <span class="stat-label">Payments</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Logging Data Statistics -->
        <div class="col-md-6">
            <div class="card">
                <div class="card-header">
                    <h5><i class="fas fa-chart-line"></i> Logging Data (Hybrid)</h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number" id="total-logs">@Model.IntegrationLogs</span>
                                <span class="stat-label">Total Logs</span>
                            </div>
                        </div>
                        <div class="col-6">
                            <div class="stat-item">
                                <span class="stat-number text-danger" id="today-errors">Loading...</span>
                                <span class="stat-label">Today's Errors</span>
                            </div>
                        </div>
                        <div class="col-12 mt-3">
                            <button class="btn btn-outline-info btn-sm" onclick="refreshLoggingStats()">
                                <i class="fas fa-sync"></i> Refresh Stats
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Migration Controls (Admin Only) -->
    <div class="row mt-4">
        <div class="col-12">
            <div class="card border-warning">
                <div class="card-header bg-warning">
                    <h5><i class="fas fa-cogs"></i> Migration Controls</h5>
                </div>
                <div class="card-body">
                    <div class="btn-group" role="group">
                        <button class="btn btn-outline-primary" onclick="enableDualWrite()">Enable Dual Write</button>
                        <button class="btn btn-outline-success" onclick="switchToDynamoReads()">Switch to DynamoDB Reads</button>
                        <button class="btn btn-outline-danger" onclick="disableSqlWrites()">Disable SQL Writes</button>
                    </div>
                    <div class="mt-3">
                        <button class="btn btn-info" onclick="testDualWrite()">Test Dual Write</button>
                        <button class="btn btn-secondary" onclick="showMigrationDashboard()">View Dashboard</button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
// Migration status functions
async function refreshLoggingStats() {
    try {
        const response = await fetch('/Docs/LoggingStats');
        const data = await response.json();
        
        document.getElementById('total-logs').textContent = data.totalLogs;
        document.getElementById('today-errors').textContent = data.todayErrors;
        document.getElementById('migration-phase').textContent = data.migrationPhase;
        
        // Update data sources info
        const dataSources = `Business: ${data.dataSources.businessData}<br>Logs: ${data.dataSources.loggingData}`;
        document.getElementById('data-sources').innerHTML = dataSources;
    } catch (error) {
        console.error('Failed to refresh stats:', error);
    }
}

async function validateMigration() {
    try {
        const response = await fetch('/api/MigrationDashboard/validate', { method: 'POST' });
        const result = await response.json();
        
        const status = result.isConsistent ? 'Consistent' : 'Inconsistent';
        const alertClass = result.isConsistent ? 'alert-success' : 'alert-warning';
        
        const alertHtml = `
            <div class="alert ${alertClass} alert-dismissible fade show">
                <strong>Validation Result:</strong> ${status}<br>
                SQL Records: ${result.sqlRecordCount}<br>
                DynamoDB Records: ${result.dynamoDbRecordCount}<br>
                Duration: ${result.validationDuration}
                <button type="button" class="close" data-dismiss="alert">&times;</button>
            </div>
        `;
        
        document.querySelector('.container-fluid').insertAdjacentHTML('afterbegin', alertHtml);
    } catch (error) {
        console.error('Validation failed:', error);
    }
}

async function enableDualWrite() {
    try {
        const response = await fetch('/api/Migration/enable-dual-write', { method: 'POST' });
        const result = await response.json();
        showAlert(result.message, 'success');
        refreshLoggingStats();
    } catch (error) {
        showAlert('Failed to enable dual write', 'danger');
    }
}

async function switchToDynamoReads() {
    try {
        const response = await fetch('/api/Migration/switch-to-dynamo-reads', { method: 'POST' });
        const result = await response.json();
        showAlert(result.message, 'success');
        refreshLoggingStats();
    } catch (error) {
        showAlert('Failed to switch to DynamoDB reads', 'danger');
    }
}

async function disableSqlWrites() {
    if (!confirm('Are you sure you want to disable SQL writes? This completes the migration to DynamoDB.')) {
        return;
    }
    
    try {
        const response = await fetch('/api/Migration/disable-sql-writes', { method: 'POST' });
        const result = await response.json();
        showAlert(result.message, 'success');
        refreshLoggingStats();
    } catch (error) {
        showAlert('Failed to disable SQL writes', 'danger');
    }
}

async function testDualWrite() {
    try {
        const response = await fetch('/api/Migration/test-dual-write', { method: 'POST' });
        const result = await response.json();
        
        if (result.success) {
            showAlert(`Test successful! Log ID: ${result.logId}`, 'success');
        } else {
            showAlert('Test failed', 'danger');
        }
    } catch (error) {
        showAlert('Test request failed', 'danger');
    }
}

function showAlert(message, type) {
    const alertHtml = `
        <div class="alert alert-${type} alert-dismissible fade show">
            ${message}
            <button type="button" class="close" data-dismiss="alert">&times;</button>
        </div>
    `;
    document.querySelector('.container-fluid').insertAdjacentHTML('afterbegin', alertHtml);
}

// Load initial data
document.addEventListener('DOMContentLoaded', function() {
    refreshLoggingStats();
});
</script>
```

### ⚙️ Updated Program.cs

#### Program.cs (Complete Integration)
```csharp
using LoanApplication.Data;
using LoanApplication.Extensions;
using LoanApplication.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllersWithViews();

// Database context
builder.Services.AddDbContext<LoanApplicationContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Add hybrid logging services (includes DynamoDB)
builder.Services.AddHybridLoggingServices(builder.Configuration);

// Add business services
builder.Services.AddScoped<ICreditCheckService, CreditCheckService>();
builder.Services.AddScoped<ILoanService, LoanService>();
builder.Services.AddScoped<IDSRCalculationService, DSRCalculationService>();

// Add logging
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Health check endpoint
app.MapGet("/health", async (IServiceProvider services) =>
{
    var hybridService = services.GetRequiredService<IHybridLogService>();
    
    try
    {
        var count = await hybridService.GetLogCountAsync();
        return Results.Ok(new { Status = "Healthy", LogCount = count, Timestamp = DateTime.UtcNow });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Health check failed: {ex.Message}");
    }
});

app.Run();
```

### 🚀 Complete Migration Workflow

#### Migration Execution Steps
1. **Deploy DynamoDB table** using CloudFormation
2. **Update application** with hybrid logging service
3. **Enable dual-write mode** via API or configuration
4. **Run data migration tool** to transfer historical data
5. **Validate data consistency** using validation endpoints
6. **Switch reads to DynamoDB** when validation passes
7. **Disable SQL writes** to complete migration

#### Rollback Plan
- Each phase can be reversed by updating configuration
- SQL data remains intact throughout migration
- DynamoDB table can be recreated if needed

---

### 💡 Q Developer Integration Points

```
1. "Review this complete application integration and suggest improvements for monitoring, error handling, and user experience during migration."

2. "Analyze the migration workflow and recommend additional safety measures and validation steps for production deployment."

3. "Examine the dashboard implementation and suggest enhancements for real-time monitoring and alerting during the migration process."
```

**Next**: [Testing and Validation](../05-comparison/01-validation-procedures.md)