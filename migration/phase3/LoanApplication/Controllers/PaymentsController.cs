using Microsoft.AspNetCore.Mvc;
using LoanApplication.Services;
using LoanApplication.Models;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PaymentsController : ControllerBase
    {
        private readonly IPaymentService _paymentService;
        private readonly ILogger<PaymentsController> _logger;

        public PaymentsController(IPaymentService paymentService, ILogger<PaymentsController> logger)
        {
            _paymentService = paymentService;
            _logger = logger;
        }

        [HttpPost]
        public async Task<IActionResult> ProcessPayment([FromBody] DynamoDbPayment payment)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var success = await _paymentService.ProcessPaymentAsync(payment);
            
            if (success)
                return Ok(new { message = "Payment processed successfully", paymentId = payment.PaymentId });
            
            return StatusCode(500, new { message = "Payment processing failed" });
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetCustomerPayments(int customerId, [FromQuery] int limit = 50)
        {
            var payments = await _paymentService.GetCustomerPaymentHistoryAsync(customerId, limit);
            return Ok(new { customerId, count = payments.Count, payments });
        }

        [HttpGet("loan/{loanId}")]
        public async Task<IActionResult> GetLoanPayments(int loanId)
        {
            var payments = await _paymentService.GetLoanPaymentSummaryAsync(loanId);
            return Ok(new { loanId, count = payments.Count, payments });
        }

        [HttpPut("{paymentId}/status")]
        public async Task<IActionResult> UpdatePaymentStatus(int paymentId, [FromBody] string newStatus)
        {
            var success = await _paymentService.UpdatePaymentStatusAsync(paymentId, newStatus);
            
            if (success)
                return Ok(new { message = "Payment status updated", paymentId, newStatus });
            
            return NotFound(new { message = "Payment not found" });
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingPayments()
        {
            var payments = await _paymentService.GetPendingPaymentsAsync();
            return Ok(new { count = payments.Count, payments });
        }
    }
}