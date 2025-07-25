# AWS Database Modernization Workshop - Architecture Documentation

## 🏗️ System Overview

This workshop demonstrates a three-phase database modernization journey using a realistic Loan Application System. The baseline environment represents a typical enterprise application that will be migrated from on-premises SQL Server to modern AWS database services.

## 📊 Current Architecture (Baseline)

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │───▶│   IIS Server    │───▶│  SQL Server     │
│                 │    │                 │    │                 │
│ - Customers     │    │ - .NET 9.0 App  │    │ - Applications  │
│ - Loan Officers │    │ - ASP.NET Core  │    │ - Customers     │
│ - Admins        │    │ - MVC + Web API │    │ - Loans         │
└─────────────────┘    └─────────────────┘    │ - Payments      │
                                              │ - Documents     │
                                              │ - Audit Logs    │
                                              └─────────────────┘
```

### Technology Stack
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: .NET 9.0, ASP.NET Core MVC
- **Database**: SQL Server 2022 Web Edition
- **Web Server**: IIS 10.0
- **ORM**: Entity Framework Core 9.0
- **Authentication**: SQL Server Authentication

## 🗄️ Database Schema

### Core Tables
- **Applications** (5,000 records) - Main loan application data
- **Customers** (1,000 records) - Customer master data
- **Loans** (2,000 records) - Approved loan details
- **Payments** (50,000+ records) - Payment transaction history

### Supporting Tables
- **Branches** (50 records) - Bank branch information
- **LoanOfficers** (200 records) - Staff member details
- **Documents** (30,000 records) - Application document metadata
- **CreditChecks** (14,000+ records) - Credit verification records

### High-Volume Tables (Migration Candidates)
- **IntegrationLogs** (149,000+ records) - API and service logs
- **AuditTrail** (25,000+ records) - System change tracking

## 🔧 Application Components

### Controllers
- **HomeController** - Main application pages with database statistics
- **ApplicationsController** - RESTful API for loan applications
- **CustomersController** - Customer management API
- **DocsController** - Interactive documentation system

### Services & Business Logic
- **LoanService** - Loan lifecycle management
- **CreditCheckService** - Credit verification with mock external API
- **DSRCalculationService** - Debt-to-income ratio calculations

### Data Access
- **Entity Framework Core** - ORM with code-first approach
- **Repository Pattern** - Data access abstraction
- **Direct Context Queries** - Optimized for API endpoints

## 📈 Stored Procedures

### Simple Procedures (3)
- `sp_GetApplicationsByStatus` - Filter applications by status
- `sp_GetCustomerLoanHistory` - Customer's loan application history  
- `sp_UpdateApplicationStatus` - Change application status with audit

### Complex Procedure (1)
- `sp_ComprehensiveLoanEligibilityAssessment` - Advanced risk assessment featuring:
  - Common Table Expressions (CTEs)
  - Window Functions
  - Temporary Tables
  - Cursors
  - Dynamic SQL
  - Error Handling
  - Transactions

## 🚀 Migration Phases

### Phase 1: Lift & Shift to RDS SQL Server
**Objective**: Move to managed SQL Server with minimal changes
- Database backup and restore to RDS
- Connection string updates
- Infrastructure benefits (managed backups, monitoring)
- Performance baseline establishment

### Phase 2: Modernize to Aurora PostgreSQL  
**Objective**: Convert to open-source database platform
- Schema conversion using AWS SCT
- Data migration using AWS DMS
- Stored procedure conversion (T-SQL → PL/pgSQL)
- Application code updates for PostgreSQL

### Phase 3: NoSQL Integration
**Objective**: Optimize high-volume data with DynamoDB
- Migrate IntegrationLogs table to DynamoDB
- Design for time-series access patterns
- Implement hybrid data access (PostgreSQL + DynamoDB)
- Cost and performance optimization

## 🎯 Learning Objectives

### Technical Skills
- **Assessment**: Evaluate applications for cloud migration readiness
- **Strategy**: Choose appropriate migration patterns (Lift & Shift vs. Modernization)
- **Tools**: Use AWS DMS, SCT, and other migration services
- **Challenges**: Handle stored procedure conversion and data type mapping

### Business Outcomes
- **Cost Optimization**: Reduce licensing and operational costs
- **Performance**: Leverage cloud-native database optimizations
- **Scalability**: Implement auto-scaling and high availability
- **Innovation**: Enable modern application architectures

## 🔗 API Endpoints

The application exposes RESTful APIs for testing and integration:

- `GET /api/applications` - List all loan applications
- `GET /api/applications/count` - Get application count
- `GET /api/applications/status/{status}` - Filter by status
- `GET /api/customers` - List all customers  
- `GET /api/customers/{id}` - Get specific customer
- `GET /api/customers/count` - Get customer count

## 📚 Documentation

### Interactive Documentation
Access comprehensive documentation at:
- **Overview**: `/docs` - System overview with live database statistics
- **Architecture**: `/docs/architecture` - Detailed technical architecture
- **Database**: `/docs/database` - Complete schema documentation
- **Migration**: `/docs/migration` - Three-phase migration strategy

### Key Features
- **Live Data**: Real-time database statistics and sample queries
- **Interactive**: Clickable API endpoints and code examples
- **Comprehensive**: Architecture diagrams, migration plans, and best practices
- **Educational**: Learning objectives and hands-on exercises

## 🛠️ Deployment

### Prerequisites
- AWS EC2 Windows Server 2022 with SQL Server 2022 Web Edition
- Administrator access via RDP
- Internet connectivity for package downloads

### Quick Deployment
```powershell
# Clone repository
git clone https://github.com/yourusername/aws-modernize-workshop-db.git C:\Workshop

# Run complete deployment
cd C:\Workshop
.\deployment\fresh-ec2-deployment.ps1 -SQLPassword "WorkshopDB123!"
```

### Verification
- **Homepage**: http://localhost - Application with database statistics
- **Documentation**: http://localhost/docs - Interactive documentation
- **APIs**: All endpoints return proper JSON data

## 🎓 Workshop Flow

1. **Environment Setup** (30 minutes)
   - Deploy baseline application
   - Explore architecture and database
   - Establish performance baselines

2. **Phase 1: RDS Migration** (2-3 hours)
   - Create RDS SQL Server instance
   - Migrate database using backup/restore
   - Update application configuration
   - Validate functionality and performance

3. **Phase 2: PostgreSQL Conversion** (4-5 hours)
   - Use AWS SCT for schema analysis
   - Set up Aurora PostgreSQL cluster
   - Migrate data using AWS DMS
   - Convert stored procedures
   - Update application code
   - Test and optimize

4. **Phase 3: DynamoDB Integration** (2-3 hours)
   - Design DynamoDB table for logs
   - Migrate IntegrationLogs data
   - Implement hybrid data access
   - Validate performance improvements

## 📊 Success Metrics

### Technical Metrics
- **Functionality**: All features work after migration
- **Performance**: Meets or exceeds baseline performance
- **Data Integrity**: 100% data migration accuracy
- **Availability**: High availability configuration

### Business Metrics  
- **Cost Reduction**: Lower total cost of ownership
- **Operational Efficiency**: Reduced maintenance overhead
- **Scalability**: Improved ability to handle growth
- **Innovation**: Foundation for modern architectures

---

This architecture provides a realistic foundation for learning database modernization concepts, tools, and best practices in a hands-on workshop environment.