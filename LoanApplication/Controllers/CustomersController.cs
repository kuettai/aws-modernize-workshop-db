using Microsoft.AspNetCore.Mvc;
using LoanApplication.Data;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CustomersController : ControllerBase
    {
        private readonly LoanApplicationContext _context;

        public CustomersController(LoanApplicationContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetCustomers()
        {
            var customers = await _context.Customers
                .Where(c => c.IsActive)
                .Select(c => new {
                    c.CustomerId,
                    c.CustomerNumber,
                    c.FirstName,
                    c.LastName,
                    c.Email,
                    c.MonthlyIncome,
                    c.EmploymentStatus
                })
                .OrderBy(c => c.LastName)
                .Take(10)
                .ToListAsync();
            
            return Ok(customers);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetCustomer(int id)
        {
            var customer = await _context.Customers
                .Where(c => c.CustomerId == id && c.IsActive)
                .Select(c => new {
                    c.CustomerId,
                    c.CustomerNumber,
                    c.FirstName,
                    c.LastName,
                    c.Email,
                    c.MonthlyIncome,
                    c.EmploymentStatus,
                    c.DateOfBirth,
                    c.Phone
                })
                .FirstOrDefaultAsync();
            
            if (customer == null)
                return NotFound();
            
            return Ok(customer);
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetCount()
        {
            var count = await _context.Customers.CountAsync(c => c.IsActive);
            return Ok(new { count });
        }

        [HttpGet("{id}/history")]
        public async Task<IActionResult> GetLoanHistory(int id)
        {
            var history = await _context.Applications
                .Where(a => a.CustomerId == id)
                .Select(a => new {
                    a.ApplicationId,
                    a.ApplicationNumber,
                    a.RequestedAmount,
                    a.ApplicationStatus,
                    a.SubmissionDate
                })
                .OrderByDescending(a => a.SubmissionDate)
                .ToListAsync();
            
            return Ok(history);
        }
    }
}