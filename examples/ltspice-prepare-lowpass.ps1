$ErrorActionPreference = "Stop"

$InstallRoot = "C:\Users\xuan\AppData\Local\Programs\ADI\LTspice"
$LtspiceExe = Join-Path $InstallRoot "LTspice.exe"
$Source = "C:\Users\xuan\AppData\Local\LTspice\examples\Educational\2ndOrderLowpass.asc"
$ProjectDir = "C:\EE-Projects\wga-ltspice-demo"
$Target = Join-Path $ProjectDir "2ndOrderLowpass.asc"
$Manifest = Join-Path $ProjectDir "ltspice-demo-manifest.txt"

if (!(Test-Path -LiteralPath $LtspiceExe)) {
    throw "LTspice executable not found: $LtspiceExe"
}

if (!(Test-Path -LiteralPath $Source)) {
    throw "LTspice example source not found: $Source"
}

New-Item -ItemType Directory -Force -Path $ProjectDir | Out-Null
Copy-Item -LiteralPath $Source -Destination $Target -Force

$version = (Get-Item -LiteralPath $LtspiceExe).VersionInfo.ProductVersion
Set-Content -LiteralPath $Manifest -Encoding ascii -Value @(
    "LTspice demo prepared by win-gui-agent",
    "version=$version",
    "exe=$LtspiceExe",
    "project=$Target"
)

Get-Item -LiteralPath $LtspiceExe, $Target, $Manifest |
    Select-Object FullName, Length, LastWriteTime
