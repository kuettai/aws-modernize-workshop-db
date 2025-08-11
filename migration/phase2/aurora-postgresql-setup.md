# Phase 2: Aurora PostgreSQL Setup
## Aurora PostgreSQL Cluster Configuration and Optimization

### 🎯 Setup Objectives
- Create Aurora PostgreSQL cluster with optimal configuration
- Configure security and networking for migration
- Set up parameter groups for performance
- Enable monitoring and backup policies

### 📋 Prerequisites
- Phase 1 completed (RDS SQL Server running)
- AWS CLI configured with appropriate permissions
- VPC and security groups from Phase 1
- Schema conversion assessment completed

### 🚀 Aurora PostgreSQL Cluster Creation

#### Method 1: AWS CLI (Recommended)
```bash
# Create Aurora PostgreSQL cluster
aws rds create-db-cluster \
    --db-cluster-identifier workshop-aurora-postgresql \
    --engine aurora-postgresql \
    --engine-version 15.4 \
    --master-username postgres \
    --master-user-password WorkshopDB123! \
    --database-name loanapplicationdb \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --db-subnet-group-name default \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "sun:04:00-sun:05:00" \
    --storage-encrypted \
    --kms-key-id alias/aws/rds \
    --deletion-protection false \
    --tags Key=Workshop,Value=DatabaseModernization Key=Phase,Value=2

# Create cluster instances
aws rds create-db-instance \
    --db-instance-identifier workshop-aurora-postgresql-writer \
    --db-instance-class db.t3.medium \
    --engine aurora-postgresql \
    --db-cluster-identifier workshop-aurora-postgresql \
    --publicly-accessible true \
    --tags Key=Workshop,Value=DatabaseModernization Key=Role,Value=Writer

aws rds create-db-instance \
    --db-instance-identifier workshop-aurora-postgresql-reader \
    --db-instance-class db.t3.medium \
    --engine aurora-postgresql \
    --db-cluster-identifier workshop-aurora-postgresql \
    --publicly-accessible true \
    --tags Key=Workshop,Value=DatabaseModernization Key=Role,Value=Reader
```

#### Method 2: AWS Console Steps
1. **Navigate to RDS Console**
   - Go to AWS RDS Console
   - Click "Create database"

2. **Engine Selection**
   - Choose "Amazon Aurora"
   - Select "Aurora (PostgreSQL Compatible)"
   - Version: PostgreSQL 15.4-compatible

3. **Cluster Configuration**
   - DB cluster identifier: `workshop-aurora-postgresql`
   - Master username: `postgres`
   - Master password: `WorkshopDB123!`
   - Initial database name: `loanapplicationdb`

4. **Instance Configuration**
   - DB instance class: `db.t3.medium`
   - Multi-AZ deployment: Create Aurora Replica
   - Writer instance: 1
   - Reader instances: 1

5. **Connectivity**
   - VPC: Same as Phase 1
   - Subnet group: Default
   - Public access: Yes (workshop only)
   - VPC security groups: Create new or reuse

6. **Additional Configuration**
   - Backup retention: 7 days
   - Backup window: 03:00-04:00 UTC
   - Maintenance window: Sunday 04:00-05:00 UTC
   - Encryption: Enabled
   - Performance Insights: Enabled

### 🔒 Security Configuration

#### Security Group for Aurora PostgreSQL
```bash
# Create security group for Aurora PostgreSQL
aws ec2 create-security-group \
    --group-name workshop-aurora-sg \
    --description "Security group for workshop Aurora PostgreSQL" \
    --vpc-id vpc-xxxxxxxxx

# Add inbound rule for PostgreSQL (port 5432)
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --source-group sg-xxxxxxxxx  # EC2 security group

# Add rule for DMS access
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --source-group sg-xxxxxxxxx  # DMS security group

# Add rule for workshop access
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --cidr 10.0.0.0/16  # VPC CIDR
```

#### Security Group Rules Summary
| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| Inbound | TCP | 5432 | EC2-SG | Application access |
| Inbound | TCP | 5432 | DMS-SG | Migration access |
| Inbound | TCP | 5432 | VPC CIDR | Workshop access |
| Outbound | All | All | 0.0.0.0/0 | Default outbound |

### ⚙️ Parameter Group Configuration

#### Create Custom Parameter Group
```bash
# Create cluster parameter group
aws rds create-db-cluster-parameter-group \
    --db-cluster-parameter-group-name workshop-aurora-postgresql-cluster \
    --db-parameter-group-family aurora-postgresql15 \
    --description "Custom cluster parameters for workshop Aurora PostgreSQL"

# Create instance parameter group
aws rds create-db-parameter-group \
    --db-parameter-group-name workshop-aurora-postgresql-instance \
    --db-parameter-group-family aurora-postgresql15 \
    --description "Custom instance parameters for workshop Aurora PostgreSQL"

# Modify cluster parameters
aws rds modify-db-cluster-parameter-group \
    --db-cluster-parameter-group-name workshop-aurora-postgresql-cluster \
    --parameters "ParameterName=shared_preload_libraries,ParameterValue=pg_stat_statements,ApplyMethod=pending-reboot" \
                 "ParameterName=log_statement,ParameterValue=all,ApplyMethod=immediate" \
                 "ParameterName=log_min_duration_statement,ParameterValue=1000,ApplyMethod=immediate"

# Modify instance parameters
aws rds modify-db-parameter-group \
    --db-parameter-group-name workshop-aurora-postgresql-instance \
    --parameters "ParameterName=work_mem,ParameterValue=16384,ApplyMethod=immediate" \
                 "ParameterName=maintenance_work_mem,ParameterValue=65536,ApplyMethod=immediate" \
                 "ParameterName=effective_cache_size,ParameterValue=1048576,ApplyMethod=immediate"
```

#### Key Parameters for Workshop
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `shared_preload_libraries` | `pg_stat_statements` | Query performance monitoring |
| `log_statement` | `all` | Log all SQL statements |
| `log_min_duration_statement` | `1000` | Log slow queries (>1s) |
| `work_mem` | `16MB` | Sort/hash operations memory |
| `maintenance_work_mem` | `64MB` | Maintenance operations memory |
| `effective_cache_size` | `1GB` | Query planner cache estimate |

### 🔧 PostgreSQL Extensions Setup

#### Enable Required Extensions
```sql
-- Connect to Aurora PostgreSQL and enable extensions
-- Run after cluster is available

-- UUID generation (for UNIQUEIDENTIFIER replacement)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Additional useful extensions
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";  -- For indexing

-- Verify extensions
SELECT extname, extversion 
FROM pg_extension 
ORDER BY extname;
```

### 📊 Monitoring and Performance Setup

#### Enable Performance Insights
```bash
# Enable Performance Insights on cluster instances
aws rds modify-db-instance \
    --db-instance-identifier workshop-aurora-postgresql-writer \
    --enable-performance-insights \
    --performance-insights-retention-period 7

aws rds modify-db-instance \
    --db-instance-identifier workshop-aurora-postgresql-reader \
    --enable-performance-insights \
    --performance-insights-retention-period 7
```

#### CloudWatch Alarms for Aurora
```bash
# CPU utilization alarm for writer
aws cloudwatch put-metric-alarm \
    --alarm-name "Aurora-HighCPU-Writer" \
    --alarm-description "Aurora PostgreSQL writer CPU high" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-aurora-postgresql-writer \
    --evaluation-periods 2

# Database connections alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Aurora-HighConnections" \
    --alarm-description "Aurora PostgreSQL connection count high" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 40 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-aurora-postgresql-writer \
    --evaluation-periods 2

# Aurora-specific metrics
aws cloudwatch put-metric-alarm \
    --alarm-name "Aurora-ReplicaLag" \
    --alarm-description "Aurora replica lag high" \
    --metric-name AuroraReplicaLag \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 1000 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-aurora-postgresql-reader \
    --evaluation-periods 2
```

### 🔄 Cluster Validation

#### Check Cluster Status
```bash
# Check cluster status
aws rds describe-db-clusters \
    --db-cluster-identifier workshop-aurora-postgresql \
    --query 'DBClusters[0].{Status:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint,Engine:Engine,EngineVersion:EngineVersion}'

# Check instance status
aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `workshop-aurora-postgresql`)].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Role:PromotionTier}'
```

#### Test Connectivity
```powershell
# Test from Windows EC2 instance
$AuroraWriterEndpoint = "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com"
$AuroraReaderEndpoint = "workshop-aurora-postgresql.cluster-ro-xxxxxxxxx.us-east-1.rds.amazonaws.com"

# Install PostgreSQL client tools
choco install postgresql -y

# Test writer connection
try {
    $env:PGPASSWORD = "WorkshopDB123!"
    psql -h $AuroraWriterEndpoint -U postgres -d loanapplicationdb -c "SELECT version();"
    Write-Host "✅ Aurora Writer Connection Successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Aurora Writer Connection Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test reader connection
try {
    $env:PGPASSWORD = "WorkshopDB123!"
    psql -h $AuroraReaderEndpoint -U postgres -d loanapplicationdb -c "SELECT version();"
    Write-Host "✅ Aurora Reader Connection Successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Aurora Reader Connection Failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

### 🎯 Aurora Configuration Summary

```
Aurora PostgreSQL Cluster Configuration
=======================================
Cluster Identifier: workshop-aurora-postgresql
Engine: Aurora PostgreSQL 15.4-compatible
Writer Instance: db.t3.medium
Reader Instance: db.t3.medium
Storage: Aurora shared storage (auto-scaling)
Backup Retention: 7 days
Encryption: Enabled (KMS)
Multi-AZ: Yes (Aurora native)

Connection Details
==================
Writer Endpoint: workshop-aurora-postgresql.cluster-xxx.us-east-1.rds.amazonaws.com
Reader Endpoint: workshop-aurora-postgresql.cluster-ro-xxx.us-east-1.rds.amazonaws.com
Port: 5432
Username: postgres
Password: WorkshopDB123!
Database: loanapplicationdb

Estimated Monthly Cost: ~$120 (2 instances)
```

### 📋 Post-Creation Checklist

#### Immediate Tasks
- [ ] Cluster status shows "available"
- [ ] Both writer and reader instances running
- [ ] Endpoints accessible from EC2
- [ ] Security groups configured correctly
- [ ] Parameter groups applied

#### Configuration Validation
- [ ] Can connect using psql client
- [ ] Extensions enabled successfully
- [ ] Performance Insights enabled
- [ ] CloudWatch alarms created
- [ ] Backup and maintenance windows set

#### Preparation for Migration
- [ ] Schema conversion tools ready
- [ ] DMS replication instance planned
- [ ] Application code review completed
- [ ] Testing environment prepared

### 🚨 Workshop-Specific Notes

#### Aurora Benefits
- **Serverless Scaling**: Storage auto-scales from 10GB to 128TB
- **High Availability**: Multi-AZ with automatic failover
- **Performance**: Up to 3x faster than standard PostgreSQL
- **Backup**: Continuous backup to S3 with point-in-time recovery

#### Cost Considerations
- **Instance Costs**: ~$58/month per db.t3.medium instance
- **Storage**: Pay for actual usage (starts at ~$0.10/GB/month)
- **I/O**: Pay per request (~$0.20 per 1M requests)
- **Backup**: Free up to 100% of cluster storage

The Aurora PostgreSQL cluster is now ready for schema deployment and data migration in the next steps.