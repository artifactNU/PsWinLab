# 0CONFIG.ps1 - Main script to gather user input and create a configuration file

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
$vmConfigs = @{}
$vmConfigs["Server1"] = @{
    IPAddress = Read-Host "Enter the IP Address for Server1"
}
$vmConfigs["Server2"] = @{
    IPAddress = Read-Host "Enter the IP Address for Server2"
}
$vmConfigs["Win10Client"] = @{
    IPAddress = Read-Host "Enter the IP Address for Win10Client"
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

# Generate the new VM configurations block
$vmConfigurationsBlock = @"
    "DC1" = @{
        IPAddress = "$($vmConfigs["DC1"].IPAddress)"
        Subnet    = "$($vmConfigs["DC1"].Subnet)"
        Gateway   = "$($vmConfigs["DC1"].Gateway)"
        DNS       = @("$($vmConfigs["DC1"].DNS[0])")
    }
    "Server1" = @{
        IPAddress = "$($vmConfigs["Server1"].IPAddress)"
        Subnet    = "$($vmConfigs["Server1"].Subnet)"
        Gateway   = "$($vmConfigs["Server1"].Gateway)"
        DNS       = @("$($vmConfigs["Server1"].DNS[0])")
    }
    "Server2" = @{
        IPAddress = "$($vmConfigs["Server2"].IPAddress)"
        Subnet    = "$($vmConfigs["Server2"].Subnet)"
        Gateway   = "$($vmConfigs["Server2"].Gateway)"
        DNS       = @("$($vmConfigs["Server2"].DNS[0])")
    }
    "Win10Client" = @{
        IPAddress = "$($vmConfigs["Win10Client"].IPAddress)"
        Subnet    = "$($vmConfigs["Win10Client"].Subnet)"
        Gateway   = "$($vmConfigs["Win10Client"].Gateway)"
        DNS       = @("$($vmConfigs["Win10Client"].DNS[0])")
    }
"@

# Path to the 3IPNAMECONF.ps1 script
$scriptPath = ".\\3IPNAMECONF.ps1"
if (-Not (Test-Path $scriptPath)) {
    Write-Error "3IPNAMECONF.ps1 not found in the current directory. Ensure the script exists."
    exit
}

# Read the contents of 3IPNAMECONF.ps1
$scriptContent = Get-Content $scriptPath -Raw

# Find the position to insert the new configuration
$insertPosition = $scriptContent.IndexOf("`$VMConfigurations = @{") + ("`$VMConfigurations = @{").Length

# Insert the new configuration block
$updatedContent = $scriptContent.Insert($insertPosition, $vmConfigurationsBlock)

# Write the updated content back to the file
Set-Content -Path $scriptPath -Value $updatedContent

Write-Host "3IPNAMECONF.ps1 updated with the new configuration."
Write-Host "You can now run the updated 3IPNAMECONF.ps1 script."
