# Rerun DMS Task - Delete existing task and recreate
param(
    [Parameter(Mandatory=$true)]
    [string]$ReplicationInstanceId,
    [string]$Environment = "dev",
    [Parameter(Mandatory=$true)]
    [string]$PostgreSQLHost,
    [string]$PostgreSQLPassword = "WorkshopDB123!",
    [string]$MigrationType = "full-load-and-cdc"
)

Write-Host "🔄 Rerunning DMS Migration Task" -ForegroundColor Green

$taskId = "postgresql-to-dynamodb-$Environment"

try {
    # 1. Delete existing task if exists
    Write-Host "Step 1: Checking for existing DMS task..." -ForegroundColor Yellow
    
    $existingTask = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0]' 2>$null
    
    if ($existingTask -and $existingTask -ne "null") {
        Write-Host "  Found existing task: $taskId" -ForegroundColor Cyan
        
        $taskArn = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0].ReplicationTaskArn' --output text
        $taskStatus = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0].Status' --output text
        
        # Stop task if running
        if ($taskStatus -eq "running") {
            Write-Host "  Stopping running task..." -ForegroundColor Cyan
            aws dms stop-replication-task --replication-task-arn $taskArn --output text | Out-Null
            
            # Wait for task to stop
            do {
                Start-Sleep -Seconds 10
                $taskStatus = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0].Status' --output text
                Write-Host "  Task status: $taskStatus" -ForegroundColor Gray
            } while ($taskStatus -eq "stopping")
        }
        
        # Delete task
        Write-Host "  Deleting existing task..." -ForegroundColor Cyan
        aws dms delete-replication-task --replication-task-arn $taskArn --output text | Out-Null
        
        # Wait for deletion
        do {
            Start-Sleep -Seconds 5
            $taskExists = aws dms describe-replication-tasks --filters Name=replication-task-id,Values=$taskId --query 'ReplicationTasks[0]' 2>$null
        } while ($taskExists -and $taskExists -ne "null")
        
        Write-Host "  ✅ Existing task deleted" -ForegroundColor Green
    } else {
        Write-Host "  No existing task found" -ForegroundColor Gray
    }
    
    # 2. Create new task using existing script
    Write-Host "Step 2: Creating new DMS task..." -ForegroundColor Yellow
    
    & "./create-dms-task.ps1" -ReplicationInstanceId $ReplicationInstanceId -Environment $Environment -PostgreSQLHost $PostgreSQLHost -PostgreSQLPassword $PostgreSQLPassword -MigrationType $MigrationType
    
    Write-Host "`n✅ DMS Task Rerun Complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error during DMS task rerun: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}