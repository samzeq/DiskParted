# Check if running as admin
function Check-Admin {
    $isAdmin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $isAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Check-Admin)) {
    # Restart as admin
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Add necessary assemblies
Add-Type -AssemblyName System.Windows.Forms

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DiskParted"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"

# Set the icon for the form using the PowerShell executable icon
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Reflection.Assembly]::GetExecutingAssembly().Location)

# Create DataGridView for disks
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Size = New-Object System.Drawing.Size(580, 300)
$dataGridView.Location = New-Object System.Drawing.Point(10, 10)
$dataGridView.AutoGenerateColumns = $true

# Function to execute DiskPart commands and get output
function Execute-DiskPart {
    param (
        [string]$Command
    )
    $tempFile = "$env:TEMP\diskpart_output.txt"
    $commandString = "diskpart.exe /s $tempFile"

    # Write command to temporary file
    Set-Content -Path $tempFile -Value $Command
    & cmd /c $commandString | Out-Null # Run DiskPart command
    $output = Get-Content $tempFile
    Remove-Item $tempFile -Force
    return $output
}

# Function to update the disk list
function Update-DiskList {
    $diskList = Execute-DiskPart "list disk"
    $disks = @()
    
    foreach ($line in $diskList) {
        # Match the output for disk information
        if ($line -match '^\s*(\d+)\s+(\d+)\s+(.*)') {
            $disks += New-Object PSObject -Property @{
                DiskNumber = $matches[1]
                Size       = $matches[2]
                Status     = $matches[3]
            }
        }
    }
    
    # Set DataGridView DataSource
    if ($disks.Count -gt 0) {
        $dataGridView.DataSource = $disks
    } else {
        $dataGridView.DataSource = $null
    }
}

Update-DiskList

# Store selected actions
$selectedActions = @()

# Buttons
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(10, 320)
$btnStart.Size = New-Object System.Drawing.Size(75, 30)
$btnStart.Text = "Start"
$btnStart.Add_Click({
    foreach ($action in $selectedActions) {
        Execute-DiskPart $action
    }
    # Clear actions after execution
    $selectedActions.Clear()
    Update-DiskList
})

$btnFormat = New-Object System.Windows.Forms.Button
$btnFormat.Location = New-Object System.Drawing.Point(100, 320)
$btnFormat.Size = New-Object System.Drawing.Size(75, 30)
$btnFormat.Text = "Format"
$btnFormat.Add_Click({
    $selectedDisk = $dataGridView.CurrentRow
    if ($selectedDisk) {
        # Open format options form
        $formatForm = New-Object System.Windows.Forms.Form
        $formatForm.Text = "Format Options"
        $formatForm.Size = New-Object System.Drawing.Size(300, 200)
        $formatForm.StartPosition = "CenterParent"

        # Create labels and controls
        $lblFileSystem = New-Object System.Windows.Forms.Label
        $lblFileSystem.Text = "File System:"
        $lblFileSystem.Location = New-Object System.Drawing.Point(10, 20)
        
        $cboFileSystem = New-Object System.Windows.Forms.ComboBox
        $cboFileSystem.Location = New-Object System.Drawing.Point(100, 20)
        $cboFileSystem.Items.AddRange("NTFS", "exFAT", "FAT32")

        $lblSize = New-Object System.Windows.Forms.Label
        $lblSize.Text = "Size (MB):"
        $lblSize.Location = New-Object System.Drawing.Point(10, 60)

        $txtSize = New-Object System.Windows.Forms.TextBox
        $txtSize.Location = New-Object System.Drawing.Point(100, 60)
        
        $chkQuickFormat = New-Object System.Windows.Forms.CheckBox
        $chkQuickFormat.Text = "Quick Format"
        $chkQuickFormat.Location = New-Object System.Drawing.Point(10, 100)

        $btnDefine = New-Object System.Windows.Forms.Button
        $btnDefine.Text = "Define"
        $btnDefine.Location = New-Object System.Drawing.Point(10, 140)
        $btnDefine.Add_Click({
            $size = $txtSize.Text
            $fileSystem = $cboFileSystem.SelectedItem
            $quickFormat = if ($chkQuickFormat.Checked) { " quick" } else { "" }
            
            $action = "select disk $($selectedDisk.DiskNumber)`r`n create partition primary size=$size`r`n format fs=$fileSystem$quickFormat"
            $selectedActions += $action
            $formatForm.Close()
        })

        # Add controls to format form
        $formatForm.Controls.AddRange(@($lblFileSystem, $cboFileSystem, $lblSize, $txtSize, $chkQuickFormat, $btnDefine))
        $formatForm.ShowDialog()
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a disk.", "No Disk Selected", [System.Windows.Forms.MessageBoxButtons]::OK)
    }
})

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(190, 320)
$btnStop.Size = New-Object System.Drawing.Size(75, 30)
$btnStop.Text = "Stop Disk"
$btnStop.Add_Click({
    $selectedDisk = $dataGridView.CurrentRow
    if ($selectedDisk) {
        $action = "select disk $($selectedDisk.DiskNumber)`r`n offline disk"
        $selectedActions += $action
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a disk.", "No Disk Selected", [System.Windows.Forms.MessageBoxButtons]::OK)
    }
})

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(280, 320)
$btnClose.Size = New-Object System.Drawing.Size(75, 30)
$btnClose.Text = "Close"
$btnClose.Add_Click({ $form.Close() })

# Add controls to the main form
$form.Controls.Add($dataGridView)
$form.Controls.Add($btnStart)
$form.Controls.Add($btnFormat)
$form.Controls.Add($btnStop)
$form.Controls.Add($btnClose)

# Show the main form
$form.ShowDialog()
