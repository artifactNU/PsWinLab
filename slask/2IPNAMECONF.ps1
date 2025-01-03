$VMConfigurations = @{
    "DC1"        = @{
        IPAddress = "10.6.67.210"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("10.6.67.210")
    }
    "Server1"    = @{
        IPAddress = "10.6.67.211"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("10.6.67.210")
    }
    "Server2"    = @{
        IPAddress = "10.6.67.212"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("10.6.67.210")
    }
    "Win10Client" = @{
        IPAddress = "10.6.67.213"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("10.6.67.210")
    }
}

# Hardcoded password for all VMs
$Password = "Linux4Ever"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("Administrator", $SecurePassword)

function Convert-SubnetMaskToPrefixLength {
    param ([string]$SubnetMask)
    $binarySubnet = ($SubnetMask -split '\.' | ForEach-Object { [convert]::ToString([int]$_, 2).PadLeft(8, '0') })
    return ($binarySubnet -join '' -split '1').Length - 1
}

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
                function Convert-SubnetMaskToPrefixLength {
                    param ([string]$SubnetMask)
                    $binarySubnet = ($SubnetMask -split '\.' | ForEach-Object { [convert]::ToString([int]$_, 2).PadLeft(8, '0') })
                    return ($binarySubnet -join '' -split '1').Length - 1
                }

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

# Loop through configurations and rename computers while setting static IP
foreach ($VMName in $VMConfigurations.Keys) {
    $config = $VMConfigurations[$VMName]
    Set-VMStaticIPAndRename -VMName $VMName `
                            -NewComputerName $VMName `
                            -IPAddress $config.IPAddress `
                            -Subnet $config.Subnet `
                            -Gateway $config.Gateway `
                            -DNS $config.DNS
}

Write-Host "Static IP and computer name configuration complete."
