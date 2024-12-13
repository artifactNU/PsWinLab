# Variables
$ServerName = "10.6.67.212"                     # Remote computer name or IP
$Credential = Get-Credential                   # Prompt for administrator credentials

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
    $Content = @"
<!DOCTYPE html>
<html lang="sv">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Hemsida</title>
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
        <h1>Välkommen till Test Hemsidan!</h1>
    </header>
    <section>
        <p>Denna sida är en enkel test för att kontrollera att webbservern fungerar korrekt.</p>
        <p>Servern körs på: <strong>$($env:COMPUTERNAME)</strong></p>
        <p>IP-adress: <strong>10.6.67.216</strong></p>
    </section>
    <footer>
        <p>© 2024 Test Hemsida. Alla rättigheter reserverade.</p>
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
