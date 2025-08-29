using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Npgsql;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;

namespace PaymentMigration
{
    public class PaymentMigrationValidator
    {
        private readonly string _pgConnectionString;
        private readonly IAmazonDynamoDB _dynamoClient;
        private readonly ILogger<PaymentMigrationValidator> _logger;

        public PaymentMigrationValidator(string pgConnectionString, IAmazonDynamoDB dynamoClient, ILogger<PaymentMigrationValidator> logger)
        {
            _pgConnectionString = pgConnectionString;
            _dynamoClient = dynamoClient;
            _logger = logger;
        }

        public async Task<ValidationResult> ValidateSourceDataAsync()
        {
            var result = new ValidationResult();
            
            using var connection = new NpgsqlConnection(_pgConnectionString);
            await connection.OpenAsync();

            var validationQueries = new Dictionary<string, string>
            {
                ["TotalPayments"] = "SELECT COUNT(*) FROM payments",
                ["PaymentsWithNullCustomerId"] = "SELECT COUNT(*) FROM payments WHERE customerid IS NULL",
                ["PaymentsWithNullAmount"] = "SELECT COUNT(*) FROM payments WHERE paymentamount IS NULL",
                ["PaymentsWithInvalidDates"] = "SELECT COUNT(*) FROM payments WHERE paymentdate IS NULL OR paymentdate > NOW()",
                ["DuplicatePaymentIds"] = "SELECT COUNT(*) - COUNT(DISTINCT paymentid) FROM payments"
            };

            foreach (var query in validationQueries)
            {
                try
                {
                    using var command = new NpgsqlCommand(query.Value, connection);
                    var queryResult = await command.ExecuteScalarAsync();
                    result.ValidationResults[query.Key] = queryResult?.ToString() ?? "NULL";
                    _logger.LogInformation("✅ {QueryName}: {Result}", query.Key, queryResult);
                }
                catch (Exception ex)
                {
                    result.Errors.Add($"Validation query {query.Key} failed: {ex.Message}");
                    _logger.LogError("❌ {QueryName} failed: {Error}", query.Key, ex.Message);
                }
            }

            // Validate data quality
            if (int.Parse(result.ValidationResults["PaymentsWithNullCustomerId"]) > 0)
                result.Errors.Add("Found payments with NULL CustomerId");
            
            if (int.Parse(result.ValidationResults["PaymentsWithNullAmount"]) > 0)
                result.Errors.Add("Found payments with NULL PaymentAmount");

            if (int.Parse(result.ValidationResults["DuplicatePaymentIds"]) > 0)
                result.Errors.Add("Found duplicate PaymentIds");

            result.IsValid = result.Errors.Count == 0;
            return result;
        }

        public async Task<bool> ValidateDynamoTableAsync()
        {
            try
            {
                var response = await _dynamoClient.DescribeTableAsync("Payments");
                var table = response.Table;

                if (table.TableStatus != TableStatus.ACTIVE)
                {
                    _logger.LogError("❌ DynamoDB table is not ACTIVE. Status: {Status}", table.TableStatus);
                    return false;
                }

                var requiredIndexes = new[] { "PaymentStatusIndex", "LoanPaymentIndex", "PaymentMethodIndex" };
                foreach (var indexName in requiredIndexes)
                {
                    var gsi = table.GlobalSecondaryIndexes.FirstOrDefault(g => g.IndexName == indexName);
                    if (gsi == null || gsi.IndexStatus != IndexStatus.ACTIVE)
                    {
                        _logger.LogError("❌ Required GSI {IndexName} is missing or not ACTIVE", indexName);
                        return false;
                    }
                }

                _logger.LogInformation("✅ DynamoDB table validation successful");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError("❌ DynamoDB table validation failed: {Error}", ex.Message);
                return false;
            }
        }
    }

    public class ValidationResult
    {
        public bool IsValid { get; set; }
        public Dictionary<string, string> ValidationResults { get; set; } = new();
        public List<string> Errors { get; set; } = new();
    }
}