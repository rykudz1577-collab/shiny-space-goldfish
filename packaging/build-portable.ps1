# Antares 3.0 — Windows portable build (spec 3.0 mục 65-66)
# Chạy trên Windows với Python 3.11+ đã cài dependencies:
#   pip install -r requirements.txt pyinstaller
#   powershell -ExecutionPolicy Bypass -File packaging\build-portable.ps1
#
# Output: dist/Antares-1.0.0-portable.zip
#   Antares/
#     Antares.exe        — GUI (WebView2)
#     portable.flag      — bật portable mode (data nằm ./data cạnh exe)
#     start.bat          — chạy không cần cài đặt
#     README-PORTABLE.txt

$ErrorActionPreference = "Stop"
$Version = "1.0.0"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "==> Build Antares $Version (onefolder)" -ForegroundColor Cyan
Set-Location $Root
python -m PyInstaller packaging\antares.spec --noconfirm --clean
if ($LASTEXITCODE -ne 0) { throw "PyInstaller failed" }

$Dist = Join-Path $Root "dist\Antares"
if (-not (Test-Path $Dist)) { throw "dist\Antares not found" }

Write-Host "==> Thêm portable markers" -ForegroundColor Cyan
# portable.flag rỗng -> AppPaths đón data tại .\data (mục 65)
New-Item -ItemType File -Force -Path (Join-Path $Dist "portable.flag") | Out-Null

# start.bat — double-click chạy không console
@'
@echo off
start "" "%~dp0Antares.exe"
'@ | Set-Content -Path (Join-Path $Dist "start.bat") -Encoding ASCII

Copy-Item (Join-Path $Root "README-PORTABLE.md") (Join-Path $Dist "README-PORTABLE.txt")

Write-Host "==> ZIP" -ForegroundColor Cyan
$Zip = Join-Path $Root "dist\Antares-$Version-portable.zip"
Compress-Archive -Path $Dist -DestinationPath $Zip -Force

Write-Host "==> Done: $Zip" -ForegroundColor Green
