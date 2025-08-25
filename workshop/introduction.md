# AWS Database Modernization Workshop
## From Legacy SQL Server to Modern Cloud Architecture

### Workshop Overview

Welcome to the AWS Database Modernization Workshop! This hands-on workshop guides you through a real-world database modernization journey, transforming a legacy .NET loan application from SQL Server to modern AWS services using a progressive 3-phase approach.

**What You'll Build**: Transform a financial services loan application through three distinct modernization phases, each addressing different aspects of cloud migration and modernization.

### Learning Objectives

By the end of this workshop, you will be able to:

1. **Assess Legacy Applications** for cloud migration readiness
2. **Execute Lift-and-Shift Migration** from on-premises SQL Server to AWS RDS
3. **Modernize Database Engine** from SQL Server to PostgreSQL with schema conversion
4. **Implement NoSQL Integration** using DynamoDB for high-volume operational data
5. **Leverage AI-Assisted Development** with Amazon Q Developer throughout the migration process

### Workshop Architecture Journey

#### Phase 1: Lift and Shift to AWS RDS SQL Server
- **Objective**: Move existing SQL Server database to AWS with minimal changes
- **Duration**: 90 minutes
- **Key Skills**: AWS RDS setup, data migration, connection string updates
- **Q Developer Focus**: Infrastructure analysis and migration script generation

#### Phase 2: Engine Modernization to PostgreSQL
- **Objective**: Convert from SQL Server to PostgreSQL for cost optimization and open-source benefits
- **Duration**: 120 minutes  
- **Key Skills**: Schema conversion, stored procedure refactoring, Entity Framework updates
- **Q Developer Focus**: T-SQL to PostgreSQL conversion and application code updates

#### Phase 3: NoSQL Integration with DynamoDB
- **Objective**: Migrate high-volume logs to DynamoDB for scalability and cost efficiency
- **Duration**: 90 minutes
- **Key Skills**: NoSQL data modeling, hybrid architecture, dual-write patterns
- **Q Developer Focus**: NoSQL design patterns and AWS SDK integration

### Target Application: Personal Loan Processing System

**Business Context**: A financial services application that processes personal loan applications with debt-service-ratio (DSR) calculations and credit check integrations.

**Technical Stack**:
- **.NET 9 Web API** with Entity Framework Core
- **SQL Server Database** with 200,000+ loan records
- **4 Stored Procedures** including complex financial calculations
- **Integration Logging** for audit and compliance requirements

### Amazon Q Developer Integration

This workshop showcases AI-assisted development throughout the modernization process:

**Discovery-Based Learning**: Each phase includes guided prompts that help you understand the current state, analyze requirements, and develop migration strategies using Q Developer.

**Code Analysis & Conversion**: Learn to use Q Developer for:
- Analyzing existing T-SQL stored procedures
- Converting database schemas between engines
- Refactoring application code for new data access patterns
- Generating migration and validation scripts

**Best Practices Application**: Q Developer helps identify optimization opportunities and apply AWS best practices throughout the migration.

### Workshop Prerequisites

**Technical Requirements**:
- Basic knowledge of SQL Server and .NET development
- Familiarity with AWS services (RDS, DynamoDB)
- Understanding of database concepts and Entity Framework

**AWS Account Setup**:
- AWS account with appropriate permissions
- AWS CLI configured
- Amazon Q Developer enabled in your IDE

**Development Environment**:
- Visual Studio or VS Code with Q Developer extension
- .NET 9 SDK
- SQL Server Management Studio or Azure Data Studio

### Expected Outcomes

**Technical Achievements**:
- Successfully migrate a production-like application through 3 modernization phases
- Implement hybrid data architecture with both relational and NoSQL components
- Achieve 98% cost reduction for high-volume logging workloads
- Demonstrate 70% performance improvement for time-series queries

**Learning Achievements**:
- Master progressive modernization strategies
- Understand when to use different AWS database services
- Learn AI-assisted development workflows with Q Developer
- Gain hands-on experience with real-world migration challenges

### Workshop Structure

Each phase follows a consistent learning pattern:

1. **Current State Analysis** - Understand what you're working with
2. **Requirements Assessment** - Define migration goals and constraints  
3. **Strategy Development** - Plan the migration approach
4. **Implementation** - Execute the migration with Q Developer assistance
5. **Validation & Testing** - Verify successful migration
6. **Performance Analysis** - Measure improvements and optimizations

### Success Metrics

**Migration Success Indicators**:
- Zero data loss during all migration phases
- Application functionality maintained throughout
- Performance improvements demonstrated
- Cost optimization achieved

**Learning Success Indicators**:
- Confident use of Q Developer for code analysis and generation
- Understanding of when to apply different modernization strategies
- Ability to troubleshoot common migration issues
- Knowledge of AWS database service selection criteria

### Getting Started

Ready to begin your modernization journey? Let's start by setting up your development environment and exploring the baseline loan application that we'll be transforming throughout this workshop.

**Next Steps**:
1. Review the setup instructions
2. Deploy the baseline application
3. Explore the current architecture with Q Developer
4. Begin Phase 1: Lift and Shift to AWS RDS

---

*This workshop demonstrates real-world database modernization patterns using AWS services and AI-assisted development with Amazon Q Developer. All code examples and procedures are production-ready and follow AWS best practices.*