# =============================================
# Multi-stage Dockerfile for Loan Application System
# Optimized for production deployment
# =============================================

# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project files
COPY LoanApplication/LoanApplication.csproj LoanApplication/
RUN dotnet restore LoanApplication/LoanApplication.csproj

# Copy source code
COPY LoanApplication/ LoanApplication/

# Build application
WORKDIR /src/LoanApplication
RUN dotnet build LoanApplication.csproj -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish LoanApplication.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Create non-root user for security
RUN groupadd -r loanapp && useradd -r -g loanapp loanapp

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy published application
COPY --from=publish /app/publish .

# Create logs directory
RUN mkdir -p /app/logs && chown -R loanapp:loanapp /app

# Switch to non-root user
USER loanapp

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Set entry point
ENTRYPOINT ["dotnet", "LoanApplication.dll"]