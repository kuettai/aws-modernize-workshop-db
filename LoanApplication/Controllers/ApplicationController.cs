using Microsoft.AspNetCore.Mvc;
using LoanApplication.Models;
using LoanApplication.Services;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    public class ApplicationController : Controller
    {
        private readonly IApplicationRepository _applicationRepository;
        private readonly ILoanService _loanService;
        private readonly IDSRCalculationService _dsrService;
        private readonly ICreditCheckService _creditCheckService;

        public ApplicationController(
            IApplicationRepository applicationRepository,
            ILoanService loanService,
            IDSRCalculationService dsrService,
            ICreditCheckService creditCheckService)
        {
            _applicationRepository = applicationRepository;
            _loanService = loanService;
            _dsrService = dsrService;
            _creditCheckService = creditCheckService;
        }

        // GET: Application
        public async Task<IActionResult> Index()
        {
            var applications = await _applicationRepository.GetAllApplicationsAsync();
            return View(applications);
        }

        // GET: Application/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var application = await _applicationRepository.GetApplicationByIdAsync(id);
            if (application == null)
            {
                return NotFound();
            }
            return View(application);
        }

        // GET: Application/Create
        public IActionResult Create()
        {
            return View();
        }

        // POST: Application/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Application application)
        {
            if (ModelState.IsValid)
            {
                // Generate application number
                application.ApplicationNumber = await GenerateApplicationNumber();
                
                // Calculate DSR
                application.DSRRatio = await _dsrService.CalculateDSRAsync(application.CustomerId, application.RequestedAmount);
                
                // Perform credit check
                var creditCheck = await _creditCheckService.PerformCreditCheckAsync(application.CustomerId);
                application.CreditScore = creditCheck.CreditScore;
                
                await _applicationRepository.CreateApplicationAsync(application);
                return RedirectToAction(nameof(Index));
            }
            return View(application);
        }

        // GET: Application/Edit/5
        public async Task<IActionResult> Edit(int id)
        {
            var application = await _applicationRepository.GetApplicationByIdAsync(id);
            if (application == null)
            {
                return NotFound();
            }
            return View(application);
        }

        // POST: Application/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, Application application)
        {
            if (id != application.ApplicationId)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                await _applicationRepository.UpdateApplicationAsync(application);
                return RedirectToAction(nameof(Index));
            }
            return View(application);
        }

        // POST: Application/UpdateStatus/5
        [HttpPost]
        public async Task<IActionResult> UpdateStatus(int id, string status, string reason)
        {
            await _applicationRepository.UpdateApplicationStatusAsync(id, status, reason);
            return RedirectToAction(nameof(Details), new { id });
        }

        private async Task<string> GenerateApplicationNumber()
        {
            var count = await _applicationRepository.GetApplicationCountAsync();
            return $"APP{DateTime.Now:yyyyMM}{(count + 1):D6}";
        }
    }
}