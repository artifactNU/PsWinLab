# 0MAIN.ps1 - Main script to gather user input and create a configuration file

# Prompt user for DC configuration
Write-Host "Configure Domain Controller (DC1)"
$domainName = Read-Host "Enter the Domain Name (e.g., contoso.com)"
$accountName = Read-Host "Enter the Domain Administrator Username"
$domainAdmin = "$domainName\$accountName"
$domainPassword = Read-Host "Enter the Domain Administrator Password" -AsSecureString
$dcIP = Read-Host "Enter the IP Address of the Domain Controller"
$subnetMask = Read-Host "Enter the Subnet Mask"
$gateway = Read-Host "Enter the Default Gateway"

# Convert the password to a plain text string for storage
$plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($domainPassword)
)

# Automatically set DNS for other VMs to DC IP
$dnsServer = $dcIP

# Prompt user for IPs of other VMs
$vmConfigs = @{
    "Server1" = @{
        IPAddress = Read-Host "Enter the IP Address for Server1"
    }
    "Server2" = @{
        IPAddress = Read-Host "Enter the IP Address for Server2"
    }
    "Win10Client" = @{
        IPAddress = Read-Host "Enter the IP Address for Win10Client"
    }
}

# Populate other VM details using defaults
foreach ($vmName in $vmConfigs.Keys) {
    $vmConfigs[$vmName].Subnet = $subnetMask
    $vmConfigs[$vmName].Gateway = $gateway
    $vmConfigs[$vmName].DNS = @($dnsServer)
}

# Add DC configuration
$vmConfigs["DC1"] = @{
    IPAddress = $dcIP
    Subnet    = $subnetMask
    Gateway   = $gateway
    DNS       = @($dnsServer)
}

# Define the full configuration as a hashtable
$config = @{
    DomainName = $domainName
    DomainAdmin = $domainAdmin
    DomainPassword = $plainTextPassword
    SubnetMask = $subnetMask
    Gateway = $gateway
    VMs = $vmConfigs
}

# Convert the hashtable to JSON and save it to a file
$configFilePath = ".\\config.json"
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath

Write-Host "Configuration saved to $configFilePath"
Write-Host "You can now run the other scripts."
