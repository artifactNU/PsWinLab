# Domain Configuration Variables
$DomainName = "acme.local"
$NetBIOSName = "ACME"
$SafeModePassword = "Linux4Ever"  # DSRM (Directory Services Restore Mode) password
$LocalPassword = ConvertTo-SecureString "Linux4Ever" -AsPlainText -Force
$LocalCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $LocalPassword) # Local credentials
$DomainCredential = $null  # Will be updated after domain configuration

# Function to Configure TrustedHosts for DC1
function Configure-TrustedHosts {
    param ([string]$DCName)

    Write-Host "Configuring TrustedHosts for $DCName..."
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $DCName -Force
    Write-Host "TrustedHosts configured for $DCName."
}

# Function to Restart and Wait for DC1
function Restart-And-Wait {
    param (
        [string]$DCName,
        [int]$TimeoutSeconds = 1200
    )

    Write-Host "Restarting $DCName and waiting for it to come online..."

    Restart-Computer -ComputerName $DCName -Force -Credential $LocalCredential

    $StartTime = Get-Date
    while ((Get-Date) - $StartTime -lt (New-TimeSpan -Seconds $TimeoutSeconds)) {
        try {
            Test-Connection -ComputerName $DCName -Count 1 -Quiet
            Write-Host "$DCName is back online."
            return
        } catch {
            Write-Host "Waiting for $DCName to come online..."
            Start-Sleep -Seconds 15
        }
    }

    throw "Timeout reached. $DCName did not come back online within $TimeoutSeconds seconds."
}

# Function to Install and Configure AD DS on the Domain Controller
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

# Function to Wait for DC1 to Be Fully Operational
function Wait-ForDCReadiness {
    param (
        [string]$DCName,
        [int]$TimeoutSeconds = 1200
    )

    Write-Host "Waiting for $DCName to be fully operational after restart..."

    $StartTime = Get-Date
    while ((Get-Date) - $StartTime -lt (New-TimeSpan -Seconds $TimeoutSeconds)) {
        try {
            $DomainCredential = New-Object System.Management.Automation.PSCredential ("ACME\Administrator", $LocalPassword)
            $DomainPing = Test-Connection -ComputerName $DCName -Count 1 -Quiet
            $DnsCheck = Invoke-Command -ComputerName $DCName -Credential $DomainCredential -ScriptBlock {
                param ($DomainName)
                Resolve-DnsName -Name $DomainName -ErrorAction Stop
            } -ArgumentList $DomainName

            if ($DomainPing -and $DnsCheck) {
                Write-Host "$DCName is fully operational."
                return
            }
        } catch {
            Write-Host "Still waiting for $DCName to become operational..."
            Start-Sleep -Seconds 15
        }
    }

    throw "Timeout reached. $DCName is not ready after $TimeoutSeconds seconds."
}

# Function to Join Computers to the Domain
function Join-ComputerToDomain {
    param (
        [string]$VMName,
        [string]$DomainName
    )

    Write-Host "Joining $VMName to the domain $DomainName..."

    Invoke-Command -VMName $VMName -Credential $DomainCredential -ScriptBlock {
        param ($DomainName, $Credential)

        # Join the domain
        Add-Computer -DomainName $DomainName -Credential $Credential -Force -Restart
    } -ArgumentList $DomainName, $DomainCredential

    Write-Host "$VMName has been joined to the domain $DomainName."
}

# Configure TrustedHosts for DC1
Configure-TrustedHosts -DCName "DC1"

# Configure DC1 as the Domain Controller
Configure-DomainController -DCName "DC1" -DomainName $DomainName -NetBIOSName $NetBIOSName -SafeModePassword $SafeModePassword

# Restart DC1 and Wait for It to Come Online
Restart-And-Wait -DCName "DC1" -TimeoutSeconds 1200

# Wait for DC1 to be fully operational
Wait-ForDCReadiness -DCName "DC1"

# Update DomainCredential after DC1 is fully operational
$DomainCredential = New-Object System.Management.Automation.PSCredential ("ACME\Administrator", $LocalPassword)

# Join other computers to the domain
$VMNamesToJoin = @("Server1", "Server2", "Win10Client")
foreach ($VMName in $VMNamesToJoin) {
    Join-ComputerToDomain -VMName $VMName -DomainName $DomainName
}

Write-Host "Domain configuration complete. All computers have been joined to the domain."
