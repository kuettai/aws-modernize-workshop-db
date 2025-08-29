using Microsoft.AspNetCore.Mvc;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    public class HomeController : Controller
    {
        private readonly IApplicationRepository _applicationRepository;
        private readonly ICustomerRepository _customerRepository;

        public HomeController(IApplicationRepository applicationRepository, ICustomerRepository customerRepository)
        {
            _applicationRepository = applicationRepository;
            _customerRepository = customerRepository;
        }

        public async Task<IActionResult> Index()
        {
            var applicationCount = await _applicationRepository.GetApplicationCountAsync();
            var customerCount = await _customerRepository.GetCustomerCountAsync();
            
            ViewBag.ApplicationCount = applicationCount;
            ViewBag.CustomerCount = customerCount;
            ViewBag.DatabaseStatus = "Connected to PostgreSQL + DynamoDB (Phase 3: Hybrid Architecture)";
            
            return View();
        }
    }
}