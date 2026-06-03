$ErrorActionPreference = "Stop"

$InstallRoot = "C:\Users\xuan\AppData\Local\Programs\ADI\LTspice"
$LtspiceExe = Join-Path $InstallRoot "LTspice.exe"
$Source = "C:\Users\xuan\AppData\Local\LTspice\examples\Educational\2ndOrderLowpass.asc"
$ProjectDir = "C:\EE-Projects\wga-ltspice-demo"
$Target = Join-Path $ProjectDir "2ndOrderLowpass.asc"
$SimNetlist = Join-Path $ProjectDir "rc_filter.cir"
$SimLog = Join-Path $ProjectDir "rc_filter.log"
$SimRaw = Join-Path $ProjectDir "rc_filter.raw"
$Manifest = Join-Path $ProjectDir "ltspice-demo-manifest.txt"

if (!(Test-Path -LiteralPath $LtspiceExe)) {
    throw "LTspice executable not found: $LtspiceExe"
}

if (!(Test-Path -LiteralPath $Source)) {
    throw "LTspice example source not found: $Source"
}

New-Item -ItemType Directory -Force -Path $ProjectDir | Out-Null
Copy-Item -LiteralPath $Source -Destination $Target -Force

$simFiles = @(
    $SimNetlist,
    $SimLog,
    $SimRaw,
    (Join-Path $ProjectDir "rc_filter.db"),
    (Join-Path $ProjectDir "rc_filter.op.raw")
)
Remove-Item -LiteralPath $simFiles -Force -ErrorAction SilentlyContinue

Set-Content -LiteralPath $SimNetlist -Encoding ascii -Value @(
    "* WGA LTspice RC filter demo",
    "V1 in 0 PULSE(0 5 0 1u 1u 1m 2m)",
    "R1 in out 1k",
    "C1 out 0 1u",
    ".tran 0 5m 0 10u",
    ".meas tran vout_final FIND V(out) AT=5m",
    ".end"
)

$sim = Start-Process `
    -FilePath $LtspiceExe `
    -ArgumentList @("-b", $SimNetlist) `
    -WorkingDirectory $ProjectDir `
    -Wait `
    -PassThru

if ($sim.ExitCode -ne 0) {
    throw "LTspice batch simulation failed with exit code $($sim.ExitCode)"
}

if (!(Test-Path -LiteralPath $SimRaw)) {
    throw "LTspice simulation raw output not found: $SimRaw"
}

if (!(Test-Path -LiteralPath $SimLog)) {
    throw "LTspice simulation log not found: $SimLog"
}

$logText = Get-Content -LiteralPath $SimLog -Raw
if ($logText -notlike "*vout_final*") {
    throw "LTspice simulation measurement not found in log: vout_final"
}

$version = (Get-Item -LiteralPath $LtspiceExe).VersionInfo.ProductVersion
Set-Content -LiteralPath $Manifest -Encoding ascii -Value @(
    "LTspice demo prepared by win-gui-agent",
    "version=$version",
    "exe=$LtspiceExe",
    "project=$Target",
    "simulation=$SimNetlist",
    "raw=$SimRaw",
    "log=$SimLog"
)

Get-Item -LiteralPath $LtspiceExe, $Target, $SimNetlist, $SimLog, $SimRaw, $Manifest |
    Select-Object FullName, Length, LastWriteTime
