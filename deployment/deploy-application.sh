#!/bin/bash
# =============================================
# Application Deployment Script for Loan Application System
# Bash script for .NET application deployment
# =============================================

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/LoanApplication"
PUBLISH_DIR="$PROJECT_ROOT/deployment/publish"
LOG_FILE="$PROJECT_ROOT/deployment/deployment-$(date +%Y%m%d-%H%M%S).log"

# Default values
ENVIRONMENT="Development"
CONNECTION_STRING=""
SKIP_BUILD=false
SKIP_TESTS=false

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy the Loan Application System .NET application

OPTIONS:
    -e, --environment ENV       Target environment (Development, Staging, Production)
    -c, --connection-string CS  Database connection string
    -s, --skip-build           Skip the build process
    -t, --skip-tests           Skip running tests
    -h, --help                 Show this help message

EXAMPLES:
    $0 --environment Production --connection-string "Server=prod-db;Database=LoanApplicationDB;..."
    $0 --skip-build --skip-tests
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--connection-string)
            CONNECTION_STRING="$2"
            shift 2
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -t|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

log "INFO" "Starting application deployment for Loan Application System"
log "INFO" "Environment: $ENVIRONMENT"
log "INFO" "Project Root: $PROJECT_ROOT"
log "INFO" "Application Directory: $APP_DIR"

# =============================================
# 1. Validate Prerequisites
# =============================================
log "INFO" "Validating prerequisites..."

# Check if .NET SDK is installed
if ! command -v dotnet &> /dev/null; then
    error_exit ".NET SDK is not installed or not in PATH"
fi

DOTNET_VERSION=$(dotnet --version)
log "INFO" ".NET SDK Version: $DOTNET_VERSION"

# Check if application directory exists
if [ ! -d "$APP_DIR" ]; then
    error_exit "Application directory not found: $APP_DIR"
fi

# Check if project file exists
if [ ! -f "$APP_DIR/LoanApplication.csproj" ]; then
    error_exit "Project file not found: $APP_DIR/LoanApplication.csproj"
fi

# =============================================
# 2. Clean Previous Build
# =============================================
log "INFO" "Cleaning previous build artifacts..."
rm -rf "$PUBLISH_DIR"
mkdir -p "$PUBLISH_DIR"

cd "$APP_DIR"
dotnet clean --configuration Release || error_exit "Failed to clean project"

# =============================================
# 3. Restore NuGet Packages
# =============================================
log "INFO" "Restoring NuGet packages..."
dotnet restore || error_exit "Failed to restore NuGet packages"

# =============================================
# 4. Build Application (Optional)
# =============================================
if [ "$SKIP_BUILD" = false ]; then
    log "INFO" "Building application..."
    dotnet build --configuration Release --no-restore || error_exit "Failed to build application"
    log "INFO" "Build completed successfully"
else
    log "INFO" "Skipping build process"
fi

# =============================================
# 5. Run Tests (Optional)
# =============================================
if [ "$SKIP_TESTS" = false ]; then
    log "INFO" "Running tests..."
    if [ -d "$PROJECT_ROOT/LoanApplication.Tests" ]; then
        cd "$PROJECT_ROOT/LoanApplication.Tests"
        dotnet test --configuration Release --no-build --logger "console;verbosity=minimal" || error_exit "Tests failed"
        log "INFO" "All tests passed"
    else
        log "WARNING" "Test project not found, skipping tests"
    fi
else
    log "INFO" "Skipping tests"
fi

# =============================================
# 6. Update Configuration
# =============================================
log "INFO" "Updating application configuration..."

cd "$APP_DIR"

# Update appsettings for target environment
APPSETTINGS_FILE="appsettings.$ENVIRONMENT.json"
if [ ! -f "$APPSETTINGS_FILE" ]; then
    log "INFO" "Creating $APPSETTINGS_FILE"
    cp "appsettings.json" "$APPSETTINGS_FILE"
fi

# Update connection string if provided
if [ -n "$CONNECTION_STRING" ]; then
    log "INFO" "Updating connection string for $ENVIRONMENT environment"
    
    # Create temporary JSON with updated connection string
    cat > temp_config.json << EOF
{
  "ConnectionStrings": {
    "DefaultConnection": "$CONNECTION_STRING"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "LoanSettings": {
    "MaxDSRRatio": 40.0,
    "MinCreditScore": 600,
    "MaxLoanAmount": 1000000,
    "MinLoanAmount": 1000,
    "DefaultInterestRate": 0.08
  },
  "CreditCheckSettings": {
    "MockMode": $([ "$ENVIRONMENT" = "Development" ] && echo "true" || echo "false"),
    "DefaultCreditBureau": "Experian",
    "CacheExpiryHours": 24
  }
}
EOF
    
    mv temp_config.json "$APPSETTINGS_FILE"
    log "INFO" "Configuration updated successfully"
else
    log "WARNING" "No connection string provided, using default configuration"
fi

# =============================================
# 7. Publish Application
# =============================================
log "INFO" "Publishing application..."

dotnet publish \
    --configuration Release \
    --output "$PUBLISH_DIR" \
    --no-build \
    --runtime linux-x64 \
    --self-contained false \
    || error_exit "Failed to publish application"

log "INFO" "Application published to: $PUBLISH_DIR"

# =============================================
# 8. Create Deployment Package
# =============================================
log "INFO" "Creating deployment package..."

cd "$PROJECT_ROOT/deployment"
PACKAGE_NAME="LoanApplication-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).tar.gz"

tar -czf "$PACKAGE_NAME" -C publish . || error_exit "Failed to create deployment package"

log "INFO" "Deployment package created: $PACKAGE_NAME"

# =============================================
# 9. Generate Deployment Scripts
# =============================================
log "INFO" "Generating deployment scripts..."

# Create systemd service file for Linux deployment
cat > "$PROJECT_ROOT/deployment/loanapplication.service" << EOF
[Unit]
Description=Loan Application System
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/dotnet $PUBLISH_DIR/LoanApplication.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=loanapplication
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=$ENVIRONMENT
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

# Create startup script
cat > "$PROJECT_ROOT/deployment/start-application.sh" << 'EOF'
#!/bin/bash
# Startup script for Loan Application System

APP_DIR="/opt/loanapplication"
LOG_DIR="/var/log/loanapplication"

# Create log directory if it doesn't exist
sudo mkdir -p "$LOG_DIR"
sudo chown www-data:www-data "$LOG_DIR"

# Start the application
cd "$APP_DIR"
exec /usr/bin/dotnet LoanApplication.dll
EOF

chmod +x "$PROJECT_ROOT/deployment/start-application.sh"

# Create installation script
cat > "$PROJECT_ROOT/deployment/install.sh" << EOF
#!/bin/bash
# Installation script for Loan Application System

set -e

INSTALL_DIR="/opt/loanapplication"
SERVICE_NAME="loanapplication"

echo "Installing Loan Application System..."

# Create application directory
sudo mkdir -p "\$INSTALL_DIR"

# Extract application files
sudo tar -xzf "$PACKAGE_NAME" -C "\$INSTALL_DIR"

# Set permissions
sudo chown -R www-data:www-data "\$INSTALL_DIR"
sudo chmod +x "\$INSTALL_DIR/LoanApplication"

# Install systemd service
sudo cp loanapplication.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "\$SERVICE_NAME"

echo "Installation completed successfully!"
echo "To start the service: sudo systemctl start \$SERVICE_NAME"
echo "To check status: sudo systemctl status \$SERVICE_NAME"
echo "To view logs: sudo journalctl -u \$SERVICE_NAME -f"
EOF

chmod +x "$PROJECT_ROOT/deployment/install.sh"

# =============================================
# 10. Deployment Summary
# =============================================
log "INFO" "=== DEPLOYMENT SUMMARY ==="
log "INFO" "Environment: $ENVIRONMENT"
log "INFO" "Build: $([ "$SKIP_BUILD" = false ] && echo "Completed" || echo "Skipped")"
log "INFO" "Tests: $([ "$SKIP_TESTS" = false ] && echo "Passed" || echo "Skipped")"
log "INFO" "Publish Directory: $PUBLISH_DIR"
log "INFO" "Deployment Package: $PACKAGE_NAME"
log "INFO" "Service File: loanapplication.service"
log "INFO" "Installation Script: install.sh"
log "INFO" "Startup Script: start-application.sh"
log "INFO" "Log File: $LOG_FILE"
log "INFO" "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="

# Display next steps
cat << EOF

NEXT STEPS:
1. Copy the deployment package to your target server:
   scp $PACKAGE_NAME user@server:/tmp/

2. On the target server, run the installation:
   cd /tmp && sudo ./install.sh

3. Start the application service:
   sudo systemctl start loanapplication

4. Verify the deployment:
   curl http://localhost:5000/health (if health check endpoint exists)
   sudo systemctl status loanapplication

EOF

log "INFO" "Deployment script completed successfully"