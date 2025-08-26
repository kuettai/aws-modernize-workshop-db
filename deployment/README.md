# AWS Database Modernization Workshop - Deployment Scripts

## 📁 Deployment Files Overview

### 🚀 Main Deployment Scripts

#### `fresh-ec2-deployment.ps1` - **Primary Deployment Script**
Complete workshop environment setup for fresh EC2 instances.
- Configures SQL Server with SA authentication
- Installs .NET 9.0 SDK and ASP.NET Core hosting
- Deploys database schema and sample data
- Builds and deploys .NET application
- Configures IIS and security settings
- **Usage**: `.\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"`

#### `deploy-complete-workshop.ps1` - **Alternative Complete Setup**
Comprehensive workshop deployment with enhanced logging.
- Similar functionality to fresh-ec2-deployment.ps1
- More detailed logging and progress reporting
- **Usage**: `.\deploy-complete-workshop.ps1`

### 🔧 Supporting Scripts

#### `deploy-application.ps1` - **Application-Only Deployment**
Deploys just the .NET application (assumes database already exists).
- Builds and publishes .NET 9.0 application
- Updates connection strings
- Configures IIS
- **Usage**: `.\deploy-application.ps1 -Environment Production -ConnectionString "..."`

#### `install-dotnet9-sdk.ps1` - **Prerequisites Installation**
Installs .NET 9.0 SDK and runtime components.
- Downloads and installs .NET 9.0 SDK
- Installs ASP.NET Core hosting bundle
- **Usage**: `.\install-dotnet9-sdk.ps1`

#### `quick-git-setup.ps1` - **Repository Setup**
Installs Git and clones workshop repository.
- Installs Chocolatey and Git
- Clones workshop repository to C:\Workshop
- **Usage**: `.\quick-git-setup.ps1 -GitRepo "https://github.com/..."`

### 🗄️ Database Scripts (Root Directory)

#### `database-schema.sql` - **Database Schema Creation**
Creates the complete database structure:
- 10 tables (Applications, Customers, Loans, Payments, etc.)
- Primary keys, foreign keys, and constraints
- Indexes for performance
- **Usage**: Referenced by deployment scripts

#### `stored-procedures-simple.sql` - **Simple Stored Procedures**
Creates 3 basic stored procedures:
- `sp_GetApplicationsByStatus` - Filter applications by status
- `sp_GetCustomerLoanHistory` - Customer loan history
- `sp_UpdateApplicationStatus` - Update application status with audit

#### `stored-procedure-complex.sql` - **Complex Stored Procedure**
Creates advanced stored procedure for workshop:
- `sp_ComprehensiveLoanEligibilityAssessment` - 200+ lines
- Features: CTEs, Window functions, Cursors, Dynamic SQL, Error handling
- Demonstrates migration complexity challenges

#### `sample-data-generation.sql` - **Sample Data Population**
Generates realistic test data:
- 1,000 customers
- 5,000+ applications
- 50,000+ payment records
- 149,000+ integration logs
- Prevents duplicate key errors with existence checks

#### `data-validation-queries.sql` - **Validation Scripts**
Queries to validate data integrity and migration success:
- Row count comparisons
- Data integrity checks
- Performance validation queries

### 📚 Documentation

#### `ARCHITECTURE.md` - **Complete System Documentation**
Comprehensive documentation including:
- System architecture overview
- Database design and relationships
- Migration strategy and phases
- API endpoints and functionality

## 🎯 Recommended Deployment Flow

### For Fresh EC2 Instance (Complete Setup):
```powershell
# Step 1: Run prerequisite setup FIRST (as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yourusername/repo/main/deployment/00-prerequisite-setup.ps1" -OutFile "prerequisite-setup.ps1"
.\prerequisite-setup.ps1

# Step 2: Clone your workshop repository
cd C:\Workshop
git clone https://github.com/yourusername/your-repo.git .

# Step 3: Run main deployment
.\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

### Alternative (Manual Steps):
```powershell
# If you already have the files locally:
.\deployment\00-prerequisite-setup.ps1
# Then copy workshop files to C:\Workshop
.\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

### Manual Database Setup (if needed):
```powershell
# 1. Create database and schema
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -InputFile "database-schema.sql"

# 2. Create stored procedures
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -InputFile "stored-procedures-simple.sql"
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -InputFile "stored-procedure-complex.sql"

# 3. Generate sample data
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -InputFile "sample-data-generation.sql" -QueryTimeout 1800

# 4. Validate data
Invoke-Sqlcmd -ServerInstance "localhost" -Username "sa" -Password "WorkshopDB123!" -Database "LoanApplicationDB" -InputFile "data-validation-queries.sql"
```

### For Existing Environment:
```powershell
# Deploy only the application
.\deployment\deploy-application.ps1 -Environment Production -ConnectionString "Server=localhost;Database=LoanApplicationDB;User Id=sa;Password=WorkshopDB123!;Encrypt=false;TrustServerCertificate=true;"
```

## ✅ Post-Deployment Verification

After running deployment scripts, verify:
- **Application**: http://localhost (shows loan application homepage)
- **Documentation**: http://localhost/docs (interactive architecture docs)
- **APIs**: http://localhost/api/applications/count (returns JSON data)
- **Database**: SQL Server accessible with SA account

## 🚨 Prerequisites

- **OS**: Windows Server 2022 with SQL Server 2022 Web Edition
- **Access**: Administrator privileges via RDP
- **Network**: Internet connectivity for package downloads
- **AWS**: Configured AWS CLI (for cloud deployment phases)

## 📊 Expected Results

After successful deployment:
- ✅ SQL Server 2022 configured with SA authentication
- ✅ .NET 9.0 application running on IIS
- ✅ Database with 200K+ sample records
- ✅ Interactive documentation system
- ✅ All API endpoints functional
- ✅ Ready for 3-phase migration workshop

Total deployment time: ~15-20 minutes on fresh EC2 instance.