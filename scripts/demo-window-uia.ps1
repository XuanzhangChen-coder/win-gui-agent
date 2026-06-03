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

$windows = Invoke-RestMethod -Uri "$Base/windows"
$notepad = @($windows.windows | Where-Object { $_.title -like "*Notepad*" -or $_.title -like "*记事本*" }) | Select-Object -First 1
if ($null -eq $notepad) {
    throw "Notepad window was not found"
}

Invoke-AgentPost activate_window @{ hwnd = $notepad.hwnd } | Out-Null
Invoke-AgentPost maximize_window @{ hwnd = $notepad.hwnd } | Out-Null

$tree = Invoke-AgentPost "uia/tree" @{
    hwnd = $notepad.hwnd
    maxDepth = 4
    maxNodes = 120
}

$editorCandidates = Invoke-AgentPost "uia/find" @{
    hwnd = $notepad.hwnd
    controlType = "Document"
    limit = 10
    includeOffscreen = $false
}

if ($editorCandidates.count -lt 1) {
    $editorCandidates = Invoke-AgentPost "uia/find" @{
        hwnd = $notepad.hwnd
        controlType = "Edit"
        limit = 10
        includeOffscreen = $false
    }
}

if ($editorCandidates.count -lt 1) {
    throw "No Notepad editor UIA element found"
}

$setText = Invoke-AgentPost "uia/set_text" @{
    hwnd = $notepad.hwnd
    controlType = ($editorCandidates.elements[0].controlType -replace "^ControlType\.", "")
    text = "phase 4-5 window and uia validation"
    includeOffscreen = $false
}

$dest = "\\192.168.122.1\vmshare\wga-demo-window-uia.png"
Copy-Item $setText.after.path $dest -Force

[ordered]@{
    ok = $true
    notepad = $notepad
    treeRoot = $tree.root
    editor = $editorCandidates.elements[0]
    setTextMethod = $setText.method
    screenshot = $dest
    activeWindowTitle = $setText.screen.activeWindowTitle
}
