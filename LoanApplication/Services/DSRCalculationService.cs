using LoanApplication.Data;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Services
{
    public class DSRCalculationService : IDSRCalculationService
    {
        private readonly LoanApplicationContext _context;

        public DSRCalculationService(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<decimal> CalculateDSRAsync(int customerId, decimal requestedLoanAmount)
        {
            var monthlyIncome = await GetMonthlyIncomeAsync(customerId);
            if (monthlyIncome <= 0) return 100; // Invalid income

            var totalMonthlyDebt = await GetTotalMonthlyDebtPaymentsAsync(customerId);
            
            // Estimate monthly payment for requested loan (assuming 8% interest, 5 years)
            var estimatedMonthlyPayment = CalculateEstimatedPayment(requestedLoanAmount, 0.08m, 60);
            
            var totalDebtWithNewLoan = totalMonthlyDebt + estimatedMonthlyPayment;
            var dsrRatio = (totalDebtWithNewLoan / monthlyIncome) * 100;

            return Math.Round(dsrRatio, 2);
        }

        public async Task<decimal> GetTotalMonthlyDebtPaymentsAsync(int customerId)
        {
            // Get existing loan payments for this customer
            var existingLoans = await _context.Loans
                .Include(l => l.Application)
                .Where(l => l.Application.CustomerId == customerId && l.LoanStatus == "Active")
                .ToListAsync();

            return existingLoans.Sum(l => l.MonthlyPayment);
        }

        public async Task<decimal> GetMonthlyIncomeAsync(int customerId)
        {
            var customer = await _context.Customers.FindAsync(customerId);
            return customer?.MonthlyIncome ?? 0;
        }

        public async Task<bool> IsDSRAcceptableAsync(decimal dsrRatio)
        {
            // Standard acceptable DSR is typically 40% or less
            return dsrRatio <= 40;
        }

        private decimal CalculateEstimatedPayment(decimal principal, decimal annualRate, int termMonths)
        {
            if (annualRate == 0) return principal / termMonths;

            var monthlyRate = annualRate / 12;
            var payment = principal * (monthlyRate * (decimal)Math.Pow((double)(1 + monthlyRate), termMonths)) /
                         ((decimal)Math.Pow((double)(1 + monthlyRate), termMonths) - 1);

            return Math.Round(payment, 2);
        }
    }
}