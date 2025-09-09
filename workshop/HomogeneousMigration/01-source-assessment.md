# 2. Source DB Assessment using SQLServerTools

## Understanding the Importance of Pre-Assessment

Before performing any database migration, conducting a thorough source database assessment is crucial for ensuring a successful migration. Here's why this step is essential:

**Why Source DB Assessment is Important:**

- **Identify compatibility issues**: Discover features, configurations, or objects that may not be supported in Amazon RDS SQL Server
- **Estimate migration complexity**: Understand the scope of work required and potential challenges ahead
- **Plan resource requirements**: Determine the appropriate RDS instance size, storage, and configuration needed
- **Minimize downtime**: Identify potential blockers early to avoid surprises during the actual migration
- **Cost estimation**: Get accurate sizing information to estimate RDS costs and optimize instance selection
- **Risk mitigation**: Uncover dependencies, custom configurations, or third-party tools that need special handling
- **Migration strategy selection**: Choose the most appropriate migration method based on database size, complexity, and downtime requirements

The SQL Server assessment will help you understand:
- SQL Server version and edition compatibility
- Enabled SQL Server features and their RDS compatibility
- Performance characteristics and resource utilization (CPU, memory, IOPS, throughput)
- Right-sizing recommendations for RDS instances
- High availability configurations (FCI, Always On)
- Migration path recommendations (RDS vs RDS Custom vs EC2)

## SQLServerTools Overview

We'll be using the AWS SQLServerTools repository, which provides two complementary tools for SQL Server migration assessment:

**1. RDS Discovery Tool**
- **Purpose**: Quickly scan your SQL Server to check RDS compatibility
- **What it does**: Automatically checks 20+ SQL Server features and determines if your database can migrate to:
  - Amazon RDS (fully managed)
  - RDS Custom (more control)
  - EC2 (self-managed)
- **Output**: Excel report with compatibility recommendations
- **Runtime**: Lightweight, non-invasive scan that takes just a few minutes

**2. SQL Server Assessment Tool (SSAT)**
- **Purpose**: Analyze your SQL Server's resource usage for right-sizing on AWS
- **What it does**: Monitors CPU, memory, IOPS, and throughput over a specified time period
- **Output**: Detailed performance data and RDS instance size recommendations
- **Runtime**: Configurable monitoring period (typically 60+ minutes for accurate data)

**How They Work Together:**
1. Run RDS Discovery first to check compatibility
2. Run SSAT on compatible servers to determine optimal AWS sizing
3. Use both reports to plan your migration strategy and estimate costs

Both tools are Windows-based PowerShell scripts that require minimal setup and have very low impact on your production systems.

## Step-by-Step Assessment Instructions

### Step 1: Connect to the Source SQL Server EC2 Instance

1. Open the AWS Management Console and navigate to **EC2**
2. In the EC2 dashboard, click on **Instances** in the left navigation pane
3. Locate and select the EC2 instance named **"Self-Managed SQL Server"**
4. Click the **Connect** button at the top of the page
5. In the connection options, select **RDP client** tab
6. Select **Connect using Fleet Manager** and click **Fleet Manager Remote Desktop**
7. Select **User credentials** and enter `Administrator` as the Username
8. Retrieve your password from the workshop parameters
> ⚠️ **Note for Workshop Development**: Steps 7-8 will be updated based on the final AMI configuration and password handling mechanism once the workshop environment is finalized.
9. Click **Connect** to establish the RDP session
10. The Fleet Manager will open a browser-based RDP session to your SQL Server EC2 instance
11. Once connected, you should see the Windows desktop of your SQL Server machine

> **Note**: Fleet Manager provides secure, browser-based access to your EC2 instances without requiring direct RDP access or managing key pairs. The connection is established through the Systems Manager Agent (SSM Agent) that's pre-installed on the instance.

### Step 2: Download SQLServerTools

Once connected to the SQL Server EC2 instance, you need to download the SQLServerTools from the AWS GitHub repository.

**Option A: Using Windows UI and Microsoft Edge (Primary Method)**

1. Open **Microsoft Edge** browser from the taskbar or Start menu
2. Navigate to the SQLServerTools repository: `https://github.com/aws-samples/sqlservertools`
3. Click the green **Code** button on the repository page
4. Select **Download ZIP** from the dropdown menu
5. Click **Save** if prompted by the browser (this may happen automatically)
6. The file `sqlservertools-main.zip` will be downloaded to the **Downloads** folder
7. Open **File Explorer** and navigate to the **Downloads** folder
8. Right-click on `sqlservertools-main.zip` and select **Extract All...**
9. Choose `C:\` as the extraction destination
10. Click **Extract** to complete the process
11. Verify that the tools are extracted to `C:\sqlservertools-main\`

**Option B: Using PowerShell (Optional Method)**

1. Right-click on the **Start** button and select **Windows PowerShell (Admin)**
2. Run the following commands:
   ```powershell
   # Navigate to C: drive
   cd C:\
   
   # Download the repository as ZIP
   Invoke-WebRequest -Uri "https://github.com/aws-samples/sqlservertools/archive/refs/heads/main.zip" -OutFile "sqlservertools-main.zip"
   
   # Extract the ZIP file
   Expand-Archive -Path "sqlservertools-main.zip" -DestinationPath "C:\" -Force
   
   # Verify extraction
   dir C:\sqlservertools-main
   ```
3. Verify that the tools are extracted to `C:\sqlservertools-main\`

### Step 3: Setup Prerequisites for SQLServerTools

Before running the SQLServerTools, you need to install the required PowerShell module and prepare the tool structure.

**3.1 Install SQL Server PowerShell Module**

1. Right-click on the **Start** button and select **Windows PowerShell (Admin)**
2. When prompted by User Account Control, click **Yes** to run as administrator
3. Run the following commands one by one:
   ```powershell
   # Set execution policy to allow script execution
   Set-ExecutionPolicy RemoteSigned -Force
   
   # Install SQL Server PowerShell module
   Install-Module -Name SqlServer -Force -AllowClobber
   
   # Import the module
   Import-Module SqlServer -DisableNameChecking
   ```
4. Verify the module installation by running:
   ```powershell
   Get-Module -Name SqlServer
   ```
5. You should see the SqlServer module listed with version 22 or above

**3.2 Prepare RDSTools Directory Structure**

1. In the same PowerShell window, run the following commands:
   ```powershell
   # Navigate to the downloaded tools
   cd C:\sqlservertools-main\sqlservertools
   
   # Copy RDSTools.zip to C: drive
   Copy-Item "RDSTools.zip" "C:\RDSTools.zip"
   
   # Extract RDSTools to C:\RDSTools
   Expand-Archive -Path "C:\RDSTools.zip" -DestinationPath "C:\" -Force
   
   # Verify directory structure
   dir C:\RDSTools
   ```
2. Verify that the following directories exist:
   - `C:\RDSTools`
   - `C:\RDSTools\IN`
   - `C:\RDSTools\Out`
   - `C:\RDSTools\upload`

> **Note**: The tools require Windows PowerShell, SQL Server PowerShell module, and optionally Microsoft Excel for generating RDS instance recommendations. All prerequisites should now be configured and ready for the assessment.

### Step 4: Run the Assessment Tools

Now we'll run both assessment tools in sequence to get a complete picture of your SQL Server environment.

**4.1 Prepare Server List**

1. Open **File Explorer** and navigate to `C:\RDSTools\IN`
2. Open the file `servers.txt` with **Notepad**
3. Replace the content with your local SQL Server instance:
   ```
   localhost
   ```
4. Save and close the file

**4.2 Run RDS Discovery Tool**

1. Open **Windows PowerShell** as Administrator (or continue using the existing PowerShell window)
2. Navigate to the RDSTools directory:
   ```powershell
   cd C:\RDSTools
   ```
3. Run the RDS Discovery tool with SQL Server authentication and RDS recommendations:
   ```powershell
   .\Rdsdiscovery.bat -auth S -login sa -password [YourWorkshopPassword] -options rds
   ```
   > Replace `[YourWorkshopPassword]` with the actual password from your workshop parameters

4. The tool will scan your SQL Server and check for RDS compatibility
5. Wait for the process to complete (typically takes 2-5 minutes)
6. Once completed, you'll see a message indicating the assessment is finished
7. The tool will automatically open your browser to display the results, and the results will also be saved as a CSV file in `C:\RDSTools\out\`

**4.3 SQL Server Assessment Tool (SSAT) - Optional**

> **Workshop Focus**: For this workshop, we will focus on the compatibility assessment from Step 4.2. The SQL Server Assessment Tool (SSAT) is a valuable tool for performance analysis and RDS right-sizing, but it's considered optional for our current scope.
>
> **Good to Have**: SSAT provides detailed performance metrics (CPU, memory, IOPS, throughput) and RDS sizing recommendations. In real-world scenarios, running SSAT after confirming RDS compatibility helps determine the optimal RDS instance size and configuration.
>
> **Time Consideration**: SSAT requires a monitoring period (typically 60+ minutes in production) to collect meaningful performance data, which extends beyond our workshop timeframe.

**4.4 Review Assessment Results**

1. Open **File Explorer** and navigate to `C:\RDSTools\out\`
2. You should see the **RdsDiscovery.csv** file - Compatibility assessment and migration recommendations
3. Open the CSV file with Excel or a text editor to review:
   - Check the **"RDS"** column to confirm compatibility:
     - **"Y"** means the source database is compatible with RDS and ready to migrate
     - **"N"** means the source database uses features not supported by RDS
   - Review the **"Recommendation"** column for migration path (RDS/RDS Custom/EC2)
   - Note any features or configurations that may need attention

> **Important**: Keep this assessment report as it will guide your migration planning in the next steps. The compatibility assessment confirms whether your SQL Server can migrate to Amazon RDS.
>
> **Note for Real-Life Scenarios**: If the RDS column shows "N", it indicates your database uses features not supported by Amazon RDS. You can review the [Amazon RDS for SQL Server Prerequisites](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_SQLServer.html#SQLServer.Concepts.General.FeatureSupport) documentation to understand supported features and limitations. In such cases, consider reaching out to an AWS Solution Architect to discuss alternative options such as RDS Custom or EC2-based solutions.

---
[← Back to Prerequisites](01-prerequisites.md) | [Next: Database Migration →](03-database-migration.md)