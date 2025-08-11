# Phase 1: RDS SQL Server Setup Procedures
## Step-by-Step RDS Instance Creation and Configuration

### 🎯 Setup Objectives
- Create RDS SQL Server instance with optimal configuration
- Configure security groups and networking
- Set up parameter groups for performance
- Enable monitoring and backup policies

### 📋 Prerequisites
- AWS CLI configured with appropriate permissions
- VPC with public/private subnets
- Security groups configured
- Parameter group created (optional)

### 🚀 RDS Instance Creation

#### Method 1: AWS CLI (Recommended for Workshop)
```bash
# Create RDS SQL Server instance
aws rds create-db-instance \
    --db-instance-identifier workshop-sqlserver-rds \
    --db-instance-class db.t3.medium \
    --engine sqlserver-web \
    --engine-version 15.00.4236.7.v1 \
    --master-username admin \
    --master-user-password WorkshopDB123! \
    --allocated-storage 20 \
    --storage-type gp2 \
    --storage-encrypted \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --db-subnet-group-name default \
    --backup-retention-period 7 \
    --multi-az false \
    --publicly-accessible true \
    --auto-minor-version-upgrade true \
    --license-model license-included \
    --option-group-name default:sqlserver-web-15-00 \
    --db-parameter-group-name default.sqlserver-web-15.0 \
    --deletion-protection false \
    --tags Key=Workshop,Value=DatabaseModernization Key=Phase,Value=1
```

#### Method 2: AWS Console Steps
1. **Navigate to RDS Console**
   - Go to AWS RDS Console
   - Click "Create database"

2. **Engine Selection**
   - Choose "Microsoft SQL Server"
   - Select "SQL Server Web Edition"
   - Version: Latest available (15.00.4236.7.v1 or newer)

3. **Instance Configuration**
   - DB instance identifier: `workshop-sqlserver-rds`
   - Master username: `admin`
   - Master password: `WorkshopDB123!`
   - DB instance class: `db.t3.medium`

4. **Storage Configuration**
   - Storage type: General Purpose (SSD)
   - Allocated storage: 20 GB
   - Enable storage autoscaling: Yes
   - Maximum storage threshold: 100 GB

5. **Connectivity**
   - VPC: Default or workshop-specific VPC
   - Subnet group: Default
   - Public access: Yes (for workshop only)
   - VPC security groups: Create new or select existing

6. **Additional Configuration**
   - Initial database name: Leave blank (will create manually)
   - Backup retention: 7 days
   - Backup window: Default
   - Maintenance window: Default
   - Enable deletion protection: No (workshop environment)

### 🔒 Security Group Configuration

#### Create Security Group
```bash
# Create security group for RDS
aws ec2 create-security-group \
    --group-name workshop-rds-sg \
    --description "Security group for workshop RDS SQL Server" \
    --vpc-id vpc-xxxxxxxxx

# Add inbound rule for SQL Server (port 1433)
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 1433 \
    --source-group sg-xxxxxxxxx  # Application server security group

# Add rule for workshop EC2 instance
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 1433 \
    --cidr 10.0.0.0/16  # VPC CIDR or specific IP
```

#### Security Group Rules
| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| Inbound | TCP | 1433 | Application SG | App server access |
| Inbound | TCP | 1433 | Workshop IP | Direct access for migration |
| Outbound | All | All | 0.0.0.0/0 | Default outbound |

### ⚙️ Parameter Group Configuration

#### Create Custom Parameter Group
```bash
# Create parameter group
aws rds create-db-parameter-group \
    --db-parameter-group-name workshop-sqlserver-params \
    --db-parameter-group-family sqlserver-web-15.0 \
    --description "Custom parameters for workshop SQL Server"

# Modify parameters for workshop optimization
aws rds modify-db-parameter-group \
    --db-parameter-group-name workshop-sqlserver-params \
    --parameters "ParameterName=max degree of parallelism,ParameterValue=2,ApplyMethod=immediate" \
                 "ParameterName=cost threshold for parallelism,ParameterValue=50,ApplyMethod=immediate"
```

#### Key Parameters for Workshop
| Parameter | Value | Purpose |
|-----------|-------|---------|
| max degree of parallelism | 2 | Optimize for small instance |
| cost threshold for parallelism | 50 | Prevent excessive parallelism |
| max server memory (MB) | 3072 | Leave memory for OS |

### 📊 Monitoring Setup

#### Enable Enhanced Monitoring
```bash
# Create IAM role for enhanced monitoring
aws iam create-role \
    --role-name rds-monitoring-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "monitoring.rds.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Attach policy
aws iam attach-role-policy \
    --role-name rds-monitoring-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole

# Enable enhanced monitoring on instance
aws rds modify-db-instance \
    --db-instance-identifier workshop-sqlserver-rds \
    --monitoring-interval 60 \
    --monitoring-role-arn arn:aws:iam::ACCOUNT:role/rds-monitoring-role
```

#### CloudWatch Alarms
```bash
# CPU utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "RDS-HighCPU-workshop-sqlserver" \
    --alarm-description "RDS CPU utilization high" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-sqlserver-rds \
    --evaluation-periods 2

# Database connections alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "RDS-HighConnections-workshop-sqlserver" \
    --alarm-description "RDS connection count high" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 40 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=workshop-sqlserver-rds \
    --evaluation-periods 2
```

### 🔄 Instance Validation

#### Check Instance Status
```bash
# Check instance status
aws rds describe-db-instances \
    --db-instance-identifier workshop-sqlserver-rds \
    --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}'
```

#### Test Connectivity
```powershell
# Test from Windows EC2 instance
$RDSEndpoint = "workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com"
$ConnectionString = "Server=$RDSEndpoint;Database=master;User Id=admin;Password=WorkshopDB123!;Encrypt=true;TrustServerCertificate=true;"

try {
    Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "SELECT @@VERSION" -QueryTimeout 30
    Write-Host "✅ RDS Connection Successful" -ForegroundColor Green
} catch {
    Write-Host "❌ RDS Connection Failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

### 📋 Post-Creation Checklist

#### Immediate Tasks
- [ ] Instance status shows "available"
- [ ] Endpoint address is accessible
- [ ] Security groups allow required access
- [ ] Parameter group applied correctly
- [ ] Enhanced monitoring enabled

#### Configuration Validation
- [ ] Can connect using SQL Server Management Studio
- [ ] Can connect from application server
- [ ] Backup retention policy configured
- [ ] CloudWatch alarms created
- [ ] Tags applied for cost tracking

### 🎯 RDS Configuration Summary

```
RDS Instance Configuration
==========================
Identifier: workshop-sqlserver-rds
Engine: SQL Server Web Edition 15.00.4236.7.v1
Instance Class: db.t3.medium (2 vCPU, 4GB RAM)
Storage: 20GB GP2 with autoscaling
Multi-AZ: Disabled (workshop only)
Backup Retention: 7 days
Enhanced Monitoring: 60-second intervals
Encryption: Enabled
Public Access: Enabled (workshop only)

Connection Details
==================
Endpoint: workshop-sqlserver-rds.xxxxxxxxx.us-east-1.rds.amazonaws.com
Port: 1433
Username: admin
Password: WorkshopDB123!

Estimated Monthly Cost: ~$61
```

### 🚨 Workshop-Specific Notes

#### Security Considerations
- **Public Access**: Enabled for workshop simplicity (disable in production)
- **Simple Password**: Using workshop standard (use complex passwords in production)
- **Open Security Groups**: Restricted to workshop environment

#### Cost Optimization
- **Instance Size**: Right-sized for workshop workload
- **Storage**: Minimal allocation with autoscaling
- **Multi-AZ**: Disabled to reduce costs (enable in production)

The RDS instance is now ready for database migration in the next step.