using LoanApplication.Data;
using LoanApplication.Models;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Repositories
{
    public class CustomerRepository : ICustomerRepository
    {
        private readonly LoanApplicationContext _context;

        public CustomerRepository(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Customer>> GetAllCustomersAsync()
        {
            return await _context.Customers
                .Where(c => c.IsActive)
                .OrderBy(c => c.LastName)
                .ToListAsync();
        }

        public async Task<Customer?> GetCustomerByIdAsync(int customerId)
        {
            return await _context.Customers
                .Include(c => c.Applications)
                .FirstOrDefaultAsync(c => c.CustomerId == customerId);
        }

        public async Task<Customer> CreateCustomerAsync(Customer customer)
        {
            _context.Customers.Add(customer);
            await _context.SaveChangesAsync();
            return customer;
        }

        public async Task<Customer> UpdateCustomerAsync(Customer customer)
        {
            _context.Customers.Update(customer);
            await _context.SaveChangesAsync();
            return customer;
        }

        public async Task<int> GetCustomerCountAsync()
        {
            return await _context.Customers.CountAsync();
        }

        public async Task<IEnumerable<Models.Application>> GetCustomerLoanHistoryAsync(int customerId)
        {
            return await _context.Applications
                .Where(a => a.CustomerId == customerId)
                .Include(a => a.Loan)
                .ThenInclude(l => l.Payments)
                .OrderByDescending(a => a.SubmissionDate)
                .ToListAsync();
        }

        public async Task<Customer?> GetCustomerBySSNAsync(string ssn)
        {
            return await _context.Customers
                .FirstOrDefaultAsync(c => c.SSN == ssn && c.IsActive);
        }

        public async Task<Customer?> GetCustomerByEmailAsync(string email)
        {
            return await _context.Customers
                .FirstOrDefaultAsync(c => c.Email == email && c.IsActive);
        }
    }
}