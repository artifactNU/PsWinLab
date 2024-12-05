# Load the configuration
$configFilePath = ".\\config.json"
if (-Not (Test-Path $configFilePath)) {
    Write-Error "Configuration file not found at $configFilePath. Please run 0CONFIG.ps1 first."
    exit
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Extract configuration
$DomainName = $config.DomainName
$DomainAdmin = $config.DomainAdmin
$DomainPassword = $config.DomainPassword
$LocalPassword = $config.LocalPassword
$SecureDomainPassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainAdmin, $SecureDomainPassword)

# Create local administrator credential
$SecureLocalPassword = ConvertTo-SecureString $LocalPassword -AsPlainText -Force
$LocalCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $SecureLocalPassword)

# Function to Join Computers to the Domain
function Join-ComputerToDomain {
    param (
        [string]$VMName,
        [string]$DomainName,
        [PSCredential]$DomainCredential,
        [PSCredential]$LocalCredential
    )

    Write-Host "Joining $VMName to the domain $DomainName..."

    for ($i = 0; $i -lt 3; $i++) {
        try {
            # Use local credentials to connect to the VM
            Invoke-Command -VMName $VMName -Credential $LocalCredential -ScriptBlock {
                param ($DomainName, $DomainCredential)

                # Join the domain using domain credentials
                Add-Computer -DomainName $DomainName -Credential $DomainCredential -Force -Restart
            } -ArgumentList $DomainName, $DomainCredential

            Write-Host "$VMName has been joined to the domain $DomainName."
            return
        } catch {
            Write-Host "Failed to join $VMName to the domain. Retrying... ($($i + 1)/3)"
            Start-Sleep -Seconds 15
        }
    }

    Write-Error "Failed to join $VMName to the domain $DomainName after multiple attempts."
}

# List of computers to join the domain
$VMNamesToJoin = @("Server1", "Server2", "Win10Client")

# Ensure DC1 is reachable
Write-Host "Verifying domain controller (DC1) is reachable..."
if (-not (Test-Connection -ComputerName "DC1" -Count 1 -Quiet)) {
    throw "DC1 is not reachable. Ensure the domain controller is online and try again."
}

# Join computers to the domain
foreach ($VMName in $VMNamesToJoin) {
    Join-ComputerToDomain -VMName $VMName `
                          -DomainName $DomainName `
                          -DomainCredential $DomainCredential `
                          -LocalCredential $LocalCredential
}

Write-Host "All computers have been joined to the domain."
