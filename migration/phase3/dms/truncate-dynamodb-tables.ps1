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
    Write-Host "Truncating table: $table" -ForegroundColor Cyan
    
    # Check if table exists
    $tableExists = aws dynamodb describe-table --table-name $table --query 'Table.TableName' --output text 2>$null
    
    if ($tableExists -and $tableExists -ne "null") {
        # Get table key schema to know what keys to delete
        $keySchema = aws dynamodb describe-table --table-name $table --query 'Table.KeySchema' --output json | ConvertFrom-Json
        $hashKey = ($keySchema | Where-Object { $_.KeyType -eq "HASH" }).AttributeName
        $rangeKey = ($keySchema | Where-Object { $_.KeyType -eq "RANGE" }).AttributeName
        
        Write-Host "  Hash Key: $hashKey" -ForegroundColor Gray
        if ($rangeKey) { Write-Host "  Range Key: $rangeKey" -ForegroundColor Gray }
        
        # Scan and delete all items
        Write-Host "  Scanning and deleting items..." -ForegroundColor Gray
        
        do {
            if ($rangeKey) {
                # Table has both hash and range key
                $items = aws dynamodb scan --table-name $table --projection-expression "$hashKey, $rangeKey" --max-items 25 --output json | ConvertFrom-Json
            } else {
                # Table has only hash key
                $items = aws dynamodb scan --table-name $table --projection-expression "$hashKey" --max-items 25 --output json | ConvertFrom-Json
            }
            
            if ($items.Items -and $items.Items.Count -gt 0) {
                # Build batch delete request
                $deleteRequests = @()
                foreach ($item in $items.Items) {
                    $key = @{}
                    $key[$hashKey] = $item.$hashKey
                    if ($rangeKey) { $key[$rangeKey] = $item.$rangeKey }
                    
                    $deleteRequests += @{ "DeleteRequest" = @{ "Key" = $key } }
                }
                
                $batchRequest = @{ $table = $deleteRequests } | ConvertTo-Json -Depth 10
                aws dynamodb batch-write-item --request-items $batchRequest --output text | Out-Null
                
                Write-Host "    Deleted $($items.Items.Count) items" -ForegroundColor Gray
            }
        } while ($items.Items -and $items.Items.Count -gt 0)
        
        Write-Host "  ✅ Table truncated: $table (GSIs preserved)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Table not found: $table" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ DynamoDB tables truncated!" -ForegroundColor Green
Write-Host "Tables and GSIs preserved - only data deleted." -ForegroundColor White