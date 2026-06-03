$ErrorActionPreference = "Stop"

$KiCadCli = "C:\Program Files\KiCad\10.0\bin\kicad-cli.exe"
$ProjectDir = "C:\EE-Projects\wga-kicad-demo\pic_programmer"
$OutDir = "C:\EE-Projects\wga-kicad-demo\outputs"

New-Item -ItemType Directory -Force $OutDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $OutDir "gerbers") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $OutDir "drill") | Out-Null

& $KiCadCli sch erc `
    (Join-Path $ProjectDir "pic_programmer.kicad_sch") `
    -o (Join-Path $OutDir "erc.rpt") `
    --format report `
    --severity-all
if ($LASTEXITCODE -ne 0) { throw "ERC failed with exit code $LASTEXITCODE" }

& $KiCadCli pcb drc `
    (Join-Path $ProjectDir "pic_programmer.kicad_pcb") `
    -o (Join-Path $OutDir "drc.rpt") `
    --format report `
    --severity-all `
    --refill-zones
if ($LASTEXITCODE -ne 0) { throw "DRC failed with exit code $LASTEXITCODE" }

& $KiCadCli sch export pdf `
    (Join-Path $ProjectDir "pic_programmer.kicad_sch") `
    -o (Join-Path $OutDir "schematic.pdf") `
    --black-and-white
if ($LASTEXITCODE -ne 0) { throw "Schematic PDF export failed with exit code $LASTEXITCODE" }

& $KiCadCli pcb export gerbers `
    (Join-Path $ProjectDir "pic_programmer.kicad_pcb") `
    -o (Join-Path $OutDir "gerbers") `
    --board-plot-params
if ($LASTEXITCODE -ne 0) { throw "Gerber export failed with exit code $LASTEXITCODE" }

& $KiCadCli pcb export drill `
    (Join-Path $ProjectDir "pic_programmer.kicad_pcb") `
    -o (Join-Path $OutDir "drill") `
    --generate-report `
    --report-path (Join-Path $OutDir "drill\drill_report.rpt")
if ($LASTEXITCODE -ne 0) { throw "Drill export failed with exit code $LASTEXITCODE" }

Get-ChildItem $OutDir -Recurse |
    Select-Object FullName, Length |
    Sort-Object FullName |
    ConvertTo-Json -Depth 3
