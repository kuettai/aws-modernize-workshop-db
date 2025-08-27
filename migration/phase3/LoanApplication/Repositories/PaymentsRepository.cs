using Amazon.DynamoDBv2.DataModel;
using Amazon.DynamoDBv2.DocumentModel;
using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public class PaymentsRepository : IPaymentsRepository
    {
        private readonly DynamoDBContext _dynamoContext;
        private readonly ILogger<PaymentsRepository> _logger;

        public PaymentsRepository(DynamoDBContext dynamoContext, ILogger<PaymentsRepository> logger)
        {
            _dynamoContext = dynamoContext;
            _logger = logger;
        }

        public async Task<Payment?> GetPaymentByIdAsync(int paymentId)
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

        public async Task<List<Payment>> GetCustomerPaymentsAsync(int customerId, DateTime? startDate = null, DateTime? endDate = null, int limit = 50)
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
                    BackwardSearch = true
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
                return new List<Payment>();
            }
        }

        public async Task<List<Payment>> GetPaymentsByStatusAsync(string status, DateTime? startDate = null, DateTime? endDate = null)
        {
            try
            {
                var queryConfig = new QueryOperationConfig
                {
                    IndexName = "PaymentStatusIndex",
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "PaymentStatus = :status",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":status", status }
                        }
                    }
                };

                if (startDate.HasValue && endDate.HasValue)
                {
                    queryConfig.KeyExpression.ExpressionStatement += " AND PaymentDate BETWEEN :startDate AND :endDate";
                    queryConfig.KeyExpression.ExpressionAttributeValues.Add(":startDate", startDate.Value.ToString("yyyy-MM-ddTHH:mm:ssZ"));
                    queryConfig.KeyExpression.ExpressionAttributeValues.Add(":endDate", endDate.Value.ToString("yyyy-MM-ddTHH:mm:ssZ"));
                }

                var search = _dynamoContext.FromQueryAsync<Payment>(queryConfig);
                return await search.GetRemainingAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get payments by status {Status}", status);
                return new List<Payment>();
            }
        }

        public async Task<List<Payment>> GetLoanPaymentsAsync(int loanId)
        {
            try
            {
                var queryConfig = new QueryOperationConfig
                {
                    IndexName = "LoanPaymentIndex",
                    KeyExpression = new Expression
                    {
                        ExpressionStatement = "LoanId = :loanId",
                        ExpressionAttributeValues = new Dictionary<string, DynamoDBEntry>
                        {
                            { ":loanId", loanId }
                        }
                    },
                    BackwardSearch = true
                };

                var search = _dynamoContext.FromQueryAsync<Payment>(queryConfig);
                return await search.GetRemainingAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get payments for loan {LoanId}", loanId);
                return new List<Payment>();
            }
        }

        public async Task<bool> InsertPaymentAsync(Payment payment)
        {
            try
            {
                payment.PaymentDateId = $"{payment.PaymentDate:yyyy-MM-ddTHH:mm:ssZ}#{payment.PaymentId}";
                payment.TTL = DateTimeOffset.UtcNow.AddYears(7).ToUnixTimeSeconds();
                
                await _dynamoContext.SaveAsync(payment);
                _logger.LogDebug("Successfully inserted payment {PaymentId}", payment.PaymentId);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to insert payment {PaymentId}", payment.PaymentId);
                return false;
            }
        }

        public async Task<bool> UpdatePaymentStatusAsync(int paymentId, string newStatus)
        {
            try
            {
                var payment = await GetPaymentByIdAsync(paymentId);
                if (payment == null) return false;

                payment.PaymentStatus = newStatus;
                payment.UpdatedDate = DateTime.UtcNow;
                
                await _dynamoContext.SaveAsync(payment);
                _logger.LogDebug("Successfully updated payment {PaymentId} status to {Status}", paymentId, newStatus);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update payment {PaymentId} status", paymentId);
                return false;
            }
        }

        public async Task<bool> InsertPaymentBatchAsync(List<Payment> payments)
        {
            try
            {
                var batchWrite = _dynamoContext.CreateBatchWrite<Payment>();
                
                foreach (var payment in payments)
                {
                    payment.PaymentDateId = $"{payment.PaymentDate:yyyy-MM-ddTHH:mm:ssZ}#{payment.PaymentId}";
                    payment.TTL = DateTimeOffset.UtcNow.AddYears(7).ToUnixTimeSeconds();
                    batchWrite.AddPutItem(payment);
                }
                
                await batchWrite.ExecuteAsync();
                _logger.LogDebug("Successfully inserted {Count} payments in batch", payments.Count);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to insert batch of {Count} payments", payments.Count);
                return false;
            }
        }
    }
}