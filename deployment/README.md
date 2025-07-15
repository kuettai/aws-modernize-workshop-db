# Loan Application System - Deployment Guide

This directory contains deployment scripts and configurations for the Loan Application System used in the AWS Database Modernization Workshop.

## Deployment Options

### 1. Traditional Server Deployment

#### Database Deployment (PowerShell)
```powershell
# Deploy database with sample data
.\deploy-database.ps1 -ServerName "localhost" -GenerateSampleData

# Deploy to specific server with credentials
.\deploy-database.ps1 -ServerName "prod-server" -Username "sa" -Password "YourPassword" -DatabaseName "LoanApplicationDB"

# Deploy without validation (faster)
.\deploy-database.ps1 -ServerName "localhost" -SkipValidation
```

#### Application Deployment (Windows PowerShell)
```powershell
# Deploy to development environment
.\deploy-application.ps1 -Environment Development

# Deploy to production with IIS configuration
.\deploy-application.ps1 -Environment Production -ConnectionString "Server=prod-db;Database=LoanApplicationDB;..." -Port 80

# Quick deployment (skip build and tests)
.\deploy-application.ps1 -SkipBuild -SkipTests

# Using batch file wrapper
.\deploy-windows.bat prod
.\deploy-windows.bat dev
```

### 2. Docker Deployment

#### Quick Start
```bash
# Start all services (SQL Server + Application + Redis)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

#### Database Setup in Docker
```bash
# After containers are running, initialize the database
docker exec -it loanapp-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'LoanApp123!' -i /docker-entrypoint-initdb.d/01-init-database.sql

# Apply full schema (copy schema file to container first)
docker cp ../database-schema.sql loanapp-sqlserver:/tmp/
docker exec -it loanapp-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'LoanApp123!' -i /tmp/database-schema.sql
```

## Configuration

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Development, Staging, Production
- `ConnectionStrings__DefaultConnection`: Database connection string
- `LoanSettings__MaxDSRRatio`: Maximum debt service ratio (default: 40.0)
- `CreditCheckSettings__MockMode`: Enable mock credit checks (default: true for Development)

### Connection Strings
- **Local Development**: `Server=localhost;Database=LoanApplicationDB;Trusted_Connection=true;`
- **Docker**: `Server=sqlserver,1433;Database=LoanApplicationDB;User Id=sa;Password=LoanApp123!;TrustServerCertificate=true;`
- **Production**: Use secure credentials and encrypted connections

## File Structure

```
deployment/
├── deploy-database.ps1          # PowerShell database deployment script
├── deploy-application.sh        # Bash application deployment script
├── docker-compose.yml           # Docker Compose configuration
├── Dockerfile                   # Application container definition
├── init-scripts/
│   └── 01-init-database.sql    # Database initialization for Docker
├── loanapplication.service      # Systemd service file (generated)
├── start-application.sh         # Application startup script (generated)
├── install.sh                   # Installation script (generated)
└── README.md                    # This file
```

## Workshop Usage

### Phase 1: Initial Deployment
1. Deploy SQL Server database locally
2. Generate sample data for testing
3. Deploy .NET application
4. Verify functionality

### Phase 2: Migration to AWS RDS
1. Create RDS SQL Server instance
2. Migrate database using deployment scripts
3. Update application connection strings
4. Test migrated application

### Phase 3: PostgreSQL Migration
1. Create Aurora PostgreSQL cluster
2. Convert schema and stored procedures
3. Migrate data using AWS DMS
4. Update application for PostgreSQL

### Phase 4: DynamoDB Integration
1. Create DynamoDB table for IntegrationLogs
2. Update application to use DynamoDB SDK
3. Migrate historical log data
4. Test hybrid architecture

## Troubleshooting

### Common Issues

#### Database Connection Failures
- Verify SQL Server is running
- Check connection string format
- Ensure firewall allows connections
- Validate credentials

#### Application Startup Issues
- Check .NET SDK version (6.0 required)
- Verify all NuGet packages restored
- Check application logs
- Validate configuration files

#### Docker Issues
- Ensure Docker daemon is running
- Check container logs: `docker-compose logs [service-name]`
- Verify port availability
- Check resource limits

### Health Checks

#### Database Health
```sql
-- Check database connectivity
SELECT @@VERSION;

-- Verify tables exist
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';

-- Check sample data
SELECT COUNT(*) FROM Applications;
```

#### Application Health
```bash
# Check application status
curl http://localhost:8080/health

# Check systemd service (Linux)
sudo systemctl status loanapplication

# Check application logs
sudo journalctl -u loanapplication -f
```

## Security Considerations

### Production Deployment
- Use strong passwords for database connections
- Enable SSL/TLS for database connections
- Configure firewall rules appropriately
- Use service accounts with minimal permissions
- Enable application logging and monitoring
- Regular security updates

### Docker Security
- Use non-root user in containers
- Scan images for vulnerabilities
- Use secrets management for sensitive data
- Enable container resource limits
- Regular base image updates

## Performance Tuning

### Database Optimization
- Configure appropriate memory settings
- Optimize indexes based on query patterns
- Monitor query performance
- Regular maintenance tasks

### Application Optimization
- Configure connection pooling
- Enable response caching where appropriate
- Monitor memory usage
- Configure logging levels appropriately

## Support

For workshop-specific questions or deployment issues, refer to the workshop documentation or contact the workshop facilitators.