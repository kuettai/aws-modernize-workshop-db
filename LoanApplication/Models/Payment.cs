using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Payment
    {
        public int PaymentId { get; set; }
        
        [Required]
        public int LoanId { get; set; }
        
        [Required]
        public int PaymentNumber { get; set; }
        
        [Required]
        public DateTime PaymentDate { get; set; }
        
        [Required]
        [Range(0.01, double.MaxValue)]
        public decimal PaymentAmount { get; set; }
        
        [Required]
        [Range(0, double.MaxValue)]
        public decimal PrincipalAmount { get; set; }
        
        [Required]
        [Range(0, double.MaxValue)]
        public decimal InterestAmount { get; set; }
        
        [Required]
        public string PaymentMethod { get; set; } = string.Empty;
        
        [Required]
        public string PaymentStatus { get; set; } = "Completed";
        
        public string? TransactionId { get; set; }
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual Loan Loan { get; set; } = null!;
    }
}