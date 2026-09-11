#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

function Install-Driver {
    param([string]$Path)
    Write-Host "Installing driver: $Path" -ForegroundColor Cyan
    & pnputil.exe /add-driver $Path /install
    if ($LASTEXITCODE -notin @(0, 3010)) {
        throw "pnputil failed for $Path with exit code $LASTEXITCODE"
    }
}

Install-Driver (Join-Path $PSScriptRoot "amd64\vioserial\vioser.inf")
Install-Driver (Join-Path $PSScriptRoot "amd64\qxl\qxldod.inf")

$installDir = Join-Path $env:ProgramFiles "SPICE Guest Tools"
$existingService = Get-Service -Name "vdservice" -ErrorAction SilentlyContinue
if ($existingService) {
    Stop-Service -Name "vdservice" -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot "amd64\vdagent\*") $installDir

if (-not $existingService) {
    & (Join-Path $installDir "vdservice.exe") install
    if ($LASTEXITCODE -ne 0) {
        throw "SPICE guest agent service installation failed with exit code $LASTEXITCODE"
    }
}

Start-Service -Name "vdservice"
Write-Host ""
Write-Host "SPICE display driver and guest agent installed." -ForegroundColor Green
Write-Host "Restart Windows, then resize or maximize the VM window."
