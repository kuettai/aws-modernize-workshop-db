using LoanApplication.Models;
using LoanApplication.Services;
using System.Text.Json;

namespace LoanApplication.Services
{
    public class CreditCheckService : ICreditCheckService
    {
        private readonly IHybridLogService _logService;
        private readonly ILogger<CreditCheckService> _logger;

        public CreditCheckService(IHybridLogService logService, ILogger<CreditCheckService> logger)
        {
            _logService = logService;
            _logger = logger;
        }

        public async Task<CreditCheckResult> CheckCreditAsync(int customerId, decimal loanAmount)
        {
            var correlationId = Guid.NewGuid().ToString();
            var startTime = DateTime.UtcNow;

            // Log request
            var requestLog = new IntegrationLog
            {
                LogType = "API",
                ServiceName = "CreditCheckService",
                LogTimestamp = startTime,
                RequestData = JsonSerializer.Serialize(new { customerId, loanAmount }),
                CorrelationId = correlationId,
                UserId = "system" // In real app, get from context
            };

            try
            {
                _logger.LogInformation("Starting credit check for customer {CustomerId}, amount {Amount}",
                    customerId, loanAmount);

                // Simulate credit check processing
                await Task.Delay(Random.Shared.Next(100, 500)); // Simulate API call time

                var creditScore = Random.Shared.Next(300, 850);
                var isApproved = creditScore >= 650 && loanAmount <= 100000;

                var result = new CreditCheckResult
                {
                    CustomerId = customerId,
                    CreditScore = creditScore,
                    IsApproved = isApproved,
                    MaxLoanAmount = isApproved ? loanAmount * 1.2m : 0,
                    CheckDate = DateTime.UtcNow,
                    CorrelationId = correlationId
                };

                // Log successful response
                var processingTime = (int)(DateTime.UtcNow - startTime).TotalMilliseconds;
                requestLog.ResponseData = JsonSerializer.Serialize(result);
                requestLog.IsSuccess = true;
                requestLog.StatusCode = "200";
                requestLog.ProcessingTimeMs = processingTime;

                await _logService.WriteLogAsync(requestLog);

                _logger.LogInformation("Credit check completed for customer {CustomerId}. Score: {Score}, Approved: {Approved}",
                    customerId, creditScore, isApproved);

                return result;
            }
            catch (Exception ex)
            {
                // Log error
                var processingTime = (int)(DateTime.UtcNow - startTime).TotalMilliseconds;
                requestLog.IsSuccess = false;
                requestLog.StatusCode = "500";
                requestLog.ErrorMessage = ex.Message;
                requestLog.ProcessingTimeMs = processingTime;

                await _logService.WriteLogAsync(requestLog);

                _logger.LogError(ex, "Credit check failed for customer {CustomerId}", customerId);
                throw;
            }
        }
    }
}