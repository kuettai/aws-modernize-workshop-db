using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public interface IApplicationRepository
    {
        Task<IEnumerable<Application>> GetAllApplicationsAsync();
        Task<Application?> GetApplicationByIdAsync(int applicationId);
        Task<Application> CreateApplicationAsync(Application application);
        Task<Application> UpdateApplicationAsync(Application application);
        Task<bool> UpdateApplicationStatusAsync(int applicationId, string status, string? reason = null);
        Task<int> GetApplicationCountAsync();
        Task<IEnumerable<Application>> GetApplicationsByCustomerIdAsync(int customerId);
        Task<IEnumerable<Application>> GetApplicationsByStatusAsync(string status);
    }
}