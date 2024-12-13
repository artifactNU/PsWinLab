# Domain Configuration Variables
$DomainName = "acme.local"
$NetBIOSName = "ACME"
$SafeModePassword = "Linux4Ever"  # DSRM password
$LocalPassword = ConvertTo-SecureString "Linux4Ever" -AsPlainText -Force
$LocalCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $LocalPassword)

# Function to Wait for DC1 to Be Fully Operational
function Wait-ForDCReadiness {
    param (
        [string]$DCName,
        [int]$TimeoutSeconds = 300
    )

    Write-Host "Waiting for $DCName to be fully operational after restart..."

    $StartTime = Get-Date
    while ((Get-Date) - $StartTime -lt (New-TimeSpan -Seconds $TimeoutSeconds)) {
        try {
            $DomainCredential = New-Object System.Management.Automation.PSCredential ("ACME\Administrator", $LocalPassword)

            # Check if DC1 services (NTDS, DNS) are running
            $ServicesReady = Invoke-Command -ComputerName $DCName -Credential $DomainCredential -ScriptBlock {
                Get-Service -Name NTDS, DNS | Where-Object { $_.Status -ne 'Running' }
            }

            if (-not $ServicesReady) {
                Write-Host "$DCName is fully operational."
                return
            }

            Write-Host "Waiting for services on $DCName to start..."
        } catch {
            Write-Host "Still waiting for $DCName to become operational..."
        }

        Start-Sleep -Seconds 15
    }

    throw "Timeout reached. $DCName is not ready after $TimeoutSeconds seconds."
}

# Function to Promote DC1 to Domain Controller
function Configure-DomainController {
    param (
        [string]$DCName,
        [string]$DomainName,
        [string]$NetBIOSName,
        [string]$SafeModePassword
    )

    Write-Host "Starting domain configuration on $DCName..."

    # Convert SafeModePassword to SecureString
    $SecureSafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force

    # Install AD DS role
    Write-Host "Installing AD DS role on $DCName..."
    Invoke-Command -VMName $DCName -Credential $LocalCredential -ScriptBlock {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    }

    # Configure the domain and promote the server to a domain controller
    Write-Host "Promoting $DCName to a Domain Controller for domain $DomainName..."
    Invoke-Command -VMName $DCName -Credential $LocalCredential -ScriptBlock {
        param ($DomainName, $NetBIOSName, $SecureSafeModePassword)
        Import-Module ADDSDeployment
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $NetBIOSName `
            -SafeModeAdministratorPassword $SecureSafeModePassword `
            -Force `
            -InstallDns
    } -ArgumentList $DomainName, $NetBIOSName, $SecureSafeModePassword

    Write-Host "Domain Controller configuration on $DCName is complete."
}

# Configure DC1
Configure-DomainController -DCName "DC1" -DomainName $DomainName -NetBIOSName $NetBIOSName -SafeModePassword $SafeModePassword

# Wait for DC1 to be fully operational
Wait-ForDCReadiness -DCName "DC1"

Write-Host "DC1 has been promoted to a domain controller and is fully operational."
