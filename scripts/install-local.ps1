$ErrorActionPreference = "Stop"

$Source = "\\192.168.122.1\vmshare\win-gui-agent"
$Target = "C:\GuiAgent\win-gui-agent"

if (!(Test-Path $Source)) {
    throw "Source path not found: $Source"
}

if (Test-Path $Target) {
    Remove-Item $Target -Recurse -Force
}

New-Item -ItemType Directory -Path (Split-Path $Target -Parent) -Force | Out-Null
Copy-Item $Source $Target -Recurse -Force

Get-Item "$Target\agent\WinGuiAgent.ps1" | Select-Object FullName, Length, LastWriteTime
