# Final Application Changes: Switch from MSSQL to Aurora PostgreSQL
## Phase 2: Database Engine Migration - Complete Student Guide

### 🎯 **Objective**
Switch your .NET application from local MSSQL Server to Aurora PostgreSQL after completing SCT schema conversion and DMS data migration.

---

## 🎓 **Student Guide: Switch from MSSQL to Aurora PostgreSQL**

### **Step 1: Update NuGet Packages**
```powershell
cd LoanApplication

# Remove SQL Server package
dotnet remove package Microsoft.EntityFrameworkCore.SqlServer

# Add PostgreSQL package
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.0.0
```

### **Step 2: Update Program.cs**
Find this line:
```csharp
options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"))
```

Change to:
```csharp
options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
```

### **Step 3: Update ApplicationDbContextFactory.cs**
**3a. Add missing using statements at top:**
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
```

**3b. Change both `UseSqlServer` calls to `UseNpgsql`:**
```csharp
// Find these two lines and change both:
optionsBuilder.UseSqlServer(connectionString);
// To:
optionsBuilder.UseNpgsql(connectionString);
```

### **Step 4: Update Connection String in appsettings.json**
**4a. Find your Aurora PostgreSQL endpoint in AWS Console**
- Go to AWS Console → RDS → Databases
- Click your Aurora cluster
- Copy the endpoint from "Connectivity & security"

**4b. Update connection string:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=your-aurora-endpoint;Database=postgres;Username=postgres;Password=WorkshopDB123!;SslMode=Require"
  }
}
```

**Important Notes:**
- Use `Database=postgres` (the actual database name)
- Use `SslMode=Require` (no spaces)
- Remove `Trust Server Certificate=true` (not needed for Aurora)

### **Step 5: Set Database Schema**
Open `LoanApplication/Data/LoanApplicationContext.cs` and add to `OnModelCreating`:
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.HasDefaultSchema("dbo");  // or "loanapplicationdb" - use whichever contains your tables
    
    // ... rest of existing code
}
```

### **Step 6: Fix JSON Formatting**
Ensure proper indentation (2 spaces) for all JSON sections in appsettings.json.

**Common JSON issues:**
- Use spaces, not tabs for indentation
- Ensure all sections have proper 2-space indentation
- Check for missing commas between sections

### **Step 7: Test Connection**
```powershell
# Stop any running app first (Ctrl+C)
dotnet build
dotnet run

# Test in browser
# http://localhost:5000 - should work
# http://localhost:5000/api/applications - should show data
```

---

## 🔍 **Common Issues & Solutions**

### **Build Errors**
- **Issue**: File locked errors during build
- **Solution**: Stop running app before building (Ctrl+C)

### **JSON Parse Errors**
- **Issue**: "Unable to parse JSON"
- **Solution**: Check indentation (use spaces, not tabs), verify comma placement

### **Database Connection Errors**
- **Issue**: Database "loanapplicationdb" does not exist
- **Solution**: Use `Database=postgres` in connection string

### **Schema Issues**
- **Issue**: Tables not found
- **Solution**: Add `modelBuilder.HasDefaultSchema("dbo")` in LoanApplicationContext

### **Data Type Errors**
- **Issue**: DateTime casting errors
- **Solution**: May need to fix column types in PostgreSQL after SCT/DMS migration

### **SSL Connection Issues**
- **Issue**: SSL/TLS connection failures
- **Solution**: Use `SslMode=Require` (correct format) or `SslMode=Disable` for testing

---

## 📋 **Verification Checklist**

✅ **NuGet packages updated** (removed SqlServer, added PostgreSQL)  
✅ **Program.cs updated** (UseNpgsql instead of UseSqlServer)  
✅ **ApplicationDbContextFactory.cs updated** (both locations)  
✅ **Connection string updated** (Aurora endpoint, correct database name)  
✅ **Schema configured** (HasDefaultSchema in context)  
✅ **JSON formatting correct** (proper indentation)  
✅ **Application builds successfully**  
✅ **Application runs and connects to Aurora PostgreSQL**  
✅ **API endpoints return data** (/api/applications works)  

---

## 🎯 **Expected Result**
Your .NET application now:
- Connects to Aurora PostgreSQL instead of local MSSQL Server
- Uses all migrated data from SCT/DMS process
- Maintains full functionality with PostgreSQL backend
- Ready for Phase 3 (DynamoDB hybrid architecture)

---

## 💡 **Next Steps**
After completing these changes, your application is ready for:
- Phase 3: DynamoDB integration for logging data
- Dual-write pattern implementation
- Complete database modernization workflow

**🎉 Congratulations!** You've successfully migrated from MSSQL Server to Aurora PostgreSQL!