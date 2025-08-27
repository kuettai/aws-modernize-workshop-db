# SQL Server to PostgreSQL Procedure Conversion Notes

## sp_CreateLoanApplication Conversion Summary

### SCT Issues Addressed

#### Issue 7922: PostgreSQL Error Handling
**Problem**: PostgreSQL uses different error handling approach
**Solution**: 
- Replaced `RAISERROR` with `RAISE EXCEPTION`
- Used `EXCEPTION WHEN OTHERS` block instead of `BEGIN CATCH`
- Added `USING ERRCODE` for custom error codes

#### Issue 7811: Unsupported Functions (5 instances)
**Problems & Solutions**:
1. `GETDATE()` → `NOW()`
2. `FORMAT(GETDATE(), 'yyyyMM')` → `TO_CHAR(NOW(), 'YYYYMM')`
3. `FORMAT(@AppCount + 1, 'D6')` → `LPAD((v_app_count + 1)::TEXT, 6, '0')`
4. `SCOPE_IDENTITY()` → `RETURNING applicationid INTO v_application_id`
5. `SYSTEM_USER` → `CURRENT_USER`

#### Issue 7807: Transaction Management Commands (2 instances)
**Problem**: `BEGIN TRANSACTION`, `COMMIT TRANSACTION`, `ROLLBACK TRANSACTION`
**Solution**: 
- Removed explicit transaction commands from function
- Created wrapper function for application-level transaction management
- PostgreSQL functions run in implicit transactions

#### Issue 7615: Transaction Control in Exception Handlers
**Problem**: `ROLLBACK TRANSACTION` inside `BEGIN CATCH`
**Solution**:
- Moved transaction control to application layer
- PostgreSQL automatically rolls back on function exceptions
- Created separate wrapper function for transaction management

### Key Conversion Changes

#### 1. Function Structure
```sql
-- SQL Server
CREATE PROCEDURE sp_CreateLoanApplication
    @CustomerId INT,
    @ApplicationNumber NVARCHAR(20) OUTPUT,
    @ApplicationId INT OUTPUT

-- PostgreSQL  
CREATE OR REPLACE FUNCTION create_loan_application(
    p_customer_id INTEGER,
    p_requested_amount NUMERIC(12,2)
)
RETURNS TABLE (
    application_id INTEGER,
    application_number VARCHAR(20),
    message TEXT
)
```

#### 2. Variable Declarations
```sql
-- SQL Server
DECLARE @AppCount INT;
DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

-- PostgreSQL
DECLARE
    v_app_count INTEGER;
    v_error_message TEXT;
```

#### 3. Error Handling
```sql
-- SQL Server
BEGIN TRY
    -- code
END TRY
BEGIN CATCH
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH

-- PostgreSQL
BEGIN
    -- code
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        RAISE;
END;
```

#### 4. Data Type Mappings
| SQL Server | PostgreSQL |
|------------|------------|
| `INT` | `INTEGER` |
| `NVARCHAR(n)` | `VARCHAR(n)` |
| `DECIMAL(12,2)` | `NUMERIC(12,2)` |
| `BIT` | `BOOLEAN` |
| `DATETIME2` | `TIMESTAMP` |

#### 5. Case Sensitivity
- PostgreSQL uses lowercase for table/column names
- `Applications` → `applications`
- `CustomerId` → `customerid`

### Application Integration Changes Required

#### .NET Entity Framework Updates
```csharp
// Before (SQL Server)
var result = await context.Database.ExecuteSqlRawAsync(
    "EXEC sp_CreateLoanApplication @CustomerId, @LoanOfficerId, @BranchId, @RequestedAmount, @LoanPurpose, @ApplicationNumber OUTPUT, @ApplicationId OUTPUT",
    parameters);

// After (PostgreSQL)
var result = await context.Database.ExecuteSqlRawAsync(
    "SELECT * FROM create_loan_application($1, $2, $3, $4, $5)",
    customerId, loanOfficerId, branchId, requestedAmount, loanPurpose);
```

#### Transaction Management
```csharp
// Application-level transaction management
using var transaction = await context.Database.BeginTransactionAsync();
try 
{
    var result = await context.Database.ExecuteSqlRawAsync(
        "SELECT * FROM create_loan_application($1, $2, $3, $4, $5)",
        parameters);
    
    await transaction.CommitAsync();
    return result;
}
catch 
{
    await transaction.RollbackAsync();
    throw;
}
```

### Testing Validation

#### Test Cases to Verify
1. **Valid Application Creation**
   - Verify application record created
   - Verify integration log entry
   - Verify return values

2. **Validation Errors**
   - Invalid customer ID
   - Invalid loan officer ID  
   - Invalid branch ID
   - Invalid loan amount

3. **Error Handling**
   - Database constraint violations
   - Network interruptions
   - Transaction rollback scenarios

4. **Performance**
   - Compare execution times
   - Verify no memory leaks
   - Check connection pooling

### Deployment Steps

1. **Deploy PostgreSQL Function**
   ```sql
   \i sp_CreateLoanApplication_postgresql.sql
   ```

2. **Update Application Code**
   - Change stored procedure calls to function calls
   - Update parameter binding
   - Add transaction management

3. **Test Migration**
   - Run unit tests
   - Perform integration testing
   - Validate error scenarios

4. **Monitor Performance**
   - Compare before/after metrics
   - Check query execution plans
   - Monitor error rates

The converted function maintains the same business logic while being fully compatible with PostgreSQL and addressing all SCT conversion issues.