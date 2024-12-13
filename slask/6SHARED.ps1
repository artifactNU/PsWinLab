# Variables
$VMName = "Server1"                     # Name of the VM in Hyper-V
$ShareName = "Gemensamt"                # Name of the shared folder
$SharePath = "C:\Gemensamt"             # Path to the shared folder inside the VM
$DriveLetter = "G"                      # Drive letter to map on the host
$Permissions = "Everyone"               # Share permissions
$Description = "Shared folder for all users"
$AdminUsername = "ACME\Administrator"        # VM Administrator username
$AdminPassword = "Linux4Ever"          # VM Administrator password

# Create credential for VM
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($AdminUsername, $SecurePassword)

# Step 1: Enable PowerShell Remoting on the VM
Write-Host "Configuring PowerShell remoting on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Restart-Service WinRM

    # Ensure SMB is enabled and firewall allows file sharing
    Enable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol"
    New-NetFirewallRule -DisplayName "Allow SMB" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
}

# Step 2: Create Shared Folder and Configure Share on the VM
Write-Host "Creating shared folder on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    param($SharePath, $ShareName, $Description, $Permissions)

    # Create folder if it doesn't exist
    if (-not (Test-Path -Path $SharePath)) {
        New-Item -ItemType Directory -Path $SharePath -Force
    }

    # Create or verify the share
    if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $ShareName -Path $SharePath -Description $Description -FullAccess $Permissions
    }
    Grant-SmbShareAccess -Name $ShareName -AccountName $Permissions -AccessRight Full -Force
} -ArgumentList $SharePath, $ShareName, $Description, $Permissions

# Step 3: Map the Shared Folder on the Host
Write-Host "Mapping shared folder \\$VMName\$ShareName to drive $DriveLetter..."
$MappedCredential = New-Object System.Management.Automation.PSCredential ("Server1\Administrator", $SecurePassword)

if (Test-Path "\\$VMName\$ShareName") {
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root "\\$VMName\$ShareName" -Credential $MappedCredential -Persist
    Write-Host "Drive $DriveLetter : successfully mapped to \\$VMName\$ShareName"
} else {
    Write-Error "Failed to access \\$VMName\$ShareName"
}
