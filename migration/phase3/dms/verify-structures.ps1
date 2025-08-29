# Verify PostgreSQL and DynamoDB table structures
param(
    [string]$Environment = "dev"
)

Write-Host "=== PostgreSQL Table Structures ===" -ForegroundColor Cyan

# Get PostgreSQL table structures
Write-Host "`nIntegrationLogs columns:" -ForegroundColor Yellow
psql -h pgaurora-instance-1.crco8oc6go5j.ap-southeast-1.rds.amazonaws.com -d postgres -U postgres -c "
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'dbo' AND table_name = 'IntegrationLogs'
ORDER BY ordinal_position;"

Write-Host "`nPayments columns:" -ForegroundColor Yellow  
psql -h pgaurora-instance-1.crco8oc6go5j.ap-southeast-1.rds.amazonaws.com -d postgres -U postgres -c "
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'dbo' AND table_name = 'Payments'
ORDER BY ordinal_position;"

Write-Host "`n=== DynamoDB Table Structures ===" -ForegroundColor Cyan

# Get DynamoDB table structures
Write-Host "`nLoanApp-IntegrationLogs-$Environment key schema:" -ForegroundColor Yellow
aws dynamodb describe-table --table-name "LoanApp-IntegrationLogs-$Environment" --query 'Table.KeySchema' --profile mmws

Write-Host "`nLoanApp-Payments-$Environment key schema:" -ForegroundColor Yellow
aws dynamodb describe-table --table-name "LoanApp-Payments-$Environment" --query 'Table.KeySchema' --profile mmws

Write-Host "`n=== Expected DMS Mapping ===" -ForegroundColor Green
Write-Host "IntegrationLogs: LogId (bigint) -> LogId (N), LogTimestamp (varchar) -> LogTimestamp (S)"
Write-Host "Payments: PaymentId (integer) -> PaymentId (N)"