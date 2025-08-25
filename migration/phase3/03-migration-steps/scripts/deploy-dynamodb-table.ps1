# Deploy DynamoDB Table for Phase 3 Migration
# AWS Database Modernization Workshop

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [string]$Region = "us-east-1",
    [string]$StackName = "loanapp-dynamodb-logs"
)

Write-Host "🚀 Deploying DynamoDB Infrastructure for Phase 3" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Stack Name: $StackName-$Environment" -ForegroundColor Cyan

# Check if AWS CLI is configured
try {
    $awsIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "✅ AWS Identity: $($awsIdentity.Arn)" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not configured. Please run 'aws configure'" -ForegroundColor Red
    exit 1
}

# Validate CloudFormation template
Write-Host "🔍 Validating CloudFormation template..." -ForegroundColor Yellow
aws cloudformation validate-template --template-body file://dynamodb-table.yaml --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Template validation failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Template validation successful" -ForegroundColor Green

# Deploy CloudFormation stack
Write-Host "📦 Deploying CloudFormation stack..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file "dynamodb-table.yaml" `
    --stack-name "$StackName-$Environment" `
    --parameter-overrides Environment=$Environment `
    --region $Region `
    --capabilities CAPABILITY_NAMED_IAM `
    --tags `
        Workshop=DatabaseModernization `
        Phase=Phase3-DynamoDB `
        Environment=$Environment

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ CloudFormation stack deployed successfully" -ForegroundColor Green
    
    # Get stack outputs
    Write-Host "📊 Retrieving stack outputs..." -ForegroundColor Yellow
    $outputs = aws cloudformation describe-stacks `
        --stack-name "$StackName-$Environment" `
        --region $Region `
        --query "Stacks[0].Outputs" `
        --output json | ConvertFrom-Json
    
    Write-Host "📋 Stack Outputs:" -ForegroundColor Cyan
    foreach ($output in $outputs) {
        Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor White
    }
    
    # Get table details
    $tableName = ($outputs | Where-Object { $_.OutputKey -eq "TableName" }).OutputValue
    
    Write-Host "🔍 Verifying table status..." -ForegroundColor Yellow
    $tableStatus = aws dynamodb describe-table --table-name $tableName --region $Region --query "Table.TableStatus" --output text
    
    if ($tableStatus -eq "ACTIVE") {
        Write-Host "✅ Table is ACTIVE and ready for use" -ForegroundColor Green
        
        # Display table information
        $tableInfo = aws dynamodb describe-table --table-name $tableName --region $Region --output json | ConvertFrom-Json
        
        Write-Host "📊 Table Information:" -ForegroundColor Cyan
        Write-Host "  Table Name: $($tableInfo.Table.TableName)" -ForegroundColor White
        Write-Host "  Table Status: $($tableInfo.Table.TableStatus)" -ForegroundColor White
        Write-Host "  Billing Mode: $($tableInfo.Table.BillingModeSummary.BillingMode)" -ForegroundColor White
        Write-Host "  Item Count: $($tableInfo.Table.ItemCount)" -ForegroundColor White
        Write-Host "  Table Size: $($tableInfo.Table.TableSizeBytes) bytes" -ForegroundColor White
        
        Write-Host "🔑 Global Secondary Indexes:" -ForegroundColor Cyan
        foreach ($gsi in $tableInfo.Table.GlobalSecondaryIndexes) {
            Write-Host "  - $($gsi.IndexName): $($gsi.IndexStatus)" -ForegroundColor White
        }
        
        # Test basic operations
        Write-Host "🧪 Testing basic table operations..." -ForegroundColor Yellow
        
        # Test write operation
        $testItem = @{
            PK = @{ S = "TestService-$(Get-Date -Format 'yyyy-MM-dd')" }
            SK = @{ S = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')#TEST001" }
            LogId = @{ N = "1" }
            LogType = @{ S = "TEST" }
            ServiceName = @{ S = "TestService" }
            LogTimestamp = @{ S = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')" }
            IsSuccess = @{ BOOL = $true }
            TTL = @{ N = "$([DateTimeOffset]::UtcNow.AddDays(1).ToUnixTimeSeconds())" }
        } | ConvertTo-Json -Depth 10
        
        aws dynamodb put-item --table-name $tableName --item $testItem --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Test write operation successful" -ForegroundColor Green
            
            # Test read operation
            aws dynamodb get-item `
                --table-name $tableName `
                --key "{`"PK`":{`"S`":`"TestService-$(Get-Date -Format 'yyyy-MM-dd')`"},`"SK`":{`"S`":`"$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')#TEST001`"}}" `
                --region $Region `
                --output table
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Test read operation successful" -ForegroundColor Green
            }
        }
        
    } else {
        Write-Host "⚠️  Table status: $tableStatus (not yet active)" -ForegroundColor Yellow
    }
    
    Write-Host "🎉 Phase 3 DynamoDB infrastructure deployment complete!" -ForegroundColor Green
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Update application configuration with table name: $tableName" -ForegroundColor White
    Write-Host "  2. Implement DynamoDB service layer" -ForegroundColor White
    Write-Host "  3. Test application integration" -ForegroundColor White
    
} else {
    Write-Host "❌ CloudFormation deployment failed" -ForegroundColor Red
    
    # Get stack events for troubleshooting
    Write-Host "📋 Recent stack events:" -ForegroundColor Yellow
    aws cloudformation describe-stack-events `
        --stack-name "$StackName-$Environment" `
        --region $Region `
        --query "StackEvents[0:5].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]" `
        --output table
    
    exit 1
}

Write-Host "✨ Deployment script completed" -ForegroundColor Green