# AWS Database Modernization Workshop
## Progressive Migration from SQL Server to Modern Cloud Architecture with Amazon Q Developer

[![AWS](https://img.shields.io/badge/AWS-Database%20Modernization-orange)](https://aws.amazon.com/databases/)
[![.NET](https://img.shields.io/badge/.NET-9-blue)](https://dotnet.microsoft.com/)
[![Q Developer](https://img.shields.io/badge/Amazon%20Q-Developer-green)](https://aws.amazon.com/q/developer/)

A comprehensive hands-on workshop demonstrating database modernization through three progressive phases, showcasing AI-assisted development with Amazon Q Developer throughout the migration journey.

## 🎯 Workshop Overview

Transform a legacy .NET loan application through a **3-phase modernization journey**:

**Phase 1**: SQL Server → AWS RDS (Lift & Shift)  
**Phase 2**: RDS SQL Server → Aurora PostgreSQL (Engine Modernization)  
**Phase 3**: PostgreSQL + DynamoDB (Hybrid Architecture - Logs to NoSQL)

### Key Results Demonstrated
- **Up to 98% cost reduction** for high-volume logging workloads (DynamoDB vs PostgreSQL)
- **Up to 70% performance improvement** for time-series log queries with optimized NoSQL design
- **Zero data loss** throughout all migration phases
- **Production-ready** hybrid cloud architecture patterns

## 🚀 What You'll Learn

- **Progressive Migration Strategies** for risk mitigation
- **AI-Assisted Development** with Amazon Q Developer
- **Schema Conversion** from T-SQL to PostgreSQL
- **Stored Procedure Refactoring** to application logic
- **NoSQL Integration** with DynamoDB for operational data
- **Hybrid Architecture** patterns for modern applications

## 📋 Prerequisites

- AWS account with administrative access
- Visual Studio 2022 or VS Code with Amazon Q Developer extension
- .NET 9 SDK
- Basic knowledge of SQL Server and .NET development

## 🏗️ Architecture Evolution

```
Legacy On-Premises          →    Phase 1: AWS RDS        →    Phase 2: PostgreSQL    →    Phase 3: Hybrid Cloud
┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│  .NET App       │              │  .NET App       │          │  .NET App       │          │  .NET App       │
│  SQL Server     │              │  RDS SQL Server │          │  Aurora PostgreSQL│        │  PostgreSQL +   │
│  (On-Premises)  │              │  (Managed)      │          │  (Open Source)  │          │  DynamoDB       │
└─────────────────┘              └─────────────────┘          └─────────────────┘          └─────────────────┘
```

## 📁 Repository Structure

```
AIDev1/
├── LoanApplication/              # .NET 9 baseline application
│   ├── Controllers/             # API controllers
│   ├── Models/                  # Entity models
│   ├── Data/                    # Entity Framework context
│   └── Scripts/                 # Database deployment scripts
├── migration/                   # Migration procedures and scripts
│   ├── phase1/                  # RDS SQL Server migration
│   ├── phase2/                  # PostgreSQL conversion
│   └── phase3/                  # DynamoDB integration
├── workshop/                    # Workshop materials
│   ├── introduction.md          # Workshop overview and objectives
│   ├── setup-instructions.md    # Environment setup guide
│   ├── lab-instructions.md      # Hands-on lab procedures
│   ├── troubleshooting-guide.md # Issue resolution with Q Developer
│   └── cleanup-procedures.md    # Resource cleanup automation
├── quality-assurance/           # Testing and validation framework
└── q-developer-integration.md   # AI-assisted development guide
```

## 🎓 Workshop Timeline (4-6 hours)

| Phase | Duration | Objective | Key Technologies |
|-------|----------|-----------|------------------|
| **Setup** | 30 min | Environment preparation | AWS CLI, Q Developer, .NET 9 |
| **Phase 1** | 90 min | Lift-and-shift to RDS | CloudFormation, RDS, S3 |
| **Phase 2** | 120 min | PostgreSQL modernization | Aurora, DMS, Entity Framework |
| **Phase 3** | 90 min | DynamoDB integration | DynamoDB, AWS SDK, Hybrid patterns |
| **Wrap-up** | 45 min | Results review and Q&A | Performance analysis, cost optimization |

## 🤖 Amazon Q Developer Integration

This workshop showcases **AI-assisted development** throughout all phases:

### Discovery-Based Learning
Each phase includes guided prompts that help you:
- Understand current state and requirements
- Analyze migration complexity and risks  
- Develop optimal migration strategies
- Generate production-ready code and scripts

### Sample Q Developer Interactions
```
@q Analyze this SQL Server stored procedure and recommend PostgreSQL conversion strategy
@q Design optimal DynamoDB table structure for these high-volume log access patterns  
@q Generate CloudFormation template for Aurora PostgreSQL with financial services optimization
@q Create comprehensive data migration script with error handling and progress tracking
```

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/aws-database-modernization-workshop.git
cd aws-database-modernization-workshop
```

### 2. Setup Environment
```bash
# Deploy baseline application
cd LoanApplication
dotnet run

# Verify Q Developer integration
# Open Visual Studio/VS Code and test Q Developer connectivity
```

### 3. Follow Workshop Guide
1. **Setup Instructions**: `workshop/setup-instructions.md`
2. **Lab Procedures**: `workshop/lab-instructions.md`  
3. **Troubleshooting**: `workshop/troubleshooting-guide.md`

## 📊 Technical Specifications

### Baseline Application
- **.NET 9 Web API** with Entity Framework Core
- **SQL Server Database** with 200,000+ loan records
- **4 Stored Procedures** (3 simple + 1 complex with 200+ lines)
- **Financial Services Logic** including DSR calculations and credit checks

### Migration Targets
- **AWS RDS SQL Server** (Phase 1)
- **Aurora PostgreSQL** (Phase 2)  
- **DynamoDB** for high-volume logs (Phase 3)

### Performance Results
| Metric | Baseline | Phase 1 | Phase 2 | Phase 3 |
|--------|----------|---------|---------|---------|
| **Infrastructure Cost** | $500 | $1,000 | $800 | $650 |
| **Query Response** | 150ms | 145ms | 120ms | 120ms (business) / 45ms (logs) |
| **Scalability** | Limited | Enhanced | Optimized | Hybrid Optimized |

### Total Cost of Ownership (TCO) Analysis
| Cost Component | Baseline | Phase 1 | Phase 2 | Phase 3 |
|----------------|----------|---------|---------|---------|
| **Infrastructure** | $500 | $1,000 | $800 | $650 |
| **DBA/Operations** | $2,000 | $500 | $400 | $350 |
| **Licensing** | $300 | $0 | $0 | $0 |
| **Backup/DR** | $200 | $0 | $0 | $0 |
| **Monitoring** | $100 | $0 | $0 | $0 |
| **Monthly TCO** | **$3,100** | **$1,500** | **$1,200** | **$1,000** |
| **Annual Savings** | Baseline | $19,200 | $22,800 | $25,200 |

*TCO includes infrastructure, operational overhead, licensing, backup/DR, and monitoring costs*

**Note: These are typical benchmark figures for demonstration purposes, not actual costs**

## 🛠️ Key Features

### Production-Ready Implementation
- **CloudFormation Templates** for infrastructure automation
- **PowerShell Scripts** for migration automation  
- **Comprehensive Validation** with data integrity checks
- **Performance Benchmarking** and cost analysis
- **Emergency Rollback** procedures

### Educational Excellence  
- **Discovery-Based Learning** with 50+ Q Developer prompts
- **Progressive Complexity** from simple lift-and-shift to hybrid architecture
- **Real-World Scenarios** based on financial services requirements
- **Comprehensive Documentation** with troubleshooting guides

## 🔧 Advanced Features

### Phase 3: Hybrid Architecture Highlights
- **Dual-Write Pattern** for safe migration
- **Service Layer Abstraction** for seamless integration
- **Batch Migration Tools** with resume capability
- **Real-Time Monitoring** dashboard
- **Cost Optimization** demonstrating significant reduction potential

## 📚 Additional Resources

- **Q Developer Integration Guide**: Comprehensive AI-assisted development patterns
- **Migration Best Practices**: AWS database modernization strategies  
- **Troubleshooting Guide**: Common issues and Q Developer solutions
- **Performance Optimization**: Cloud-native database tuning techniques

## 🤝 Contributing

This workshop is designed for educational purposes and demonstrates production-ready migration patterns. Contributions welcome for:
- Additional migration scenarios
- Enhanced Q Developer prompts
- Performance optimizations
- Documentation improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Workshop Achievements

Upon completion, participants will have:
- ✅ **Migrated a complete application** through 3 database platforms
- ✅ **Mastered AI-assisted development** with Amazon Q Developer  
- ✅ **Implemented hybrid cloud architecture** with demonstrated cost optimization patterns
- ✅ **Applied AWS best practices** for database modernization
- ✅ **Gained hands-on experience** with real-world migration challenges

---

**Ready to modernize your databases?** Start with the [Workshop Introduction](workshop/introduction.md) and transform your legacy applications into modern, cloud-native architectures with the power of AI-assisted development.

[![Start Workshop](https://img.shields.io/badge/Start-Workshop-success?style=for-the-badge)](workshop/introduction.md)