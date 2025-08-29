using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using LoanApplication.Configuration;
using LoanApplication.Services;

namespace LoanApplication.Extensions
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddDynamoDbServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.Configure<DynamoDbConfiguration>(configuration.GetSection(DynamoDbConfiguration.SectionName));
            
            var dynamoConfig = configuration.GetSection(DynamoDbConfiguration.SectionName).Get<DynamoDbConfiguration>() ?? new DynamoDbConfiguration();
            
            if (dynamoConfig.UseLocalDynamoDB)
            {
                services.AddSingleton<IAmazonDynamoDB>(provider =>
                {
                    var clientConfig = new AmazonDynamoDBConfig
                    {
                        ServiceURL = dynamoConfig.LocalDynamoDBUrl
                    };
                    return new AmazonDynamoDBClient(clientConfig);
                });
            }
            else
            {
                services.AddDefaultAWSOptions(configuration.GetAWSOptions());
                services.AddAWSService<IAmazonDynamoDB>();
            }
            
            services.AddSingleton<DynamoDBContext>(provider =>
            {
                var client = provider.GetRequiredService<IAmazonDynamoDB>();
                var contextConfig = new DynamoDBContextConfig
                {
                    TableNamePrefix = string.Empty
                };
                return new DynamoDBContext(client, contextConfig);
            });
            
            services.AddScoped<IDynamoDbLogService, DynamoDbLogService>();
            
            return services;
        }
        
        public static IServiceCollection AddHybridLoggingServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddDynamoDbServices(configuration);
            services.Configure<HybridLogConfiguration>(configuration.GetSection(HybridLogConfiguration.SectionName));
            services.AddScoped<IHybridLogService, HybridLogService>();
            return services;
        }
    }
}