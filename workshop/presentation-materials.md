# Presentation Materials
## AWS Database Modernization Workshop

### Slide Deck Structure (45-60 slides)

#### Opening Slides (5 slides)
**Slide 1: Welcome**
- Workshop title and AWS branding
- Instructor introduction
- Workshop duration and format

**Slide 2: Agenda Overview**
- 3-phase modernization journey
- Timing and break schedule
- Q Developer integration highlights

**Slide 3: Learning Objectives**
- Technical skills to be gained
- AI-assisted development focus
- Expected outcomes and deliverables

**Slide 4: Prerequisites Check**
- Environment setup verification
- Q Developer authentication status
- AWS account access confirmation

**Slide 5: Workshop Rules**
- Hands-on approach emphasis
- Q Developer usage expectations
- Support and troubleshooting process

---

#### Architecture Overview (8 slides)

**Slide 6: Baseline Application**
- Personal loan processing system
- .NET 9 Web API architecture
- SQL Server database with 200K+ records

**Slide 7: Current State Analysis**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │───▶│  .NET 9 Web API │───▶│  SQL Server DB  │
│   (Swagger UI)  │    │  (Controllers)  │    │  (Entity Data)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Slide 8: Migration Strategy**
- Progressive 3-phase approach
- Risk mitigation through incremental changes
- Performance and cost optimization goals

**Slide 9: Success Metrics**
- Zero data loss requirement
- Performance improvement targets
- Cost optimization expectations

**Slide 10: Q Developer Integration**
- AI-assisted code analysis
- Automated script generation
- Best practices application

**Slide 11: Database Schema Overview**
- Core tables: LoanApplications, Customers, IntegrationLogs
- Stored procedures complexity
- Data volume and access patterns

**Slide 12: Migration Challenges**
- Schema conversion complexity
- Stored procedure refactoring
- Application code updates required

**Slide 13: Expected Outcomes**
- 98% cost reduction for logging workload
- 70% performance improvement for time-series queries
- Modern cloud-native architecture

---

#### Phase 1: RDS Migration (8 slides)

**Slide 14: Phase 1 Overview**
- Lift-and-shift strategy
- Minimal application changes
- AWS RDS SQL Server benefits

**Slide 15: RDS Architecture**
```
On-Premises SQL Server → AWS RDS SQL Server
- Same T-SQL compatibility
- Managed service benefits
- Enhanced security and backup
```

**Slide 16: Migration Process**
1. Infrastructure setup with CloudFormation
2. Database backup and S3 upload
3. Native backup restore to RDS
4. Connection string updates

**Slide 17: Q Developer Demo - Infrastructure Analysis**
```
@q Analyze this SQL Server database and recommend optimal RDS configuration for a financial services workload
```

**Slide 18: Performance Considerations**
- Instance class selection
- Storage optimization
- Parameter group tuning

**Slide 19: Security Enhancements**
- VPC isolation
- Encryption at rest and in transit
- IAM database authentication

**Slide 20: Validation Process**
- Data integrity verification
- Application functionality testing
- Performance baseline comparison

**Slide 21: Phase 1 Results**
- Migration success metrics
- Performance comparison
- Lessons learned

---

#### Phase 2: PostgreSQL Modernization (10 slides)

**Slide 22: Phase 2 Overview**
- Engine modernization benefits
- Open-source cost advantages
- Enhanced performance capabilities

**Slide 23: Conversion Challenges**
```
SQL Server T-SQL → PostgreSQL
- Data type mappings
- Stored procedure complexity
- Application layer updates
```

**Slide 24: Schema Conversion Strategy**
- Automated conversion tools
- Manual refinement requirements
- Q Developer assistance for complex cases

**Slide 25: Q Developer Demo - Stored Procedure Analysis**
```
@q Analyze this T-SQL stored procedure and recommend conversion strategy to PostgreSQL or C# application logic
```

**Slide 26: Stored Procedure Refactoring**
- Simple procedures: Direct conversion
- Complex procedures: Application logic migration
- Performance optimization opportunities

**Slide 27: Entity Framework Updates**
```csharp
// Before: SQL Server
services.AddDbContext<LoanContext>(options =>
    options.UseSqlServer(connectionString));

// After: PostgreSQL
services.AddDbContext<LoanContext>(options =>
    options.UseNpgsql(connectionString));
```

**Slide 28: DMS Migration Process**
- Replication instance setup
- Task configuration
- Monitoring and validation

**Slide 29: Application Testing Strategy**
- Unit test updates
- Integration test validation
- Performance regression testing

**Slide 30: Q Developer Demo - Code Conversion**
```
@q Convert this Entity Framework model from SQL Server to PostgreSQL with proper data type mappings
```

**Slide 31: Phase 2 Results**
- Conversion success rate
- Performance improvements
- Cost optimization achieved

---

#### Phase 3: DynamoDB Integration (8 slides)

**Slide 32: Phase 3 Overview**
- NoSQL integration benefits
- High-volume data optimization
- Hybrid architecture approach

**Slide 33: DynamoDB Design Principles**
```
Access Pattern Analysis:
1. Get logs by service and date
2. Query by status code
3. Time-range queries for audit
```

**Slide 34: Table Design Strategy**
```json
{
  "PartitionKey": "ServiceName-Date",
  "SortKey": "LogTimestamp#LogId",
  "GSI1": "StatusCode-LogTimestamp",
  "GSI2": "ServiceName-StatusCode"
}
```

**Slide 35: Q Developer Demo - NoSQL Design**
```
@q Analyze these IntegrationLogs access patterns and design optimal DynamoDB table structure with GSIs
```

**Slide 36: Hybrid Architecture**
```
PostgreSQL (Transactional) + DynamoDB (Operational Logs)
- Dual-write pattern implementation
- Consistency management
- Gradual migration approach
```

**Slide 37: Service Layer Implementation**
```csharp
public class HybridLoggingService
{
    // Dual-write to both PostgreSQL and DynamoDB
    // Q Developer helps implement error handling
}
```

**Slide 38: Migration Process**
- Batch data migration
- Validation and integrity checks
- Performance testing

**Slide 39: Phase 3 Results**
- 98% cost reduction achieved
- 70% performance improvement
- Scalability benefits demonstrated

---

#### Wrap-up and Next Steps (6 slides)

**Slide 40: Workshop Summary**
- Three phases completed successfully
- Technical achievements overview
- Q Developer usage patterns learned

**Slide 41: Performance Results**
```
Baseline → Phase 1 → Phase 2 → Phase 3
- Cost: $1000/month → $950 → $800 → $200
- Performance: 150ms → 145ms → 120ms → 45ms (logs)
- Scalability: Limited → Enhanced → Optimized → Unlimited
```

**Slide 42: Q Developer Best Practices**
- Discovery-based prompting
- Iterative refinement approach
- Integration with development workflow

**Slide 43: Architecture Evolution**
```
Legacy SQL Server → Modern Hybrid Cloud
- Managed services adoption
- NoSQL integration
- AI-assisted development
```

**Slide 44: Next Steps and Resources**
- Additional AWS database services
- Advanced Q Developer techniques
- Continued learning paths

**Slide 45: Q&A and Support**
- Workshop feedback collection
- Follow-up resources
- Contact information

---

### Live Demo Scripts

#### Demo 1: Q Developer Code Analysis (5 minutes)
**Setup**: Open LoanController.cs
**Prompt**: 
```
@q Analyze this loan controller and explain the business logic, identify any potential issues, and suggest improvements for cloud deployment
```
**Expected Output**: Detailed analysis with AWS best practices recommendations

#### Demo 2: Schema Conversion (7 minutes)
**Setup**: Display T-SQL CREATE TABLE statement
**Prompt**:
```
@q Convert this SQL Server table definition to PostgreSQL, including proper data type mappings and constraint conversions
```
**Expected Output**: Complete PostgreSQL DDL with explanations

#### Demo 3: Stored Procedure Refactoring (8 minutes)
**Setup**: Show complex stored procedure
**Prompt**:
```
@q This stored procedure is too complex for direct PostgreSQL conversion. Help me refactor it into C# service methods with proper separation of concerns
```
**Expected Output**: C# service class implementation

#### Demo 4: DynamoDB Design (6 minutes)
**Setup**: Show IntegrationLogs access patterns
**Prompt**:
```
@q Design a DynamoDB table for these log access patterns, including partition key, sort key, and GSI recommendations with cost optimization
```
**Expected Output**: Complete table design with CloudFormation template

---

### Interactive Elements

#### Polling Questions
1. "What's your biggest database modernization challenge?"
2. "How familiar are you with AI-assisted development?"
3. "Which phase seems most complex to you?"

#### Breakout Activities
- **Phase 1**: Pair programming for RDS setup
- **Phase 2**: Team discussion on stored procedure conversion strategy
- **Phase 3**: Group design session for DynamoDB access patterns

#### Q Developer Challenges
- **Challenge 1**: Generate migration script in under 2 minutes
- **Challenge 2**: Troubleshoot a connection issue using Q Developer
- **Challenge 3**: Optimize a query with AI assistance

---

### Backup Slides (10 slides)

**Backup 1-3**: Detailed troubleshooting for common issues
**Backup 4-6**: Advanced Q Developer techniques and prompts
**Backup 7-8**: Alternative migration strategies
**Backup 9-10**: Additional AWS database services overview

---

### Presentation Notes

**Timing Guidelines**:
- Spend 60% time on hands-on labs
- 25% on demonstrations and explanations
- 15% on Q&A and troubleshooting

**Q Developer Integration**:
- Demonstrate live prompting in every phase
- Show iterative refinement of AI responses
- Emphasize discovery-based learning approach

**Engagement Strategies**:
- Encourage participants to try their own Q Developer prompts
- Share screens for collaborative problem-solving
- Use real-time polling for engagement tracking