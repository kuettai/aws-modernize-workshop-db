using Microsoft.EntityFrameworkCore;

namespace LoanApplication.Data
{
    public class ApplicationDbContextFactory
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ApplicationDbContextFactory> _logger;

        public ApplicationDbContextFactory(IConfiguration configuration, ILogger<ApplicationDbContextFactory> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public LoanApplicationContext CreateWriteContext()
        {
            var connectionString = _configuration.GetConnectionString("DefaultConnection");
            var optionsBuilder = new DbContextOptionsBuilder<LoanApplicationContext>();
            optionsBuilder.UseNpgsql(connectionString);
            
            _logger.LogDebug("Created write context with primary connection");
            return new LoanApplicationContext(optionsBuilder.Options);
        }

        public LoanApplicationContext CreateReadContext()
        {
            var enableReadReplica = _configuration.GetValue<bool>("DatabaseSettings:EnableReadReplica");
            var connectionString = enableReadReplica 
                ? _configuration.GetConnectionString("ReadOnlyConnection")
                : _configuration.GetConnectionString("DefaultConnection");

            var optionsBuilder = new DbContextOptionsBuilder<LoanApplicationContext>();
            optionsBuilder.UseNpgsql(connectionString);
            
            _logger.LogDebug("Created read context using {ConnectionType}", 
                enableReadReplica ? "read replica" : "primary connection");
            
            return new LoanApplicationContext(optionsBuilder.Options);
        }
    }
}