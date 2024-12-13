# Skapa en Generation 1 virtuell maskin i Hyper-V

# Variabler
$VMName = "DC1"                               # New VM Name
$VMPath = "C:\Users\Administrator\Desktop\VM\$VMName"  # Path for VM files
$BaseVHDPath = "C:\Users\Administrator\Desktop\VMtemplate\DCBaseImageAutomatic.vhdx"  # Path to base VHDX
$NewVHDPath = "$VMPath\$VMName.vhdx"          # Path for the new VM's VHDX
$MemoryStartupBytes = 4GB                     # Startup memory for the VM
$SwitchName = "Intel(R) Ethernet Connection (2) I219-LM - Virtual Switch"  # Network switch

# Kontrollera att bas VHD-filen existerar
If (-Not (Test-Path -Path $BaseVHDPath)) {
    Write-Error "Bas VHD-filen hittades inte på sökvägen $BaseVHDPath. Kontrollera och försök igen."
    Break
}

# Kontrollera att den virtuella switchen existerar
If (-Not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    Write-Error "Den virtuella switchen '$SwitchName' existerar inte. Skapa den eller ange rätt namn."
    Break
}

# Skapa katalog för VM om den inte redan finns
If (-Not (Test-Path -Path $VMPath)) {
    New-Item -ItemType Directory -Path $VMPath -Force
}

# Kopiera bas VHD till ny plats för att skapa en ny VM
Write-Host "Kopierar bas VHD till $NewVHDPath..."
Copy-Item -Path $BaseVHDPath -Destination $NewVHDPath -Force

# Skapa den virtuella maskinen (Generation 1)
Write-Host "Skapar virtuell maskin '$VMName'..."
New-VM -Name $VMName `
       -MemoryStartupBytes $MemoryStartupBytes `
       -BootDevice VHD `
       -VHDPath $NewVHDPath `
       -Path $VMPath `
       -Generation 1 `
       -SwitchName $SwitchName

# Kontrollera om BIOS redan har rätt startordning
$CurrentBios = Get-VMBios -VMName $VMName
If ($CurrentBios.StartupOrder -notcontains "IDE") {
    Write-Host "Ställer in BIOS för att boota från VHD först..."
    Set-VMBios -VMName $VMName -StartupOrder IDE,LegacyNetworkAdapter
} else {
    Write-Host "BIOS är redan korrekt konfigurerad för att boota från VHD."
}

# Starta den virtuella maskinen
Write-Host "Startar den virtuella maskinen '$VMName'..."
Start-VM -Name $VMName

Write-Host "Den virtuella maskinen '$VMName' har skapats och startats korrekt."
