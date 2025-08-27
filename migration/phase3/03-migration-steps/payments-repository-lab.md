# Interactive Code Lab: DynamoDB Payments Repository
## Step 4.4 - Guided Implementation with Q Developer

### 🎯 Lab Objectives
- Build a production-ready DynamoDB repository using guided steps
- Learn AWS SDK patterns through hands-on implementation
- Use Q Developer for intelligent code completion and validation
- Complete implementation in 45-60 minutes with checkpoints

### 📋 Lab Prerequisites
- Visual Studio/VS Code with Q Developer extension active
- AWS SDK for .NET installed
- DynamoDB Payments table created (from previous steps)
- Basic understanding of repository pattern

---

## 🚀 Lab Exercise 1: Repository Interface Design (10 minutes)

### Starter Code
```csharp
// Create: LoanApplication/Repositories/IPaymentsRepository.cs
using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public interface IPaymentsRepository
    {
        // TODO: Add method signatures for payment operations
        // Hint: Think about the 6 access patterns from our analysis
    }
}
```

### 🤖 Q Developer Prompt
```
@q I need to design a repository interface for DynamoDB payment operations. Based on these access patterns, what methods should I include?

Access Patterns:
1. Get customer payment history (40% of queries)
2. Get payments by status (25% of queries) 
3. Get payments for a loan (20% of queries)
4. Insert new payment (write operation)
5. Update payment status (write operation)
6. Get payment by ID (lookup operation)

Create the interface with proper async methods and return types.
```

### ✅ Checkpoint 1
Your interface should have 6-8 methods covering all access patterns. Verify with instructor before proceeding.

---

## 🚀 Lab Exercise 2: Basic Repository Structure (15 minutes)

### Starter Code
```csharp
// Create: LoanApplication/Repositories/PaymentsRepository.cs
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using LoanApplication.Models;
using Microsoft.Extensions.Logging;

namespace LoanApplication.Repositories
{
    public class PaymentsRepository : IPaymentsRepository
    {
        private readonly IAmazonDynamoDB _dynamoClient;
        private readonly ILogger<PaymentsRepository> _logger;
        private const string TABLE_NAME = "Payments";

        public PaymentsRepository(IAmazonDynamoDB dynamoClient, ILogger<PaymentsRepository> logger)
        {
            _dynamoClient = dynamoClient;
            _logger = logger;
        }

        // TODO: Implement interface methods
        // Start with the simplest one: GetPaymentByIdAsync
    }
}
```

### 🤖 Q Developer Prompt
```
@q Help me implement GetPaymentByIdAsync method for DynamoDB. The table structure is:
- Partition Key: CustomerId (Number)
- Sort Key: PaymentDateId (String format: "2024-01-15T10:30:00Z#12345")

I need to query by PaymentId, but it's part of the sort key. What's the best approach?
```

### ✅ Checkpoint 2
You should have a working GetPaymentByIdAsync method. Test it compiles before proceeding.

---

## 🚀 Lab Exercise 3: Customer Payment History (15 minutes)

### 🤖 Q Developer Prompt
```
@q Implement GetCustomerPaymentsAsync method that:
1. Queries DynamoDB by CustomerId (partition key)
2. Supports optional date range filtering
3. Returns results in descending order (newest first)
4. Includes pagination support
5. Handles DynamoDB exceptions properly

Table: Payments
Partition Key: CustomerId
Sort Key: PaymentDateId (format: "YYYY-MM-DDTHH:mm:ssZ#PaymentId")
```

### Starter Template
```csharp
public async Task<List<Payment>> GetCustomerPaymentsAsync(int customerId, DateTime? startDate = null, DateTime? endDate = null, int limit = 50)
{
    try
    {
        // TODO: Build DynamoDB query request
        // TODO: Handle date range filtering
        // TODO: Execute query and transform results
        // TODO: Return Payment objects
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to get payments for customer {CustomerId}", customerId);
        throw;
    }
}
```

### ✅ Checkpoint 3
Test your method with a sample CustomerId. Verify it returns payments in correct order.

---

## 🚀 Lab Exercise 4: Payment Status Queries (10 minutes)

### 🤖 Q Developer Prompt
```
@q Implement GetPaymentsByStatusAsync using the PaymentStatusIndex GSI:
- GSI Partition Key: PaymentStatus
- GSI Sort Key: PaymentDate
- Support date range filtering
- Return payments matching the status

Show me the complete implementation with proper error handling.
```

### ✅ Checkpoint 4
Verify your GSI query works and returns payments filtered by status.

---

## 🚀 Lab Exercise 5: Write Operations (10 minutes)

### 🤖 Q Developer Prompt
```
@q Implement these write operations for DynamoDB Payments table:

1. InsertPaymentAsync - Add new payment with proper key generation
2. UpdatePaymentStatusAsync - Update only the PaymentStatus attribute

Key format: PaymentDateId = "YYYY-MM-DDTHH:mm:ssZ#PaymentId"
Include TTL attribute set to 7 years from now.
Add proper error handling and logging.
```

### ✅ Checkpoint 5
Test both write operations. Verify the payment appears in DynamoDB console.

---

## 🚀 Lab Exercise 6: Batch Operations (15 minutes)

### 🤖 Q Developer Prompt
```
@q Create InsertPaymentBatchAsync method for high-throughput scenarios:
1. Accept List<Payment> input
2. Use DynamoDB BatchWriteItem (max 25 items per batch)
3. Handle unprocessed items with retry logic
4. Include progress logging
5. Return success/failure summary

Show me the complete implementation with proper batch handling.
```

### Advanced Challenge (Optional)
```
@q Add GetLoanPaymentsAsync method using the LoanPaymentIndex GSI. Include pagination support and date filtering.
```

---

## 🔧 Lab Exercise 7: Service Registration (5 minutes)

### 🤖 Q Developer Prompt
```
@q Update Program.cs to register the PaymentsRepository with dependency injection. Include:
1. AWS DynamoDB client registration
2. PaymentsRepository registration
3. Proper configuration for AWS credentials
```

### Starter Code
```csharp
// In Program.cs
// TODO: Add AWS services and repository registration
```

---

## 📊 Final Validation & Testing

### Integration Test Template
```csharp
// Create: Tests/PaymentsRepositoryTests.cs
[Test]
public async Task GetCustomerPayments_ShouldReturnPaymentsInDescendingOrder()
{
    // TODO: Use Q Developer to generate integration test
    // Test with real DynamoDB table (use test data)
}
```

### 🤖 Q Developer Prompt for Testing
```
@q Generate integration tests for PaymentsRepository that:
1. Test GetCustomerPaymentsAsync with date filtering
2. Test GetPaymentsByStatusAsync with different statuses  
3. Test InsertPaymentAsync and verify data integrity
4. Use realistic test data for loan application scenario
```

---

## 🎯 Lab Completion Checklist

### Core Implementation ✅
- [ ] IPaymentsRepository interface with all required methods
- [ ] PaymentsRepository class with DynamoDB operations
- [ ] GetCustomerPaymentsAsync with date filtering and pagination
- [ ] GetPaymentsByStatusAsync using GSI
- [ ] InsertPaymentAsync with proper key generation
- [ ] UpdatePaymentStatusAsync for status changes
- [ ] InsertPaymentBatchAsync for high-throughput scenarios
- [ ] Proper error handling and logging throughout

### Integration ✅
- [ ] Repository registered in Program.cs
- [ ] AWS DynamoDB client configured
- [ ] Integration tests created and passing
- [ ] Manual testing with DynamoDB console verification

### Performance & Best Practices ✅
- [ ] Efficient query patterns using partition keys
- [ ] Proper GSI usage for secondary access patterns
- [ ] Batch operations for high-throughput scenarios
- [ ] TTL configuration for data lifecycle management
- [ ] Comprehensive error handling and retry logic

---

## 🚨 Troubleshooting Guide

### Common Issues & Q Developer Solutions

#### Issue: "Cannot find table 'Payments'"
**Q Developer Prompt:**
```
@q I'm getting a ResourceNotFoundException for DynamoDB table 'Payments'. Help me verify the table exists and my AWS configuration is correct.
```

#### Issue: "Query returns no results"
**Q Developer Prompt:**
```
@q My DynamoDB query returns empty results but I know data exists. Help me debug this query and check if my key conditions are correct.
[Paste your query code]
```

#### Issue: "Batch write fails with unprocessed items"
**Q Developer Prompt:**
```
@q My BatchWriteItem operation has unprocessed items. Show me how to implement proper retry logic with exponential backoff.
```

#### Issue: "Performance is slower than expected"
**Q Developer Prompt:**
```
@q My DynamoDB queries are slow. Analyze my implementation and suggest performance optimizations for these access patterns.
[Paste your repository methods]
```

---

## 🎓 Learning Outcomes

By completing this lab, participants will have:

### Technical Skills ✅
- **DynamoDB Expertise**: Hands-on experience with AWS SDK operations
- **Repository Pattern**: Clean architecture implementation
- **Async Programming**: Proper async/await patterns in C#
- **Error Handling**: Production-ready exception management
- **Performance Optimization**: Efficient query patterns and batch operations

### AI-Assisted Development ✅
- **Q Developer Proficiency**: Effective prompting for complex implementations
- **Code Generation**: Using AI for boilerplate and complex logic
- **Debugging Skills**: AI-assisted troubleshooting techniques
- **Best Practices**: Learning from AI-recommended patterns

### AWS Cloud Skills ✅
- **NoSQL Design**: Understanding DynamoDB access patterns
- **GSI Usage**: Secondary index implementation
- **Batch Operations**: High-throughput data processing
- **Cost Optimization**: Efficient query and storage patterns

---

## 🚀 Next Steps

After completing this lab:
1. **Proceed to Step 4.5**: Update Payment controllers and services
2. **Review Performance**: Analyze query execution times
3. **Optimize Further**: Implement caching strategies if needed
4. **Document Learnings**: Note key insights for future projects

**Estimated Completion Time**: 45-60 minutes with Q Developer assistance
**Difficulty Level**: Intermediate (with guided support)
**Success Rate**: 95%+ with checkpoint validation