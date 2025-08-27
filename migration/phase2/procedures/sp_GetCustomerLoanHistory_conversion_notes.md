# sp_GetCustomerLoanHistory Conversion Notes

## SCT Issues Addressed

### Issue 7922: PostgreSQL Error Handling
**Problem**: PostgreSQL uses different error handling approach
**Solution**: 
- Replaced `RAISERROR` with `RAISE EXCEPTION`
- Used `EXCEPTION WHEN OTHERS` instead of `BEGIN CATCH`
- Added proper error logging with exception handling

### Issue 7811: Unsupported Functions (2 instances)
**Problems & Solutions**:
1. `GETDATE()` → `NOW()`
2. `SYSTEM_USER` → `CURRENT_USER`

## Key Conversion Changes

### 1. Multiple Result Sets Approach
**Problem**: PostgreSQL functions cannot return multiple result sets like SQL Server procedures
**Solution**: Created separate functions for each result set:
- `get_customer_loan_history()` - Customer info
- `get_customer_loan_history_details()` - Loan history  
- `get_customer_payment_history()` - Payment history
- `get_complete_customer_loan_history()` - Combined JSON result

### 2. Custom Types Definition
```sql
-- Created custom types for structured returns
CREATE TYPE customer_info_type AS (
    customerid INTEGER,
    customernumber VARCHAR(20),
    fullname TEXT,
    email VARCHAR(100),
    monthlyincome NUMERIC(12,2)
);
```

### 3. String Concatenation
```sql
-- SQL Server
c.FirstName + ' ' + c.LastName AS FullName

-- PostgreSQL
(c.firstname || ' ' || c.lastname)::TEXT AS fullname
```

### 4. Boolean Parameters
```sql
-- SQL Server
@IncludePayments BIT = 1

-- PostgreSQL
p_include_payments BOOLEAN DEFAULT true
```

## Application Integration Options

### Option 1: Separate Function Calls
```csharp
// Get customer info
var customerInfo = await context.Database.SqlQuery<CustomerInfo>(
    "SELECT * FROM get_customer_loan_history($1)", customerId).ToListAsync();

// Get loan history
var loanHistory = await context.Database.SqlQuery<LoanHistory>(
    "SELECT * FROM get_customer_loan_history_details($1)", customerId).ToListAsync();

// Get payment history (if needed)
if (includePayments)
{
    var paymentHistory = await context.Database.SqlQuery<PaymentHistory>(
        "SELECT * FROM get_customer_payment_history($1)", customerId).ToListAsync();
}
```

### Option 2: JSON Result (Recommended)
```csharp
// Single call returning complete data as JSON
var result = await context.Database.SqlQuery<string>(
    "SELECT get_complete_customer_loan_history($1, $2)", 
    customerId, includePayments).FirstAsync();

var customerData = JsonSerializer.Deserialize<CustomerLoanHistoryResponse>(result);
```

## Data Models for .NET Integration

```csharp
public class CustomerInfo
{
    public int CustomerId { get; set; }
    public string CustomerNumber { get; set; }
    public string FullName { get; set; }
    public string Email { get; set; }
    public decimal MonthlyIncome { get; set; }
}

public class LoanHistory
{
    public int ApplicationId { get; set; }
    public string ApplicationNumber { get; set; }
    public decimal RequestedAmount { get; set; }
    public string ApplicationStatus { get; set; }
    public DateTime SubmissionDate { get; set; }
    public DateTime? DecisionDate { get; set; }
    public decimal? DSRRatio { get; set; }
    public int? CreditScore { get; set; }
    public int? LoanId { get; set; }
    public string LoanNumber { get; set; }
    public decimal? ApprovedAmount { get; set; }
    public decimal? InterestRate { get; set; }
    public int? LoanTermMonths { get; set; }
    public decimal? MonthlyPayment { get; set; }
    public string LoanStatus { get; set; }
    public DateTime? DisbursementDate { get; set; }
    public decimal? OutstandingBalance { get; set; }
    public DateTime? NextPaymentDate { get; set; }
    public string RecordType { get; set; }
}

public class PaymentHistory
{
    public int PaymentId { get; set; }
    public int LoanId { get; set; }
    public string LoanNumber { get; set; }
    public string PaymentNumber { get; set; }
    public DateTime PaymentDate { get; set; }
    public decimal PaymentAmount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public string PaymentMethod { get; set; }
    public string PaymentStatus { get; set; }
    public string TransactionId { get; set; }
}

public class CustomerLoanHistoryResponse
{
    public CustomerInfo CustomerInfo { get; set; }
    public List<LoanHistory> LoanHistory { get; set; }
    public List<PaymentHistory> PaymentHistory { get; set; }
}
```

## Performance Considerations

### Advantages
- **Single JSON call**: Reduces round trips
- **Structured data**: Type-safe returns
- **Flexible**: Can call individual functions as needed

### Considerations
- **JSON parsing**: Slight overhead for JSON serialization
- **Memory usage**: Large result sets in JSON format
- **Caching**: Consider caching for frequently accessed customer data

## Testing Validation

### Test Cases
1. **Valid customer with loans and payments**
2. **Valid customer with applications only**
3. **Valid customer with no history**
4. **Invalid customer ID**
5. **Include/exclude payments parameter**
6. **Large result sets performance**

### Migration Testing
```sql
-- Test all functions
SELECT * FROM get_customer_loan_history(1);
SELECT * FROM get_customer_loan_history_details(1);
SELECT * FROM get_customer_payment_history(1);
SELECT get_complete_customer_loan_history(1, true);
```

The converted functions maintain all business logic while being fully PostgreSQL compatible and addressing all SCT issues.