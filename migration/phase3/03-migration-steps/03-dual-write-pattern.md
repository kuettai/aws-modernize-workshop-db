# Step 3: Dual-Write Pattern Implementation
## Phase 3: DynamoDB Migration - Hybrid Logging Strategy

### 🎯 Objective
Implement dual-write pattern to safely migrate from PostgreSQL to DynamoDB logging while maintaining data consistency and zero downtime.

### 📚 Learning Examples

#### Example 1: Basic Dual-Write Interface
```csharp
using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IHybridLogService
    {
        Task<bool> WriteLogAsync(IntegrationLog logEntry);
        Task<bool> EnableDualWriteAsync();
        Task<bool> SwitchToDynamoDbReadsAsync();
    }
}
```

#### Example 2: Simple Configuration Model
```csharp
namespace LoanApplication.Configuration
{
    public class HybridLogConfiguration
    {
        public bool WritesToSql { get; set; } = true;
        public bool WritesToDynamoDb { get; set; } = false;
        public bool ReadsFromDynamoDb { get; set; } = false;
    }
}
```

### 📁 Copy Complete Dual-Write Implementation

All dual-write files have been pre-created. Copy the complete hybrid logging system:

```powershell
# Copy hybrid logging files
copy migration\phase3\LoanApplication-03\Services\IHybridLogService.cs LoanApplication\Services\
copy migration\phase3\LoanApplication-03\Services\HybridLogService.cs LoanApplication\Services\
copy migration\phase3\LoanApplication-03\Configuration\HybridLogConfiguration.cs LoanApplication\Configuration\
copy migration\phase3\LoanApplication-03\Controllers\MigrationController.cs LoanApplication\Controllers\
copy migration\phase3\LoanApplication-03\Extensions\ServiceCollectionExtensions.cs LoanApplication\Extensions\
```

### ⚙️ Update Configuration

Add to appsettings.json:
```json
{
  "HybridLogging": {
    "WritesToSql": true,
    "WritesToDynamoDb": false,
    "ReadsFromDynamoDb": false
  }
}
```

### 🔧 Update Program.cs

Replace the DynamoDB service registration:
```csharp
// Replace this line:
// builder.Services.AddDynamoDbServices(builder.Configuration);

// With this:
builder.Services.AddHybridLoggingServices(builder.Configuration);
```

### 🚀 Test Dual-Write Pattern

```powershell
# Build and run
cd LoanApplication
dotnet build
dotnet run

# Test endpoints (use your app's port)
Invoke-RestMethod -Uri http://localhost:5000/api/migration/test-dual-write -Method POST
Invoke-RestMethod -Uri http://localhost:5000/api/migration/enable-dual-write -Method POST
```

### 🎯 Migration Phases

1. **Phase 0**: PostgreSQL only (current state)
2. **Phase 1**: Enable dual-write (PostgreSQL + DynamoDB writes, PostgreSQL reads)
3. **Phase 2**: Switch reads to DynamoDB (PostgreSQL + DynamoDB writes, DynamoDB reads)
4. **Phase 3**: Disable PostgreSQL writes (DynamoDB only)

---

### 💡 Q Developer Integration Points

```
1. "Review this dual-write pattern implementation and suggest improvements for error handling and data consistency."

2. "Analyze the migration phase management and recommend additional safety measures for production deployment."

3. "Examine the validation logic and suggest enhancements for detecting data discrepancies between SQL and DynamoDB."
```

**Next**: [DMS Migration](./04-dms-migration.md)