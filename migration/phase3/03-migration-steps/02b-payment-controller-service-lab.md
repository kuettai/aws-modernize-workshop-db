# Payment Controller & Service Integration
## Step 5 - Dual-Write Pattern with Working Examples

### 🎯 Objectives
- Understand dual-write pattern through 2 key examples
- Copy working service and controller files to your project
- Test the hybrid payment system

### 📋 Prerequisites
- Completed Step 4 (PaymentsRepository implementation)
- DMS migration completed (PostgreSQL Payments data migrated to LoanApp-Payments-dev)
- Existing .NET loan application running
- Understanding of dependency injection

---

## 📝 Example 1: Dual-Write Pattern (ProcessPaymentAsync)

**File**: `LoanApplication/Services/PaymentService.cs`

```csharp
public async Task<bool> ProcessPaymentAsync(DynamoDbPayment payment)
{
    try
    {
        // Dual-write: PostgreSQL first (existing system)
        var pgPayment = new Payment
        {
            PaymentId = payment.PaymentId,
            CustomerId = payment.CustomerId,
            LoanId = payment.LoanId,
            PaymentAmount = payment.PaymentAmount,
            PaymentDate = payment.PaymentDate,
            PaymentMethod = payment.PaymentMethod,
            PaymentStatus = payment.PaymentStatus,
            CreatedDate = payment.CreatedDate
        };

        _pgContext.Payments.Add(pgPayment);
        await _pgContext.SaveChangesAsync();

        // DynamoDB second (new system)
        var enableDynamoDB = _configuration.GetValue<bool>("PaymentSettings:EnableDynamoDBWrites", true);
        if (enableDynamoDB)
        {
            var success = await _dynamoRepository.InsertPaymentAsync(payment);
            if (!success)
            {
                _logger.LogWarning("DynamoDB write failed for payment {PaymentId}", payment.PaymentId);
            }
        }

        return true;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to process payment {PaymentId}", payment.PaymentId);
        return false;
    }
}
```

**Key Points:**
- Write to PostgreSQL first (existing system)
- Write to DynamoDB second (new system)
- Configuration-driven DynamoDB writes
- Error handling with logging

---

## 📝 Example 2: Smart Read Routing (GetCustomerPaymentHistoryAsync)

**File**: `LoanApplication/Services/PaymentService.cs`

```csharp
public async Task<List<DynamoDbPayment>> GetCustomerPaymentHistoryAsync(int customerId, int limit = 50)
{
    var readFromDynamoDB = _configuration.GetValue<bool>("PaymentSettings:ReadFromDynamoDB", false);
    
    if (readFromDynamoDB)
    {
        try
        {
            return await _dynamoRepository.GetCustomerPaymentsAsync(customerId, limit: limit);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "DynamoDB read failed, falling back to PostgreSQL");
        }
    }

    // Fallback to PostgreSQL
    var pgPayments = await _pgContext.Payments
        .Where(p => p.CustomerId == customerId)
        .OrderByDescending(p => p.PaymentDate)
        .Take(limit)
        .ToListAsync();

    return pgPayments.Select(p => new DynamoDbPayment
    {
        PaymentId = p.PaymentId,
        CustomerId = p.CustomerId,
        LoanId = p.LoanId,
        PaymentAmount = p.PaymentAmount,
        PaymentDate = p.PaymentDate,
        PaymentMethod = p.PaymentMethod,
        PaymentStatus = p.PaymentStatus,
        CreatedDate = p.CreatedDate
    }).ToList();
}
```

**Key Points:**
- Configuration-driven read routing
- DynamoDB first, PostgreSQL fallback
- Data transformation between models
- Graceful error handling

---

## 📁 Copy Working Files

All service and controller files are pre-created. Copy them to your project:

```powershell
# Copy service files
copy migration\phase3\LoanApplication\Services\IPaymentService.cs LoanApplication\Services\
copy migration\phase3\LoanApplication\Services\PaymentService.cs LoanApplication\Services\

# Copy controller file
copy migration\phase3\LoanApplication\Controllers\PaymentsController.cs LoanApplication\Controllers\
```

### ⚙️ Add Configuration to appsettings.json

```json
{
  "PaymentSettings": {
    "EnableDynamoDBWrites": true,
    "ReadFromDynamoDB": false
  }
}
```

### 🔧 Register Services in Program.cs

Add after existing services:
```csharp
using LoanApplication.Services;

// Add payment service
builder.Services.AddScoped<IPaymentService, PaymentService>();
```

### 🧪 Test the Service

1. **Run the application**:
```powershell
cd LoanApplication
dotnet run
```

2. **Test GET endpoints**:
- `GET http://localhost:5000/api/payments/customer/1` - Get customer payments
- `GET http://localhost:5000/api/payments/pending` - Get pending payments

3. **Test POST endpoint** (dual-write to both MSSQL and DynamoDB):
```powershell
$payment = @{
    CustomerId = 1
    LoanId = 1
    PaymentAmount = 500.00
    PaymentDate = "2024-01-15T10:30:00Z"
    PaymentMethod = "Cash"  # Valid: Cash, Check, CreditCard, BankTransfer
    PaymentStatus = "Completed"
    CreatedDate = "2024-01-15T10:30:00Z"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5000/api/payments" -Method POST -Body $payment -ContentType "application/json"
```

**Estimated Time**: 15-20 minutes  
**Difficulty**: Easy (copy and test)

### 🚨 Troubleshooting

**Error**: `IPaymentService could not be found`  
**Fix**: Add `using LoanApplication.Services;` to Program.cs

**Error**: `PaymentSettings section not found`  
**Fix**: Add PaymentSettings section to appsettings.json

**Error**: `CHECK constraint violation on PaymentMethod`  
**Fix**: Use valid PaymentMethod values: `Cash`, `Check`, `CreditCard`, or `BankTransfer`