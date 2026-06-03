$ErrorActionPreference = "Stop"

$TaskName = "WinGuiAgent"
$AgentPath = "C:\GuiAgent\win-gui-agent\agent\WinGuiAgent.ps1"

if (!(Test-Path $AgentPath)) {
    throw "Agent script not found: $AgentPath"
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File $AgentPath -HostName 127.0.0.1 -Port 8765"

$Principal = New-ScheduledTaskPrincipal `
    -UserId "$env:COMPUTERNAME\xuan" `
    -LogonType Interactive `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 12)

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -Settings $Settings | Out-Null
Get-ScheduledTask -TaskName $TaskName
