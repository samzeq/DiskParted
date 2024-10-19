Add-Type -AssemblyName System.Windows.Forms

# Function to run DiskPart commands
function Run-DiskPart {
    param (
        [string]$Command
    )
    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s $Command" -NoNewWindow -PassThru
    $process.WaitForExit()
}

# Create a new Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DiskParted"
$form.Size = New-Object System.Drawing.Size(400, 300)

# Create a Label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter DiskPart Command:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10, 20)

# Create a TextBox for the command input
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 50)
$textBox.Size = New-Object System.Drawing.Size(360, 20)

# Create a Button to execute the command
$button = New-Object System.Windows.Forms.Button
$button.Text = "Execute"
$button.Location = New-Object System.Drawing.Point(10, 80)
$button.Size = New-Object System.Drawing.Size(75, 23)
$button.Add_Click({
    $command = $textBox.Text
    if (-not [string]::IsNullOrWhiteSpace($command)) {
        # Create a temporary script file for DiskPart
        $tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
        Set-Content -Path $tempFile -Value $command
        Run-DiskPart -Command $tempFile
        
        # Optionally, display a message box with success information
        [System.Windows.Forms.MessageBox]::Show("Command executed: $command", "Success")
        
        # Clean up the temporary file
        Remove-Item -Path $tempFile -Force
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please enter a command.", "Error")
    }
})

# Create a Button to close the application
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Location = New-Object System.Drawing.Point(100, 80)
$closeButton.Size = New-Object System.Drawing.Size(75, 23)
$closeButton.Add_Click({ $form.Close() })

# Add controls to the Form
$form.Controls.Add($label)
$form.Controls.Add($textBox)
$form.Controls.Add($button)
$form.Controls.Add($closeButton)

# Show the Form
$form.ShowDialog()

