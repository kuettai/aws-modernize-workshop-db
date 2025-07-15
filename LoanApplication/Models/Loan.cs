using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Loan
    {
        public int LoanId { get; set; }
        
        [Required]
        [StringLength(20)]
        public string LoanNumber { get; set; } = string.Empty;
        
        [Required]
        public int ApplicationId { get; set; }
        
        [Required]
        [Range(1000, 1000000)]
        public decimal ApprovedAmount { get; set; }
        
        [Required]
        [Range(0.01, 0.5)]
        public decimal InterestRate { get; set; }
        
        [Required]
        [Range(12, 360)]
        public int LoanTermMonths { get; set; }
        
        [Required]
        [Range(1, double.MaxValue)]
        public decimal MonthlyPayment { get; set; }
        
        [Required]
        public string LoanStatus { get; set; } = "Active";
        
        public DateTime? DisbursementDate { get; set; }
        
        public DateTime? MaturityDate { get; set; }
        
        [Required]
        [Range(0, double.MaxValue)]
        public decimal OutstandingBalance { get; set; }
        
        public DateTime? NextPaymentDate { get; set; }
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual Application Application { get; set; } = null!;
        public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();
    }
}