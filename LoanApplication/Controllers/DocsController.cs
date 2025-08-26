using Microsoft.AspNetCore.Mvc;
using LoanApplication.Data;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Controllers
{
    public class DocsController : Controller
    {
        private readonly LoanApplicationContext _context;

        public DocsController(LoanApplicationContext context)
        {
            _context = context;
        }

        public async Task<IActionResult> Index()
        {
            // Get live database statistics
            var stats = new
            {
                Applications = await _context.Applications.CountAsync(),
                Customers = await _context.Customers.CountAsync(),
                Loans = await _context.Loans.CountAsync(),
                Payments = await _context.Payments.CountAsync(),
                Documents = await _context.Documents.CountAsync(),
                CreditChecks = await _context.CreditChecks.CountAsync(),
                IntegrationLogs = await _context.IntegrationLogs.CountAsync(),
                AuditTrail = 0 // Not implemented yet
            };

            ViewBag.DatabaseStats = stats;
            return View();
        }

        public IActionResult Architecture()
        {
            return View();
        }

        public IActionResult Database()
        {
            return View();
        }

        public IActionResult Migration()
        {
            return View();
        }
    }
}