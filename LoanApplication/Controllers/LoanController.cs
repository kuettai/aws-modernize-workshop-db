using Microsoft.AspNetCore.Mvc;
using LoanApplication.Models;
using LoanApplication.Services;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    public class LoanController : Controller
    {
        private readonly ILoanService _loanService;

        public LoanController(ILoanService loanService)
        {
            _loanService = loanService;
        }

        // GET: Loan
        public async Task<IActionResult> Index()
        {
            var loans = await _loanService.GetAllLoansAsync();
            return View(loans);
        }

        // GET: Loan/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var loan = await _loanService.GetLoanByIdAsync(id);
            if (loan == null)
            {
                return NotFound();
            }
            return View(loan);
        }

        // GET: Loan/PaymentSchedule/5
        public async Task<IActionResult> PaymentSchedule(int id)
        {
            var paymentSchedule = await _loanService.GetPaymentScheduleAsync(id);
            return View(paymentSchedule);
        }

        // POST: Loan/ProcessPayment/5
        [HttpPost]
        public async Task<IActionResult> ProcessPayment(int id, decimal amount, string paymentMethod)
        {
            try
            {
                await _loanService.ProcessPaymentAsync(id, amount, paymentMethod);
                return RedirectToAction(nameof(Details), new { id });
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", ex.Message);
                return RedirectToAction(nameof(Details), new { id });
            }
        }

        // GET: Loan/PaymentHistory/5
        public async Task<IActionResult> PaymentHistory(int id)
        {
            var payments = await _loanService.GetPaymentHistoryAsync(id);
            return View(payments);
        }
    }
}