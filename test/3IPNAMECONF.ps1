# Load the configuration
$configFilePath = ".\\config.json"
if (-Not (Test-Path $configFilePath)) {
    Write-Error "Configuration file not found at $configFilePath. Please run 0CONFIG.ps1 first."
    exit
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Use the local password from the config file
$Password = $config.LocalPassword
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("Administrator", $SecurePassword)

# Function to convert subnet mask to prefix length
function Convert-SubnetMaskToPrefixLength {
    param ([string]$SubnetMask)
    $binarySubnet = ($SubnetMask -split '\.' | ForEach-Object { [convert]::ToString([int]$_, 2).PadLeft(8, '0') })
    return ($binarySubnet -join '' -split '1').Length - 1
}

# Function to set static IP and rename VM
function Set-VMStaticIPAndRename {
    param (
        [string]$VMName,
        [string]$NewComputerName,
        [string]$IPAddress,
        [string]$Subnet,
        [string]$Gateway,
        [string[]]$DNS
    )

    try {
        Start-Sleep -Seconds 30

        # Remote execution to set IP and rename computer
        Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
            param ($NewComputerName, $IPAddress, $Subnet, $Gateway, $DNS)

            # Rename the computer
            Write-Host "Renaming computer to $NewComputerName..."
            Rename-Computer -NewName $NewComputerName -Force

            # Configure static IP
            Write-Host "Configuring static IP $IPAddress..."
            $interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            if (!$interface) {
                throw "No active network adapter found."
            }

            $existingIP = Get-NetIPAddress -InterfaceIndex $interface.IfIndex | Where-Object { $_.IPAddress -eq $IPAddress }
            if ($existingIP) {
                Write-Host "IP Address $IPAddress already exists. Skipping configuration."
            } else {
                # Convert subnet to prefix length
                $prefixLength = Convert-SubnetMaskToPrefixLength -SubnetMask $Subnet
                New-NetIPAddress -IPAddress $IPAddress -PrefixLength $prefixLength -DefaultGateway $Gateway -InterfaceIndex $interface.IfIndex
                Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses $DNS
            }

            # Restart the computer to apply the new name
            Write-Host "Restarting the computer to apply changes..."
            Restart-Computer -Force
        } -ArgumentList $NewComputerName, $IPAddress, $Subnet, $Gateway, $DNS

    } catch {
        Write-Error "Failed to configure $VMName : $_"
    }
}

# Loop through VM configurations from the config file and apply settings
foreach ($VMName in $config.VMs.Keys) {
    $vmConfig = $config.VMs[$VMName]
    Set-VMStaticIPAndRename -VMName $VMName `
                            -NewComputerName $VMName `
                            -IPAddress $vmConfig.IPAddress `
                            -Subnet $vmConfig.Subnet `
                            -Gateway $vmConfig.Gateway `
                            -DNS $vmConfig.DNS
}

Write-Host "Static IP and computer name configuration complete."
