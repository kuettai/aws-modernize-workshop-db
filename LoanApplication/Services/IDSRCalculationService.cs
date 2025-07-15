namespace LoanApplication.Services
{
    public interface IDSRCalculationService
    {
        Task<decimal> CalculateDSRAsync(int customerId, decimal requestedLoanAmount);
        Task<decimal> GetTotalMonthlyDebtPaymentsAsync(int customerId);
        Task<decimal> GetMonthlyIncomeAsync(int customerId);
        Task<bool> IsDSRAcceptableAsync(decimal dsrRatio);
    }
}