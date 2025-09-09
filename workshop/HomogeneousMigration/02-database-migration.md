# 3. SQL Server DB Migration from EC2 to RDS using Native Backup/Restore

Now that we've confirmed RDS compatibility, we'll perform the actual migration using SQL Server's native backup and restore functionality through Amazon S3.

## Migration Method Selection

In this workshop, we are using the **native backup/restore method** for database migration. In real-life scenarios, the choice of migration method depends on multiple factors such as:
- Database size
- Available network bandwidth
- Acceptable cutover time/downtime window
- Business requirements and constraints
- Data consistency requirements

There are various ways to perform database migration including Database Migration Service (DMS), transactional replication, log shipping, and others. If you need guidance on selecting the most appropriate migration method for your specific use case, consider engaging an AWS Solution Architect to discuss the optimal approach.

**Workshop Focus:** For learning purposes, we'll use native backup/restore as it's straightforward and demonstrates the core migration concepts effectively.

> **Additional Reading:** For comprehensive guidance on SQL Server migration and modernization strategies, refer to the AWS blog post: [Migration & modernization strategies for SQL on AWS](https://aws.amazon.com/blogs/modernizing-with-aws/migration-modernization-strategies-sql-on-aws/). This resource provides detailed insights into various migration approaches and modernization pathways available on AWS.

## 3.1 Create Database Backup

### Step 1: Connect to SQL Server

1. Open **SQL Server Management Studio (SSMS)** from the Start menu
2. Connect to the local SQL Server instance:
   - Server name: `localhost` or `.`
   - Authentication: **SQL Server Authentication**
   - Login: `sa`
   - Password: Use the password from your workshop parameters
3. Click **Connect**

### Step 2: Create Database Backup

1. In SSMS Object Explorer, expand **Databases**
2. Right-click on the database named **"LoanApplicationDB"**
3. Select **Tasks** > **Back Up...**
4. In the **Back Up Database** dialog:
   - **Database**: Verify the correct database is selected
   - **Backup type**: Full
   - **Destination**: Click **Remove** to clear default path, then click **Add**
   - **File name**: Enter `C:\Backup\LoanApplicationDB.bak`
   - Click **OK** to create the backup directory if prompted
5. Click **OK** to start the backup process
6. Wait for the backup to complete successfully

## 3.2 Upload Backup to Amazon S3

### Step 1: Prepare S3 Bucket

1. Open **Windows PowerShell** as Administrator
2. The workshop environment has a pre-created S3 bucket for the migration. Use the bucket named:
   ```
   db-mod-[aws-account-id]
   ```
   > Replace `[aws-account-id]` with your actual AWS account ID from the workshop parameters

> **Note**: The EC2 instance has an IAM role with the necessary S3 permissions, so no AWS CLI configuration is required.

### Step 2: Upload Backup File to S3

1. Upload the backup file to S3:
   ```powershell
   aws s3 cp "C:\Backup\LoanApplicationDB.bak" s3://sql-migration-workshop-[aws-account-id]/
   ```
2. Verify the upload:
   ```powershell
   aws s3 ls s3://sql-migration-workshop-[aws-account-id]/
   ```
   > Replace `[aws-account-id]` with your actual AWS account ID from the workshop parameters
3. You should see your backup file listed

## 3.3 Create RDS SQL Server Instance

### Step 1: Create RDS Instance

1. Open the **AWS Management Console** and navigate to **RDS**
2. Click **Create database**
3. Choose **Standard create**
4. **Engine options**:
   - Engine type: **Microsoft SQL Server**
   - Edition: **SQL Server Web Edition**
   - Version: **Latest available**
5. **Templates**: **Dev/Test**
6. **Settings**:
   - DB instance identifier: `workshop-sqlserver-rds`
   - Master username: `admin`
   - Credentials management: Choose `Managed in AWS Secrets Manager - most secure`
7. **DB instance class**: `db.t3.large`
8. **Storage**: Keep default settings
9. **Connectivity**:
   - VPC: migration-workshop-vpc
   - Public access: **No** 
   - VPC security group: Choose `RDS SG`
10. **Additional configuration**: Keep the remaining configuration as default
11. Click **Create database**
12. Wait for the RDS instance to become **Available** (this may take 10-15 minutes)

## 3.4 Restore Database from S3 Backup

### Step 1: Create Option Group for Native Backup/Restore

1. In the RDS console, click **Option groups** in the left navigation
2. Click **Create group**
3. **Name**: `sqlserver-backup-restore`
4. **Description**: `Option group for SQL Server native backup/restore`
5. **Engine**: Microsoft SQL Server
6. **Major engine version**: Match your RDS instance version
7. Click **Create**
8. Select the created option group and click **Add option**
9. **Option name**: `SQLSERVER_BACKUP_RESTORE`
10. **IAM role**: Select `RDSRestoreRole`
11. Click **Add option**

### Step 2: Modify RDS Instance to Use Option Group

1. Go back to **Databases** and select your RDS instance
2. Click **Modify**
3. **Database options**:
   - Option group: Select `sqlserver-backup-restore`
4. **Scheduling of modifications**: **Apply immediately**
5. Click **Continue** and **Modify DB instance**
6. Wait for the modification to complete

### Step 3: Restore Database from S3

1. Retrieve the RDS password from AWS Secrets Manager:
   - Open the **AWS Management Console** and navigate to **Secrets Manager**
   - Locate the secret for your RDS instance (typically named similar to `rds-db-credentials/workshop-sqlserver-rds`)
   - Click on the secret name
   - Click **Retrieve secret value**
   - Copy the **password** value

2. Connect to your RDS instance using SSMS:
   - Server name: Use the RDS endpoint from the AWS console
   - Authentication: **SQL Server Authentication**
   - Login: `admin` (or the master username you created)
   - Password: Use the password retrieved from Secrets Manager

3. Execute the restore command:
   ```sql
   EXEC msdb.dbo.rds_restore_database 
       @restore_db_name='LoanApplicationDB',
       @s3_arn_to_restore_from='arn:aws:s3:::db-mod-[aws-account-id]/LoanApplicationDB.bak';
   ```

4. Monitor the restore progress:
   ```sql
   EXEC msdb.dbo.rds_task_status @db_name='LoanApplicationDB';
   ```

5. Wait for the task status to show **SUCCESS**

### Step 4: Verify Migration

1. In SSMS connected to RDS, expand **Databases**
2. Verify your database appears in the list
3. Expand the database and check tables, views, and stored procedures
4. Run a sample query to verify data integrity:
   ```sql
   USE [DatabaseName];
   SELECT COUNT(*) FROM [SampleTable];
   ```

> **Migration Complete**: Your SQL Server database has been successfully migrated from EC2 to Amazon RDS using native backup and restore functionality.

---
[← Back to Source Assessment](02-source-assessment.md) | [Next: Post Migration Validation →](04-post-migration-validation.md)