# DynamoDB Payments Repository Implementation
## Step 4 - Repository Pattern with Working Examples

### 🎯 Objectives
- Understand DynamoDB repository patterns through 2 key examples
- Copy working implementation files to your project
- Test the repository with real DynamoDB operations

### 📋 Prerequisites
- DynamoDB Payments table created (from previous steps)
- AWS SDK packages installed
- Basic understanding of repository pattern

---

## 📝 Example 1: Get Payment by ID (GSI Query)

**File**: `LoanApplication/Repositories/PaymentsRepository.cs`

```csharp
public async Task<DynamoDbPayment?> GetPaymentByIdAsync(int paymentId)
{
    try
    {
        var queryConfig = new QueryOperationConfig
        {
            IndexName = "GSI4-PaymentId-Index",
            KeyExpression = new Expression
            {
                ExpressionStatement = "PaymentId = :paymentId",
                ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                {
                    { ":paymentId", paymentId }
                }
            }
        };

        var search = _dynamoContext.FromQueryAsync<Payment>(queryConfig);
        var results = await search.GetRemainingAsync();
        return results.FirstOrDefault();
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to get payment by ID {PaymentId}", paymentId);
        return null;
    }
}
```

**Key Points:**
- Uses GSI4-PaymentId-Index to query by PaymentId
- DynamoDBContext with QueryOperationConfig
- Proper error handling and logging

---

## 📝 Example 2: Get Customer Payments (Primary Key Query)

**File**: `LoanApplication/Repositories/PaymentsRepository.cs`

```csharp
public async Task<List<DynamoDbPayment>> GetCustomerPaymentsAsync(int customerId, DateTime? startDate = null, DateTime? endDate = null, int limit = 50)
{
    try
    {
        var queryConfig = new QueryOperationConfig
        {
            KeyExpression = new Expression
            {
                ExpressionStatement = "CustomerId = :customerId",
                ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                {
                    { ":customerId", customerId }
                }
            },
            Limit = limit,
            BackwardSearch = true // Newest first
        };

        if (startDate.HasValue && endDate.HasValue)
        {
            var startKey = $"{startDate.Value:yyyy-MM-ddTHH:mm:ssZ}#0";
            var endKey = $"{endDate.Value:yyyy-MM-ddTHH:mm:ssZ}#999999999";
            
            queryConfig.KeyExpression.ExpressionStatement += " AND PaymentDateId BETWEEN :startKey AND :endKey";
            queryConfig.KeyExpression.ExpressionAttributeValues.Add(":startKey", startKey);
            queryConfig.KeyExpression.ExpressionAttributeValues.Add(":endKey", endKey);
        }

        var search = _dynamoContext.FromQueryAsync<Payment>(queryConfig);
        return await search.GetRemainingAsync();
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to get payments for customer {CustomerId}", customerId);
        return new List<DynamoDbPayment>();
    }
}
```

**Key Points:**
- Queries by CustomerId (partition key)
- Optional date range filtering on sort key
- BackwardSearch for newest-first ordering
- Pagination support with limit

---

## 📁 Copy Working Files

All repository files are pre-created. Copy them to your project:

```powershell
# Create Repositories directory
mkdir LoanApplication\Repositories -Force

# Copy repository files
copy migration\phase3\LoanApplication\Repositories\IPaymentsRepository.cs LoanApplication\Repositories\
copy migration\phase3\LoanApplication\Repositories\PaymentsRepository.cs LoanApplication\Repositories\

# Copy DynamoDB model (rename to avoid conflict with existing Payment.cs)
copy migration\phase3\LoanApplication\Models\Payment.cs LoanApplication\Models\DynamoDbPayment.cs
```

### 🔧 Register Repository in Program.cs

Add to your Program.cs:
```csharp
using LoanApplication.Repositories;

// Add after DynamoDB services registration
builder.Services.AddScoped<IPaymentsRepository, PaymentsRepository>();
```

### 🧪 Test the Repository

1. **Add using directive** to DocsController.cs:
```csharp
using LoanApplication.Repositories;
```

2. **Add test endpoint** to DocsController:
```csharp
[HttpGet("test-payments")]
public async Task<IActionResult> TestPayments([FromServices] IPaymentsRepository paymentsRepo)
{
    // Test getting payments for customer ID 1
    var payments = await paymentsRepo.GetCustomerPaymentsAsync(1, limit: 10);
    return Ok(new { count = payments.Count, payments });
}
```

3. **Run the application**:
```powershell
cd LoanApplication
dotnet run
```

4. **Test the endpoint**: Visit `http://localhost:5000/test-payments`

**Estimated Time**: 10-15 minutes  
**Difficulty**: Easy (copy and test)

### 🚨 Troubleshooting

**Error**: `IPaymentsRepository could not be found`  
**Fix**: Add `using LoanApplication.Repositories;` to DocsController.cs

**Error**: `Payment does not contain definition for PaymentNumber`  
**Fix**: Don't overwrite the original Payment.cs - copy as DynamoDbPayment.cs instead