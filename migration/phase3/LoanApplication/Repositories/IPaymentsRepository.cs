using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public interface IPaymentsRepository
    {
        Task<DynamoDbPayment?> GetPaymentByIdAsync(int paymentId);
        Task<List<DynamoDbPayment>> GetCustomerPaymentsAsync(int customerId, DateTime? startDate = null, DateTime? endDate = null, int limit = 50);
        Task<List<DynamoDbPayment>> GetPaymentsByStatusAsync(string status, DateTime? startDate = null, DateTime? endDate = null);
        Task<List<DynamoDbPayment>> GetLoanPaymentsAsync(int loanId);
        Task<bool> InsertPaymentAsync(DynamoDbPayment payment);
        Task<bool> UpdatePaymentStatusAsync(int paymentId, string newStatus);
        Task<bool> InsertPaymentBatchAsync(List<DynamoDbPayment> payments);
    }
}