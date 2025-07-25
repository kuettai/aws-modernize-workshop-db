using Microsoft.AspNetCore.Mvc;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CustomersController : ControllerBase
    {
        private readonly ICustomerRepository _customerRepository;

        public CustomersController(ICustomerRepository customerRepository)
        {
            _customerRepository = customerRepository;
        }

        [HttpGet]
        public async Task<IActionResult> GetCustomers()
        {
            var customers = await _customerRepository.GetAllCustomersAsync();
            return Ok(customers.Take(10)); // Return first 10 for demo
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetCustomer(int id)
        {
            var customer = await _customerRepository.GetCustomerByIdAsync(id);
            if (customer == null)
                return NotFound();
            
            return Ok(customer);
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetCount()
        {
            var count = await _customerRepository.GetCustomerCountAsync();
            return Ok(new { count });
        }

        [HttpGet("{id}/history")]
        public async Task<IActionResult> GetLoanHistory(int id)
        {
            var history = await _customerRepository.GetCustomerLoanHistoryAsync(id);
            return Ok(history);
        }
    }
}