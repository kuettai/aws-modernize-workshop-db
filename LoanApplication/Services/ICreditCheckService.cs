using LoanApplication.Models;

namespace LoanApplication.Services
{
    public interface ICreditCheckService
    {
        Task<CreditCheck> PerformCreditCheckAsync(int customerId);
        Task<CreditCheck> PerformCreditCheckAsync(int customerId, int? applicationId);
        Task<bool> IsCreditScoreAcceptableAsync(int creditScore);
        Task<CreditCheck?> GetLatestCreditCheckAsync(int customerId);
    }
}