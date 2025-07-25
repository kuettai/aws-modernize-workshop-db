using LoanApplication.Data;
using LoanApplication.Models;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Services
{
    public class CreditCheckService : ICreditCheckService
    {
        private readonly LoanApplicationContext _context;

        public CreditCheckService(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<CreditCheck> PerformCreditCheckAsync(int customerId)
        {
            return await PerformCreditCheckAsync(customerId, null);
        }

        public async Task<CreditCheck> PerformCreditCheckAsync(int customerId, int? applicationId)
        {
            // Check if recent credit check exists (within 30 days)
            var recentCheck = await _context.CreditChecks
                .Where(cc => cc.CustomerId == customerId && 
                           cc.CheckDate >= DateTime.Now.AddDays(-30) &&
                           cc.IsSuccessful)
                .OrderByDescending(cc => cc.CheckDate)
                .FirstOrDefaultAsync();

            if (recentCheck != null)
            {
                return recentCheck; // Return cached result
            }

            // Perform new credit check (mock implementation)
            var creditCheck = new CreditCheck
            {
                CustomerId = customerId,
                ApplicationId = applicationId,
                CreditBureau = "Experian",
                CreditScore = GenerateMockCreditScore(),
                CreditReportData = GenerateMockCreditReport(),
                CheckDate = DateTime.Now,
                ExpiryDate = DateTime.Now.AddYears(1),
                RequestId = Guid.NewGuid().ToString(),
                ResponseCode = "200",
                IsSuccessful = true,
                CreatedDate = DateTime.Now
            };

            _context.CreditChecks.Add(creditCheck);
            await _context.SaveChangesAsync();

            return creditCheck;
        }

        public async Task<bool> IsCreditScoreAcceptableAsync(int creditScore)
        {
            // Standard acceptable credit score is typically 600 or higher
            return creditScore >= 600;
        }

        public async Task<CreditCheck?> GetLatestCreditCheckAsync(int customerId)
        {
            return await _context.CreditChecks
                .Where(cc => cc.CustomerId == customerId && cc.IsSuccessful)
                .OrderByDescending(cc => cc.CheckDate)
                .FirstOrDefaultAsync();
        }

        private int GenerateMockCreditScore()
        {
            // Generate realistic credit score distribution
            var random = new Random();
            var scoreRanges = new[]
            {
                (600, 650, 0.15), // 15% chance of 600-650 (Fair)
                (650, 700, 0.25), // 25% chance of 650-700 (Good)
                (700, 750, 0.35), // 35% chance of 700-750 (Very Good)
                (750, 850, 0.25)  // 25% chance of 750-850 (Excellent)
            };

            var randomValue = random.NextDouble();
            var cumulative = 0.0;

            foreach (var (min, max, probability) in scoreRanges)
            {
                cumulative += probability;
                if (randomValue <= cumulative)
                {
                    return random.Next(min, max + 1);
                }
            }

            return 720; // Default fallback
        }

        private string GenerateMockCreditReport()
        {
            var mockReport = new
            {
                score = GenerateMockCreditScore(),
                factors = new[]
                {
                    "Payment History",
                    "Credit Utilization",
                    "Length of Credit History",
                    "Credit Mix",
                    "New Credit"
                },
                accounts = new[]
                {
                    new { type = "Credit Card", balance = 2500, limit = 10000, status = "Current" },
                    new { type = "Auto Loan", balance = 15000, limit = 25000, status = "Current" },
                    new { type = "Mortgage", balance = 180000, limit = 200000, status = "Current" }
                },
                inquiries = 2,
                reportDate = DateTime.Now.ToString("yyyy-MM-dd")
            };

            return System.Text.Json.JsonSerializer.Serialize(mockReport);
        }
    }
}