# Verify PostgreSQL and DynamoDB table structures
param(
    [string]$Environment = "dev"
)

Write-Host "=== PostgreSQL Table Structures ===" -ForegroundColor Cyan
Write-Host "Run these queries in DBeaver:" -ForegroundColor Yellow

Write-Host "`n-- IntegrationLogs columns:"
Write-Host "SELECT column_name, data_type, is_nullable "
Write-Host "FROM information_schema.columns "
Write-Host "WHERE table_schema = 'dbo' AND table_name = 'IntegrationLogs'"
Write-Host "ORDER BY ordinal_position;"

Write-Host "`n-- Payments columns:"
Write-Host "SELECT column_name, data_type, is_nullable "
Write-Host "FROM information_schema.columns "
Write-Host "WHERE table_schema = 'dbo' AND table_name = 'Payments'"
Write-Host "ORDER BY ordinal_position;"

Write-Host "`n=== DynamoDB Table Structures ===" -ForegroundColor Cyan

# Get DynamoDB table structures
Write-Host "`nLoanApp-IntegrationLogs-$Environment key schema:" -ForegroundColor Yellow
aws dynamodb describe-table --table-name "LoanApp-IntegrationLogs-$Environment" --query 'Table.KeySchema' --profile mmws

Write-Host "`nLoanApp-Payments-$Environment key schema:" -ForegroundColor Yellow
aws dynamodb describe-table --table-name "LoanApp-Payments-$Environment" --query 'Table.KeySchema' --profile mmws

Write-Host "`n=== Expected DMS Mapping ===" -ForegroundColor Green
Write-Host "IntegrationLogs: LogId (bigint) -> LogId (N), LogTimestamp (varchar) -> LogTimestamp (S)"
Write-Host "Payments: PaymentId (integer) -> PaymentId (N)"