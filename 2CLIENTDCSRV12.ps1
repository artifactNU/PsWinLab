# Skapa tre Generation 1 virtuella maskiner och en Windows 10 klient i Hyper-V

# Variabler
$ScriptPath = $PSScriptRoot  # Hämta sökvägen där skriptet körs
$VMNames = @("DC1", "Server1", "Server2")     # Names of the server VMs
$Windows10VMName = "Win10Client"             # Name of the Windows 10 client VM
$BaseVHDPath = Join-Path $ScriptPath "BaseImage.vhdx"              # Relativ sökväg för serverns bas VHDX
$Win10BaseVHDPath = Join-Path $ScriptPath "Win10BaseImage.vhdx"    # Relativ sökväg för Windows 10 bas VHDX
$VMBasePath = Join-Path $ScriptPath "VM"                          # Relativ sökväg för alla VM-mappar
$MemoryStartupBytes = 4GB                     # Startup memory for the VMs
$Win10MemoryStartupBytes = 4GB                # Startup memory for Windows 10 client
$SwitchName = "Intel(R) Ethernet Connection (2) I219-LM - Virtual Switch"  # Network switch

# Kontrollera att bas VHD-filerna existerar
If (-Not (Test-Path -Path $BaseVHDPath)) {
    Write-Error "Bas VHD-filen hittades inte på sökvägen $BaseVHDPath. Kontrollera och försök igen."
    Break
}

If (-Not (Test-Path -Path $Win10BaseVHDPath)) {
    Write-Error "Windows 10 bas VHD-filen hittades inte på sökvägen $Win10BaseVHDPath. Kontrollera och försök igen."
    Break
}

# Kontrollera att den virtuella switchen existerar
If (-Not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    Write-Error "Den virtuella switchen '$SwitchName' existerar inte. Skapa den eller ange rätt namn."
    Break
}

# Funktion för att skapa en virtuell maskin
function Create-VMCustom {
    param (
        [string]$VMName,
        [string]$BaseVHDPath,
        [int64]$MemoryStartupBytes
    )

    # Kontrollera att VMName och BaseVHDPath är korrekta
    If (-not $VMName) {
        Write-Error "VMName is empty. Check the input to the Create-VMCustom function."
        Return
    }
    If (-not (Test-Path -Path $BaseVHDPath)) {
        Write-Error "Base VHD Path '$BaseVHDPath' does not exist. Check the file path."
        Return
    }

    $VMPath = Join-Path $VMBasePath $VMName          # Path for VM files
    $NewVHDPath = Join-Path $VMPath "$VMName.vhdx"   # Path for the new VM's VHDX

    # Skapa katalog för VM om den inte redan finns
    If (-Not (Test-Path -Path $VMPath)) {
        Write-Host "Skapar katalog för '$VMName'..."
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
        Write-Host "Ställer in BIOS för att boota från VHD först för '$VMName'..."
        Set-VMBios -VMName $VMName -StartupOrder IDE,LegacyNetworkAdapter
    } else {
        Write-Host "BIOS är redan korrekt konfigurerad för att boota från VHD för '$VMName'."
    }

    # Starta den virtuella maskinen
    Write-Host "Startar den virtuella maskinen '$VMName'..."
    Start-VM -Name $VMName

    Write-Host "Den virtuella maskinen '$VMName' har skapats och startats korrekt."
}

# Skapa Windows 10 klient först
Write-Host "Skapar Windows 10 klient: $Windows10VMName"
Create-VMCustom -VMName $Windows10VMName -BaseVHDPath $Win10BaseVHDPath -MemoryStartupBytes $Win10MemoryStartupBytes

# Loopa genom server-VM-namn och skapa varje server-VM
foreach ($VMName in $VMNames) {
    Write-Host "Creating VM: $VMName"
    Create-VMCustom -VMName $VMName -BaseVHDPath $BaseVHDPath -MemoryStartupBytes $MemoryStartupBytes
}

Write-Host "Alla virtuella maskiner har skapats och startats korrekt."
