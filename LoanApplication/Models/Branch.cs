using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Branch
    {
        public int BranchId { get; set; }
        
        [Required]
        [StringLength(10)]
        public string BranchCode { get; set; } = string.Empty;
        
        [Required]
        [StringLength(100)]
        public string BranchName { get; set; } = string.Empty;
        
        [Required]
        public string Address { get; set; } = string.Empty;
        
        [Required]
        public string City { get; set; } = string.Empty;
        
        [Required]
        public string State { get; set; } = string.Empty;
        
        [Required]
        public string ZipCode { get; set; } = string.Empty;
        
        public string? Phone { get; set; }
        
        [EmailAddress]
        public string? Email { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual ICollection<LoanOfficer> LoanOfficers { get; set; } = new List<LoanOfficer>();
        public virtual ICollection<Application> Applications { get; set; } = new List<Application>();
    }
}