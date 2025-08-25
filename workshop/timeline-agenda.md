# Workshop Timeline and Agenda
## AWS Database Modernization Workshop (4-6 Hours)

### Pre-Workshop Setup (30 minutes)
**Timing**: Complete before workshop start
- [ ] Environment setup verification
- [ ] Q Developer authentication test
- [ ] Baseline application deployment confirmation

### Workshop Agenda

#### Opening Session (30 minutes)
**9:00 - 9:30 AM**

**Welcome & Introductions** (10 min)
- Workshop objectives and expected outcomes
- Participant introductions and experience levels

**Q Developer Setup Verification** (10 min)
- Test Q Developer connectivity
- Verify AWS authentication
- Quick functionality demonstration

**Architecture Overview** (10 min)
- Baseline loan application walkthrough
- Migration strategy overview
- Success metrics definition

---

#### Phase 1: Lift and Shift to RDS (90 minutes)
**9:30 - 11:00 AM**

**Current State Analysis** (20 min)
- Database assessment with Q Developer
- Performance baseline establishment
- Migration readiness evaluation

**RDS Infrastructure Setup** (25 min)
- CloudFormation deployment
- Security group configuration
- Parameter group optimization

**Data Migration Execution** (25 min)
- Database backup and restore
- Connection string updates
- Application testing

**Validation & Performance** (20 min)
- Data integrity verification
- Performance comparison
- Troubleshooting common issues

---

#### Break (15 minutes)
**11:00 - 11:15 AM**

---

#### Phase 2: PostgreSQL Modernization (120 minutes)
**11:15 AM - 1:15 PM**

**Schema Conversion Planning** (30 min)
- T-SQL to PostgreSQL analysis with Q Developer
- Stored procedure complexity assessment
- Migration strategy development

**Aurora PostgreSQL Setup** (20 min)
- Infrastructure deployment
- Configuration optimization
- Extension installation

**Schema and Data Migration** (35 min)
- Schema conversion execution
- Data migration with DMS
- Stored procedure refactoring

**Application Code Updates** (35 min)
- Entity Framework provider change
- Connection string modifications
- Business logic migration from stored procedures

---

#### Lunch Break (45 minutes)
**1:15 - 2:00 PM**

---

#### Phase 3: DynamoDB Integration (90 minutes)
**2:00 - 3:30 PM**

**NoSQL Design Workshop** (25 min)
- Access pattern analysis with Q Developer
- DynamoDB table design
- GSI strategy development

**Infrastructure & Service Layer** (25 min)
- DynamoDB table creation
- Service layer implementation
- Dual-write pattern setup

**Data Migration & Validation** (25 min)
- Batch migration execution
- Data integrity verification
- Performance testing

**Hybrid Architecture Testing** (15 min)
- End-to-end application testing
- Performance comparison
- Cost analysis review

---

#### Break (15 minutes)
**3:30 - 3:45 PM**

---

#### Wrap-up and Q&A (45 minutes)
**3:45 - 4:30 PM**

**Results Review** (20 min)
- Migration success metrics
- Performance improvements achieved
- Cost optimization results

**Q Developer Best Practices** (15 min)
- Key learnings and patterns
- Advanced usage techniques
- Integration workflow optimization

**Q&A and Next Steps** (10 min)
- Open discussion
- Additional resources
- Follow-up support options

---

### Alternative Timing Options

#### Compressed 4-Hour Format
- **Phase 1**: 60 minutes (reduce hands-on time)
- **Phase 2**: 90 minutes (focus on key conversions)
- **Phase 3**: 75 minutes (streamlined implementation)
- **Breaks**: 15 minutes total

#### Extended 6-Hour Format
- **Phase 1**: 120 minutes (additional troubleshooting)
- **Phase 2**: 150 minutes (comprehensive stored procedure conversion)
- **Phase 3**: 120 minutes (advanced DynamoDB patterns)
- **Additional**: 30 minutes for advanced Q Developer techniques

### Instructor Notes

**Preparation Checklist**:
- [ ] All CloudFormation templates tested
- [ ] Sample data generation verified
- [ ] Q Developer prompts validated
- [ ] Backup slides for common issues prepared

**Key Timing Considerations**:
- **Phase 2** typically requires most time due to stored procedure complexity
- **Q Developer interactions** add 10-15% to each phase duration
- **Troubleshooting buffer** of 15 minutes per phase recommended

**Success Indicators**:
- All participants complete Phase 1 migration
- 80%+ complete PostgreSQL conversion
- 70%+ successfully implement DynamoDB integration
- 100% demonstrate Q Developer usage proficiency