# Cleanup Procedures
## AWS Database Modernization Workshop

### Automated Cleanup Script

**Q Developer Prompt for Script Generation**:
```
@q Create a comprehensive cleanup script for AWS resources created during the database modernization workshop, including RDS, DynamoDB, CloudFormation stacks, and S3 buckets
```

### PowerShell Cleanup Script

```powershell
# Workshop-Cleanup.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$WorkshopPrefix,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

Write-Host "Starting AWS Database Modernization Workshop Cleanup..." -ForegroundColor Green
Write-Host "Workshop Prefix: $WorkshopPrefix" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN MODE - No resources will be deleted" -ForegroundColor Cyan
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Function to safely delete resources
function Remove-AWSResourceSafely {
    param($ResourceType, $ResourceId, $DeleteCommand)
    
    try {
        Write-Host "Deleting $ResourceType: $ResourceId" -ForegroundColor Yellow
        if (-not $DryRun) {
            Invoke-Expression $DeleteCommand
            Write-Host "✓ Deleted $ResourceType: $ResourceId" -ForegroundColor Green
        } else {
            Write-Host "✓ Would delete $ResourceType: $ResourceId" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "✗ Failed to delete $ResourceType: $ResourceId - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 1. Delete DynamoDB Tables
Write-Host "`n=== Cleaning up DynamoDB Tables ===" -ForegroundColor Magenta
$dynamoTables = aws dynamodb list-tables --query "TableNames[?contains(@, '$WorkshopPrefix')]" --output text
if ($dynamoTables) {
    foreach ($table in $dynamoTables.Split()) {
        Remove-AWSResourceSafely "DynamoDB Table" $table "aws dynamodb delete-table --table-name $table"
    }
}

# 2. Delete RDS Instances
Write-Host "`n=== Cleaning up RDS Instances ===" -ForegroundColor Magenta
$rdsInstances = aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, '$WorkshopPrefix')].DBInstanceIdentifier" --output text
if ($rdsInstances) {
    foreach ($instance in $rdsInstances.Split()) {
        Remove-AWSResourceSafely "RDS Instance" $instance "aws rds delete-db-instance --db-instance-identifier $instance --skip-final-snapshot --delete-automated-backups"
    }
}

# 3. Delete RDS Clusters (Aurora)
Write-Host "`n=== Cleaning up RDS Clusters ===" -ForegroundColor Magenta
$rdsClusters = aws rds describe-db-clusters --query "DBClusters[?contains(DBClusterIdentifier, '$WorkshopPrefix')].DBClusterIdentifier" --output text
if ($rdsClusters) {
    foreach ($cluster in $rdsClusters.Split()) {
        # Delete cluster instances first
        $clusterInstances = aws rds describe-db-clusters --db-cluster-identifier $cluster --query "DBClusters[0].DBClusterMembers[].DBInstanceIdentifier" --output text
        foreach ($instance in $clusterInstances.Split()) {
            Remove-AWSResourceSafely "RDS Cluster Instance" $instance "aws rds delete-db-instance --db-instance-identifier $instance --skip-final-snapshot"
        }
        
        # Wait for instances to be deleted, then delete cluster
        Start-Sleep -Seconds 30
        Remove-AWSResourceSafely "RDS Cluster" $cluster "aws rds delete-db-cluster --db-cluster-identifier $cluster --skip-final-snapshot"
    }
}

# 4. Delete DMS Resources
Write-Host "`n=== Cleaning up DMS Resources ===" -ForegroundColor Magenta
$dmsTasks = aws dms describe-replication-tasks --query "ReplicationTasks[?contains(ReplicationTaskIdentifier, '$WorkshopPrefix')].ReplicationTaskArn" --output text
foreach ($task in $dmsTasks.Split()) {
    if ($task) {
        Remove-AWSResourceSafely "DMS Task" $task "aws dms delete-replication-task --replication-task-arn $task"
    }
}

$dmsInstances = aws dms describe-replication-instances --query "ReplicationInstances[?contains(ReplicationInstanceIdentifier, '$WorkshopPrefix')].ReplicationInstanceArn" --output text
foreach ($instance in $dmsInstances.Split()) {
    if ($instance) {
        Remove-AWSResourceSafely "DMS Instance" $instance "aws dms delete-replication-instance --replication-instance-arn $instance"
    }
}

# 5. Delete CloudFormation Stacks
Write-Host "`n=== Cleaning up CloudFormation Stacks ===" -ForegroundColor Magenta
$cfStacks = aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, '$WorkshopPrefix')].StackName" --output text
foreach ($stack in $cfStacks.Split()) {
    if ($stack) {
        Remove-AWSResourceSafely "CloudFormation Stack" $stack "aws cloudformation delete-stack --stack-name $stack"
    }
}

# 6. Delete S3 Buckets
Write-Host "`n=== Cleaning up S3 Buckets ===" -ForegroundColor Magenta
$s3Buckets = aws s3api list-buckets --query "Buckets[?contains(Name, '$WorkshopPrefix')].Name" --output text
foreach ($bucket in $s3Buckets.Split()) {
    if ($bucket) {
        # Empty bucket first
        if (-not $DryRun) {
            aws s3 rm s3://$bucket --recursive
        }
        Remove-AWSResourceSafely "S3 Bucket" $bucket "aws s3api delete-bucket --bucket $bucket"
    }
}

# 7. Delete IAM Roles and Policies
Write-Host "`n=== Cleaning up IAM Resources ===" -ForegroundColor Magenta
$iamRoles = aws iam list-roles --query "Roles[?contains(RoleName, '$WorkshopPrefix')].RoleName" --output text
foreach ($role in $iamRoles.Split()) {
    if ($role) {
        # Detach policies first
        $attachedPolicies = aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text
        foreach ($policy in $attachedPolicies.Split()) {
            if ($policy -and -not $DryRun) {
                aws iam detach-role-policy --role-name $role --policy-arn $policy
            }
        }
        Remove-AWSResourceSafely "IAM Role" $role "aws iam delete-role --role-name $role"
    }
}

# 8. Delete Parameter Store Parameters
Write-Host "`n=== Cleaning up Parameter Store ===" -ForegroundColor Magenta
$parameters = aws ssm describe-parameters --query "Parameters[?contains(Name, '/workshop/')].Name" --output text
foreach ($param in $parameters.Split()) {
    if ($param) {
        Remove-AWSResourceSafely "SSM Parameter" $param "aws ssm delete-parameter --name $param"
    }
}

# 9. Delete Security Groups
Write-Host "`n=== Cleaning up Security Groups ===" -ForegroundColor Magenta
$securityGroups = aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, '$WorkshopPrefix') && GroupName != 'default'].GroupId" --output text
foreach ($sg in $securityGroups.Split()) {
    if ($sg) {
        Remove-AWSResourceSafely "Security Group" $sg "aws ec2 delete-security-group --group-id $sg"
    }
}

Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Green
Write-Host "Workshop cleanup completed for prefix: $WorkshopPrefix" -ForegroundColor Green
Write-Host "Please verify in AWS Console that all resources have been removed." -ForegroundColor Yellow
Write-Host "Note: Some resources may take several minutes to fully delete." -ForegroundColor Yellow
```

### Manual Cleanup Checklist

#### Phase 1 Resources
- [ ] **RDS SQL Server Instance**: `workshop-sqlserver-[timestamp]`
- [ ] **RDS Subnet Group**: `workshop-subnet-group`
- [ ] **RDS Parameter Group**: `workshop-sqlserver-params`
- [ ] **Security Groups**: `workshop-rds-sg`
- [ ] **S3 Backup Bucket**: `workshop-backups-[account-id]`

#### Phase 2 Resources
- [ ] **Aurora PostgreSQL Cluster**: `workshop-postgresql-cluster`
- [ ] **Aurora Instances**: `workshop-postgresql-instance-1`, `workshop-postgresql-instance-2`
- [ ] **DMS Replication Instance**: `workshop-dms-instance`
- [ ] **DMS Replication Tasks**: `workshop-migration-task`
- [ ] **DMS Endpoints**: Source and target endpoints

#### Phase 3 Resources
- [ ] **DynamoDB Table**: `IntegrationLogs`
- [ ] **DynamoDB GSIs**: All Global Secondary Indexes
- [ ] **IAM Roles**: `WorkshopDynamoDBRole`, `WorkshopLambdaRole`
- [ ] **CloudWatch Log Groups**: `/aws/lambda/workshop-*`

#### CloudFormation Stacks
- [ ] **Phase 1 Stack**: `workshop-phase1-infrastructure`
- [ ] **Phase 2 Stack**: `workshop-phase2-postgresql`
- [ ] **Phase 3 Stack**: `workshop-phase3-dynamodb`

### Cost Verification

**Q Developer Prompt for Cost Analysis**:
```
@q Help me create a script to verify all AWS resources from the workshop have been deleted and no ongoing charges will occur
```

**Cost Check Commands**:
```bash
# Verify no running RDS instances
aws rds describe-db-instances --query "DBInstances[?DBInstanceStatus=='available']"

# Check DynamoDB tables
aws dynamodb list-tables

# Verify S3 buckets are empty
aws s3api list-buckets --query "Buckets[?contains(Name, 'workshop')]"

# Check CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Verify no DMS resources
aws dms describe-replication-instances
aws dms describe-replication-tasks
```

### Participant Cleanup Instructions

#### Individual Cleanup Steps
1. **Run Automated Script**:
   ```powershell
   .\Scripts\Workshop-Cleanup.ps1 -WorkshopPrefix "dbmod-[your-timestamp]" -Region "us-east-1"
   ```

2. **Verify Deletion**:
   - Check AWS Console for remaining resources
   - Review billing dashboard for ongoing charges
   - Confirm CloudFormation stacks are deleted

3. **Local Environment Cleanup**:
   ```bash
   # Remove workshop files (optional)
   rm -rf database-modernization-workshop
   
   # Clear AWS CLI cache
   aws configure list-profiles
   aws sso logout
   ```

### Instructor Cleanup Procedures

#### Pre-Workshop Cleanup
- [ ] Verify no existing workshop resources in demo account
- [ ] Clear previous CloudFormation stacks
- [ ] Reset demo environment to baseline state

#### Post-Workshop Cleanup
- [ ] Run cleanup script for all participant prefixes
- [ ] Verify billing dashboard shows no unexpected charges
- [ ] Document any resources requiring manual deletion
- [ ] Update cleanup procedures based on lessons learned

### Emergency Cleanup

**If Automated Script Fails**:
1. **Manual AWS Console Cleanup**:
   - Navigate to each service console
   - Filter by workshop prefix or tags
   - Delete resources in dependency order

2. **Force Delete Commands**:
   ```bash
   # Force delete CloudFormation stack
   aws cloudformation delete-stack --stack-name [stack-name]
   
   # Force delete RDS with immediate effect
   aws rds delete-db-instance --db-instance-identifier [instance] --skip-final-snapshot --delete-automated-backups
   ```

3. **Contact AWS Support**:
   - For stuck resources that won't delete
   - For unexpected billing charges
   - For service limit issues

### Cleanup Validation

**Final Verification Checklist**:
- [ ] AWS Cost Explorer shows no ongoing charges
- [ ] All CloudFormation stacks deleted
- [ ] No RDS instances or clusters running
- [ ] DynamoDB tables removed
- [ ] S3 buckets empty and deleted
- [ ] IAM roles and policies cleaned up
- [ ] Parameter Store entries removed

**Q Developer Final Check**:
```
@q Review my AWS account and identify any remaining resources from the database modernization workshop that might incur charges
```

---

**Important Notes**:
- Always run cleanup script with `--DryRun` first
- Some resources may take 10-15 minutes to fully delete
- Monitor AWS billing dashboard for 24-48 hours post-cleanup
- Keep workshop prefix consistent for effective cleanup