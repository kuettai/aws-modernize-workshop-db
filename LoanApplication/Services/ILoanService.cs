using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface ILoanService
    {
        Task<IEnumerable<Loan>> GetAllLoansAsync();
        Task<Loan?> GetLoanByIdAsync(int loanId);
        Task<Loan> CreateLoanAsync(Application application);
        Task<IEnumerable<Payment>> GetPaymentScheduleAsync(int loanId);
        Task<Payment> ProcessPaymentAsync(int loanId, decimal amount, string paymentMethod);
        Task<IEnumerable<Payment>> GetPaymentHistoryAsync(int loanId);
        Task<decimal> CalculateMonthlyPaymentAsync(decimal principal, decimal interestRate, int termMonths);
    }
}