$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$installDir = "C:\GuiAgent\trial-install"
$markerPath = Join-Path $installDir "installed.txt"

$form = New-Object System.Windows.Forms.Form
$form.Text = "WGA Trial Installer"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size 620, 420
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.AutoSize = $false
$title.Location = New-Object System.Drawing.Point 24, 22
$title.Size = New-Object System.Drawing.Size 560, 34
$title.Font = New-Object System.Drawing.Font "Segoe UI", 15, ([System.Drawing.FontStyle]::Bold)

$body = New-Object System.Windows.Forms.Label
$body.AutoSize = $false
$body.Location = New-Object System.Drawing.Point 26, 70
$body.Size = New-Object System.Drawing.Size 540, 80
$body.Font = New-Object System.Drawing.Font "Segoe UI", 10

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point 30, 164
$pathBox.Size = New-Object System.Drawing.Size 520, 26
$pathBox.Text = $installDir

$agree = New-Object System.Windows.Forms.CheckBox
$agree.Location = New-Object System.Drawing.Point 30, 160
$agree.Size = New-Object System.Drawing.Size 520, 30
$agree.Text = "I accept the trial installer terms"

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point 30, 165
$progress.Size = New-Object System.Drawing.Size 520, 24
$progress.Minimum = 0
$progress.Maximum = 100

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point 30, 205
$status.Size = New-Object System.Drawing.Size 520, 34
$status.Font = New-Object System.Drawing.Font "Segoe UI", 10

$back = New-Object System.Windows.Forms.Button
$back.Location = New-Object System.Drawing.Point 310, 322
$back.Size = New-Object System.Drawing.Size 82, 32
$back.Text = "Back"

$next = New-Object System.Windows.Forms.Button
$next.Location = New-Object System.Drawing.Point 402, 322
$next.Size = New-Object System.Drawing.Size 82, 32
$next.Text = "Next"

$cancel = New-Object System.Windows.Forms.Button
$cancel.Location = New-Object System.Drawing.Point 494, 322
$cancel.Size = New-Object System.Drawing.Size 82, 32
$cancel.Text = "Cancel"

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 180

$script:page = 0
$script:installStarted = $false

function Set-Page {
    param([int]$Page)
    $script:page = $Page
    $agree.Visible = $false
    $pathBox.Visible = $false
    $progress.Visible = $false
    $status.Visible = $false
    $back.Enabled = $Page -gt 0 -and $Page -lt 3
    $next.Enabled = $true
    $cancel.Enabled = $true

    if ($Page -eq 0) {
        $title.Text = "Welcome to the WGA Trial Installer"
        $body.Text = "This safe local wizard simulates a real installer flow for GUI automation validation."
        $next.Text = "Next"
    } elseif ($Page -eq 1) {
        $title.Text = "License Agreement"
        $body.Text = "Accept the trial installer terms to continue. This test does not install system software."
        $agree.Visible = $true
        $next.Text = "Next"
        $next.Enabled = $agree.Checked
    } elseif ($Page -eq 2) {
        $title.Text = "Choose Install Location"
        $body.Text = "The wizard will write a small marker file to prove that the simulated install completed."
        $pathBox.Visible = $true
        $next.Text = "Install"
    } elseif ($Page -eq 3) {
        $title.Text = "Installing WGA Trial"
        $body.Text = "Please wait while the wizard performs the simulated installation."
        $progress.Visible = $true
        $status.Visible = $true
        $status.Text = "Installing..."
        $back.Enabled = $false
        $next.Enabled = $false
        $cancel.Enabled = $false
        $next.Text = "Install"
        if (!$script:installStarted) {
            $script:installStarted = $true
            $progress.Value = 0
            $timer.Start()
        }
    } elseif ($Page -eq 4) {
        $title.Text = "Installation Complete"
        $body.Text = "WGA trial installer completed successfully."
        $status.Visible = $true
        $status.Text = "Installed marker: $markerPath"
        $back.Enabled = $false
        $next.Enabled = $true
        $cancel.Enabled = $false
        $next.Text = "Finish"
    }
}

$agree.Add_CheckedChanged({
    if ($script:page -eq 1) {
        $next.Enabled = $agree.Checked
    }
})

$back.Add_Click({
    if ($script:page -gt 0 -and $script:page -lt 3) {
        Set-Page ($script:page - 1)
    }
})

$next.Add_Click({
    if ($script:page -eq 4) {
        $form.Close()
        return
    }
    if ($script:page -eq 2) {
        $script:installStarted = $false
        Set-Page 3
        return
    }
    Set-Page ($script:page + 1)
})

$cancel.Add_Click({
    $form.Close()
})

$timer.Add_Tick({
    if ($progress.Value -lt 100) {
        $progress.Value = [Math]::Min(100, $progress.Value + 20)
        $status.Text = "Installing... $($progress.Value)%"
    }
    if ($progress.Value -ge 100) {
        $timer.Stop()
        New-Item -ItemType Directory -Path $pathBox.Text -Force | Out-Null
        "WGA trial installer completed at $(Get-Date -Format o)" | Set-Content -Path $markerPath -Encoding UTF8
        Set-Page 4
    }
})

$form.Controls.AddRange(@($title, $body, $pathBox, $agree, $progress, $status, $back, $next, $cancel))
Set-Page 0
[void]$form.ShowDialog()
