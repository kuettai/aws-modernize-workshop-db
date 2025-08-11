# Phase 1: Architecture Diagrams
## SQL Server to AWS RDS SQL Server Migration

### 🏗️ Current State (Baseline Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ON-PREMISES ENVIRONMENT                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │   Web Browser   │───▶│   EC2 Instance  │───▶│    SQL Server 2022     │  │
│  │                 │    │                 │    │                         │  │
│  │ • Users         │    │ • Windows 2022  │    │ • LoanApplicationDB     │  │
│  │ • Loan Officers │    │ • IIS 10.0      │    │ • 200K+ Records         │  │
│  │ • Admins        │    │ • .NET 9.0 App  │    │ • 4 Stored Procedures  │  │
│  │                 │    │ • Port 80       │    │ • Port 1433 (Local)    │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│                                                                             │
│  Connection String: Server=localhost;Database=LoanApplicationDB;...         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🚀 Target State (Phase 1 - RDS Migration)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │   Web Browser   │───▶│   EC2 Instance  │───▶│    RDS SQL Server       │  │
│  │                 │    │                 │    │                         │  │
│  │ • Users         │    │ • Windows 2022  │    │ • LoanApplicationDB     │  │
│  │ • Loan Officers │    │ • IIS 10.0      │    │ • db.t3.medium          │  │
│  │ • Admins        │    │ • .NET 9.0 App  │    │ • 20GB GP2 Storage     │  │
│  │                 │    │ • Port 80       │    │ • Port 1433             │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│                                                                             │
│  Connection String: Server=workshop-sqlserver-rds.xxx.rds.amazonaws.com... │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┤
│  │                        SUPPORTING SERVICES                              │
│  ├─────────────────────────────────────────────────────────────────────────┤
│  │                                                                         │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│  │  │   S3 Bucket     │  │ Security Groups │  │     CloudWatch          │ │
│  │  │                 │  │                 │  │                         │ │
│  │  │ • Backup Files  │  │ • RDS Access    │  │ • Performance Metrics  │ │
│  │  │ • Migration     │  │ • Port 1433     │  │ • CPU, Memory, IOPS     │ │
│  │  │   Artifacts     │  │ • EC2 → RDS     │  │ • Connection Count      │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │
│  └─────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🔄 Migration Flow Architecture

```
MIGRATION PROCESS FLOW
======================

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Source DB      │    │   S3 Bucket     │    │  Target RDS     │
│                 │    │                 │    │                 │
│ • SQL Server    │───▶│ • Backup Files  │───▶│ • RDS SQL       │
│ • localhost     │ 1  │ • .bak format   │ 2  │ • Managed       │
│ • Full Backup   │    │ • Encrypted     │    │ • Restored      │
└─────────────────┘    └─────────────────┘    └─────────────────┘

Step 1: BACKUP DATABASE TO DISK → Upload to S3
Step 2: RDS RESTORE FROM S3 → exec msdb.dbo.rds_restore_database

┌─────────────────────────────────────────────────────────────────────────────┐
│                           VALIDATION PROCESS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │  Row Count      │    │  Data Integrity │    │  Application Test       │  │
│  │  Validation     │    │  Validation     │    │                         │  │
│  │                 │    │                 │    │ • API Endpoints         │  │
│  │ • Compare       │───▶│ • Sample Data   │───▶│ • Stored Procedures     │  │
│  │   Source vs     │    │ • Key Records   │    │ • Performance           │  │
│  │   Target        │    │ • Relationships │    │ • Functionality         │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🔒 Security Architecture

```
SECURITY COMPONENTS
===================

┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC SECURITY                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┤
│  │                        SECURITY GROUPS                                  │
│  ├─────────────────────────────────────────────────────────────────────────┤
│  │                                                                         │
│  │  ┌─────────────────┐              ┌─────────────────────────────────────┐ │
│  │  │   EC2-SG        │              │         RDS-SG                      │ │
│  │  │                 │              │                                     │ │
│  │  │ Inbound:        │─────────────▶│ Inbound:                            │ │
│  │  │ • HTTP (80)     │              │ • MySQL/Aurora (1433) from EC2-SG  │ │
│  │  │ • RDP (3389)    │              │ • MySQL/Aurora (1433) from VPC     │ │
│  │  │                 │              │                                     │ │
│  │  │ Outbound:       │              │ Outbound:                           │ │
│  │  │ • All Traffic   │              │ • All Traffic                       │ │
│  │  └─────────────────┘              └─────────────────────────────────────┘ │
│  └─────────────────────────────────────────────────────────────────────────┘
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┤
│  │                        ENCRYPTION                                       │
│  ├─────────────────────────────────────────────────────────────────────────┤
│  │                                                                         │
│  │  ┌─────────────────┐              ┌─────────────────────────────────────┐ │
│  │  │ In Transit      │              │ At Rest                             │ │
│  │  │                 │              │                                     │ │
│  │  │ • TLS 1.2       │              │ • RDS Encryption                    │ │
│  │  │ • SSL Certs     │              │ • KMS Keys                          │ │
│  │  │ • Encrypted     │              │ • S3 Encryption                     │ │
│  │  │   Connections   │              │ • EBS Encryption                    │ │
│  │  └─────────────────┘              └─────────────────────────────────────┘ │
│  └─────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────────┘
```

### 📊 Monitoring Architecture

```
MONITORING AND OBSERVABILITY
============================

┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLOUDWATCH METRICS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │   RDS Metrics   │    │  EC2 Metrics    │    │    Custom Metrics       │  │
│  │                 │    │                 │    │                         │  │
│  │ • CPU Usage     │    │ • CPU Usage     │    │ • Application Logs      │  │
│  │ • Memory Usage  │    │ • Memory Usage  │    │ • API Response Times    │  │
│  │ • IOPS          │    │ • Disk Usage    │    │ • Error Rates           │  │
│  │ • Connections   │    │ • Network I/O   │    │ • Business Metrics      │  │
│  │ • Query Time    │    │                 │    │                         │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│                                │                                            │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┤
│  │                           ALARMS                                        │
│  ├─────────────────────────────────────────────────────────────────────────┤
│  │                                                                         │
│  │ • High CPU (> 80%)          • High Memory (> 85%)                      │ │
│  │ • High Connection Count     • Slow Query Performance                   │ │
│  │ • Storage Space Low         • Application Errors                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────────┘
```

### 💰 Cost Architecture

```
COST COMPONENTS
===============

┌─────────────────────────────────────────────────────────────────────────────┐
│                              MONTHLY COSTS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │   RDS Instance  │    │    Storage      │    │    Data Transfer        │  │
│  │                 │    │                 │    │                         │  │
│  │ db.t3.medium    │    │ 20GB GP2        │    │ • Backup Storage        │  │
│  │ ~$58/month      │    │ ~$2.30/month    │    │ • S3 Storage            │  │
│  │                 │    │                 │    │ • CloudWatch Logs       │  │
│  │ • 2 vCPU        │    │ • 3 IOPS/GB     │    │ ~$3/month               │  │
│  │ • 4GB RAM       │    │ • Auto-scaling  │    │                         │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│                                                                             │
│                    TOTAL ESTIMATED: ~$63/month                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┤
│  │                        COST OPTIMIZATION                                │
│  ├─────────────────────────────────────────────────────────────────────────┤
│  │                                                                         │
│  │ • Right-sized instance for workload                                    │ │
│  │ • GP2 storage with auto-scaling                                        │ │
│  │ • Single-AZ deployment (workshop only)                                 │ │
│  │ • 7-day backup retention                                               │ │
│  │ • Reserved Instance potential: 30-40% savings                          │ │
│  └─────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🔄 Rollback Architecture

```
ROLLBACK STRATEGY
=================

┌─────────────────────────────────────────────────────────────────────────────┐
│                           ROLLBACK COMPONENTS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │  Original DB    │    │  Config Backup  │    │   Rollback Script       │  │
│  │                 │    │                 │    │                         │  │
│  │ • Unchanged     │◄───│ • Connection    │◄───│ • Automated             │  │
│  │ • Available     │    │   Strings       │    │ • Tested                │  │
│  │ • Functional    │    │ • App Settings  │    │ • Quick Recovery        │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│                                                                             │
│                    ROLLBACK TIME: < 5 minutes                              │
└─────────────────────────────────────────────────────────────────────────────┘

ROLLBACK PROCESS:
1. Update connection string to localhost
2. Restart IIS application
3. Validate application functionality
4. Notify stakeholders of rollback completion
```

### 🎯 Network Flow Diagram

```
NETWORK TRAFFIC FLOW
====================

Internet                    AWS VPC (10.0.0.0/16)
   │                              │
   │ HTTPS (443)                  │
   │ HTTP (80)                    │
   ▼                              ▼
┌─────────────────┐    ┌─────────────────────────────────────┐
│  Internet       │    │         Public Subnet               │
│  Gateway        │───▶│         (10.0.1.0/24)              │
│                 │    │                                     │
└─────────────────┘    │  ┌─────────────────────────────────┐│
                       │  │        EC2 Instance             ││
                       │  │                                 ││
                       │  │ • Windows Server 2022           ││
                       │  │ • IIS + .NET Application        ││
                       │  │ • Security Group: EC2-SG        ││
                       │  └─────────────────────────────────┘│
                       └─────────────────────────────────────┘
                                          │
                                          │ SQL (1433)
                                          ▼
                       ┌─────────────────────────────────────┐
                       │         Private Subnet              │
                       │         (10.0.2.0/24)              │
                       │                                     │
                       │  ┌─────────────────────────────────┐│
                       │  │        RDS Instance             ││
                       │  │                                 ││
                       │  │ • SQL Server Web Edition        ││
                       │  │ • Multi-AZ: Disabled            ││
                       │  │ • Security Group: RDS-SG        ││
                       │  └─────────────────────────────────┘│
                       └─────────────────────────────────────┘
```

This architecture provides a clear visual representation of all components involved in Phase 1 migration, including the supporting AWS services, security configurations, and data flow patterns.