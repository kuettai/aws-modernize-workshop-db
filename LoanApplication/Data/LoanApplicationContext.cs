using Microsoft.EntityFrameworkCore;
using LoanApplication.Models;

namespace LoanApplication.Data
{
    public class LoanApplicationContext : DbContext
    {
        public LoanApplicationContext(DbContextOptions<LoanApplicationContext> options) : base(options)
        {
        }

        public DbSet<Branch> Branches { get; set; }
        public DbSet<LoanOfficer> LoanOfficers { get; set; }
        public DbSet<Customer> Customers { get; set; }
        public DbSet<Application> Applications { get; set; }
        public DbSet<Loan> Loans { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<Document> Documents { get; set; }
        public DbSet<CreditCheck> CreditChecks { get; set; }
        public DbSet<IntegrationLog> IntegrationLogs { get; set; }

    // Reporting Tables
    public DbSet<DailyApplicationSummary> DailyApplicationSummaries { get; set; }
    public DbSet<MonthlyLoanOfficerPerformance> MonthlyLoanOfficerPerformances { get; set; }
    public DbSet<WeeklyCustomerAnalytics> WeeklyCustomerAnalytics { get; set; }
    public DbSet<BatchJobExecutionLog> BatchJobExecutionLogs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Branch configuration
            modelBuilder.Entity<Branch>(entity =>
            {
                entity.HasKey(e => e.BranchId);
                entity.HasIndex(e => e.BranchCode).IsUnique();
                entity.Property(e => e.BranchCode).HasMaxLength(10);
                entity.Property(e => e.BranchName).HasMaxLength(100);
            });

            // LoanOfficer configuration
            modelBuilder.Entity<LoanOfficer>(entity =>
            {
                entity.HasKey(e => e.LoanOfficerId);
                entity.HasIndex(e => e.EmployeeId).IsUnique();
                entity.Property(e => e.EmployeeId).HasMaxLength(20);
                entity.HasOne(d => d.Branch)
                    .WithMany(p => p.LoanOfficers)
                    .HasForeignKey(d => d.BranchId);
            });

            // Customer configuration
            modelBuilder.Entity<Customer>(entity =>
            {
                entity.HasKey(e => e.CustomerId);
                entity.HasIndex(e => e.CustomerNumber).IsUnique();
                entity.HasIndex(e => e.SSN).IsUnique();
                entity.Property(e => e.CustomerNumber).HasMaxLength(20);
                entity.Property(e => e.MonthlyIncome).HasColumnType("decimal(12,2)");
            });

            // Application configuration
            modelBuilder.Entity<Application>(entity =>
            {
                entity.HasKey(e => e.ApplicationId);
                entity.HasIndex(e => e.ApplicationNumber).IsUnique();
                entity.Property(e => e.ApplicationNumber).HasMaxLength(20);
                entity.Property(e => e.RequestedAmount).HasColumnType("decimal(12,2)");
                entity.Property(e => e.DSRRatio).HasColumnType("decimal(5,2)");
                
                entity.HasOne(d => d.Customer)
                    .WithMany(p => p.Applications)
                    .HasForeignKey(d => d.CustomerId);
                
                entity.HasOne(d => d.LoanOfficer)
                    .WithMany(p => p.Applications)
                    .HasForeignKey(d => d.LoanOfficerId);
                
                entity.HasOne(d => d.Branch)
                    .WithMany(p => p.Applications)
                    .HasForeignKey(d => d.BranchId);
            });

            // Loan configuration
            modelBuilder.Entity<Loan>(entity =>
            {
                entity.HasKey(e => e.LoanId);
                entity.HasIndex(e => e.LoanNumber).IsUnique();
                entity.Property(e => e.LoanNumber).HasMaxLength(20);
                entity.Property(e => e.ApprovedAmount).HasColumnType("decimal(12,2)");
                entity.Property(e => e.InterestRate).HasColumnType("decimal(5,4)");
                entity.Property(e => e.MonthlyPayment).HasColumnType("decimal(10,2)");
                entity.Property(e => e.OutstandingBalance).HasColumnType("decimal(12,2)");
                
                entity.HasOne(d => d.Application)
                    .WithOne(p => p.Loan)
                    .HasForeignKey<Loan>(d => d.ApplicationId);
            });

            // Payment configuration
            modelBuilder.Entity<Payment>(entity =>
            {
                entity.HasKey(e => e.PaymentId);
                entity.Property(e => e.PaymentAmount).HasColumnType("decimal(10,2)");
                entity.Property(e => e.PrincipalAmount).HasColumnType("decimal(10,2)");
                entity.Property(e => e.InterestAmount).HasColumnType("decimal(10,2)");
                
                entity.HasOne(d => d.Loan)
                    .WithMany(p => p.Payments)
                    .HasForeignKey(d => d.LoanId);
            });

            // Document configuration
            modelBuilder.Entity<Document>(entity =>
            {
                entity.HasKey(e => e.DocumentId);
                entity.HasOne(d => d.Application)
                    .WithMany(p => p.Documents)
                    .HasForeignKey(d => d.ApplicationId);
            });

            // CreditCheck configuration
            modelBuilder.Entity<CreditCheck>(entity =>
            {
                entity.HasKey(e => e.CreditCheckId);
                entity.HasOne(d => d.Customer)
                    .WithMany(p => p.CreditChecks)
                    .HasForeignKey(d => d.CustomerId);
                
                entity.HasOne(d => d.Application)
                    .WithMany(p => p.CreditChecks)
                    .HasForeignKey(d => d.ApplicationId);
            });

            // IntegrationLog configuration
            modelBuilder.Entity<IntegrationLog>(entity =>
            {
                entity.HasKey(e => e.LogId);
                entity.HasOne(d => d.Application)
                    .WithMany(p => p.IntegrationLogs)
                    .HasForeignKey(d => d.ApplicationId);
            });

            // Reporting Tables Configuration
            modelBuilder.Entity<DailyApplicationSummary>(entity =>
            {
                entity.HasKey(e => e.SummaryId);
            });

            modelBuilder.Entity<MonthlyLoanOfficerPerformance>(entity =>
            {
                entity.HasKey(e => e.PerformanceId);
            });

            modelBuilder.Entity<WeeklyCustomerAnalytics>(entity =>
            {
                entity.HasKey(e => e.AnalyticsId);
            });

            modelBuilder.Entity<BatchJobExecutionLog>(entity =>
            {
                entity.HasKey(e => e.ExecutionId);
            });

            base.OnModelCreating(modelBuilder);
        }
    }
}