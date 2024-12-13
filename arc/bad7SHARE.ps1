# Load the configuration
$configFilePath = ".\\config.json"
if (-Not (Test-Path $configFilePath)) {
    Write-Error "Configuration file not found at $configFilePath. Please run 0CONFIG.ps1 first."
    exit
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Variables
$VMName = "Server1"                     # Name of the VM where the shared folder is created
$OtherVMs = @("DC1", "Server2")         # Other VMs that need the shared folder as a drive
$ShareName = "share"                    # Name of the shared folder
$SharePath = "C:\share"                 # Path to the shared folder inside the VM
$DriveLetter = "S"                      # Drive letter to map the share
$Permissions = "Everyone"               # Share permissions (adjust as needed)
$Description = "Shared folder for inter-VM access"

# Domain credentials from the configuration file
$AdminUsername = $config.DomainAdmin
$AdminPassword = $config.DomainPassword
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($AdminUsername, $SecurePassword)

# Step 1: Enable PowerShell Remoting and SMB on the VM
Write-Host "Configuring PowerShell remoting and SMB on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    # Configure SMB and firewall rules
    Enable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol"
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
    New-NetFirewallRule -DisplayName "Allow SMB" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow
    Restart-Service WinRM
}

# Step 2: Create the Shared Folder
Write-Host "Creating shared folder on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    param($SharePath, $ShareName, $Description, $Permissions)

    # Create the folder if it doesn't exist
    if (-not (Test-Path -Path $SharePath)) {
        New-Item -ItemType Directory -Path $SharePath -Force
    }

    # Share the folder if it is not already shared
    if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $ShareName -Path $SharePath -Description $Description -FullAccess $Permissions
    }

    # Set share permissions
    Grant-SmbShareAccess -Name $ShareName -AccountName $Permissions -AccessRight Full -Force
} -ArgumentList $SharePath, $ShareName, $Description, $Permissions

# Step 3: Map the Share as a Drive on the Other VMs
foreach ($VM in $OtherVMs) {
    Write-Host "Mapping shared folder \\$VMName\$ShareName as drive $DriveLetter on VM: $VM..."
    Invoke-Command -VMName $VM -Credential $Credential -ScriptBlock {
        param($VMName, $ShareName, $DriveLetter)

        # Remove existing mapping if present
        if (Test-Path "$DriveLetter :\") {
            Remove-PSDrive -Name $DriveLetter -Force
        }

        # Map the shared folder as a drive
        New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root "\\$VMName\$ShareName" -Persist
        Write-Host "Drive $DriveLetter successfully mapped to \\$VMName\$ShareName"
    } -ArgumentList $VMName, $ShareName, $DriveLetter
}
