# Load the configuration
$configFilePath = ".\\config.json"
if (-Not (Test-Path $configFilePath)) {
    Write-Error "Configuration file not found at $configFilePath. Please run 0CONFIG.ps1 first."
    exit
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Extract domain information
$DomainName = $config.DomainName
$DomainDN = "DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])"
$DomainAdmin = $config.DomainAdmin
$DomainPassword = $config.DomainPassword
$SecureDomainPassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($DomainAdmin, $SecureDomainPassword)

if (-Not $Credential) {
    Write-Error "Credential creation failed. Verify DomainAdmin and DomainPassword."
    exit
}

# Target computer (DC IP address from config)
$TargetComputer = $config.VMs.DC1.IPAddress
if (-not $TargetComputer) {
    Write-Error "No IPAddress found for DC1 in the config.json. Please specify it."
    exit
}

Write-Host "Target DC IP: $TargetComputer" -ForegroundColor Cyan

# Add the target to TrustedHosts if needed
$trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Ignore).Value
if ($trustedHosts -notlike "*$TargetComputer*") {
    Write-Host "Adding $TargetComputer to TrustedHosts..."
    if ([string]::IsNullOrEmpty($trustedHosts)) {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $TargetComputer -Force
    } else {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$trustedHosts,$TargetComputer" -Force
    }
}

# Verify existing connection to the target computer
Write-Host "Verifying network connectivity to $TargetComputer..." -ForegroundColor Cyan
if (-Not (Test-Connection -ComputerName $TargetComputer -Count 1 -Quiet)) {
    Write-Error "Cannot connect to $TargetComputer. Verify network and firewall settings."
    exit
}

# Test if remoting is already functional
Write-Host "Testing existing PowerShell remoting connection to $TargetComputer..." -ForegroundColor Cyan
$ConnectionTest = $null
try {
    $ConnectionTest = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock { "Test Passed" } -ErrorAction Stop
} catch {
    Write-Host "Remoting not functional, configuring PowerShell remoting..." -ForegroundColor Yellow
}

if ($ConnectionTest -eq "Test Passed") {
    Write-Host "PowerShell remoting is already functional. Skipping configuration." -ForegroundColor Green
} else {
    # Configure PowerShell remoting
    Write-Host "Forcefully configuring PowerShell remoting on $TargetComputer..." -ForegroundColor Cyan
    try {
        Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
            Enable-PSRemoting -Force
            if (-not (Get-NetFirewallRule -Name "Allow WinRM" -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -Name "Allow WinRM" -DisplayName "Allow WinRM" -Protocol TCP -LocalPort 5985 -Action Allow -Enabled True
                Write-Host "Firewall rule for WinRM added."
            } else {
                Write-Host "Firewall rule for WinRM already exists."
            }
            Restart-Service WinRM
        } -ErrorAction Stop
    } catch {
        Write-Error "Failed to configure PowerShell remoting on $TargetComputer : $_"
        exit
    }

    # Retest connectivity
    $ConnectionTest = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock { "Test Passed" } -ErrorAction Stop
    if ($ConnectionTest -eq "Test Passed") {
        Write-Host "Remoting functional after configuration." -ForegroundColor Green
    } else {
        Write-Error "Unable to establish a working PowerShell remoting session to $TargetComputer."
        exit
    }
}

# Define Organizational Units (OUs) and Users
$OUs = @(
    @{ Name = "NewDivision"; Path = $DomainDN },
    @{ Name = "HR"; Path = "OU=NewDivision,$DomainDN" },
    @{ Name = "Finance"; Path = "OU=NewDivision,$DomainDN" },
    @{ Name = "IT"; Path = "OU=NewDivision,$DomainDN" }
)

$Users = @(
    @{ Name = "John Doe"; SamAccountName = "jdoe"; Password = "P@ssw0rd123"; OU = "OU=HR,OU=NewDivision,$DomainDN" },
    @{ Name = "Jane Smith"; SamAccountName = "jsmith"; Password = "P@ssw0rd123"; OU = "OU=Finance,OU=NewDivision,$DomainDN" },
    @{ Name = "Alice Brown"; SamAccountName = "abrown"; Password = "P@ssw0rd123"; OU = "OU=IT,OU=NewDivision,$DomainDN" },
    @{ Name = "Bob White"; SamAccountName = "bwhite"; Password = "P@ssw0rd123"; OU = "OU=IT,OU=NewDivision,$DomainDN" }
)

# Create OUs
Write-Host "Creating Organizational Units..." -ForegroundColor Cyan
foreach ($OU in $OUs) {
    try {
        Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
            param ($OUName, $OUPath)
            Import-Module ActiveDirectory
            if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $OUName } -SearchBase $OUPath -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $OUName -Path $OUPath
                Write-Host "Created OU: $OUName in $OUPath"
            } else {
                Write-Host "OU already exists: $OUName in $OUPath"
            }
        } -ArgumentList $OU.Name, $OU.Path -ErrorAction Stop
    } catch {
        Write-Error "Failed to create OU $($OU.Name): $_"
    }
}

# Create Users
Write-Host "Creating Users..." -ForegroundColor Cyan
foreach ($User in $Users) {
    try {
        Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
            param ($UserArgs, $DomainName)
            Import-Module ActiveDirectory
            $SamAccountName = $UserArgs["SamAccountName"]
            $Name = $UserArgs["Name"]
            $Password = $UserArgs["Password"]
            $OU = $UserArgs["OU"]

            if (-not (Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue)) {
                New-ADUser -Name $Name -SamAccountName $SamAccountName `
                           -UserPrincipalName "$SamAccountName@$DomainName" `
                           -Path $OU -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
                           -Enabled $true
                Write-Host "Created user: $Name in OU: $OU"
            } else {
                Write-Host "User already exists: $SamAccountName"
            }
        } -ArgumentList $User, $DomainName -ErrorAction Stop
    } catch {
        Write-Error "Failed to create user $($User.Name): $_"
    }
}

Write-Host "OU structure and user creation complete." -ForegroundColor Green
