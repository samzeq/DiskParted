# DiskParted.ps1
# Disk management tool using PowerShell GUI
# Licensed under the GNU General Public License (GPL)

Add-Type -AssemblyName PresentationFramework

function Show-Message {
    param (
        [string]$Message,
        [string]$Title = "DiskParted"
    )
    [System.Windows.MessageBox]::Show($Message, $Title)
}

function Execute-DiskPart {
    param (
        [string]$CommandFile
    )
    $diskPartProcess = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s $CommandFile" -Wait -PassThru
    return $diskPartProcess.ExitCode
}

function Update-Disks {
    $disks = Get-Content "$env:TEMP\list_disks.txt" -ErrorAction SilentlyContinue
    $volumes = Get-Content "$env:TEMP\list_volumes.txt" -ErrorAction SilentlyContinue

    # Clear previous list
    $ListViewDisks.Items.Clear()
    $ListViewVolumes.Items.Clear()

    foreach ($disk in $disks) {
        $ListViewDisks.Items.Add($disk)
    }

    foreach ($volume in $volumes) {
        $ListViewVolumes.Items.Add($volume)
    }
}

# Check if running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Restart as administrator
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Create temp commands file
$tempFolder = [System.IO.Path]::GetTempPath()
$commandFile = "$tempFolder\diskpart_commands.txt"

# Create the GUI
$Window = New-Object System.Windows.Window
$Window.Title = "DiskParted"
$Window.Width = 600
$Window.Height = 400

$Grid = New-Object System.Windows.Controls.Grid
$Window.Content = $Grid

$ListViewDisks = New-Object System.Windows.Controls.ListView
$ListViewDisks.Margin = "10,10,10,10"
$ListViewDisks.Width = 260
$ListViewDisks.Height = 300
$Grid.Children.Add($ListViewDisks)

$ListViewVolumes = New-Object System.Windows.Controls.ListView
$ListViewVolumes.Margin = "280,10,10,10"
$ListViewVolumes.Width = 260
$ListViewVolumes.Height = 300
$Grid.Children.Add($ListViewVolumes)

$StartButton = New-Object System.Windows.Controls.Button
$StartButton.Content = "Start"
$StartButton.Margin = "10,320,0,0"
$StartButton.Width = 100
$StartButton.Height = 30
$StartButton.Add_Click({
    $selectedDisk = $ListViewDisks.SelectedItem
    if ($selectedDisk) {
        Add-Content -Path $commandFile -Value "select disk $selectedDisk`nonline"
        $exitCode = Execute-DiskPart -CommandFile $commandFile
        if ($exitCode -eq 0) {
            Show-Message "Disk $selectedDisk is now online."
        } else {
            Show-Message "Failed to bring disk $selectedDisk online."
        }
        Update-Disks
    } else {
        Show-Message "Please select a disk."
    }
})
$Grid.Children.Add($StartButton)

$FormatButton = New-Object System.Windows.Controls.Button
$FormatButton.Content = "Format"
$FormatButton.Margin = "120,320,0,0"
$FormatButton.Width = 100
$FormatButton.Height = 30
$FormatButton.Add_Click({
    $selectedVolume = $ListViewVolumes.SelectedItem
    if ($selectedVolume) {
        $fsType = "NTFS"  # Set the file system type as needed
        Add-Content -Path $commandFile -Value "select volume $selectedVolume`nformat fs=$fsType quick"
        $exitCode = Execute-DiskPart -CommandFile $commandFile
        if ($exitCode -eq 0) {
            Show-Message "Volume $selectedVolume has been formatted as $fsType."
        } else {
            Show-Message "Failed to format volume $selectedVolume."
        }
        Update-Disks
    } else {
        Show-Message "Please select a volume."
    }
})
$Grid.Children.Add($FormatButton)

$StopButton = New-Object System.Windows.Controls.Button
$StopButton.Content = "Stop Disk"
$StopButton.Margin = "230,320,0,0"
$StopButton.Width = 100
$StopButton.Height = 30
$StopButton.Add_Click({
    $selectedDisk = $ListViewDisks.SelectedItem
    if ($selectedDisk) {
        Add-Content -Path $commandFile -Value "select disk $selectedDisk`noffline"
        $exitCode = Execute-DiskPart -CommandFile $commandFile
        if ($exitCode -eq 0) {
            Show-Message "Disk $selectedDisk is now offline."
        } else {
            Show-Message "Failed to take disk $selectedDisk offline."
        }
        Update-Disks
    } else {
        Show-Message "Please select a disk."
    }
})
$Grid.Children.Add($StopButton)

$CloseButton = New-Object System.Windows.Controls.Button
$CloseButton.Content = "Close"
$CloseButton.Margin = "340,320,0,0"
$CloseButton.Width = 100
$CloseButton.Height = 30
$CloseButton.Add_Click({
    $Window.Close()
})
$Grid.Children.Add($CloseButton)

# Execute DiskPart to list disks and volumes
Add-Content -Path $commandFile -Value "list disk`n"
Add-Content -Path $commandFile -Value "list volume`n"
Execute-DiskPart -CommandFile $commandFile

# Update the lists in the GUI
Update-Disks

# Show the window
$Window.ShowDialog() | Out-Null
