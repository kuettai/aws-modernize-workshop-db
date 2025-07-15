using Microsoft.AspNetCore.Mvc;
using LoanApplication.Models;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    public class CustomerController : Controller
    {
        private readonly ICustomerRepository _customerRepository;

        public CustomerController(ICustomerRepository customerRepository)
        {
            _customerRepository = customerRepository;
        }

        // GET: Customer
        public async Task<IActionResult> Index()
        {
            var customers = await _customerRepository.GetAllCustomersAsync();
            return View(customers);
        }

        // GET: Customer/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var customer = await _customerRepository.GetCustomerByIdAsync(id);
            if (customer == null)
            {
                return NotFound();
            }
            return View(customer);
        }

        // GET: Customer/Create
        public IActionResult Create()
        {
            return View();
        }

        // POST: Customer/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Customer customer)
        {
            if (ModelState.IsValid)
            {
                customer.CustomerNumber = await GenerateCustomerNumber();
                await _customerRepository.CreateCustomerAsync(customer);
                return RedirectToAction(nameof(Index));
            }
            return View(customer);
        }

        // GET: Customer/Edit/5
        public async Task<IActionResult> Edit(int id)
        {
            var customer = await _customerRepository.GetCustomerByIdAsync(id);
            if (customer == null)
            {
                return NotFound();
            }
            return View(customer);
        }

        // POST: Customer/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, Customer customer)
        {
            if (id != customer.CustomerId)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                await _customerRepository.UpdateCustomerAsync(customer);
                return RedirectToAction(nameof(Index));
            }
            return View(customer);
        }

        // GET: Customer/LoanHistory/5
        public async Task<IActionResult> LoanHistory(int id)
        {
            var loanHistory = await _customerRepository.GetCustomerLoanHistoryAsync(id);
            return View(loanHistory);
        }

        private async Task<string> GenerateCustomerNumber()
        {
            var count = await _customerRepository.GetCustomerCountAsync();
            return $"CUST{DateTime.Now:yyyy}{(count + 1):D6}";
        }
    }
}