# Prompt for credentials
$Credential = Get-Credential

# Configure PowerShell remoting on the local and remote machine
Write-Host "Configuring PowerShell remoting..." -ForegroundColor Cyan

# Allow remote connections on the target machine
Invoke-Command -ComputerName 10.6.67.210 -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Restart-Service WinRM
} -ErrorAction SilentlyContinue

# Add the remote server to TrustedHosts on the local machine
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.6.67.210" -Force

# Restart the WinRM service on the local machine
Restart-Service WinRM

# Define the script block
$RemoteScript = {
    param(
        [string]$OUBase = "OU=NewDivision,DC=acme,DC=local"
    )

    Import-Module ActiveDirectory

    # Ensure required OUs exist
    Write-Host "Ensuring OUs exist..." -ForegroundColor Cyan
    $OUs = @(
        @{ Name = "NewDivision"; Path = "DC=acme,DC=local" },
        @{ Name = "HR"; Path = "OU=NewDivision,DC=acme,DC=local" },
        @{ Name = "Finance"; Path = "OU=NewDivision,DC=acme,DC=local" },
        @{ Name = "IT"; Path = "OU=NewDivision,DC=acme,DC=local" }
    )

    foreach ($OU in $OUs) {
        try {
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($OU.Name)'" -SearchBase $OU.Path -ErrorAction SilentlyContinue)) {
                Write-Host "Creating OU: $($OU.Name) under $($OU.Path)"
                New-ADOrganizationalUnit -Name $OU.Name -Path $OU.Path
            } else {
                Write-Host "OU already exists: $($OU.Name)"
            }
        } catch {
            Write-Host "Failed to create or verify OU: $($OU.Name). Error: $_"
        }
    }

    # Define users to create
    $Users = @(
        @{ Name = "John Doe"; SamAccountName = "jdoe"; Password = "P@ssw0rd123"; OU = "OU=HR" },
        @{ Name = "Jane Smith"; SamAccountName = "jsmith"; Password = "P@ssw0rd123"; OU = "OU=Finance" },
        @{ Name = "Alice Brown"; SamAccountName = "abrown"; Password = "P@ssw0rd123"; OU = "OU=IT" },
        @{ Name = "Bob White"; SamAccountName = "bwhite"; Password = "P@ssw0rd123"; OU = "OU=IT" },
        @{ Name = "Carol Green"; SamAccountName = "cgreen"; Password = "P@ssw0rd123"; OU = "OU=HR" },
        @{ Name = "David Black"; SamAccountName = "dblack"; Password = "P@ssw0rd123"; OU = "OU=Finance" },
        @{ Name = "Eve Adams"; SamAccountName = "eadams"; Password = "P@ssw0rd123"; OU = "OU=IT" },
        @{ Name = "Frank Blue"; SamAccountName = "fblue"; Password = "P@ssw0rd123"; OU = "OU=IT" },
        @{ Name = "Grace Red"; SamAccountName = "gred"; Password = "P@ssw0rd123"; OU = "OU=Finance" },
        @{ Name = "Hannah Yellow"; SamAccountName = "hyellow"; Password = "P@ssw0rd123"; OU = "OU=HR" },
        @{ Name = "Isaac Gray"; SamAccountName = "igray"; Password = "P@ssw0rd123"; OU = "OU=Finance" }
    )

    # Add users to respective OUs
    foreach ($user in $Users) {
        $UserOU = "$($user.OU),$OUBase"
        $SamAccountName = $user.SamAccountName
        $Name = $user.Name
        $Password = $user.Password

        try {
            # Check if user already exists
            if (-not (Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue)) {
                # Create the new user
                Write-Host "Creating user: $Name in OU: $UserOU"
                New-ADUser -Name $Name -SamAccountName $SamAccountName `
                           -UserPrincipalName "$SamAccountName@acme.local" `
                           -Path $UserOU -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
                           -Enabled $true
            } else {
                Write-Host "User already exists: $SamAccountName"
            }
        } catch {
            Write-Host "Failed to create user: $Name. Error: $_"
        }
    }

    Write-Host "OU structure and users creation complete." -ForegroundColor Green
}

# Execute the script block on the VM
Invoke-Command -ComputerName 10.6.67.210 -Credential $Credential -ScriptBlock $RemoteScript -ArgumentList "OU=NewDivision,DC=acme,DC=local"
