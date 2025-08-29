using LoanApplication.Models;

namespace LoanApplication.Services
{
    // Extend existing interface with new method for Phase 3
    public partial interface ICreditCheckService
    {
        Task<CreditCheckResult> CheckCreditAsync(int customerId, decimal loanAmount);
    }

    public class CreditCheckResult
    {
        public int CustomerId { get; set; }
        public int CreditScore { get; set; }
        public bool IsApproved { get; set; }
        public decimal MaxLoanAmount { get; set; }
        public DateTime CheckDate { get; set; }
        public string CorrelationId { get; set; } = string.Empty;
    }
}