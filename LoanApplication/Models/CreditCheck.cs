using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class CreditCheck
    {
        public int CreditCheckId { get; set; }
        
        [Required]
        public int CustomerId { get; set; }
        
        public int? ApplicationId { get; set; }
        
        [Required]
        public string CreditBureau { get; set; } = string.Empty;
        
        [Required]
        [Range(300, 850)]
        public int CreditScore { get; set; }
        
        public string? CreditReportData { get; set; }
        
        public DateTime CheckDate { get; set; } = DateTime.Now;
        
        [Required]
        public DateTime ExpiryDate { get; set; }
        
        [Required]
        public string RequestId { get; set; } = string.Empty;
        
        public string? ResponseCode { get; set; }
        
        public bool IsSuccessful { get; set; } = true;
        
        public string? ErrorMessage { get; set; }
        
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual Customer Customer { get; set; } = null!;
        public virtual Application? Application { get; set; }
    }
}