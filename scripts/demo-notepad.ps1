$ErrorActionPreference = "Stop"

$Base = "http://127.0.0.1:8765"

function Invoke-AgentPost {
    param(
        [string]$Path,
        [hashtable]$Body
    )
    $json = $Body | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -ContentType "application/json" -Body $json -Uri "$Base/$Path"
}

Invoke-AgentPost run @{ file = "notepad.exe" } | Out-Null
Start-Sleep -Seconds 1

$text = "hello gui agent - phase 3 action loop"
$result = Invoke-AgentPost type @{ text = $text }

$dest = "\\192.168.122.1\vmshare\wga-demo-notepad.png"
Copy-Item $result.after.path $dest -Force

[ordered]@{
    ok = $true
    text = $text
    screenshot = $dest
    activeWindowTitle = $result.screen.activeWindowTitle
}
