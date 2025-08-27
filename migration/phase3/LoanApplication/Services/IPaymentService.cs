using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface IPaymentService
    {
        Task<bool> ProcessPaymentAsync(DynamoDbPayment payment);
        Task<List<DynamoDbPayment>> GetCustomerPaymentHistoryAsync(int customerId, int limit = 50);
        Task<List<DynamoDbPayment>> GetLoanPaymentSummaryAsync(int loanId);
        Task<bool> UpdatePaymentStatusAsync(int paymentId, string newStatus);
        Task<List<DynamoDbPayment>> GetPendingPaymentsAsync();
        Task<bool> ProcessBulkPaymentsAsync(List<DynamoDbPayment> payments);
    }
}