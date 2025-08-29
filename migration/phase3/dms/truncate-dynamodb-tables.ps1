# Truncate DynamoDB Tables
param(
    [string]$Environment = "dev"
)

Write-Host "🗑️ Truncating DynamoDB Tables" -ForegroundColor Yellow

$tables = @(
    "LoanApp-IntegrationLogs-$Environment",
    "LoanApp-Payments-$Environment"
)

foreach ($table in $tables) {
    Write-Host "Recreating table: $table" -ForegroundColor Cyan
    
    # Check if table exists
    $tableExists = aws dynamodb describe-table --table-name $table --query 'Table.TableName' --output text 2>$null
    
    if ($tableExists -and $tableExists -ne "null") {
        # Delete table
        Write-Host "  Deleting existing table..." -ForegroundColor Gray
        aws dynamodb delete-table --table-name $table --output text | Out-Null
        
        # Wait for deletion
        aws dynamodb wait table-not-exists --table-name $table
        Write-Host "  ✅ Table deleted" -ForegroundColor Green
    }
    
    # Recreate table based on table name
    Write-Host "  Creating new table..." -ForegroundColor Gray
    
    if ($table -like "*IntegrationLogs*") {
        # IntegrationLogs table with composite key and GSIs
        aws dynamodb create-table --table-name $table `
            --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S AttributeName=ApplicationId,AttributeType=N AttributeName=LogTimestamp,AttributeType=S AttributeName=CorrelationId,AttributeType=S AttributeName=ErrorStatus,AttributeType=S `
            --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE `
            --global-secondary-indexes IndexName=GSI1-ApplicationId-LogTimestamp,KeySchema=[{AttributeName=ApplicationId,KeyType=HASH},{AttributeName=LogTimestamp,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} IndexName=GSI2-CorrelationId-LogTimestamp,KeySchema=[{AttributeName=CorrelationId,KeyType=HASH},{AttributeName=LogTimestamp,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} IndexName=GSI3-ErrorStatus-LogTimestamp,KeySchema=[{AttributeName=ErrorStatus,KeyType=HASH},{AttributeName=LogTimestamp,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} `
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --output text | Out-Null
    } elseif ($table -like "*Payments*") {
        # Payments table with single key
        aws dynamodb create-table --table-name $table `
            --attribute-definitions AttributeName=PaymentId,AttributeType=N `
            --key-schema AttributeName=PaymentId,KeyType=HASH `
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --output text | Out-Null
    }
    
    # Wait for table to be active
    aws dynamodb wait table-exists --table-name $table
    Write-Host "  ✅ Table recreated: $table" -ForegroundColor Green
}

Write-Host "`n✅ DynamoDB tables recreated!" -ForegroundColor Green
Write-Host "Fresh tables with correct PK/SK and GSIs ready for migration." -ForegroundColor White