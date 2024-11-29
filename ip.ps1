$VMConfigurations = @{
    "DC1"        = @{
        IPAddress = "10.6.67.210"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("1.1.1.1", "8.8.8.8")
    }
    "Server1"    = @{
        IPAddress = "10.6.67.211"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("1.1.1.1", "8.8.8.8")
    }
    "Server2"    = @{
        IPAddress = "10.6.67.212"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("1.1.1.1", "8.8.8.8")
    }
    "Win10Client" = @{
        IPAddress = "10.6.67.213"
        Subnet    = "255.255.255.0"
        Gateway   = "10.6.67.1"
        DNS       = @("1.1.1.1", "8.8.8.8")
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

function Set-VMStaticIP {
    param (
        [string]$VMName,
        [string]$IPAddress,
        [string]$Subnet,
        [string]$Gateway,
        [string[]]$DNS
    )

    try {
        Start-Sleep -Seconds 30

        $interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        if (!$interface) {
            throw "No active network adapter found for $VMName."
        }

        $existingIP = Get-NetIPAddress -InterfaceIndex $interface.IfIndex | Where-Object { $_.IPAddress -eq $IPAddress }
        if ($existingIP) {
            Write-Host "IP Address $IPAddress already exists on $VMName. Skipping configuration."
            return
        }

        $prefixLength = Convert-SubnetMaskToPrefixLength -SubnetMask $Subnet
        New-NetIPAddress -IPAddress $IPAddress -PrefixLength $prefixLength -DefaultGateway $Gateway -InterfaceIndex $interface.IfIndex
        Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses $DNS
    } catch {
        Write-Error "Failed to configure IP for $VMName : $_"
    }
}

foreach ($VMName in $VMConfigurations.Keys) {
    $config = $VMConfigurations[$VMName]
    try {
        $session = New-PSSession -VMName $VMName -Credential $Credential
        Invoke-Command -Session $session -ScriptBlock {
            param ($IPAddress, $Subnet, $Gateway, $DNS)
            function Convert-SubnetMaskToPrefixLength {
                param ([string]$SubnetMask)
                $binarySubnet = ($SubnetMask -split '\.' | ForEach-Object { [convert]::ToString([int]$_, 2).PadLeft(8, '0') })
                return ($binarySubnet -join '' -split '1').Length - 1
            }

            $interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            if (!$interface) {
                throw "No active network adapter found."
            }

            $existingIP = Get-NetIPAddress -InterfaceIndex $interface.IfIndex | Where-Object { $_.IPAddress -eq $IPAddress }
            if ($existingIP) {
                Write-Host "IP Address $IPAddress already exists. Skipping configuration."
                return
            }

            $prefixLength = Convert-SubnetMaskToPrefixLength -SubnetMask $Subnet
            New-NetIPAddress -IPAddress $IPAddress -PrefixLength $prefixLength -DefaultGateway $Gateway -InterfaceIndex $interface.IfIndex
            Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses $DNS
        } -ArgumentList $config.IPAddress, $config.Subnet, $config.Gateway, $config.DNS
        Remove-PSSession -Session $session
    } catch {
        Write-Error "Error processing VM $VMName : $_"
    }
}
