# Instructor Materials and Setup Scripts
## AWS Database Modernization Workshop

### Pre-Workshop Setup Script

```powershell
# Instructor-Setup.ps1
param(
    [Parameter(Mandatory=$true)]
    [int]$ParticipantCount,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

Write-Host "Setting up workshop for $ParticipantCount participants" -ForegroundColor Green

# Create workshop IAM roles
aws iam create-role --role-name WorkshopInstructorRole --assume-role-policy-document file://instructor-trust-policy.json
aws iam attach-role-policy --role-name WorkshopInstructorRole --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Pre-create common resources
for ($i = 1; $i -le $ParticipantCount; $i++) {
    $prefix = "workshop-participant-$i"
    Write-Host "Pre-creating resources for participant $i with prefix: $prefix"
    
    # Create S3 bucket for backups
    aws s3 mb s3://$prefix-backups-$(Get-Random) --region $Region
    
    # Create parameter store entries
    aws ssm put-parameter --name "/$prefix/db-password" --value (New-Guid).Guid.Substring(0,12) --type SecureString
}

Write-Host "Workshop setup complete" -ForegroundColor Green
```

### Instructor Checklist

#### 1 Week Before Workshop
- [ ] Test all CloudFormation templates
- [ ] Verify Q Developer functionality in demo environment
- [ ] Prepare backup slides for common issues
- [ ] Send pre-workshop setup instructions to participants

#### Day of Workshop
- [ ] Verify demo environment is working
- [ ] Test Q Developer authentication
- [ ] Prepare troubleshooting resources
- [ ] Set up screen sharing and recording

#### During Workshop
- [ ] Monitor participant progress
- [ ] Assist with Q Developer prompting techniques
- [ ] Document common issues for future improvements
- [ ] Collect real-time feedback

### Demo Environment Setup

**Baseline Application**:
- Pre-deployed with 200K+ sample records
- All stored procedures tested and functional
- Performance baselines established

**AWS Resources**:
- Demo RDS instance for troubleshooting examples
- Sample DynamoDB table with test data
- CloudFormation templates validated

### Common Issues and Solutions

**Q Developer Not Responding**:
- Check AWS authentication status
- Restart IDE and re-authenticate
- Verify network connectivity

**CloudFormation Failures**:
- Check service limits in target region
- Verify IAM permissions
- Use backup manual deployment procedures

**Performance Issues**:
- Monitor participant count vs. AWS limits
- Have alternative regions ready
- Prepare manual deployment scripts

### Success Metrics Tracking

**Technical Metrics**:
- Completion rate by phase
- Average time per phase
- Common error patterns

**Learning Metrics**:
- Q Developer usage proficiency
- Participant confidence levels
- Workshop satisfaction scores