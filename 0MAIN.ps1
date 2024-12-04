# Master script

function Wait-ForUserConfirmation {
    param (
        [string]$Message = "Press Enter to continue..."
    )
    Write-Host $Message -ForegroundColor Green
    Read-Host
}

# Step 1: Create Virtual Machines
Write-Host "Step 1: Creating Virtual Machines..." -ForegroundColor Cyan

# Script 1
# Skapa tre Generation 1 virtuella maskiner och en Windows 10 klient i Hyper-V
# Place the first script here or save as a function and call it

# Call the script block or function for creating VMs
.\1CLIENTDCSRV12.ps1

# Define total time (7 minutes in seconds) and intervals
$TotalSeconds = 420
$Intervals = 100
$SleepDuration = $TotalSeconds / $Intervals  # Time to sleep per interval

# Create a loading bar using Write-Progress
for ($i = 1; $i -le $Intervals; $i++) {
    # Calculate percentage complete
    $PercentComplete = ($i / $Intervals) * 100

    # Display the loading bar
    Write-Progress -Activity "Processing..." `
                   -Status "Please wait, completing task..." `
                   -PercentComplete $PercentComplete

    # Sleep for the duration of one interval
    Start-Sleep -Seconds $SleepDuration
}

# Final message
Write-Host "Loading complete!" -ForegroundColor Green


Write-Host "Step 1 completed: Virtual Machines created." -ForegroundColor Green
Wait-ForUserConfirmation "Virtual Machines are created. Press Enter to proceed to Step 2..."

# Step 2: Configure Static IPs and Rename Computers
Write-Host "Step 2: Configuring Static IPs and Renaming Computers..." -ForegroundColor Cyan

# Script 2
# Place the second script here or save as a function and call it

# Call the script block or function for configuring IPs
.\2IPNAMECONF.ps1

# Define total time (1 minutes in seconds) and intervals
$TotalSeconds = 60
$Intervals = 100
$SleepDuration = $TotalSeconds / $Intervals  # Time to sleep per interval

# Create a loading bar using Write-Progress
for ($i = 1; $i -le $Intervals; $i++) {
    # Calculate percentage complete
    $PercentComplete = ($i / $Intervals) * 100

    # Display the loading bar
    Write-Progress -Activity "Processing..." `
                   -Status "Please wait, completing task..." `
                   -PercentComplete $PercentComplete

    # Sleep for the duration of one interval
    Start-Sleep -Seconds $SleepDuration
}

# Final message
Write-Host "Loading complete!" -ForegroundColor Green

Write-Host "Step 2 completed: IPs configured and computers renamed." -ForegroundColor Green
Wait-ForUserConfirmation "IPs and computer names are configured. Press Enter to proceed to Step 3..."

# Step 3: Promote DC1 to Domain Controller
Write-Host "Step 3: Promoting DC1 to Domain Controller..." -ForegroundColor Cyan

# Script 3
# Place the third script here or save as a function and call it

# Call the script block or function for domain controller promotion
.\3PROMOTEDC.ps1

# Define total time (11 minutes in seconds) and intervals
$TotalSeconds = 480
$Intervals = 100
$SleepDuration = $TotalSeconds / $Intervals  # Time to sleep per interval

# Create a loading bar using Write-Progress
for ($i = 1; $i -le $Intervals; $i++) {
    # Calculate percentage complete
    $PercentComplete = ($i / $Intervals) * 100

    # Display the loading bar
    Write-Progress -Activity "Processing..." `
                   -Status "Please wait, completing task..." `
                   -PercentComplete $PercentComplete

    # Sleep for the duration of one interval
    Start-Sleep -Seconds $SleepDuration
}

# Final message
Write-Host "Loading complete!" -ForegroundColor Green

Write-Host "Step 3 completed: DC1 promoted to Domain Controller." -ForegroundColor Green
Wait-ForUserConfirmation "DC1 is now a Domain Controller. Press Enter to proceed to Step 4..."

# Step 4: Join Computers to the Domain
Write-Host "Step 4: Joining Computers to the Domain..." -ForegroundColor Cyan

# Script 4
# Place the fourth script here or save as a function and call it
.\4JOINDOMAIN.ps1

# Define total time (1 minutes in seconds) and intervals
$TotalSeconds = 60
$Intervals = 100
$SleepDuration = $TotalSeconds / $Intervals  # Time to sleep per interval

# Create a loading bar using Write-Progress
for ($i = 1; $i -le $Intervals; $i++) {
    # Calculate percentage complete
    $PercentComplete = ($i / $Intervals) * 100

    # Display the loading bar
    Write-Progress -Activity "Processing..." `
                   -Status "Please wait, completing task..." `
                   -PercentComplete $PercentComplete

    # Sleep for the duration of one interval
    Start-Sleep -Seconds $SleepDuration
}

Write-Host "Step 4 completed: All computers joined to the domain." -ForegroundColor Green
Wait-ForUserConfirmation "Computers have joined the domain. Press Enter to proceed to Step 4..."

# Call the script block or function for domain join
.\5CREATEOUANDUSERS.ps1

Write-Host "Step 5 completed: OU and users where created." -ForegroundColor Green
Write-Host "All steps completed successfully!" -ForegroundColor Green
