# Create DMS Replication Task for PostgreSQL to DynamoDB Migration
param(
    [Parameter(Mandatory=$true)]
    [string]$ReplicationInstanceId,
    [string]$Environment = "dev",
    [string]$SourceEndpointId = "postgresql-source",
    [string]$TargetEndpointId = "dynamodb-target",
    [string]$PostgreSQLHost = "localhost",
    [string]$PostgreSQLPassword = "WorkshopDB123!"
)

Write-Host "🚀 Creating DMS Migration Task for PostgreSQL to DynamoDB" -ForegroundColor Green

try {
    # 1. Create replication instance if not exists
    Write-Host "Step 1: Creating DMS replication instance..." -ForegroundColor Yellow
    
    $replicationInstance = aws dms describe-replication-instances --filters Name=replication-instance-id,Values=$ReplicationInstanceId --query 'ReplicationInstances[0]' 2>$null
    
    if (-not $replicationInstance -or $replicationInstance -eq "null") {
        Write-Host "  Creating new replication instance..." -ForegroundColor Cyan
        
        aws dms create-replication-instance `
            --replication-instance-identifier $ReplicationInstanceId `
            --replication-instance-class dms.t3.micro `
            --allocated-storage 20 `
            --apply-immediately `
            --auto-minor-version-upgrade `
            --multi-az false `
            --publicly-accessible true `
            --tags Key=Environment,Value=$Environment Key=Purpose,Value=LoanAppMigration
        
        Write-Host "  Waiting for replication instance to be available..." -ForegroundColor Cyan
        aws dms wait replication-instance-available --filters Name=replication-instance-id,Values=$ReplicationInstanceId
        Write-Host "  ✅ Replication instance created" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Replication instance already exists" -ForegroundColor Green
    }
    
    # 2. Create source endpoint (PostgreSQL)
    Write-Host "Step 2: Creating PostgreSQL source endpoint..." -ForegroundColor Yellow
    
    $sourceEndpoint = aws dms describe-endpoints --filters Name=endpoint-id,Values=$SourceEndpointId --query 'Endpoints[0]' 2>$null
    
    if (-not $sourceEndpoint -or $sourceEndpoint -eq "null") {
        Write-Host "  Creating PostgreSQL source endpoint..." -ForegroundColor Cyan
        
        aws dms create-endpoint `
            --endpoint-identifier $SourceEndpointId `
            --endpoint-type source `
            --engine-name postgres `
            --server-name $PostgreSQLHost `
            --port 5432 `
            --database-name LoanApplicationDB `
            --username postgres `
            --password $PostgreSQLPassword `
            --tags Key=Environment,Value=$Environment
        
        Write-Host "  ✅ PostgreSQL source endpoint created" -ForegroundColor Green
    } else {
        Write-Host "  ✅ PostgreSQL source endpoint already exists" -ForegroundColor Green
    }
    
    # 3. Create/Verify DMS DynamoDB IAM Role
    Write-Host "Step 3: Creating/Verifying DMS DynamoDB IAM Role..." -ForegroundColor Yellow
    
    $accountId = aws sts get-caller-identity --query Account --output text
    $roleName = "dms-dynamodb-role"
    $roleArn = "arn:aws:iam::$accountId`:role/$roleName"
    
    # Check if role exists
    $roleExists = aws iam get-role --role-name $roleName --query 'Role.RoleName' --output text 2>$null
    
    if (-not $roleExists -or $roleExists -eq "null") {
        Write-Host "  Creating DMS DynamoDB IAM role..." -ForegroundColor Cyan
        
        # Create trust policy
        $trustPolicy = @'
{
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
}
'@
        
        $trustPolicy | Out-File -FilePath "trust-policy.json" -Encoding utf8
        
        # Create role
        aws iam create-role --role-name $roleName --assume-role-policy-document file://trust-policy.json
        
        # Attach DynamoDB full access policy
        aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
        
        # Clean up temp file
        Remove-Item "trust-policy.json" -Force
        
        Write-Host "  ✅ DMS DynamoDB IAM role created" -ForegroundColor Green
        
        # Wait for role to propagate
        Write-Host "  Waiting for IAM role to propagate..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    } else {
        Write-Host "  ✅ DMS DynamoDB IAM role already exists" -ForegroundColor Green
    }
    
    # 4. Create target endpoint (DynamoDB)
    Write-Host "Step 4: Creating DynamoDB target endpoint..." -ForegroundColor Yellow
    
    $targetEndpoint = aws dms describe-endpoints --filters Name=endpoint-id,Values=$TargetEndpointId --query 'Endpoints[0]' 2>$null
    
    if (-not $targetEndpoint -or $targetEndpoint -eq "null") {
        Write-Host "  Creating DynamoDB target endpoint..." -ForegroundColor Cyan
        
        aws dms create-endpoint `
            --endpoint-identifier $TargetEndpointId `
            --endpoint-type target `
            --engine-name dynamodb `
            --dynamo-db-settings ServiceAccessRoleArn=$roleArn `
            --tags Key=Environment,Value=$Environment
        
        Write-Host "  ✅ DynamoDB target endpoint created" -ForegroundColor Green
    } else {
        Write-Host "  ✅ DynamoDB target endpoint already exists" -ForegroundColor Green
    }
    
    # 5. Test endpoints
    Write-Host "Step 5: Testing endpoint connections..." -ForegroundColor Yellow
    
    Write-Host "  Testing PostgreSQL connection..." -ForegroundColor Cyan
    aws dms test-connection --replication-instance-arn $(aws dms describe-replication-instances --filters Name=replication-instance-id,Values=$ReplicationInstanceId --query 'ReplicationInstances[0].ReplicationInstanceArn' --output text) --endpoint-arn $(aws dms describe-endpoints --filters Name=endpoint-id,Values=$SourceEndpointId --query 'Endpoints[0].EndpointArn' --output text)
    
    Write-Host "  Testing DynamoDB connection..." -ForegroundColor Cyan
    aws dms test-connection --replication-instance-arn $(aws dms describe-replication-instances --filters Name=replication-instance-id,Values=$ReplicationInstanceId --query 'ReplicationInstances[0].ReplicationInstanceArn' --output text) --endpoint-arn $(aws dms describe-endpoints --filters Name=endpoint-id,Values=$TargetEndpointId --query 'Endpoints[0].EndpointArn' --output text)
    
    # 6. Create replication task
    Write-Host "Step 6: Creating replication task..." -ForegroundColor Yellow
    
    $taskId = "postgresql-to-dynamodb-$Environment"
    $existingTask = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0]' 2>$null
    
    if (-not $existingTask -or $existingTask -eq "null") {
        Write-Host "  Creating migration task..." -ForegroundColor Cyan
        
        $replicationInstanceArn = aws dms describe-replication-instances --filters Name=replication-instance-id,Values=$ReplicationInstanceId --query 'ReplicationInstances[0].ReplicationInstanceArn' --output text
        $sourceEndpointArn = aws dms describe-endpoints --filters Name=endpoint-id,Values=$SourceEndpointId --query 'Endpoints[0].EndpointArn' --output text
        $targetEndpointArn = aws dms describe-endpoints --filters Name=endpoint-id,Values=$TargetEndpointId --query 'Endpoints[0].EndpointArn' --output text
        
        aws dms create-replication-task `
            --replication-task-identifier $taskId `
            --source-endpoint-arn $sourceEndpointArn `
            --target-endpoint-arn $targetEndpointArn `
            --replication-instance-arn $replicationInstanceArn `
            --migration-type full-load `
            --table-mappings file://table-mappings.json `
            --replication-task-settings file://task-settings.json `
            --tags Key=Environment,Value=$Environment Key=Purpose,Value=IntegrationLogsMigration
        
        Write-Host "  ✅ Replication task created: $taskId" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Replication task already exists: $taskId" -ForegroundColor Green
    }
    
    # 7. Start replication task
    Write-Host "Step 7: Starting replication task..." -ForegroundColor Yellow
    
    $taskArn = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0].ReplicationTaskArn' --output text
    
    aws dms start-replication-task --replication-task-arn $taskArn --start-replication-task-type start-replication
    
    Write-Host "  ✅ Migration task started" -ForegroundColor Green
    
    # 8. Monitor progress
    Write-Host "Step 8: Monitoring migration progress..." -ForegroundColor Yellow
    Write-Host "  Use these commands to monitor:" -ForegroundColor Cyan
    Write-Host "  aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId" -ForegroundColor Gray
    Write-Host "  aws dynamodb scan --table-name LoanApp-IntegrationLogs-$Environment --select COUNT" -ForegroundColor Gray
    
    Write-Host "`n✅ DMS Migration Setup Complete!" -ForegroundColor Green
    Write-Host "Task ID: $taskId" -ForegroundColor White
    Write-Host "Monitor progress in AWS Console: DMS > Database migration tasks" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error during DMS setup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}