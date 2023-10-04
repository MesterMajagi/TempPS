# Define the network share path
$networkShare = "\\CESHQFILE\Movies"
$scriptShare = "\\CESHQFILE\MovieScripts"

# Set the movie path to \\CESHQFILE\Movies for later use with Invoke-Command Get-ChildItem
$moviePath = "\\CESHQFILE\Movies"

# Get all *.mp4 files from $moviePath and put them into an array
$mp4Files = Get-ChildItem -Path $moviePath | Select-Object -Property Name | Sort-Object -Property Name

# Present the files for the user and let them choose which they want
$selectedFile = $mp4Files | Out-GridView -Title "Select an MP4 file" -PassThru

# Define the locations
$locations = "Herning", "Aalborg", "Aarhus", "Copenhagen", "Odense"
$selectedLocation = $locations | Out-GridView -Title "Select a location" -PassThru

# Define number of sal
$sal = "1", "2", "3", "4", "5", "6"
$selectedSal = $sal | Out-GridView -Title "Select a sal" -PassThru

# Combine the selected location and sal into a client name eg. Herning_Sal1
$selectedClient = "Desktop_$($selectedLocation)_Sal$($selectedSal).streambio.dk"

$schtaskName = "VLC Player " + $selectedFile.Name + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
$scriptPath = "$scriptShare\$($selectedClient)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").ps1"

# Create a powershell file to execute on the remote client using task scheduler and remove the task scheduler afterwards
$script = @"
Start-Process 'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe' -ArgumentList ("$networkShare\$($selectedFile.Name) --fullscreen vlc://quit") -Wait -NoNewWindow
"@

# Place the powershell file in the network share \\CESHQFILE\Scripts and name it after the client, movie and current date and time
$script | Out-File -FilePath $scriptPath

# Create a remote PowerShell session to the selected client
$session = New-PSSession -ComputerName $selectedClient

# Let the user define when the task should be run. It will be run once at the specified time. The time will be in 24h format.
$taskTime = Read-Host "Enter the time you want the task to run in 24h format (HH:mm)"

# Account name
$taskAccount = "streambio.dk\" + $selectedLocation + "_Sal" + $selectedSal

# Define the task scheduler command to execute the powershell file
$taskCommand = "schtasks /create /tn '$schtaskName' /tr 'powershell.exe -ExecutionPolicy Bypass -File $scriptPath' /sc once /st $taskTime /sd $(Get-Date -Format "dd/MM/yyyy") /ru $taskAccount /f"

# Execute the task scheduler command on the remote client
try {
    $result = Invoke-Command -Session $session -ScriptBlock {
        param($command)
        Invoke-Expression $command
    } -ArgumentList $taskCommand -ErrorAction Stop

    # Check if the task scheduler command executed successfully
    if ($result.ExitCode -eq $null) {
        Write-Host "Task scheduler command executed successfully on $($selectedClient)."
    } else {
        Write-Host "Task scheduler command encountered an error on $($selectedClient). Exit code: $($result.ExitCode)"
    }
} catch {
    Write-Host "Error executing task scheduler command on $($selectedClient): $($_.Exception.Message)"
}

# Close the remote PowerShell session
Remove-PSSession $session