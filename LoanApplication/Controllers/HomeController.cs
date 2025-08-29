using Microsoft.AspNetCore.Mvc;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    public class HomeController : Controller
    {
        private readonly IApplicationRepository _applicationRepository;
        private readonly ICustomerRepository _customerRepository;
        private readonly IConfiguration _configuration;

        public HomeController(IApplicationRepository applicationRepository, ICustomerRepository customerRepository, IConfiguration configuration)
        {
            _applicationRepository = applicationRepository;
            _customerRepository = customerRepository;
            _configuration = configuration;
        }

        public async Task<IActionResult> Index()
        {
            var applicationCount = await _applicationRepository.GetApplicationCountAsync();
            var customerCount = await _customerRepository.GetCustomerCountAsync();
            
            ViewBag.ApplicationCount = applicationCount;
            ViewBag.CustomerCount = customerCount;
            ViewBag.DatabaseStatus = GetDatabaseStatus();
            
            return View();
        }
        
        private string GetDatabaseStatus()
        {
            var connectionString = _configuration.GetConnectionString("DefaultConnection");
            
            if (string.IsNullOrEmpty(connectionString))
                return "Database connection not configured";
                
            // Detect database type from connection string
            if (connectionString.Contains("Server=tcp:") || connectionString.Contains("Data Source="))
            {
                return "Connected to SQL Server";
            }
            else if (connectionString.Contains("Host=") || connectionString.Contains("Server="))
            {
                // Check if DynamoDB is also configured (Phase 3)
                var dynamoConfig = _configuration.GetSection("DynamoDB").Exists();
                var hybridConfig = _configuration.GetSection("HybridLogging").Exists();
                
                if (hybridConfig && dynamoConfig)
                {
                    return "Connected to PostgreSQL + DynamoDB (Phase 3: Hybrid Architecture)";
                }
                else
                {
                    return "Connected to PostgreSQL (Phase 2: Modernized)";
                }
            }
            
            return "Connected to SQL Server";
        }
    }
}