# Variables
$VMName = "Server1"                     # Name of the VM where the shared folder is created
$OtherVMs = @("DC1", "Server2")         # Other VMs that need the shared folder in Quick Access
$ShareName = "share"                    # Name of the shared folder
$SharePath = "C:\share"                 # Path to the shared folder inside the VM
$DriveLetter = "S"                      # Drive letter to map the share
$Permissions = "Everyone"               # Share permissions (adjust as needed)
$Description = "Shared folder for inter-VM access"
$AdminUsername = "ACME\Administrator"   # VM Administrator username
$AdminPassword = "Linux4Ever"           # VM Administrator password

# Create credential for VM
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($AdminUsername, $SecurePassword)

# Function to Wait for a VM Restart
function Wait-ForRestart {
    param ([string]$VMName, [int]$Timeout = 300)

    Write-Host "Waiting for VM $VMName to restart..."
    $start = Get-Date
    while ((Get-Date) - $start -lt (New-TimeSpan -Seconds $Timeout)) {
        if (Test-Connection -ComputerName $VMName -Count 1 -Quiet) {
            Write-Host "VM $VMName is online."
            return
        }
        Start-Sleep -Seconds 10
    }
    throw "VM $VMName did not come online within the timeout period."
}

# Step 1: Enable PowerShell Remoting and SMB2/3 on the VM
Write-Host "Configuring PowerShell remoting and SMB on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    # Configure SMB2/3 and firewall rules
    Set-SmbServerConfiguration -EnableSMB2Protocol $true -EnableSMB1Protocol $false -Force
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
    New-NetFirewallRule -DisplayName "Allow SMB" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow
    Restart-Service WinRM
}

# Step 2: Create the Shared Folder
Write-Host "Creating shared folder on VM: $VMName..."
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
    param($SharePath, $ShareName, $Description, $Permissions)

    # Ensure SMB2/3 is enabled
    Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force

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
        $Drive = New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root "\\$VMName\$ShareName" -Persist
        Write-Host "Drive $DriveLetter successfully mapped to \\$VMName\$ShareName"

        # Add shared folder to Quick Access
        try {
            $Shell = New-Object -ComObject Shell.Application
            $NetworkFolder = $Shell.Namespace($Drive.Root)
            if ($NetworkFolder -eq $null) {
                throw "Unable to access the shared folder: \\$VMName\$ShareName"
            }

            $FolderItem = $NetworkFolder.Self
            if ($FolderItem -eq $null) {
                throw "Failed to retrieve folder item for: \\$VMName\$ShareName"
            }

            # Use the "Pin to Quick Access" verb
            Write-Host "Adding \\$VMName\$ShareName to Quick Access..."
            $FolderItem.InvokeVerb("pin to quick access")
        } catch {
            Write-Host "Error adding to Quick Access: $_"
        }
    } -ArgumentList $VMName, $ShareName, $DriveLetter
}
