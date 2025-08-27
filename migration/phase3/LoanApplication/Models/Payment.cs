using Amazon.DynamoDBv2.DataModel;

namespace LoanApplication.Models
{
    [DynamoDBTable("LoanApp-Payments-dev")]
    public class DynamoDbPayment
    {
        [DynamoDBHashKey("CustomerId")]
        public int CustomerId { get; set; }
        
        [DynamoDBRangeKey("PaymentDateId")]
        public string PaymentDateId { get; set; } = string.Empty;
        
        [DynamoDBProperty("PaymentId")]
        public int PaymentId { get; set; }
        
        [DynamoDBProperty("LoanId")]
        public int LoanId { get; set; }
        
        [DynamoDBProperty("PaymentAmount")]
        public decimal PaymentAmount { get; set; }
        
        [DynamoDBProperty("PaymentDate")]
        public DateTime PaymentDate { get; set; }
        
        [DynamoDBProperty("PaymentMethod")]
        public string PaymentMethod { get; set; } = string.Empty;
        
        [DynamoDBProperty("PaymentStatus")]
        public string PaymentStatus { get; set; } = string.Empty;
        
        [DynamoDBProperty("TransactionReference")]
        public string? TransactionReference { get; set; }
        
        [DynamoDBProperty("ProcessedDate")]
        public DateTime? ProcessedDate { get; set; }
        
        [DynamoDBProperty("CreatedDate")]
        public DateTime CreatedDate { get; set; }
        
        [DynamoDBProperty("UpdatedDate")]
        public DateTime? UpdatedDate { get; set; }
        
        [DynamoDBProperty("TTL")]
        public long TTL { get; set; }
    }
}