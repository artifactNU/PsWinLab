# Load configuration from config.json
$configFilePath = ".\\config.json"
if (-Not (Test-Path $configFilePath)) {
    Write-Error "Configuration file not found at $configFilePath. Please run 0CONFIG.ps1 first."
    exit
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Extract necessary variables
$ServerName = $config.VMs.Server2.IPAddress # IP address of Server2 from config
$AdminUsername = $config.DomainAdmin        # Administrator username
$AdminPassword = $config.DomainPassword     # Administrator password
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($AdminUsername, $SecurePassword)

# Allow remote connections on the target machine
Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Restart-Service WinRM
} -ErrorAction SilentlyContinue

# Add the remote server to TrustedHosts on the local machine
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $ServerName -Force

# Restart the WinRM service on the local machine
Restart-Service WinRM

# Script block to install IIS on the remote server and create the test page
$RemoteScript = {
    Write-Host "Installing IIS on $env:COMPUTERNAME..."
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    Write-Host "IIS Installation Complete."

    # Create a styled test HTML page
    $TestPage = "C:\inetpub\wwwroot\index.html"
    $ServerIP = $(Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.PrefixOrigin -eq "Dhcp" }).IPAddress
$Content =  @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Website</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
        }
        header {
            background-color: #0078d7;
            color: white;
            padding: 20px;
        }
        section {
            padding: 20px;
        }
        footer {
            background-color: #333;
            color: white;
            padding: 10px;
            position: absolute;
            bottom: 0;
            width: 100%;
        }
    </style>
</head>
<body>
    <header>
        <h1>Welcome to the Test Website!</h1>
    </header>
    <section>
        <p>This page is a simple test to verify that the web server is working correctly.</p>
        <p>The server is running on: <strong>$($env:COMPUTERNAME)</strong></p>
        <p>IP Address: <strong>$ServerIP</strong></p>
    </section>
    <footer>
        <p>© 2024 Test Website. All rights reserved.</p>
    </footer>
</body>
</html>
"@

    # Write the content to the test page
    Set-Content -Path $TestPage -Value $Content
    Write-Host "Test page created at $TestPage."
}

# Run the script on the remote server
Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock $RemoteScript

# Verify IIS is running
Write-Host "Checking IIS status on $ServerName..."
Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock {
    $status = Get-Service -Name W3SVC
    Write-Host "IIS Service Status: $($status.Status)"
}

Write-Host "Web server setup complete. Access it at http://$ServerName/"
