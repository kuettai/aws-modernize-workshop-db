using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class LoanOfficer
    {
        public int LoanOfficerId { get; set; }
        
        [Required]
        [StringLength(20)]
        public string EmployeeId { get; set; } = string.Empty;
        
        [Required]
        [StringLength(50)]
        public string FirstName { get; set; } = string.Empty;
        
        [Required]
        [StringLength(50)]
        public string LastName { get; set; } = string.Empty;
        
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;
        
        [Phone]
        public string? Phone { get; set; }
        
        [Required]
        public int BranchId { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        [Required]
        public DateTime HireDate { get; set; }
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual Branch Branch { get; set; } = null!;
        public virtual ICollection<Application> Applications { get; set; } = new List<Application>();
    }
}