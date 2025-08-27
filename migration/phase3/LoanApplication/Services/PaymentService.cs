using LoanApplication.Repositories;
using LoanApplication.Models;
using LoanApplication.Data;
using Microsoft.EntityFrameworkCore;

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

        public async Task<bool> ProcessPaymentAsync(DynamoDbPayment payment)
        {
            try
            {
                // Dual-write: PostgreSQL first (existing system)
                var pgPayment = new Payment
                {
                    PaymentId = payment.PaymentId,
                    LoanId = payment.LoanId,
                    PaymentNumber = 1, // Default payment number
                    PaymentAmount = payment.PaymentAmount,
                    PrincipalAmount = payment.PaymentAmount * 0.8m, // Estimate
                    InterestAmount = payment.PaymentAmount * 0.2m, // Estimate
                    PaymentDate = payment.PaymentDate,
                    PaymentMethod = payment.PaymentMethod,
                    PaymentStatus = payment.PaymentStatus,
                    TransactionId = payment.TransactionReference,
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

            // Fallback to PostgreSQL (join through Loan -> Application to get CustomerId)
            var pgPayments = await _pgContext.Payments
                .Include(p => p.Loan)
                .ThenInclude(l => l.Application)
                .Where(p => p.Loan.Application.CustomerId == customerId)
                .OrderByDescending(p => p.PaymentDate)
                .Take(limit)
                .ToListAsync();

            return pgPayments.Select(p => new DynamoDbPayment
            {
                PaymentId = p.PaymentId,
                CustomerId = p.Loan.Application.CustomerId,
                LoanId = p.LoanId,
                PaymentAmount = p.PaymentAmount,
                PaymentDate = p.PaymentDate,
                PaymentMethod = p.PaymentMethod,
                PaymentStatus = p.PaymentStatus,
                TransactionReference = p.TransactionId,
                CreatedDate = p.CreatedDate
            }).ToList();
        }

        public async Task<List<DynamoDbPayment>> GetLoanPaymentSummaryAsync(int loanId)
        {
            return await _dynamoRepository.GetLoanPaymentsAsync(loanId);
        }

        public async Task<bool> UpdatePaymentStatusAsync(int paymentId, string newStatus)
        {
            return await _dynamoRepository.UpdatePaymentStatusAsync(paymentId, newStatus);
        }

        public async Task<List<DynamoDbPayment>> GetPendingPaymentsAsync()
        {
            return await _dynamoRepository.GetPaymentsByStatusAsync("Pending");
        }

        public async Task<bool> ProcessBulkPaymentsAsync(List<DynamoDbPayment> payments)
        {
            return await _dynamoRepository.InsertPaymentBatchAsync(payments);
        }
    }
}