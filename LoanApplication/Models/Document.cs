using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class Document
    {
        public int DocumentId { get; set; }
        
        [Required]
        public int ApplicationId { get; set; }
        
        [Required]
        public string DocumentType { get; set; } = string.Empty;
        
        [Required]
        public string DocumentName { get; set; } = string.Empty;
        
        [Required]
        public string FilePath { get; set; } = string.Empty;
        
        [Required]
        public long FileSize { get; set; }
        
        [Required]
        public string ContentType { get; set; } = string.Empty;
        
        [Required]
        public string UploadedBy { get; set; } = string.Empty;
        
        public DateTime UploadDate { get; set; } = DateTime.Now;
        
        public bool IsVerified { get; set; } = false;
        
        public string? VerifiedBy { get; set; }
        
        public DateTime? VerificationDate { get; set; }
        
        // Navigation properties
        public virtual Application Application { get; set; } = null!;
    }
}