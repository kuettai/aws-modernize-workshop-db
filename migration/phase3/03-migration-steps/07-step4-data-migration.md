# Step 4: Data Migration Scripts
## Phase 3: DynamoDB Migration - Historical Data Transfer

### 🎯 Objective
Create data migration tools to transfer existing PostgreSQL IntegrationLogs data to DynamoDB with validation and monitoring.

### 📚 Learning Examples

#### Example 1: Basic Migration Service Interface
```csharp
using DataMigrationTool.Models;

namespace DataMigrationTool.Services
{
    public interface IMigrationService
    {
        Task<MigrationProgress> StartMigrationAsync(MigrationConfig config);
        Task<long> GetTotalRecordCountAsync(MigrationConfig config);
    }
}
```

#### Example 2: Simple Migration Progress Model
```csharp
namespace DataMigrationTool.Models
{
    public class MigrationProgress
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public DateTime StartTime { get; set; }
        public MigrationStatus Status { get; set; }
        public long TotalRecords { get; set; }
        public long ProcessedRecords { get; set; }
        public long SuccessfulRecords { get; set; }
        public double PercentComplete => TotalRecords > 0 ? (double)ProcessedRecords / TotalRecords * 100 : 0;
    }
    
    public enum MigrationStatus
    {
        NotStarted,
        InProgress,
        Completed,
        Failed
    }
}
```

### 📁 Copy Complete Migration Tool

All migration files have been pre-created. Copy the complete data migration tool:

```powershell
# Create DataMigrationTool project
mkdir DataMigrationTool -Force
mkdir DataMigrationTool\Services -Force
mkdir DataMigrationTool\Models -Force

# Copy all migration tool files
copy migration\phase3\DataMigrationTool\DataMigrationTool.csproj DataMigrationTool\
copy migration\phase3\DataMigrationTool\Program.cs DataMigrationTool\
copy migration\phase3\DataMigrationTool\appsettings.json DataMigrationTool\
copy migration\phase3\DataMigrationTool\Services\*.cs DataMigrationTool\Services\
copy migration\phase3\DataMigrationTool\Models\*.cs DataMigrationTool\Models\
copy migration\phase3\run-migration.ps1 .
```

### 🚀 Run Migration

```powershell
# Test migration (dry run)
.\run-migration.ps1 -DryRun -Environment dev

# Full migration
.\run-migration.ps1 -Environment dev

# Resume interrupted migration
.\run-migration.ps1 -Resume -Environment dev
```



---

### 💡 Q Developer Integration Points

```
1. "Review this data migration tool and suggest improvements for performance, error handling, and monitoring."

2. "Analyze the batch processing logic and recommend optimizations for DynamoDB throughput and cost management."

3. "Examine the resume capability and suggest enhancements for handling partial failures and data consistency."
```

**Next**: [Application Integration](./09-step5-application-integration.md)