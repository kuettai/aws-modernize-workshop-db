using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Customer
    {
        public int CustomerId { get; set; }
        
        [Required]
        [StringLength(20)]
        public string CustomerNumber { get; set; } = string.Empty;
        
        [Required]
        [StringLength(50)]
        public string FirstName { get; set; } = string.Empty;
        
        [Required]
        [StringLength(50)]
        public string LastName { get; set; } = string.Empty;
        
        [Required]
        public DateTime DateOfBirth { get; set; }
        
        [Required]
        [StringLength(11)]
        public string SSN { get; set; } = string.Empty;
        
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;
        
        [Required]
        [Phone]
        public string Phone { get; set; } = string.Empty;
        
        [Required]
        public string Address { get; set; } = string.Empty;
        
        [Required]
        public string City { get; set; } = string.Empty;
        
        [Required]
        public string State { get; set; } = string.Empty;
        
        [Required]
        public string ZipCode { get; set; } = string.Empty;
        
        [Required]
        [Range(0, double.MaxValue)]
        public decimal MonthlyIncome { get; set; }
        
        [Required]
        public string EmploymentStatus { get; set; } = string.Empty;
        
        public string? EmployerName { get; set; }
        
        public int? YearsEmployed { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual ICollection<Application> Applications { get; set; } = new List<Application>();
        public virtual ICollection<CreditCheck> CreditChecks { get; set; } = new List<CreditCheck>();
    }
}