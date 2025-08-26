# 🚀 Quick Start Guide - EC2 Workshop Setup

## Step-by-Step Setup for Fresh EC2 Instance

### **Step 1: Launch EC2 Instance**
- **AMI**: Windows Server 2022 with SQL Server 2022 Web Edition
- **Instance Type**: `t3.large` (minimum)
- **Security Group**: Allow RDP (3389), HTTP (80), SQL Server (1433)
- **Key Pair**: Your existing key pair for RDP access

### **Step 2: Connect via RDP**
- Get public IP from EC2 console
- Connect using Remote Desktop
- Username: `Administrator`
- Use your key pair for authentication

### **Step 3: Run Prerequisite Setup**

Open **PowerShell as Administrator** and run:

```powershell
# Download and run prerequisite setup
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yourusername/your-repo/main/deployment/00-prerequisite-setup.ps1" -OutFile "prerequisite-setup.ps1"
.\prerequisite-setup.ps1
```

**What this does:**
- ✅ Installs Chocolatey package manager
- ✅ Installs Git
- ✅ Creates `C:\Workshop` directory
- ✅ Configures SQL Server SA authentication
- ✅ Sets up PowerShell execution policy

### **Step 4: Clone Workshop Repository**

```powershell
# Navigate to workshop directory
cd C:\Workshop

# Clone your repository (replace with your actual repo URL)
git clone https://github.com/yourusername/aws-database-modernization-workshop.git .
```

### **Step 5: Run Complete Deployment**

```powershell
# Deploy the complete workshop environment (handles everything)
.\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

**What this does:**
- ✅ Installs .NET 9.0 SDK and ASP.NET Core hosting
- ✅ Deploys database schema (16 tables)
- ✅ Generates 200K+ sample records
- ✅ Builds and deploys .NET application
- ✅ Configures IIS web server
- ✅ Sets up firewall rules

### **Step 6: Verify Setup**

After deployment completes, test these URLs:
- **Homepage**: http://localhost
- **API Test**: http://localhost/api/applications/count
- **Documentation**: http://localhost/docs

## ⏱️ **Timeline**
- **EC2 Launch**: 5 minutes
- **RDP Connection**: 2 minutes
- **Prerequisite Setup**: 5 minutes
- **Repository Clone**: 2 minutes
- **Main Deployment**: 15-20 minutes
- **Total**: ~30 minutes

## 🚨 **Alternative: Local Files Setup**

### If You Have Workshop Files Locally:
```powershell
# Step 1: Run prerequisites
.\deployment\00-prerequisite-setup.ps1

# Step 2: Copy files to C:\Workshop
# (via RDP file transfer or USB)

# Step 3: Run deployment with local files
.\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!" -GitRepo "local"
```

## 🔧 **Troubleshooting**

### Common Issues:
- **PowerShell Execution Policy**: Run as Administrator
- **SQL Server Connection**: Check if SQL Server service is running
- **Internet Connectivity**: Required for package downloads
- **Firewall**: May need to allow PowerShell/Git through Windows Firewall

### Manual SQL Server Setup (if needed):
```sql
-- Run in SQL Server Management Studio
USE master;
ALTER LOGIN sa ENABLE;
ALTER LOGIN sa WITH PASSWORD = 'WorkshopDB123!';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
-- Then restart SQL Server service
```

## ✅ **Success Indicators**

You'll know setup is complete when:
- ✅ http://localhost shows the loan application homepage
- ✅ SQL Server accepts SA login with password "WorkshopDB123!"
- ✅ Database contains 200K+ sample records
- ✅ All API endpoints return JSON data

## 🎯 **Ready for Workshop!**

Once setup is complete, you're ready to begin:
- **Phase 1**: SQL Server → AWS RDS migration
- **Phase 2**: RDS → Aurora PostgreSQL migration  
- **Phase 3**: PostgreSQL + DynamoDB hybrid architecture

**Need help?** Check the troubleshooting section or run individual deployment components manually.