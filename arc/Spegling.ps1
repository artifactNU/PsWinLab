# Variabler
$SourceServer = "10.6.67.216"       # Namn eller IP på servern med webbservern
$DestinationServer = "10.6.67.218"  # Namn eller IP på servern som ska speglas
$SourceWebPath = "\\$SourceServer\c$\inetpub\wwwroot"  # Källväg till webbserverns rotkatalog
$DestinationWebPath = "\\$DestinationServer\c$\inetpub\wwwroot"  # Målväg på destinationen
$LogFile = "C:\WebSyncLog.txt"  # Loggfilens sökväg
$Credential = Get-Credential                   # Prompt for administrator credentials

# Allow remote connections on the target machine
Invoke-Command -ComputerName $SourceServer -Credential $Credential -ScriptBlock {
    Enable-PSRemoting -Force
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Restart-Service WinRM
} -ErrorAction SilentlyContinue

# Add the remote server to TrustedHosts on the local machine
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $SourceServer -Force

# Restart the WinRM service on the local machine
Restart-Service WinRM

# Kontrollera om målmappen finns
if (-not (Test-Path $DestinationWebPath)) {
    Write-Host "Skapar målmappen på $DestinationServer..."
    New-Item -ItemType Directory -Path $DestinationWebPath -Force
}

# Synkronisera filerna med Robocopy
Write-Host "Synkroniserar filer från $SourceServer till $DestinationServer..."

# Bygg Robocopy-argumenten
$RobocopyArgs = @(
    $SourceWebPath,
    $DestinationWebPath,
    "/MIR",               # Speglar källan och destinationen
    "/LOG:$LogFile",      # Loggar händelserna till en loggfil
    "/R:3",               # Försöker om en fil låser sig (max 3 gånger)
    "/W:5"                # Väntar 5 sekunder mellan försök
)

# Kör Robocopy
Start-Process -FilePath "robocopy.exe" -ArgumentList $RobocopyArgs -Wait -NoNewWindow

# Kontrollera om kopieringen lyckades
if ($LASTEXITCODE -eq 0) {
    Write-Host "Synkronisering av filer lyckades."
} else {
    Write-Host "Fel uppstod vid synkroniseringen. Kontrollera loggen: $LogFile"
}

# Kontrollera IIS-konfiguration
Write-Host "Synkroniserar IIS-konfiguration..."
Invoke-Command -ComputerName $SourceServer -ScriptBlock {
    Export-WebConfiguration -PSPath 'IIS:\Sites' -DestinationPath '\\HOST\Exports\IISConfig.xml'
} -ErrorAction Stop

Invoke-Command -ComputerName $DestinationServer -ScriptBlock {
    Import-WebConfiguration -PSPath 'IIS:\Sites' -SourcePath '\\HOST\Exports\IISConfig.xml'
} -ErrorAction Stop

Write-Host "Synkronisering av webbservern är klar!"