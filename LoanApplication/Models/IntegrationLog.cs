using System.ComponentModel.DataAnnotations;

namespace LoanApplication.Models
{
    public class IntegrationLog
    {
        public long LogId { get; set; }
        
        public int? ApplicationId { get; set; }
        
        [Required]
        public string LogType { get; set; } = string.Empty;
        
        [Required]
        public string ServiceName { get; set; } = string.Empty;
        
        public string? RequestData { get; set; }
        
        public string? ResponseData { get; set; }
        
        public string? StatusCode { get; set; }
        
        public bool IsSuccess { get; set; }
        
        public string? ErrorMessage { get; set; }
        
        public int? ProcessingTimeMs { get; set; }
        
        public DateTime LogTimestamp { get; set; } = DateTime.Now;
        
        public string? CorrelationId { get; set; }
        
        public string? UserId { get; set; }
        
        // Navigation properties
        public virtual Application? Application { get; set; }
    }
}