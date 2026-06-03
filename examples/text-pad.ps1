$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "WGA Text Pad"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size 760, 480
$form.MinimumSize = New-Object System.Drawing.Size 520, 320

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.AcceptsReturn = $true
$textBox.AcceptsTab = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object System.Drawing.Font "Consolas", 16
$textBox.Name = "WgaTextPadEditor"
$textBox.Text = ""

$status = New-Object System.Windows.Forms.StatusStrip
$label = New-Object System.Windows.Forms.ToolStripStatusLabel
$label.Text = "ready"
[void]$status.Items.Add($label)

$textBox.Add_TextChanged({
    $label.Text = "chars: $($textBox.TextLength)"
})

$form.Controls.Add($textBox)
$form.Controls.Add($status)
$form.Add_Shown({
    $textBox.Focus()
})

[void]$form.ShowDialog()
