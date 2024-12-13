# Master script

# Define the source folder for scripts
$ScriptFolder = Join-Path (Get-Location) "src"

# Function to prompt the user for input
function Prompt-UserAction {
    param (
        [string]$Message,
        [string[]]$ValidResponses = @("Y", "N", "SKIP"),
        [string]$DefaultResponse = "Y"
    )

    while ($true) {
        Write-Host "$Message (Y/Yes, N/No, Skip): " -NoNewline
        $Response = Read-Host
        if ([string]::IsNullOrWhiteSpace($Response)) {
            $Response = $DefaultResponse
        }

        switch ($Response.ToUpper()) {
            {$_ -eq "Y" -or $_ -eq "YES"} { return "CONTINUE" }
            {$_ -eq "N" -or $_ -eq "NO"}  { return "STOP" }
            {$_ -eq "SKIP"}               { return "SKIP" }
            default                       { Write-Host "Invalid input. Please enter Y/Yes, N/No, or Skip." }
        }
    }
}

# Step 1: Create Virtual Machines
Write-Host "Step 1: Creating Virtual Machines..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 1: Create Virtual Machines?"

switch ($UserChoice) {
    "CONTINUE" {
        & (Join-Path $ScriptFolder "2CLIENTDCSRV12.ps1")

        $TotalSeconds = 420
        $Intervals = 100
        $SleepDuration = $TotalSeconds / $Intervals

        for ($i = 1; $i -le $Intervals; $i++) {
            $PercentComplete = ($i / $Intervals) * 100
            Write-Progress -Activity "Processing..." -Status "Please wait, completing task..." -PercentComplete $PercentComplete
            Start-Sleep -Seconds $SleepDuration
        }

        Write-Host "Step 1 completed: Virtual Machines created." -ForegroundColor Green
    }
    "STOP" {
        Write-Host "Script execution stopped by user." -ForegroundColor Red
        exit
    }
    "SKIP" {
        Write-Host "Skipping Step 1." -ForegroundColor Yellow
    }
}

# Step 2: Configure Static IPs and Rename Computers
Write-Host "Step 2: Configuring Static IPs and Renaming Computers..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 2: Configure Static IPs and Rename Computers?"

switch ($UserChoice) {
    "CONTINUE" {
        & (Join-Path $ScriptFolder "3IPNAMECONF.ps1")

        $TotalSeconds = 60
        $Intervals = 100
        $SleepDuration = $TotalSeconds / $Intervals

        for ($i = 1; $i -le $Intervals; $i++) {
            $PercentComplete = ($i / $Intervals) * 100
            Write-Progress -Activity "Processing..." -Status "Please wait, completing task..." -PercentComplete $PercentComplete
            Start-Sleep -Seconds $SleepDuration
        }

        Write-Host "Step 2 completed: IPs configured and computers renamed." -ForegroundColor Green
    }
    "STOP" {
        Write-Host "Script execution stopped by user." -ForegroundColor Red
        exit
    }
    "SKIP" {
        Write-Host "Skipping Step 2." -ForegroundColor Yellow
    }
}

# Step 3: Promote DC1 to Domain Controller
Write-Host "Step 3: Promoting DC1 to Domain Controller..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 3: Promote DC1 to Domain Controller?"

switch ($UserChoice) {
    "CONTINUE" {
        & (Join-Path $ScriptFolder "4PROMOTEDC.ps1")

        $TotalSeconds = 480
        $Intervals = 100
        $SleepDuration = $TotalSeconds / $Intervals

        for ($i = 1; $i -le $Intervals; $i++) {
            $PercentComplete = ($i / $Intervals) * 100
            Write-Progress -Activity "Processing..." -Status "Please wait, completing task..." -PercentComplete $PercentComplete
            Start-Sleep -Seconds $SleepDuration
        }

        Write-Host "Step 3 completed: DC1 promoted to Domain Controller." -ForegroundColor Green
    }
    "STOP" {
        Write-Host "Script execution stopped by user." -ForegroundColor Red
        exit
    }
    "SKIP" {
        Write-Host "Skipping Step 3." -ForegroundColor Yellow
    }
}

# Steps 4-7 (similar changes)
Write-Host "Step 4: Joining Computers to the Domain..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 4: Join Computers to the Domain?"
switch ($UserChoice) {
    "CONTINUE" { & (Join-Path $ScriptFolder "5JOINDOMAIN.ps1"); Write-Host "Step 4 completed." -ForegroundColor Green }
    "STOP"     { Write-Host "Script execution stopped by user." -ForegroundColor Red; exit }
    "SKIP"     { Write-Host "Skipping Step 4." -ForegroundColor Yellow }
}

Write-Host "Step 5: Creating OUs and Users..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 5: Create OUs and Users?"
switch ($UserChoice) {
    "CONTINUE" { & (Join-Path $ScriptFolder "6CREATEOUANDUSERS.ps1"); Write-Host "Step 5 completed." -ForegroundColor Green }
    "STOP"     { Write-Host "Script execution stopped by user." -ForegroundColor Red; exit }
    "SKIP"     { Write-Host "Skipping Step 5." -ForegroundColor Yellow }
}

Write-Host "Step 6: Creating a Share Folder..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 6: Create a Share Folder?"
switch ($UserChoice) {
    "CONTINUE" { & (Join-Path $ScriptFolder "7SHARE.ps1"); Write-Host "Step 6 completed." -ForegroundColor Green }
    "STOP"     { Write-Host "Script execution stopped by user." -ForegroundColor Red; exit }
    "SKIP"     { Write-Host "Skipping Step 6." -ForegroundColor Yellow }
}

Write-Host "Step 7: Creating a Web Server with Example Website..." -ForegroundColor Cyan
$UserChoice = Prompt-UserAction -Message "Do you want to proceed with Step 7: Create a Web Server with Example Website?"
switch ($UserChoice) {
    "CONTINUE" { & (Join-Path $ScriptFolder "8WEBSERVER.ps1"); Write-Host "Step 7 completed." -ForegroundColor Green }
    "STOP"     { Write-Host "Script execution stopped by user." -ForegroundColor Red; exit }
    "SKIP"     { Write-Host "Skipping Step 7." -ForegroundColor Yellow }
}

Write-Host "All steps completed successfully!" -ForegroundColor Green
