# Step 2: Create New DynamoDB Services
## Phase 3: DynamoDB Migration - Service Layer Implementation

### 🎯 Objective
Create new service layer for DynamoDB operations while maintaining existing SQL Server logging functionality during the migration period.

### 📁 Copy Required Files

All files have been pre-created in the phase3 folder. Copy them to your main application:

```bash
# Copy all DynamoDB service files
cp migration/phase3/LoanApplication/Models/DynamoDbLogEntry.cs LoanApplication/Models/
cp migration/phase3/LoanApplication/Services/IDynamoDbLogService.cs LoanApplication/Services/
cp migration/phase3/LoanApplication/Services/DynamoDbLogService.cs LoanApplication/Services/
cp migration/phase3/LoanApplication/Configuration/DynamoDbConfiguration.cs LoanApplication/Configuration/
cp migration/phase3/LoanApplication/Extensions/ServiceCollectionExtensions.cs LoanApplication/Extensions/
```

### 🏗️ Service Architecture

#### New Components Added
```
LoanApplication/
├── Models/
│   └── DynamoDbLogEntry.cs          # ✅ DynamoDB model
├── Services/
│   ├── IDynamoDbLogService.cs       # ✅ Interface
│   └── DynamoDbLogService.cs        # ✅ Implementation
├── Configuration/
│   └── DynamoDbConfiguration.cs     # ✅ Configuration model
└── Extensions/
    └── ServiceCollectionExtensions.cs # ✅ DI registration
```

### 📊 Key Files Overview

#### DynamoDbLogEntry.cs
- DynamoDB model with proper attributes
- Key generation for partition/sort keys
- Conversion from SQL Server IntegrationLog
- TTL support for automatic cleanup

#### IDynamoDbLogService.cs & DynamoDbLogService.cs
- Service interface and implementation
- Write operations (single and batch)
- Query operations by service, application, time range
- Error handling and logging

#### DynamoDbConfiguration.cs
- Configuration model for DynamoDB settings
- Region and table name configuration
- Local DynamoDB support for testing

#### ServiceCollectionExtensions.cs
- Dependency injection setup
- AWS SDK configuration
- DynamoDB context registration

### 📦 Add NuGet Packages

```bash
# Add AWS SDK packages
dotnet add package AWSSDK.DynamoDBv2
dotnet add package AWSSDK.Extensions.NETCore.Setup
```

### ⚙️ Update Configuration

#### Add to appsettings.json
```json
{
  "DynamoDB": {
    "TableName": "LoanApp-IntegrationLogs-dev",
    "Region": "ap-southeast-1",
    "UseLocalDynamoDB": false
  },
  "AWS": {
    "Region": "ap-southeast-1"
  }
}
```

#### Update Program.cs
```csharp
using LoanApplication.Extensions;

// Add after existing services
builder.Services.AddDynamoDbServices(builder.Configuration);
```

### 🧪 Testing the Service

#### Basic Test Implementation
```csharp
// Test in controller or create unit tests
public async Task<IActionResult> TestDynamoDb()
{
    var testLog = new DynamoDbLogEntry
    {
        LogId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
        LogType = "TEST",
        ServiceName = "TestService",
        LogTimestamp = DateTime.UtcNow,
        IsSuccess = true,
        RequestData = "{\"test\": \"data\"}",
        ResponseData = "{\"result\": \"success\"}"
    };
    
    var success = await _dynamoDbLogService.WriteLogAsync(testLog);
    
    if (success)
    {
        var retrieved = await _dynamoDbLogService.GetLogByIdAsync(
            testLog.ServiceName, 
            testLog.LogTimestamp, 
            testLog.LogId);
        
        return Ok(new { written = testLog, retrieved });
    }
    
    return BadRequest("Failed to write test log");
}
```

### 🚀 Next Steps
1. **Add NuGet packages** for AWS SDK
2. **Update Program.cs** with DI registration
3. **Test service** with sample data
4. **Implement dual-write pattern** for migration

---

### 💡 Q Developer Integration Points

```
1. "Review this DynamoDB service implementation and suggest improvements for error handling and performance optimization."

2. "Analyze the dependency injection setup and recommend best practices for AWS SDK configuration in .NET applications."

3. "Examine the query patterns and suggest optimizations for DynamoDB GSI usage and cost management."
```

**Next**: [Dual-Write Pattern Implementation](./06-step3-dual-write-pattern.md)