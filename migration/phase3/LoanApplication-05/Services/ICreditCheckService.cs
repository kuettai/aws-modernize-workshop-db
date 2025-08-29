using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface ICreditCheckService
    {
        // Existing methods from baseline
        Task<CreditCheck> PerformCreditCheckAsync(int customerId);
        Task<CreditCheck> PerformCreditCheckAsync(int customerId, int? applicationId);
        Task<bool> IsCreditScoreAcceptableAsync(int creditScore);
        Task<CreditCheck?> GetLatestCreditCheckAsync(int customerId);
        
        // New method for Phase 3
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