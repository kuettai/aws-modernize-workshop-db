# DMS Prerequisites Setup
## IAM Roles, Secrets Manager, and Data Providers Configuration

### 🎯 Prerequisites Setup Objectives
- Create required IAM roles for DMS
- Set up Secrets Manager for database credentials
- Configure Data Providers for schema conversion
- Set up Instance Profiles for EC2 access

### 🔐 IAM Roles Setup

#### 1. DMS Service Role
```bash
# Create DMS service role
aws iam create-role \
    --role-name dms-vpc-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "dms.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --profile mmws

# Attach managed policy
aws iam attach-role-policy \
    --role-name dms-vpc-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole \
    --profile mmws
```

#### 2. DMS CloudWatch Logs Role
```bash
# Create CloudWatch logs role
aws iam create-role \
    --role-name dms-cloudwatch-logs-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "dms.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --profile mmws

# Attach CloudWatch logs policy
aws iam attach-role-policy \
    --role-name dms-cloudwatch-logs-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole \
    --profile mmws
```

#### 3. DMS Access for RDS Role
```bash
# Create DMS access role
aws iam create-role \
    --role-name dms-access-for-endpoint \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "dms.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --profile mmws

# Create custom policy for DMS access
aws iam create-policy \
    --policy-name DMSEndpointAccessPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "rds:DescribeDBInstances",
                    "rds:DescribeDBClusters",
                    "rds:ModifyDBInstance",
                    "rds:ModifyDBCluster",
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --profile mmws

# Attach policy to role
aws iam attach-role-policy \
    --role-name dms-access-for-endpoint \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text --profile mmws):policy/DMSEndpointAccessPolicy \
    --profile mmws
```

### 🔑 Secrets Manager Setup

#### 1. Source Database Secret (SQL Server)
```bash
# Create secret for SQL Server
aws secretsmanager create-secret \
    --name "workshop/sqlserver/credentials" \
    --description "SQL Server credentials for DMS migration" \
    --secret-string '{
        "username": "sa",
        "password": "WorkshopDB123!",
        "engine": "sqlserver",
        "host": "localhost",
        "port": 1433,
        "dbname": "LoanApplicationDB"
    }' \
    --profile mmws

# Get secret ARN
aws secretsmanager describe-secret \
    --secret-id "workshop/sqlserver/credentials" \
    --query 'ARN' \
    --output text \
    --profile mmws
```

#### 2. Target Database Secret (Aurora PostgreSQL)
```bash
# Create secret for Aurora PostgreSQL
aws secretsmanager create-secret \
    --name "workshop/aurora-postgresql/credentials" \
    --description "Aurora PostgreSQL credentials for DMS migration" \
    --secret-string '{
        "username": "postgres",
        "password": "WorkshopDB123!",
        "engine": "postgres",
        "host": "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com",
        "port": 5432,
        "dbname": "loanapplicationdb"
    }' \
    --profile mmws

# Get secret ARN
aws secretsmanager describe-secret \
    --secret-id "workshop/aurora-postgresql/credentials" \
    --query 'ARN' \
    --output text \
    --profile mmws
```

### 📊 Data Providers Setup

#### 1. SQL Server Data Provider
```bash
# Create SQL Server data provider
aws dms create-data-provider \
    --data-provider-name "workshop-sqlserver-provider" \
    --engine "sqlserver" \
    --description "SQL Server data provider for workshop migration" \
    --settings '{
        "ServerName": "localhost",
        "Port": 1433,
        "DatabaseName": "LoanApplicationDB",
        "SslMode": "require"
    }' \
    --tags Key=Workshop,Value=DatabaseModernization Key=Type,Value=Source \
    --profile mmws
```

#### 2. Aurora PostgreSQL Data Provider
```bash
# Create Aurora PostgreSQL data provider
aws dms create-data-provider \
    --data-provider-name "workshop-aurora-postgresql-provider" \
    --engine "postgres" \
    --description "Aurora PostgreSQL data provider for workshop migration" \
    --settings '{
        "ServerName": "workshop-aurora-postgresql.cluster-xxxxxxxxx.us-east-1.rds.amazonaws.com",
        "Port": 5432,
        "DatabaseName": "loanapplicationdb",
        "SslMode": "require"
    }' \
    --tags Key=Workshop,Value=DatabaseModernization Key=Type,Value=Target \
    --profile mmws
```

### 🖥️ Instance Profile Setup (for EC2)

#### 1. EC2 Role for DMS Access
```bash
# Create EC2 role for DMS operations
aws iam create-role \
    --role-name EC2-DMS-Workshop-Role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --profile mmws

# Create policy for EC2 DMS operations
aws iam create-policy \
    --policy-name EC2-DMS-Workshop-Policy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "dms:*",
                    "rds:Describe*",
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret",
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --profile mmws

# Attach policy to role
aws iam attach-role-policy \
    --role-name EC2-DMS-Workshop-Role \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text --profile mmws):policy/EC2-DMS-Workshop-Policy \
    --profile mmws

# Create instance profile
aws iam create-instance-profile \
    --instance-profile-name EC2-DMS-Workshop-Profile \
    --profile mmws

# Add role to instance profile
aws iam add-role-to-instance-profile \
    --instance-profile-name EC2-DMS-Workshop-Profile \
    --role-name EC2-DMS-Workshop-Role \
    --profile mmws
```

### 🔧 DMS Schema Conversion Setup

#### 1. Create Migration Project
```bash
# Create DMS migration project for schema conversion
aws dms create-migration-project \
    --migration-project-name "workshop-schema-conversion" \
    --source-data-provider-descriptors '[{
        "DataProviderIdentifier": "workshop-sqlserver-provider",
        "SecretsManagerSecretId": "workshop/sqlserver/credentials"
    }]' \
    --target-data-provider-descriptors '[{
        "DataProviderIdentifier": "workshop-aurora-postgresql-provider", 
        "SecretsManagerSecretId": "workshop/aurora-postgresql/credentials"
    }]' \
    --instance-profile-identifier "EC2-DMS-Workshop-Profile" \
    --transformation-rules '{
        "Rules": [
            {
                "RuleType": "selection",
                "RuleId": "1",
                "RuleName": "select-all-tables",
                "ObjectLocator": {
                    "SchemaName": "dbo",
                    "TableName": "%"
                },
                "RuleAction": "include"
            },
            {
                "RuleType": "transformation",
                "RuleId": "2", 
                "RuleName": "convert-schema-name",
                "RuleTarget": "schema",
                "ObjectLocator": {
                    "SchemaName": "dbo"
                },
                "RuleAction": "rename",
                "Value": "public"
            },
            {
                "RuleType": "transformation",
                "RuleId": "3",
                "RuleName": "convert-to-lowercase",
                "RuleTarget": "table",
                "ObjectLocator": {
                    "SchemaName": "dbo",
                    "TableName": "%"
                },
                "RuleAction": "convert-lowercase"
            }
        ]
    }' \
    --tags Key=Workshop,Value=DatabaseModernization \
    --profile mmws
```

#### 2. Start Schema Conversion
```bash
# Start schema conversion assessment
aws dms start-schema-conversion \
    --migration-project-identifier "workshop-schema-conversion" \
    --profile mmws

# Monitor conversion progress
aws dms describe-schema-conversions \
    --migration-project-identifier "workshop-schema-conversion" \
    --profile mmws
```

### 📋 Validation Scripts

#### 1. Verify IAM Roles
```powershell
# PowerShell script to verify all roles are created
$RequiredRoles = @(
    "dms-vpc-role",
    "dms-cloudwatch-logs-role", 
    "dms-access-for-endpoint",
    "EC2-DMS-Workshop-Role"
)

Write-Host "=== Verifying IAM Roles ===" -ForegroundColor Cyan

foreach ($role in $RequiredRoles) {
    try {
        $roleInfo = aws iam get-role --role-name $role --profile mmws | ConvertFrom-Json
        Write-Host "✅ Role exists: $role" -ForegroundColor Green
    } catch {
        Write-Host "❌ Role missing: $role" -ForegroundColor Red
    }
}
```

#### 2. Verify Secrets Manager
```powershell
# Verify secrets are created
$RequiredSecrets = @(
    "workshop/sqlserver/credentials",
    "workshop/aurora-postgresql/credentials"
)

Write-Host "=== Verifying Secrets Manager ===" -ForegroundColor Cyan

foreach ($secret in $RequiredSecrets) {
    try {
        $secretInfo = aws secretsmanager describe-secret --secret-id $secret --profile mmws | ConvertFrom-Json
        Write-Host "✅ Secret exists: $secret" -ForegroundColor Green
    } catch {
        Write-Host "❌ Secret missing: $secret" -ForegroundColor Red
    }
}
```

#### 3. Verify Data Providers
```powershell
# Verify data providers
Write-Host "=== Verifying Data Providers ===" -ForegroundColor Cyan

try {
    $providers = aws dms describe-data-providers --profile mmws | ConvertFrom-Json
    $providerNames = $providers.DataProviders | ForEach-Object { $_.DataProviderName }
    
    if ($providerNames -contains "workshop-sqlserver-provider") {
        Write-Host "✅ SQL Server data provider exists" -ForegroundColor Green
    } else {
        Write-Host "❌ SQL Server data provider missing" -ForegroundColor Red
    }
    
    if ($providerNames -contains "workshop-aurora-postgresql-provider") {
        Write-Host "✅ Aurora PostgreSQL data provider exists" -ForegroundColor Green
    } else {
        Write-Host "❌ Aurora PostgreSQL data provider missing" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking data providers: $($_.Exception.Message)" -ForegroundColor Red
}
```

### 🎯 Complete Setup Script

#### All-in-One Setup Script
```bash
#!/bin/bash
# Complete DMS prerequisites setup script

echo "=== DMS Prerequisites Setup ==="

# 1. Create IAM roles
echo "Creating IAM roles..."
aws iam create-role --role-name dms-vpc-role --assume-role-policy-document file://dms-trust-policy.json --profile mmws
aws iam attach-role-policy --role-name dms-vpc-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole --profile mmws

# 2. Create secrets
echo "Creating Secrets Manager entries..."
aws secretsmanager create-secret --name "workshop/sqlserver/credentials" --secret-string file://sqlserver-secret.json --profile mmws
aws secretsmanager create-secret --name "workshop/aurora-postgresql/credentials" --secret-string file://postgresql-secret.json --profile mmws

# 3. Create data providers
echo "Creating data providers..."
aws dms create-data-provider --data-provider-name "workshop-sqlserver-provider" --engine "sqlserver" --settings file://sqlserver-provider.json --profile mmws
aws dms create-data-provider --data-provider-name "workshop-aurora-postgresql-provider" --engine "postgres" --settings file://postgresql-provider.json --profile mmws

# 4. Create migration project
echo "Creating migration project..."
aws dms create-migration-project --migration-project-name "workshop-schema-conversion" --source-data-provider-descriptors file://source-provider.json --target-data-provider-descriptors file://target-provider.json --profile mmws

echo "✅ DMS prerequisites setup complete!"
```

### 📊 Setup Summary

After running these scripts, you'll have:

- **IAM Roles**: 4 roles for DMS operations
- **Secrets Manager**: 2 secrets for database credentials  
- **Data Providers**: 2 providers for source and target databases
- **Instance Profile**: EC2 profile for DMS access
- **Migration Project**: Ready for schema conversion

**Next Steps:**
1. Run Aurora PostgreSQL setup
2. Execute DMS prerequisites setup
3. Start schema conversion assessment
4. Review conversion report
5. Execute data migration

The setup provides secure, automated access to both databases for DMS operations.