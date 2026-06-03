$ErrorActionPreference = "Stop"

$SourceProject = "C:\Program Files\KiCad\10.0\share\kicad\demos\pic_programmer"
$TargetProject = "C:\EE-Projects\wga-kicad-demo\pic_programmer"
$TargetRoot = Split-Path $TargetProject -Parent

if (!(Test-Path $SourceProject)) {
    throw "KiCad demo project not found: $SourceProject"
}

New-Item -ItemType Directory -Force $TargetRoot | Out-Null

Get-Process kicad, eeschema, pcbnew -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 700

if (Test-Path $TargetProject) {
    Remove-Item $TargetProject -Recurse -Force
}

Copy-Item $SourceProject $TargetProject -Recurse

[ordered]@{
    ok = $true
    source = $SourceProject
    target = $TargetProject
    project = Join-Path $TargetProject "pic_programmer.kicad_pro"
    schematic = Join-Path $TargetProject "pic_programmer.kicad_sch"
    pcb = Join-Path $TargetProject "pic_programmer.kicad_pcb"
} | ConvertTo-Json -Depth 3
