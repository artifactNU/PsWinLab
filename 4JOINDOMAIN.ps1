# Domain Join Configuration
$DomainName = "acme.local"
$DomainCredential = New-Object System.Management.Automation.PSCredential ("ACME\Administrator", (ConvertTo-SecureString "Linux4Ever" -AsPlainText -Force))

# Function to Join Computers to the Domain
function Join-ComputerToDomain {
    param (
        [string]$VMName,
        [string]$DomainName
    )

    Write-Host "Joining $VMName to the domain $DomainName..."

    for ($i = 0; $i -lt 3; $i++) {
        try {
            Invoke-Command -VMName $VMName -Credential $DomainCredential -ScriptBlock {
                param ($DomainName, $Credential)

                # Join the domain
                Add-Computer -DomainName $DomainName -Credential $Credential -Force -Restart
            } -ArgumentList $DomainName, $DomainCredential

            Write-Host "$VMName has been joined to the domain $DomainName."
            return
        } catch {
            Write-Host "Failed to join $VMName to the domain. Retrying... ($i/3)"
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
    Join-ComputerToDomain -VMName $VMName -DomainName $DomainName
}

Write-Host "All computers have been joined to the domain."
