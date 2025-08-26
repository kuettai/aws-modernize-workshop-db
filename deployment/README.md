# AWS Database Modernization Workshop - Deployment Scripts

## 📁 Deployment Files Overview

### 🚀 Main Deployment Scripts

#### `simple-deployment.ps1` - **Primary Deployment Script**
Complete workshop environment setup for fresh EC2 instances.
- Configures SQL Server with SA authentication
- Installs prerequisites (.NET 9.0 SDK, Git, Chocolatey)
- Clones repository and deploys database schema
- Builds and deploys .NET application
- Configures IIS and security settings
- **Usage**: `.\simple-deployment.ps1 -SQLPassword "WorkshopDB123!"`

#### `00-prerequisite-setup.ps1` - **PowerShell Policy Only**
Sets PowerShell execution policy only (rarely needed).
- PowerShell execution policy to RemoteSigned
- **Usage**: `.\00-prerequisite-setup.ps1`
- **Note**: Only use if PowerShell policy prevents running simple-deployment.ps1

### 🗄️ Database Scripts (Root Directory)

#### `database-schema.sql` - **Database Schema Creation**
Creates the complete database structure:
- 16 tables (Applications, Customers, Loans, Payments, etc.)
- Primary keys, foreign keys, and constraints
- Indexes for performance

#### `stored-procedures-simple.sql` - **Simple Stored Procedures**
Creates 3 basic stored procedures:
- `sp_GetApplicationsByStatus` - Filter applications by status
- `sp_GetCustomerLoanHistory` - Customer loan history
- `sp_UpdateApplicationStatus` - Update application status with audit

#### `stored-procedure-complex.sql` - **Complex Stored Procedure**
Creates advanced stored procedure:
- `sp_ComprehensiveLoanEligibilityAssessment` - 200+ lines
- Features: CTEs, Window functions, Cursors, Dynamic SQL, Error handling

#### `sample-data-generation.sql` - **Sample Data Population**
Generates realistic test data:
- 1,000 customers
- 5,000+ applications
- 50,000+ payment records
- 149,000+ integration logs

## 🎯 Recommended Deployment Flow

### For Fresh EC2 Instance (Complete Setup):
```powershell
# Single command deployment (recommended)
.\deployment\simple-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

### If PowerShell Policy Issues:
```powershell
# Step 1: Fix PowerShell policy (if needed)
.\deployment\00-prerequisite-setup.ps1

# Step 2: Run complete deployment
.\deployment\simple-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

## ✅ Post-Deployment Verification

After running deployment scripts, verify:
- **Application**: http://localhost (shows loan application homepage)
- **APIs**: http://localhost/api/applications/count (returns JSON data)
- **Database**: SQL Server accessible with SA account

## 🚨 Prerequisites

- **OS**: Windows Server 2022 with SQL Server 2022 Web Edition
- **Access**: Administrator privileges via RDP
- **Network**: Internet connectivity for package downloads

## 📊 Expected Results

After successful deployment:
- ✅ SQL Server 2022 configured with SA authentication
- ✅ .NET 9.0 application running on IIS
- ✅ Database with 200K+ sample records
- ✅ All API endpoints functional
- ✅ Ready for 3-phase migration workshop

Total deployment time: ~15-20 minutes on fresh EC2 instance.