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
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DiskParted"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"

# Set the icon for the form using the PowerShell executable icon
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")

# Create DataGridView for disks
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Size = New-Object System.Drawing.Size(580, 300)
$dataGridView.Location = New-Object System.Drawing.Point(10, 10)
$dataGridView.AutoGenerateColumns = $true
$dataGridView.ReadOnly = $true

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

        # Create labels and controls for format options
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

$btnSelectPartition = New-Object System.Windows.Forms.Button
$btnSelectPartition.Location = New-Object System.Drawing.Point(190, 320)
$btnSelectPartition.Size = New-Object System.Drawing.Size(120, 30)
$btnSelectPartition.Text = "Select Partition"
$btnSelectPartition.Add_Click({
    $selectedDisk = $dataGridView.CurrentRow
    if ($selectedDisk) {
        # Open partition selection form
        $partitionForm = New-Object System.Windows.Forms.Form
        $partitionForm.Text = "Select Partition"
        $partitionForm.Size = New-Object System.Drawing.Size(300, 250)
        $partitionForm.StartPosition = "CenterParent"

        # Create DataGridView for partitions
        $partitionDataGridView = New-Object System.Windows.Forms.DataGridView
        $partitionDataGridView.Size = New-Object System.Drawing.Size(270, 130)
        $partitionDataGridView.Location = New-Object System.Drawing.Point(10, 10)
        $partitionDataGridView.AutoGenerateColumns = $true
        $partitionDataGridView.ReadOnly = $true

        # Function to update the partition list
        function Update-PartitionList {
            $partitionList = Execute-DiskPart "select disk $($selectedDisk.DiskNumber)`r`n list partition"
            $partitions = @()

            foreach ($line in $partitionList) {
                # Match the output for partition information
                if ($line -match '^\s*(\d+)\s+(\d+)\s+(.*)') {
                    $partitions += New-Object PSObject -Property @{
                        PartitionNumber = $matches[1]
                        Size            = $matches[2]
                        Status          = $matches[3]
                    }
                }
            }

            # Set DataGridView DataSource
            if ($partitions.Count -gt 0) {
                $partitionDataGridView.DataSource = $partitions
            } else {
                $partitionDataGridView.DataSource = $null
            }
        }

        Update-PartitionList

        # Button to confirm partition selection
        $btnConfirmSelect = New-Object System.Windows.Forms.Button
        $btnConfirmSelect.Text = "Select"
        $btnConfirmSelect.Location = New-Object System.Drawing.Point(10, 150)
        $btnConfirmSelect.Add_Click({
            $selectedPartition = $partitionDataGridView.CurrentRow
            if ($selectedPartition) {
                $action = "select partition $($selectedPartition.PartitionNumber)"
                $selectedActions += $action
                [System.Windows.Forms.MessageBox]::Show("Selected Partition: $($selectedPartition.PartitionNumber)", "Partition Selected", [System.Windows.Forms.MessageBoxButtons]::OK)
                $partitionForm.Close()
            } else {
                [System.Windows.Forms.MessageBox]::Show("Please select a partition.", "No Partition Selected", [System.Windows.Forms.MessageBoxButtons]::OK)
            }
        })

        # Button to create a new partition
        $btnCreatePartition = New-Object System.Windows.Forms.Button
        $btnCreatePartition.Text = "Create Partition"
        $btnCreatePartition.Location = New-Object System.Drawing.Point(150, 150)
        $btnCreatePartition.Add_Click({
            # Open create partition options form
            $createPartitionForm = New-Object System.Windows.Forms.Form
            $createPartitionForm.Text = "Create Partition Options"
            $createPartitionForm.Size = New-Object System.Drawing.Size(300, 200)
            $createPartitionForm.StartPosition = "CenterParent"

            # Create labels and controls for create partition options
            $lblSize = New-Object System.Windows.Forms.Label
            $lblSize.Text = "Size (MB):"
            $lblSize.Location = New-Object System.Drawing.Point(10, 20)

            $txtCreateSize = New-Object System.Windows.Forms.TextBox
            $txtCreateSize.Location = New-Object System.Drawing.Point(100, 20)

            $lblFileSystem = New-Object System.Windows.Forms.Label
            $lblFileSystem.Text = "File System:"
            $lblFileSystem.Location = New-Object System.Drawing.Point(10, 60)

            $cboCreateFileSystem = New-Object System.Windows.Forms.ComboBox
            $cboCreateFileSystem.Location = New-Object System.Drawing.Point(100, 60)
            $cboCreateFileSystem.Items.AddRange("NTFS", "exFAT", "FAT32")

            $btnCreate = New-Object System.Windows.Forms.Button
            $btnCreate.Text = "Create"
            $btnCreate.Location = New-Object System.Drawing.Point(10, 100)
            $btnCreate.Add_Click({
                $size = $txtCreateSize.Text
                $fileSystem = $cboCreateFileSystem.SelectedItem

                if ($size -and $fileSystem) {
                    $action = "select partition $($selectedPartition.PartitionNumber)`r`n create partition primary size=$size`r`n format fs=$fileSystem"
                    $selectedActions += $action
                    [System.Windows.Forms.MessageBox]::Show("Created Partition: Size = $size MB, File System = $fileSystem", "Partition Created", [System.Windows.Forms.MessageBoxButtons]::OK)
                    $createPartitionForm.Close()
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Please specify both size and file system.", "Input Error", [System.Windows.Forms.MessageBoxButtons]::OK)
                }
            })

            # Add controls to create partition form
            $createPartitionForm.Controls.AddRange(@($lblSize, $txtCreateSize, $lblFileSystem, $cboCreateFileSystem, $btnCreate))
            $createPartitionForm.ShowDialog()
        })

        # Add controls to partition selection form
        $partitionForm.Controls.AddRange(@($partitionDataGridView, $btnConfirmSelect, $btnCreatePartition))
        $partitionForm.ShowDialog()
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a disk.", "No Disk Selected", [System.Windows.Forms.MessageBoxButtons]::OK)
    }
})

# Add buttons to the form
$form.Controls.AddRange(@($dataGridView, $btnStart, $btnFormat, $btnSelectPartition))

# Show the main form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
