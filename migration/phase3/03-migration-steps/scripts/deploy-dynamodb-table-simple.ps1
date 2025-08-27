# Deploy DynamoDB Table for Phase 3 Migration
# AWS Database Modernization Workshop

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [string]$Region = "us-west-2",
    [string]$StackName = "loanapp-dynamodb-logs"
)

Write-Host "Deploying DynamoDB Infrastructure for Phase 3" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

# Deploy CloudFormation stack
Write-Host "Deploying CloudFormation stack..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file "dynamodb-table.yaml" `
    --stack-name "$StackName-$Environment" `
    --parameter-overrides Environment=$Environment `
    --region $Region `
    --capabilities CAPABILITY_NAMED_IAM

if ($LASTEXITCODE -eq 0) {
    Write-Host "CloudFormation stack deployed successfully" -ForegroundColor Green
    
    # Get table name
    $tableName = aws cloudformation describe-stacks `
        --stack-name "$StackName-$Environment" `
        --region $Region `
        --query "Stacks[0].Outputs[?OutputKey=='TableName'].OutputValue" `
        --output text
    
    Write-Host "Table Name: $tableName" -ForegroundColor Cyan
    
    # Verify table status
    $tableStatus = aws dynamodb describe-table --table-name $tableName --region $Region --query "Table.TableStatus" --output text
    
    if ($tableStatus -eq "ACTIVE") {
        Write-Host "Table is ACTIVE and ready for use" -ForegroundColor Green
    } else {
        Write-Host "Table status: $tableStatus" -ForegroundColor Yellow
    }
    
    Write-Host "Phase 3 DynamoDB infrastructure deployment complete!" -ForegroundColor Green
    
} else {
    Write-Host "CloudFormation deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "Deployment script completed" -ForegroundColor Green