using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Application
    {
        public int ApplicationId { get; set; }
        
        [Required]
        [StringLength(20)]
        public string ApplicationNumber { get; set; } = string.Empty;
        
        [Required]
        public int CustomerId { get; set; }
        
        [Required]
        public int LoanOfficerId { get; set; }
        
        [Required]
        public int BranchId { get; set; }
        
        [Required]
        [Range(1000, 1000000)]
        public decimal RequestedAmount { get; set; }
        
        [Required]
        [StringLength(100)]
        public string LoanPurpose { get; set; } = string.Empty;
        
        [Required]
        public string ApplicationStatus { get; set; } = "Submitted";
        
        public DateTime SubmissionDate { get; set; } = DateTime.Now;
        
        public DateTime? ReviewDate { get; set; }
        
        public DateTime? DecisionDate { get; set; }
        
        public string? DecisionReason { get; set; }
        
        [Range(0, 100)]
        public decimal? DSRRatio { get; set; }
        
        [Range(300, 850)]
        public int? CreditScore { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual Customer Customer { get; set; } = null!;
        public virtual LoanOfficer LoanOfficer { get; set; } = null!;
        public virtual Branch Branch { get; set; } = null!;
        public virtual Loan? Loan { get; set; }
        public virtual ICollection<Document> Documents { get; set; } = new List<Document>();
        public virtual ICollection<CreditCheck> CreditChecks { get; set; } = new List<CreditCheck>();
        public virtual ICollection<IntegrationLog> IntegrationLogs { get; set; } = new List<IntegrationLog>();
    }
}