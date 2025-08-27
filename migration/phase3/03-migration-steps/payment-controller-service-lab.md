# Interactive Code Lab: Payment Controller & Service Integration
## Step 4.5 - DynamoDB Integration with Dual-Write Pattern

### 🎯 Lab Objectives
- Integrate DynamoDB PaymentsRepository into existing .NET application
- Implement dual-write pattern for safe migration transition
- Update controllers to use hybrid payment service
- Learn service abstraction patterns for database migration
- Complete integration in 30-45 minutes with guided steps

### 📋 Lab Prerequisites
- Completed Step 4.4 (PaymentsRepository implementation)
- Existing .NET loan application running
- Understanding of dependency injection and service patterns

---

## 🚀 Lab Exercise 1: Payment Service Interface (5 minutes)

### Starter Code
```csharp
// Create: LoanApplication/Services/IPaymentService.cs
using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IPaymentService
    {
        // TODO: Define service methods that abstract data access
        // Hint: Think about business operations, not just CRUD
    }
}
```

### 🤖 Q Developer Prompt
```
@q I need a payment service interface that abstracts payment operations for a loan application. The service should support:

Business Operations:
1. Process new payment (with validation)
2. Get customer payment history
3. Get loan payment summary
4. Update payment status (for processing workflows)
5. Get pending payments for monitoring
6. Record bulk payments (batch processing)

Design the interface with proper async methods and business-focused method names.
```

### ✅ Checkpoint 1
Your interface should have 6-8 business-focused methods. Verify method names make sense from a business perspective.

---

## 🚀 Lab Exercise 2: Hybrid Payment Service (15 minutes)

### Starter Code
```csharp
// Create: LoanApplication/Services/PaymentService.cs
using LoanApplication.Repositories;
using LoanApplication.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoanApplication.Services
{
    public class PaymentService : IPaymentService
    {
        private readonly IPaymentsRepository _dynamoRepository;
        private readonly LoanApplicationContext _pgContext;
        private readonly IConfiguration _configuration;
        private readonly ILogger<PaymentService> _logger;

        public PaymentService(
            IPaymentsRepository dynamoRepository,
            LoanApplicationContext pgContext,
            IConfiguration configuration,
            ILogger<PaymentService> logger)
        {
            _dynamoRepository = dynamoRepository;
            _pgContext = pgContext;
            _configuration = configuration;
            _logger = logger;
        }

        // TODO: Implement dual-write pattern methods
        // Start with ProcessPaymentAsync
    }
}
```

### 🤖 Q Developer Prompt
```
@q Help me implement ProcessPaymentAsync with dual-write pattern:

1. Write to PostgreSQL first (existing system)
2. Write to DynamoDB second (new system)
3. If DynamoDB write fails, log error but don't fail the operation
4. Include proper transaction handling for PostgreSQL
5. Add configuration flag to enable/disable DynamoDB writes
6. Include comprehensive logging for monitoring

Configuration setting: "PaymentSettings:EnableDynamoDBWrites" (boolean)
```

### ✅ Checkpoint 2
Test ProcessPaymentAsync writes to both databases. Verify PostgreSQL transaction rollback works if needed.

---

## 🚀 Lab Exercise 3: Read Operation Strategy (10 minutes)

### 🤖 Q Developer Prompt
```
@q Implement GetCustomerPaymentHistoryAsync with smart read routing:

1. Check configuration flag "PaymentSettings:ReadFromDynamoDB"
2. If true, read from DynamoDB (new fast path)
3. If false, read from PostgreSQL (existing path)
4. Include fallback: if DynamoDB read fails, try PostgreSQL
5. Add performance logging to compare response times
6. Handle data format differences between systems

Show me the complete implementation with proper error handling and fallback logic.
```

### Configuration Template
```json
// Add to appsettings.json
{
  "PaymentSettings": {
    "EnableDynamoDBWrites": true,
    "ReadFromDynamoDB": false,
    "EnableFallbackReads": true,
    "DualWriteLogging": true
  }
}
```

### ✅ Checkpoint 3
Test read operations from both data sources. Verify fallback works when DynamoDB is unavailable.

---

## 🚀 Lab Exercise 4: Payment Controller Updates (10 minutes)

### Existing Controller Analysis
```csharp
// Current: LoanApplication/Controllers/PaymentsController.cs (if exists)
// TODO: Find existing payment endpoints and update them
```

### 🤖 Q Developer Prompt
```
@q I need to update my PaymentsController to use the new PaymentService. Here's what I need:

Endpoints to implement/update:
1. POST /api/payments - Process new payment
2. GET /api/payments/customer/{customerId} - Get customer payment history  
3. GET /api/payments/loan/{loanId} - Get loan payments
4. PUT /api/payments/{paymentId}/status - Update payment status
5. GET /api/payments/pending - Get pending payments (admin)

Requirements:
- Use the new IPaymentService (not direct repository access)
- Include proper validation and error handling
- Add request/response logging
- Return appropriate HTTP status codes
- Include pagination for list endpoints

Create a complete controller with all endpoints.
```

### ✅ Checkpoint 4
Test all controller endpoints. Verify they use PaymentService and return proper responses.

---

## 🚀 Lab Exercise 5: Service Registration & Configuration (5 minutes)

### 🤖 Q Developer Prompt
```
@q Update Program.cs to register all payment-related services:

Services to register:
1. IPaymentsRepository -> PaymentsRepository (DynamoDB)
2. IPaymentService -> PaymentService (hybrid service)
3. AWS DynamoDB client configuration
4. Configuration validation for PaymentSettings

Include proper service lifetimes (Scoped/Singleton) and any required AWS configuration.
```

### Starter Template
```csharp
// In Program.cs - Add after existing services
// TODO: Add payment service registrations
```

### ✅ Checkpoint 5
Application starts successfully with all services registered. No dependency injection errors.

---

## 🚀 Lab Exercise 6: Migration Phase Management (Advanced - Optional)

### 🤖 Q Developer Prompt
```
@q Create a PaymentMigrationManager that handles different migration phases:

Phase 1: PostgreSQL only (current state)
Phase 2: Dual-write (PostgreSQL + DynamoDB writes, PostgreSQL reads)  
Phase 3: Hybrid (PostgreSQL + DynamoDB writes, DynamoDB reads)
Phase 4: DynamoDB only (future state)

Include:
- Configuration-driven phase management
- Automatic phase detection
- Health checks for each phase
- Migration progress tracking

Show me the complete implementation.
```

---

## 📊 Lab Exercise 7: Testing & Validation

### Integration Test Template
```csharp
// Create: Tests/PaymentServiceIntegrationTests.cs
[TestFixture]
public class PaymentServiceIntegrationTests
{
    // TODO: Use Q Developer to generate comprehensive tests
}
```

### 🤖 Q Developer Prompt for Testing
```
@q Generate integration tests for PaymentService that verify:

1. Dual-write functionality (both databases updated)
2. Read routing based on configuration
3. Fallback behavior when DynamoDB is unavailable
4. Transaction rollback in PostgreSQL on errors
5. Configuration flag behavior
6. Performance comparison between data sources

Use realistic loan application test data and proper test setup/teardown.
```

### Manual Testing Checklist
```
□ Process payment writes to both PostgreSQL and DynamoDB
□ Customer payment history reads from correct source based on config
□ Fallback reads work when primary source fails
□ Configuration changes take effect without restart
□ Controller endpoints return proper HTTP status codes
□ Error handling logs appropriately without exposing internals
```

---

## 🔧 Configuration Management

### Complete appsettings.json Template
```json
{
  "PaymentSettings": {
    "EnableDynamoDBWrites": true,
    "ReadFromDynamoDB": false,
    "EnableFallbackReads": true,
    "DualWriteLogging": true,
    "MigrationPhase": "DualWrite",
    "PerformanceLogging": true,
    "BatchSize": 25,
    "RetryAttempts": 3
  },
  "AWS": {
    "Region": "us-east-1",
    "DynamoDB": {
      "PaymentsTable": "Payments"
    }
  }
}
```

### 🤖 Q Developer Prompt for Configuration
```
@q Create a PaymentSettings configuration class with validation:
1. Bind to PaymentSettings section
2. Include validation attributes for required settings
3. Add configuration validation on startup
4. Include helpful error messages for misconfiguration
```

---

## 🚨 Troubleshooting Guide

### Common Issues & Solutions

#### Issue: "Dual-write creates inconsistent data"
**Q Developer Prompt:**
```
@q My dual-write implementation sometimes creates inconsistent data between PostgreSQL and DynamoDB. Help me implement proper error handling and compensation patterns.
```

#### Issue: "Performance degraded after adding DynamoDB"
**Q Developer Prompt:**
```
@q Adding DynamoDB writes has slowed down my payment processing. Help me optimize the dual-write pattern for better performance.
```

#### Issue: "Configuration changes don't take effect"
**Q Developer Prompt:**
```
@q My PaymentSettings configuration changes require application restart. How can I implement hot configuration reloading for migration phase changes?
```

#### Issue: "Controller tests failing after service changes"
**Q Developer Prompt:**
```
@q My existing controller tests are failing after integrating the new PaymentService. Help me update the tests to work with the hybrid service pattern.
```

---

## 🎯 Lab Completion Checklist

### Service Layer ✅
- [ ] IPaymentService interface with business-focused methods
- [ ] PaymentService with dual-write pattern implementation
- [ ] Smart read routing with fallback capability
- [ ] Configuration-driven behavior (write/read flags)
- [ ] Comprehensive error handling and logging
- [ ] Transaction management for data consistency

### Controller Layer ✅
- [ ] PaymentsController with all required endpoints
- [ ] Proper HTTP status codes and error responses
- [ ] Request validation and response formatting
- [ ] Pagination support for list operations
- [ ] Integration with PaymentService (not direct repository)

### Configuration & DI ✅
- [ ] PaymentSettings configuration class with validation
- [ ] Service registration in Program.cs
- [ ] AWS DynamoDB client configuration
- [ ] Environment-specific configuration support

### Testing & Validation ✅
- [ ] Integration tests for dual-write scenarios
- [ ] Manual testing of all endpoints
- [ ] Configuration flag testing
- [ ] Performance comparison logging
- [ ] Error scenario testing (database unavailable)

---

## 🎓 Learning Outcomes

### Technical Skills ✅
- **Service Layer Design**: Clean separation between controllers and data access
- **Dual-Write Patterns**: Safe database migration techniques
- **Configuration Management**: Runtime behavior control through configuration
- **Error Handling**: Graceful degradation and fallback strategies
- **Performance Monitoring**: Comparing different data access patterns

### Migration Expertise ✅
- **Hybrid Architecture**: Managing multiple data sources simultaneously
- **Phase Management**: Controlled migration with rollback capability
- **Risk Mitigation**: Minimizing downtime and data loss during migration
- **Monitoring**: Tracking migration progress and system health

### AI-Assisted Development ✅
- **Complex Integration**: Using Q Developer for multi-system integration
- **Pattern Implementation**: AI-assisted design pattern implementation
- **Testing Strategy**: Comprehensive test generation with AI assistance
- **Troubleshooting**: AI-guided problem resolution

---

## 🚀 Next Steps

After completing this lab:
1. **Proceed to Step 4.6**: Create hybrid payment service layer (if not covered)
2. **Monitor Performance**: Compare PostgreSQL vs DynamoDB response times
3. **Plan Phase Transition**: Prepare for switching reads to DynamoDB
4. **Document Patterns**: Record successful migration patterns for future use

**Estimated Completion Time**: 30-45 minutes with Q Developer assistance
**Difficulty Level**: Intermediate (builds on Step 4.4)
**Success Rate**: 90%+ with checkpoint validation
**Key Benefit**: Production-ready dual-write implementation for safe migration