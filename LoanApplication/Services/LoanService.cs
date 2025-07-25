using LoanApplication.Data;
using LoanApplication.Models;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Services
{
    public class LoanService : ILoanService
    {
        private readonly LoanApplicationContext _context;

        public LoanService(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Loan>> GetAllLoansAsync()
        {
            return await _context.Loans
                .Include(l => l.Application)
                .ThenInclude(a => a.Customer)
                .ToListAsync();
        }

        public async Task<Loan?> GetLoanByIdAsync(int loanId)
        {
            return await _context.Loans
                .Include(l => l.Application)
                .ThenInclude(a => a.Customer)
                .Include(l => l.Payments)
                .FirstOrDefaultAsync(l => l.LoanId == loanId);
        }

        public async Task<Loan> CreateLoanAsync(Models.Application application)
        {
            var loan = new Loan
            {
                ApplicationId = application.ApplicationId,
                LoanNumber = GenerateLoanNumber(),
                ApprovedAmount = application.RequestedAmount,
                InterestRate = 0.08m, // Default 8%
                LoanTermMonths = 60, // Default 5 years
                LoanStatus = "Active",
                DisbursementDate = DateTime.Now,
                OutstandingBalance = application.RequestedAmount,
                CreatedDate = DateTime.Now,
                ModifiedDate = DateTime.Now
            };

            // Calculate monthly payment
            loan.MonthlyPayment = await CalculateMonthlyPaymentAsync(
                loan.ApprovedAmount, 
                loan.InterestRate, 
                loan.LoanTermMonths);

            loan.MaturityDate = loan.DisbursementDate?.AddMonths(loan.LoanTermMonths);
            loan.NextPaymentDate = loan.DisbursementDate?.AddMonths(1);

            _context.Loans.Add(loan);
            await _context.SaveChangesAsync();
            return loan;
        }

        public async Task<IEnumerable<Payment>> GetPaymentScheduleAsync(int loanId)
        {
            return await _context.Payments
                .Where(p => p.LoanId == loanId)
                .OrderBy(p => p.PaymentDate)
                .ToListAsync();
        }

        public async Task<Payment> ProcessPaymentAsync(int loanId, decimal amount, string paymentMethod)
        {
            var loan = await _context.Loans.FindAsync(loanId);
            if (loan == null) throw new ArgumentException("Loan not found");

            var interestPortion = loan.OutstandingBalance * (loan.InterestRate / 12);
            var principalPortion = amount - interestPortion;

            var payment = new Payment
            {
                LoanId = loanId,
                PaymentNumber = await GetNextPaymentNumberAsync(loanId),
                PaymentDate = DateTime.Now,
                PaymentAmount = amount,
                PrincipalAmount = principalPortion,
                InterestAmount = interestPortion,
                PaymentMethod = paymentMethod,
                PaymentStatus = "Completed",
                TransactionId = Guid.NewGuid().ToString(),
                CreatedDate = DateTime.Now
            };

            // Update loan balance
            loan.OutstandingBalance -= principalPortion;
            loan.NextPaymentDate = loan.NextPaymentDate?.AddMonths(1);
            loan.ModifiedDate = DateTime.Now;

            if (loan.OutstandingBalance <= 0)
            {
                loan.LoanStatus = "Paid Off";
                loan.NextPaymentDate = null;
            }

            _context.Payments.Add(payment);
            await _context.SaveChangesAsync();
            return payment;
        }

        public async Task<IEnumerable<Payment>> GetPaymentHistoryAsync(int loanId)
        {
            return await _context.Payments
                .Where(p => p.LoanId == loanId)
                .OrderByDescending(p => p.PaymentDate)
                .ToListAsync();
        }

        public async Task<decimal> CalculateMonthlyPaymentAsync(decimal principal, decimal interestRate, int termMonths)
        {
            if (interestRate == 0) return principal / termMonths;

            var monthlyRate = interestRate / 12;
            var payment = principal * (monthlyRate * (decimal)Math.Pow((double)(1 + monthlyRate), termMonths)) /
                         ((decimal)Math.Pow((double)(1 + monthlyRate), termMonths) - 1);

            return Math.Round(payment, 2);
        }

        private string GenerateLoanNumber()
        {
            return $"LOAN{DateTime.Now:yyyyMM}{Random.Shared.Next(100000, 999999)}";
        }

        private async Task<int> GetNextPaymentNumberAsync(int loanId)
        {
            var lastPayment = await _context.Payments
                .Where(p => p.LoanId == loanId)
                .OrderByDescending(p => p.PaymentNumber)
                .FirstOrDefaultAsync();

            return (lastPayment?.PaymentNumber ?? 0) + 1;
        }
    }
}