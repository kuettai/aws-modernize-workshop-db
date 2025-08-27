using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public interface IPaymentsRepository
    {
        Task<Payment?> GetPaymentByIdAsync(int paymentId);
        Task<List<Payment>> GetCustomerPaymentsAsync(int customerId, DateTime? startDate = null, DateTime? endDate = null, int limit = 50);
        Task<List<Payment>> GetPaymentsByStatusAsync(string status, DateTime? startDate = null, DateTime? endDate = null);
        Task<List<Payment>> GetLoanPaymentsAsync(int loanId);
        Task<bool> InsertPaymentAsync(Payment payment);
        Task<bool> UpdatePaymentStatusAsync(int paymentId, string newStatus);
        Task<bool> InsertPaymentBatchAsync(List<Payment> payments);
    }
}