using Microsoft.AspNetCore.Mvc;
using LoanApplication.Repositories;

namespace LoanApplication.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ApplicationsController : ControllerBase
    {
        private readonly IApplicationRepository _applicationRepository;

        public ApplicationsController(IApplicationRepository applicationRepository)
        {
            _applicationRepository = applicationRepository;
        }

        [HttpGet]
        public async Task<IActionResult> GetApplications()
        {
            var applications = await _applicationRepository.GetAllApplicationsAsync();
            return Ok(applications.Take(10)); // Return first 10 for demo
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetApplication(int id)
        {
            var application = await _applicationRepository.GetApplicationByIdAsync(id);
            if (application == null)
                return NotFound();
            
            return Ok(application);
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetCount()
        {
            var count = await _applicationRepository.GetApplicationCountAsync();
            return Ok(new { count });
        }

        [HttpGet("status/{status}")]
        public async Task<IActionResult> GetByStatus(string status)
        {
            var applications = await _applicationRepository.GetApplicationsByStatusAsync(status);
            return Ok(applications.Take(10));
        }
    }
}