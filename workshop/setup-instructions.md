# Workshop Setup Instructions
## AWS Database Modernization Workshop Environment Setup

### Prerequisites Checklist

**AWS Account Requirements**:
- [ ] AWS account with administrative access
- [ ] AWS CLI installed and configured
- [ ] Default region set to `us-east-1` or `us-west-2`

**Development Environment**:
- [ ] Visual Studio 2022 or VS Code with C# extension
- [ ] Amazon Q Developer extension installed and configured
- [ ] .NET 9 SDK installed
- [ ] SQL Server Management Studio or Azure Data Studio

**Required AWS Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:*",
        "dynamodb:*",
        "dms:*",
        "cloudformation:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 1: Clone Workshop Repository

```bash
git clone https://github.com/aws-samples/database-modernization-workshop.git
cd database-modernization-workshop
```

### Step 2: Deploy Baseline Application

**2.1 Create Local SQL Server Database**:
```powershell
# Run from LoanApplication directory
.\Scripts\Deploy-Database.ps1
```

**2.2 Restore Sample Data**:
```powershell
.\Scripts\Generate-SampleData.ps1 -RecordCount 200000
```

**2.3 Test Application**:
```bash
cd LoanApplication
dotnet run
```
Navigate to `https://localhost:7001/swagger` to verify API endpoints.

### Step 3: Configure Amazon Q Developer

**3.1 Install Q Developer Extension**:
- Visual Studio: Extensions → Manage Extensions → Search "Amazon Q"
- VS Code: Extensions → Search "Amazon Q Developer"

**3.2 Authenticate with AWS**:
```bash
aws configure sso
# Follow prompts to authenticate
```

**3.3 Test Q Developer Integration**:
Open any C# file and try the prompt:
```
@q Analyze this loan application codebase and identify the main components
```

### Step 4: Verify AWS Environment

**4.1 Test AWS CLI Access**:
```bash
aws sts get-caller-identity
aws rds describe-db-instances --region us-east-1
```

**4.2 Create Workshop IAM Role**:
```bash
aws iam create-role --role-name WorkshopRole --assume-role-policy-document file://Scripts/trust-policy.json
aws iam attach-role-policy --role-name WorkshopRole --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-role-policy --role-name WorkshopRole --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

### Step 5: Initialize Workshop Environment

**5.1 Set Environment Variables**:
```bash
export AWS_REGION=us-east-1
export WORKSHOP_PREFIX=dbmod-$(date +%s)
export DB_PASSWORD=$(openssl rand -base64 12)
```

**5.2 Create Parameter Store Values**:
```bash
aws ssm put-parameter --name "/workshop/db-password" --value "$DB_PASSWORD" --type "SecureString"
aws ssm put-parameter --name "/workshop/prefix" --value "$WORKSHOP_PREFIX" --type "String"
```

### Step 6: Validate Setup

**6.1 Database Connectivity Test**:
```sql
-- Run in SSMS/Azure Data Studio
SELECT COUNT(*) FROM LoanApplications; -- Should return ~200,000
EXEC sp_GetLoanSummary @StartDate = '2023-01-01', @EndDate = '2023-12-31';
```

**6.2 Application Health Check**:
```bash
curl -k https://localhost:7001/health
# Expected: {"status":"Healthy","totalDuration":"00:00:00.0123456"}
```

**6.3 Q Developer Functionality Test**:
Open `Controllers/LoanController.cs` and ask Q Developer:
```
Explain the loan approval logic in this controller
```

### Troubleshooting Common Issues

**Issue: Q Developer Not Responding**
```bash
# Restart AWS authentication
aws sso logout
aws configure sso
```

**Issue: Database Connection Failed**
- Verify SQL Server is running
- Check connection string in `appsettings.json`
- Ensure Windows Authentication is enabled

**Issue: AWS CLI Permission Denied**
```bash
# Verify IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

### Workshop Folder Structure

After setup completion, verify this structure exists:
```
workshop/
├── LoanApplication/          # Baseline .NET application
├── migration/               # Migration scripts and procedures
│   ├── phase1/             # RDS SQL Server migration
│   ├── phase2/             # PostgreSQL conversion
│   └── phase3/             # DynamoDB integration
├── Scripts/                # PowerShell automation scripts
└── CloudFormation/         # Infrastructure templates
```

### Ready to Start?

Once all checkboxes above are completed:

1. **Baseline Application**: Running locally with 200K+ loan records
2. **Q Developer**: Authenticated and responding to prompts
3. **AWS Environment**: CLI configured with proper permissions
4. **Workshop Materials**: All files accessible and organized

**Next Step**: Proceed to Phase 1 - Lift and Shift Migration to AWS RDS

---

**Support**: If you encounter issues during setup, use Q Developer to help troubleshoot:
```
@q I'm getting this error during workshop setup: [paste error message]
```