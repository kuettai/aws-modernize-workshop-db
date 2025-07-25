using LoanApplication.Data;
using LoanApplication.Models;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Repositories
{
    public class ApplicationRepository : IApplicationRepository
    {
        private readonly LoanApplicationContext _context;

        public ApplicationRepository(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Models.Application>> GetAllApplicationsAsync()
        {
            return await _context.Applications
                .Include(a => a.Customer)
                .Include(a => a.LoanOfficer)
                .Include(a => a.Branch)
                .ToListAsync();
        }

        public async Task<Models.Application?> GetApplicationByIdAsync(int applicationId)
        {
            return await _context.Applications
                .Include(a => a.Customer)
                .Include(a => a.LoanOfficer)
                .Include(a => a.Branch)
                .Include(a => a.Loan)
                .FirstOrDefaultAsync(a => a.ApplicationId == applicationId);
        }

        public async Task<Models.Application> CreateApplicationAsync(Models.Application application)
        {
            _context.Applications.Add(application);
            await _context.SaveChangesAsync();
            return application;
        }

        public async Task<Models.Application> UpdateApplicationAsync(Models.Application application)
        {
            _context.Applications.Update(application);
            await _context.SaveChangesAsync();
            return application;
        }

        public async Task<bool> UpdateApplicationStatusAsync(int applicationId, string status, string? reason = null)
        {
            var application = await _context.Applications.FindAsync(applicationId);
            if (application == null) return false;

            application.ApplicationStatus = status;
            application.DecisionReason = reason;
            application.ModifiedDate = DateTime.Now;

            if (status == "Approved" || status == "Rejected")
                application.DecisionDate = DateTime.Now;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<int> GetApplicationCountAsync()
        {
            return await _context.Applications.CountAsync();
        }

        public async Task<IEnumerable<Models.Application>> GetApplicationsByCustomerIdAsync(int customerId)
        {
            return await _context.Applications
                .Where(a => a.CustomerId == customerId)
                .Include(a => a.LoanOfficer)
                .Include(a => a.Branch)
                .ToListAsync();
        }

        public async Task<IEnumerable<Models.Application>> GetApplicationsByStatusAsync(string status)
        {
            return await _context.Applications
                .Where(a => a.ApplicationStatus == status)
                .Include(a => a.Customer)
                .Include(a => a.LoanOfficer)
                .ToListAsync();
        }
    }
}