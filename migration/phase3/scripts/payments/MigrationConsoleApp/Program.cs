using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Amazon.DynamoDBv2;

namespace PaymentMigration
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var host = CreateHostBuilder(args).Build();
            
            var logger = host.Services.GetRequiredService<ILogger<Program>>();
            
            try
            {
                if (args.Contains("--validate-only"))
                {
                    await RunValidationAsync(host.Services, logger);
                }
                else if (args.Contains("--migrate"))
                {
                    await RunMigrationAsync(host.Services, logger, args);
                }
                else if (args.Contains("--resume"))
                {
                    await ResumeMigrationAsync(host.Services, logger, args);
                }
                else
                {
                    ShowUsage();
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Migration process failed");
                Environment.Exit(1);
            }
        }

        static async Task RunValidationAsync(IServiceProvider services, ILogger logger)
        {
            logger.LogInformation("=== Payment Migration Validation ===");
            
            var validator = services.GetRequiredService<PaymentMigrationValidator>();
            
            // Validate source data
            logger.LogInformation("Validating source data...");
            var sourceValidation = await validator.ValidateSourceDataAsync();
            
            if (!sourceValidation.IsValid)
            {
                logger.LogError("❌ Source data validation failed:");
                foreach (var error in sourceValidation.Errors)
                {
                    logger.LogError("   {Error}", error);
                }
                Environment.Exit(1);
            }
            
            // Validate DynamoDB table
            logger.LogInformation("Validating DynamoDB table...");
            var tableValid = await validator.ValidateDynamoTableAsync();
            
            if (!tableValid)
            {
                logger.LogError("❌ DynamoDB table validation failed");
                Environment.Exit(1);
            }
            
            logger.LogInformation("🎉 All validations passed! Ready for migration.");
        }

        static async Task RunMigrationAsync(IServiceProvider services, ILogger logger, string[] args)
        {
            logger.LogInformation("=== Starting Payment Migration ===");
            
            var migrator = services.GetRequiredService<PaymentBatchMigrator>();
            
            var options = new MigrationOptions
            {
                StartDate = GetDateArg(args, "--start-date", DateTime.Parse("2020-01-01")),
                EndDate = GetDateArg(args, "--end-date", DateTime.UtcNow),
                MaxErrors = GetIntArg(args, "--max-errors", 100)
            };
            
            logger.LogInformation("Migration Parameters:");
            logger.LogInformation("  Start Date: {StartDate:yyyy-MM-dd}", options.StartDate);
            logger.LogInformation("  End Date: {EndDate:yyyy-MM-dd}", options.EndDate);
            logger.LogInformation("  Migration ID: {MigrationId}", options.MigrationId);
            
            var result = await migrator.MigratePaymentsAsync(options);
            
            if (result.Success)
            {
                logger.LogInformation("🎉 Migration completed successfully!");
                logger.LogInformation("  Processed: {Processed}/{Total} records", result.ProcessedRecords, result.TotalRecords);
                logger.LogInformation("  Duration: {Duration}", result.Duration);
                logger.LogInformation("  Errors: {Errors}", result.ErrorCount);
            }
            else
            {
                logger.LogError("❌ Migration failed: {Error}", result.ErrorMessage);
                Environment.Exit(1);
            }
        }

        static void ShowUsage()
        {
            Console.WriteLine("Payment Migration Tool");
            Console.WriteLine();
            Console.WriteLine("Usage:");
            Console.WriteLine("  dotnet run -- --validate-only");
            Console.WriteLine("  dotnet run -- --migrate [--start-date YYYY-MM-DD] [--end-date YYYY-MM-DD]");
            Console.WriteLine("  dotnet run -- --resume --migration-id <id>");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  dotnet run -- --validate-only");
            Console.WriteLine("  dotnet run -- --migrate --start-date 2023-01-01 --end-date 2023-12-31");
            Console.WriteLine("  dotnet run -- --resume --migration-id migration-20240131-143022");
        }

        static DateTime GetDateArg(string[] args, string argName, DateTime defaultValue)
        {
            var index = Array.IndexOf(args, argName);
            if (index >= 0 && index + 1 < args.Length)
            {
                return DateTime.Parse(args[index + 1]);
            }
            return defaultValue;
        }

        static int GetIntArg(string[] args, string argName, int defaultValue)
        {
            var index = Array.IndexOf(args, argName);
            if (index >= 0 && index + 1 < args.Length)
            {
                return int.Parse(args[index + 1]);
            }
            return defaultValue;
        }

        static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureServices((context, services) =>
                {
                    services.AddAWSService<IAmazonDynamoDB>();
                    services.AddScoped<PaymentBatchMigrator>();
                    services.AddScoped<PaymentMigrationValidator>();
                    services.AddScoped<MigrationStateManager>();
                });
    }
}