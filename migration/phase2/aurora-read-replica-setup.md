# Aurora PostgreSQL Read Replica Setup
## Optimizing Reporting Performance with Read Replicas

### 🎯 Read Replica Objectives
- Separate read workloads from write operations
- Optimize reporting query performance
- Reduce load on primary Aurora cluster
- Implement connection routing in .NET application

### 📋 Prerequisites
- Aurora PostgreSQL cluster running
- DMS migration completed
- Reporting scripts converted to PostgreSQL
- VPC and security groups configured

### 🚀 Create Aurora Read Replica

#### AWS CLI Commands
```bash
# Create Aurora read replica
aws rds create-db-instance \
    --db-instance-identifier workshop-aurora-postgresql-reader \
    --db-instance-class db.r6g.large \
    --engine postgres \
    --db-cluster-identifier workshop-aurora-postgresql-cluster \
    --publicly-accessible true \
    --tags Key=Workshop,Value=DatabaseModernization Key=Type,Value=ReadReplica

# Wait for read replica to be available
aws rds wait db-instance-available \
    --db-instance-identifier workshop-aurora-postgresql-reader

# Get read replica endpoint
aws rds describe-db-instances \
    --db-instance-identifier workshop-aurora-postgresql-reader \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

#### Verify Read Replica Status
```bash
# Check replication lag
aws rds describe-db-instances \
    --db-instance-identifier workshop-aurora-postgresql-reader \
    --query 'DBInstances[0].{Status:DBInstanceStatus,ReplicaLag:ReadReplicaDBInstanceIdentifiers}'

# Monitor read replica metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-aurora-postgresql-reader \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

### 🔗 Connection String Configuration

#### appsettings.json Updates
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com;Database=loanapplicationdb;Username=postgres;Password=WorkshopDB123!;SSL Mode=Require;Trust Server Certificate=true;",
    "ReadOnlyConnection": "Host=workshop-aurora-postgresql-reader.xxxxxxxxx.us-east-1.rds.amazonaws.com;Database=loanapplicationdb;Username=postgres;Password=WorkshopDB123!;SSL Mode=Require;Trust Server Certificate=true;"
  },
  "DatabaseSettings": {
    "EnableReadReplica": true,
    "ReadReplicaConnectionTimeout": 30,
    "ConnectionPoolSize": 20
  }
}
```

### 🏗️ .NET Application Updates

#### Database Context Configuration
```csharp
// Data/ApplicationDbContextFactory.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

public class ApplicationDbContextFactory
{
    private readonly IConfiguration _configuration;
    
    public ApplicationDbContextFactory(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    
    public ApplicationDbContext CreateWriteContext()
    {
        var optionsBuilder = new DbContextOptionsBuilder<ApplicationDbContext>();
        optionsBuilder.UseNpgsql(_configuration.GetConnectionString("DefaultConnection"));
        return new ApplicationDbContext(optionsBuilder.Options);
    }
    
    public ApplicationDbContext CreateReadContext()
    {
        var enableReadReplica = _configuration.GetValue<bool>("DatabaseSettings:EnableReadReplica");
        var connectionString = enableReadReplica 
            ? _configuration.GetConnectionString("ReadOnlyConnection")
            : _configuration.GetConnectionString("DefaultConnection");
            
        var optionsBuilder = new DbContextOptionsBuilder<ApplicationDbContext>();
        optionsBuilder.UseNpgsql(connectionString);
        return new ApplicationDbContext(optionsBuilder.Options);
    }
}
```

#### Service Registration
```csharp
// Program.cs updates
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register read replica factory
builder.Services.AddScoped<ApplicationDbContextFactory>();

// Register separate contexts
builder.Services.AddDbContext<ApplicationDbContext>("WriteContext", options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddDbContext<ApplicationDbContext>("ReadContext", options => {
    var enableReadReplica = builder.Configuration.GetValue<bool>("DatabaseSettings:EnableReadReplica");
    var connectionString = enableReadReplica 
        ? builder.Configuration.GetConnectionString("ReadOnlyConnection")
        : builder.Configuration.GetConnectionString("DefaultConnection");
    options.UseNpgsql(connectionString);
});
```

### 📊 Updated Reporting Service

#### Enhanced ReportingService with Read Replica
```csharp
// Services/ReportingService.cs
using Microsoft.Extensions.Caching.Memory;
using Microsoft.EntityFrameworkCore;

public class ReportingService : IReportingService
{
    private readonly ApplicationDbContextFactory _contextFactory;
    private readonly IMemoryCache _cache;
    private readonly ILogger<ReportingService> _logger;
    
    public ReportingService(
        ApplicationDbContextFactory contextFactory,
        IMemoryCache cache,
        ILogger<ReportingService> logger)
    {
        _contextFactory = contextFactory;
        _cache = cache;
        _logger = logger;
    }
    
    public async Task<List<DailyApplicationSummary>> GetDailyApplicationSummariesAsync(DateTime? startDate = null, DateTime? endDate = null)
    {
        using var context = _contextFactory.CreateReadContext();
        
        var query = context.DailyApplicationSummaries.AsQueryable();
        
        if (startDate.HasValue)
            query = query.Where(x => x.ReportDate >= startDate.Value);
            
        if (endDate.HasValue)
            query = query.Where(x => x.ReportDate <= endDate.Value);
            
        return await query.OrderByDescending(x => x.ReportDate).ToListAsync();
    }
    
    public async Task<List<MonthlyLoanOfficerPerformance>> GetMonthlyLoanOfficerPerformanceAsync(DateTime? startMonth = null)
    {
        using var context = _contextFactory.CreateReadContext();
        
        var query = context.MonthlyLoanOfficerPerformances.AsQueryable();
        
        if (startMonth.HasValue)
            query = query.Where(x => x.ReportMonth >= startMonth.Value);
            
        return await query.OrderByDescending(x => x.ReportMonth)
                         .ThenBy(x => x.PerformanceRank)
                         .ToListAsync();
    }
    
    public async Task<List<string>> GetDistinctJobNamesAsync()
    {
        const string cacheKey = "distinct_job_names";
        
        if (_cache.TryGetValue(cacheKey, out List<string> cachedJobNames))
        {
            return cachedJobNames;
        }
        
        using var context = _contextFactory.CreateReadContext();
        
        var jobNames = await context.BatchJobExecutionLogs
            .Select(x => x.JobName)
            .Distinct()
            .OrderBy(x => x)
            .ToListAsync();
            
        _cache.Set(cacheKey, jobNames, TimeSpan.FromMinutes(15));
        
        return jobNames;
    }
    
    public async Task<List<BatchJobExecutionLog>> GetBatchJobExecutionLogsAsync(string jobName = null, int daysBack = 7)
    {
        using var context = _contextFactory.CreateReadContext();
        
        var cutoffDate = DateTime.UtcNow.AddDays(-daysBack);
        var query = context.BatchJobExecutionLogs
            .Where(x => x.StartTime >= cutoffDate);
            
        if (!string.IsNullOrEmpty(jobName))
            query = query.Where(x => x.JobName == jobName);
            
        return await query.OrderByDescending(x => x.StartTime).ToListAsync();
    }
}
```

### 🎛️ Connection Health Monitoring

#### Health Check Implementation
```csharp
// Services/DatabaseHealthService.cs
public class DatabaseHealthService : IHealthCheck
{
    private readonly ApplicationDbContextFactory _contextFactory;
    private readonly ILogger<DatabaseHealthService> _logger;
    
    public DatabaseHealthService(ApplicationDbContextFactory contextFactory, ILogger<DatabaseHealthService> logger)
    {
        _contextFactory = contextFactory;
        _logger = logger;
    }
    
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            // Check write connection
            using var writeContext = _contextFactory.CreateWriteContext();
            await writeContext.Database.ExecuteSqlRawAsync("SELECT 1", cancellationToken);
            
            // Check read connection
            using var readContext = _contextFactory.CreateReadContext();
            await readContext.Database.ExecuteSqlRawAsync("SELECT 1", cancellationToken);
            
            return HealthCheckResult.Healthy("Database connections are healthy");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed");
            return HealthCheckResult.Unhealthy("Database connection failed", ex);
        }
    }
}

// Program.cs registration
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthService>("database");
```

### 📈 Performance Monitoring

#### Connection Metrics Tracking
```csharp
// Services/ConnectionMetricsService.cs
public class ConnectionMetricsService
{
    private readonly ILogger<ConnectionMetricsService> _logger;
    private static readonly Counter ConnectionCounter = Metrics
        .CreateCounter("database_connections_total", "Total database connections", new[] { "type", "status" });
    
    public ConnectionMetricsService(ILogger<ConnectionMetricsService> logger)
    {
        _logger = logger;
    }
    
    public void RecordConnection(string connectionType, bool success)
    {
        var status = success ? "success" : "failure";
        ConnectionCounter.WithLabels(connectionType, status).Inc();
        
        _logger.LogInformation("Database connection {Type}: {Status}", connectionType, status);
    }
}
```

### 🔧 Testing Read Replica Performance

#### Performance Comparison Script
```sql
-- Test query performance on both endpoints
-- Run on primary cluster
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    r.reportdate,
    r.totalapplications,
    r.approvalrate,
    r.averageprocessingdays
FROM dailyapplicationsummary r
WHERE r.reportdate >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY r.reportdate DESC;

-- Run same query on read replica
-- Compare execution times and buffer usage
```

#### Automated Performance Test
```powershell
# PowerShell script to test read replica performance
param(
    [string]$PrimaryEndpoint = "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com",
    [string]$ReaderEndpoint = "workshop-aurora-postgresql-reader.xxxxxxxxx.us-east-1.rds.amazonaws.com",
    [string]$Password = "WorkshopDB123!"
)

$env:PGPASSWORD = $Password

$TestQuery = @"
SELECT COUNT(*) as total_records,
       AVG(approvalrate) as avg_approval_rate,
       MAX(totalapplications) as max_applications
FROM dailyapplicationsummary 
WHERE reportdate >= CURRENT_DATE - INTERVAL '30 days';
"@

Write-Host "=== Read Replica Performance Test ===" -ForegroundColor Cyan

# Test primary cluster
Write-Host "Testing Primary Cluster..." -ForegroundColor Yellow
$primaryStart = Get-Date
$primaryResult = psql -h $PrimaryEndpoint -U postgres -d loanapplicationdb -c "$TestQuery" -t
$primaryEnd = Get-Date
$primaryDuration = ($primaryEnd - $primaryStart).TotalMilliseconds

# Test read replica
Write-Host "Testing Read Replica..." -ForegroundColor Yellow
$readerStart = Get-Date
$readerResult = psql -h $ReaderEndpoint -U postgres -d loanapplicationdb -c "$TestQuery" -t
$readerEnd = Get-Date
$readerDuration = ($readerEnd - $readerStart).TotalMilliseconds

Write-Host "`nPerformance Results:" -ForegroundColor Cyan
Write-Host "Primary Cluster: $($primaryDuration)ms" -ForegroundColor Green
Write-Host "Read Replica: $($readerDuration)ms" -ForegroundColor Green

$improvement = [Math]::Round((($primaryDuration - $readerDuration) / $primaryDuration) * 100, 2)
if ($improvement -gt 0) {
    Write-Host "Read Replica is $improvement% faster" -ForegroundColor Green
} else {
    Write-Host "Primary is $([Math]::Abs($improvement))% faster" -ForegroundColor Yellow
}

Write-Host "`nResults Match: $(($primaryResult.Trim() -eq $readerResult.Trim()))" -ForegroundColor $(if($primaryResult.Trim() -eq $readerResult.Trim()){"Green"}else{"Red"})
```

### 📋 Read Replica Validation Checklist

#### Configuration Validation
- [ ] **Read Replica Created**: Aurora read replica instance running
- [ ] **Connection Strings**: Separate read/write connection strings configured
- [ ] **Security Groups**: Read replica accessible from application
- [ ] **DNS Resolution**: Read replica endpoint resolving correctly

#### Application Integration
- [ ] **Context Factory**: Database context factory implemented
- [ ] **Service Updates**: Reporting service using read replica
- [ ] **Health Checks**: Connection monitoring functional
- [ ] **Error Handling**: Fallback to primary on read replica failure

#### Performance Validation
- [ ] **Query Performance**: Read queries performing as expected
- [ ] **Connection Pooling**: Connection pools configured properly
- [ ] **Monitoring**: CloudWatch metrics collecting data
- [ ] **Load Distribution**: Read traffic routing to replica

### 🎯 Success Criteria

**Technical Success:**
- ✅ Read replica responding within 2 seconds
- ✅ Reporting queries using read replica endpoint
- ✅ Zero data inconsistency between primary and replica
- ✅ Application gracefully handles replica failures

**Performance Success:**
- ✅ 20-30% reduction in primary cluster load
- ✅ Improved reporting query response times
- ✅ Concurrent read operations without blocking writes
- ✅ Consistent performance under load

**Operational Success:**
- ✅ Monitoring and alerting configured
- ✅ Failover procedures documented
- ✅ Connection routing working automatically
- ✅ Health checks passing consistently

The Aurora PostgreSQL read replica setup is now complete and ready for reporting optimization!