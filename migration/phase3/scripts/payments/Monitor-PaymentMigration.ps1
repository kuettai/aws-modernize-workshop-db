# Monitor-PaymentMigration.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$MigrationId,
    [int]$RefreshIntervalSeconds = 30
)

Write-Host "=== Payment Migration Monitor ===" -ForegroundColor Cyan
Write-Host "Migration ID: $MigrationId" -ForegroundColor Yellow
Write-Host "Refresh Interval: $RefreshIntervalSeconds seconds" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

do {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $elapsed = (Get-Date) - $startTime
    
    try {
        # Get migration state from DynamoDB
        $stateJson = aws dynamodb get-item `
            --table-name PaymentMigrationState `
            --key "{`"MigrationId`":{`"S`":`"$MigrationId`"}}" `
            --query 'Item' 2>$null
        
        if ($stateJson -and $stateJson -ne "null") {
            $state = $stateJson | ConvertFrom-Json
            
            $offset = [int]$state.LastProcessedOffset.N
            $errors = [int]$state.ErrorCount.N
            $status = $state.Status.S
            $lastUpdated = $state.LastUpdated.S
            
            # Calculate progress if total is available
            $progressText = "Processed: $offset"
            if ($state.TotalRecords) {
                $total = [int]$state.TotalRecords.N
                $progress = [math]::Round(($offset / $total) * 100, 1)
                $progressText = "Progress: $progress% ($offset/$total)"
            }
            
            $statusColor = switch ($status) {
                "InProgress" { "Green" }
                "Completed" { "Cyan" }
                "Failed" { "Red" }
                default { "Yellow" }
            }
            
            Write-Host "[$timestamp] Status: $status | $progressText | Errors: $errors | Elapsed: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor $statusColor
        } else {
            Write-Host "[$timestamp] Migration state not found - may not have started yet" -ForegroundColor Yellow
        }
        
        # Get DynamoDB table item count
        $itemCountJson = aws dynamodb scan `
            --table-name Payments `
            --select COUNT `
            --query 'Count' 2>$null
        
        if ($itemCountJson) {
            $itemCount = $itemCountJson
            Write-Host "[$timestamp] DynamoDB Items: $itemCount" -ForegroundColor Cyan
        }
        
        # Check if migration is finished
        if ($state -and ($state.Status.S -eq "Completed" -or $state.Status.S -eq "Failed")) {
            Write-Host ""
            Write-Host "Migration finished with status: $($state.Status.S)" -ForegroundColor $(if($state.Status.S -eq "Completed"){"Green"}else{"Red"})
            Write-Host "Total Duration: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
            break
        }
        
    } catch {
        Write-Host "[$timestamp] Error retrieving migration status: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep -Seconds $RefreshIntervalSeconds
    
} while ($true)

Write-Host "Monitoring stopped." -ForegroundColor Gray