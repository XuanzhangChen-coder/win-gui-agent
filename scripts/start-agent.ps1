$ErrorActionPreference = "Stop"

$AgentPath = "Z:\win-gui-agent\agent\WinGuiAgent.ps1"
if (!(Test-Path $AgentPath)) {
    $AgentPath = "C:\GuiAgent\win-gui-agent\agent\WinGuiAgent.ps1"
}

if (!(Test-Path $AgentPath)) {
    throw "Agent script not found. Checked Z:\win-gui-agent and C:\GuiAgent."
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AgentPath -HostName 127.0.0.1 -Port 8765
