using LoanApplication.Models;

namespace LoanApplication.Repositories
{
    public interface ICustomerRepository
    {
        Task<IEnumerable<Customer>> GetAllCustomersAsync();
        Task<Customer?> GetCustomerByIdAsync(int customerId);
        Task<Customer> CreateCustomerAsync(Customer customer);
        Task<Customer> UpdateCustomerAsync(Customer customer);
        Task<int> GetCustomerCountAsync();
        Task<IEnumerable<Application>> GetCustomerLoanHistoryAsync(int customerId);
        Task<Customer?> GetCustomerBySSNAsync(string ssn);
        Task<Customer?> GetCustomerByEmailAsync(string email);
    }
}