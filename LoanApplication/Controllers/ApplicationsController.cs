using Microsoft.AspNetCore.Mvc;
using LoanApplication.Data;
using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ApplicationsController : ControllerBase
    {
        private readonly LoanApplicationContext _context;

        public ApplicationsController(LoanApplicationContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetApplications()
        {
            var applications = await _context.Applications
                .Where(a => a.IsActive)
                .Select(a => new {
                    a.ApplicationId,
                    a.ApplicationNumber,
                    a.RequestedAmount,
                    a.ApplicationStatus,
                    a.SubmissionDate,
                    CustomerName = a.Customer.FirstName + " " + a.Customer.LastName,
                    LoanOfficerName = a.LoanOfficer.FirstName + " " + a.LoanOfficer.LastName,
                    BranchName = a.Branch.BranchName
                })
                .Take(10)
                .ToListAsync();
            
            return Ok(applications);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetApplication(int id)
        {
            var application = await _context.Applications
                .Where(a => a.ApplicationId == id && a.IsActive)
                .Select(a => new {
                    a.ApplicationId,
                    a.ApplicationNumber,
                    a.RequestedAmount,
                    a.ApplicationStatus,
                    a.SubmissionDate,
                    CustomerName = a.Customer.FirstName + " " + a.Customer.LastName,
                    LoanOfficerName = a.LoanOfficer.FirstName + " " + a.LoanOfficer.LastName,
                    BranchName = a.Branch.BranchName
                })
                .FirstOrDefaultAsync();
            
            if (application == null)
                return NotFound();
            
            return Ok(application);
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetCount()
        {
            var count = await _context.Applications.CountAsync(a => a.IsActive);
            return Ok(new { count });
        }

        [HttpGet("status/{status}")]
        public async Task<IActionResult> GetByStatus(string status)
        {
            var applications = await _context.Applications
                .Where(a => a.ApplicationStatus == status && a.IsActive)
                .Select(a => new {
                    a.ApplicationId,
                    a.ApplicationNumber,
                    a.RequestedAmount,
                    a.ApplicationStatus,
                    a.SubmissionDate,
                    CustomerName = a.Customer.FirstName + " " + a.Customer.LastName
                })
                .Take(10)
                .ToListAsync();
            
            return Ok(applications);
        }
    }
}