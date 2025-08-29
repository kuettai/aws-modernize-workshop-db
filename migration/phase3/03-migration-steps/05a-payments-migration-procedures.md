# Payments Migration Procedures
## PostgreSQL to DynamoDB Migration - Step-by-Step Guide

### 🎯 Migration Objectives
- Migrate 500,000+ payment records from PostgreSQL to DynamoDB
- Zero data loss with full integrity validation
- Minimal downtime using dual-write pattern
- Resume capability for interrupted migrations

### 📁 Pre-Created Migration Scripts

All migration scripts have been pre-created in the `migration/phase3/scripts/payments/` folder:

#### **Validation Scripts**
- `PaymentMigrationValidator.cs` - Validates source data integrity and DynamoDB table structure
- `PostMigrationValidator.cs` - Compares data between PostgreSQL and DynamoDB after migration

#### **Migration Engine**
- `PaymentBatchMigrator.cs` - Core migration engine with batch processing and resume capability
- `MigrationStateManager.cs` - Tracks migration progress and handles resume functionality

#### **Monitoring & Control**
- `MigrationConsoleApp/Program.cs` - Command-line interface for running migrations
- `Monitor-PaymentMigration.ps1` - PowerShell script for real-time progress monitoring

#### **Configuration Files**
- `migration-config.json` - Migration parameters and settings
- `appsettings.Migration.json` - Database connections and AWS configuration

### 🚀 Migration Execution Guide

#### **Step 1: Pre-Migration Validation (5 minutes)**

**Purpose**: Ensure source data is clean and DynamoDB table is ready

```powershell
# Run the validation script
cd migration\phase3\scripts\payments\MigrationConsoleApp
dotnet run -- --validate-only

# Expected Results:
# ✅ Total Payments: 500,247
# ✅ No NULL CustomerIds found
# ✅ No NULL PaymentAmounts found
# ✅ No duplicate PaymentIds found
# ✅ DynamoDB table ACTIVE with 3 GSIs
# ✅ All required indexes ACTIVE
```

**What it checks**:
- Data integrity (no nulls, duplicates)
- Date ranges and data quality
- DynamoDB table and GSI status
- IAM permissions

#### **Step 2: Start Migration (2-4 hours)**

**Purpose**: Migrate historical payment data in batches with progress tracking

```powershell
# Start the migration process
dotnet run -- --migrate --start-date "2020-01-01" --end-date "2024-01-31"

# Expected Results:
# Migration ID: migration-20240131-143022
# Total Records: 500,247
# Batch Size: 25 records per batch
# Estimated Duration: 3.2 hours
# Resume capability: ENABLED
```

**What it does**:
- Processes payments in batches of 25 (DynamoDB limit)
- Transforms PostgreSQL data to DynamoDB format
- Saves progress every 100 batches for resume capability
- Handles throttling with exponential backoff

#### **Step 3: Monitor Progress (Continuous)**

**Purpose**: Track migration progress and detect issues early

```powershell
# Open new PowerShell window and run monitor
.\Monitor-PaymentMigration.ps1 -MigrationId "migration-20240131-143022"

# Expected Output:
# [2024-01-31 14:35:22] Status: InProgress | Processed: 125,000 | Errors: 0 | Progress: 25.0%
# [2024-01-31 14:36:22] Status: InProgress | Processed: 128,750 | Errors: 0 | Progress: 25.7%
# [2024-01-31 14:37:22] Status: InProgress | Processed: 132,500 | Errors: 0 | Progress: 26.5%
```

**What it shows**:
- Real-time progress updates
- Error count monitoring
- DynamoDB item count verification
- Performance metrics

#### **Step 4: Handle Interruptions (If Needed)**

**Purpose**: Resume migration if interrupted

```powershell
# If migration stops, resume from last checkpoint
dotnet run -- --resume --migration-id "migration-20240131-143022"

# Expected Results:
# Resuming from offset: 245,000
# Remaining records: 255,247
# Estimated time: 1.8 hours
```

**What it does**:
- Loads last saved state from DynamoDB
- Continues from exact stopping point
- No duplicate data processing

#### **Step 5: Post-Migration Validation (10 minutes)**

**Purpose**: Verify migration completed successfully with data integrity

```powershell
# Run comprehensive validation
dotnet run -- --validate-migration --migration-id "migration-20240131-143022"

# Expected Results:
# ✅ Record Count Match: PostgreSQL: 500,247 | DynamoDB: 500,247
# ✅ Sample Validation: 100/100 records match exactly
# ✅ Query Performance: Average 45ms (Target: <100ms)
# ✅ All GSI Queries: Functional
# ✅ Error Rate: 0.0% (Target: <0.1%)
# 🎉 MIGRATION SUCCESSFUL
```

**What it validates**:
- Exact record count match
- Random sample data comparison
- Query performance benchmarks
- GSI functionality tests

### 📊 Understanding Migration Progress

#### **Progress Indicators**
- **Processed Records**: Number of payments migrated
- **Error Count**: Failed records (should stay at 0)
- **Progress %**: Completion percentage
- **ETA**: Estimated time remaining

#### **Performance Metrics**
- **Batch Duration**: Time per 25-record batch (target: <500ms)
- **Throughput**: Records per second (target: 50-100)
- **DynamoDB Latency**: Write response time (target: <50ms)

#### **Error Scenarios**
- **Throttling**: Script automatically handles with backoff
- **Network Issues**: Automatic retry with exponential delay
- **Data Errors**: Logged for manual review, migration continues

### 🔧 Configuration Options

#### **Migration Parameters** (in `migration-config.json`)
```json
{
  "BatchSize": 25,
  "MaxErrors": 100,
  "RetryAttempts": 3,
  "ThrottleBackoffMs": 1000,
  "ProgressSaveInterval": 100
}
```

#### **Date Range Filtering**
```powershell
# Migrate specific date range
dotnet run -- --migrate --start-date "2023-01-01" --end-date "2023-12-31"

# Migrate recent data only
dotnet run -- --migrate --start-date "2024-01-01"
```

### 🚨 Troubleshooting Common Issues

#### **Issue**: Migration stops with throttling errors
**Solution**: Script handles automatically, but you can reduce batch size:
```powershell
dotnet run -- --migrate --batch-size 10
```

#### **Issue**: High error count
**Solution**: Check logs and run data validation:
```powershell
dotnet run -- --validate-only --detailed-errors
```

#### **Issue**: Performance slower than expected
**Solution**: Check DynamoDB provisioned capacity or switch to on-demand billing

### ✅ Success Criteria

**Migration is successful when**:
- ✅ Record counts match exactly
- ✅ Sample validation passes 100%
- ✅ Error rate < 0.1%
- ✅ Query performance < 100ms average
- ✅ All GSI queries functional

**Ready for next step when**:
- All validation checks pass
- Application can query DynamoDB successfully
- Performance meets requirements

---

### 💡 Q Developer Integration Points

```
1. "Review the migration results and suggest optimizations for query performance and cost efficiency."

2. "Analyze any data discrepancies found during validation and recommend data quality improvements."

3. "Examine the migration performance metrics and suggest scaling optimizations for larger datasets."
```

**Next**: [Enhanced Dual-Write Strategy](./05b-enhanced-dual-write-strategy.md)