# Stages a clean distributable folder (deploy\) and builds the installer.
# Run from anywhere:  powershell -File scripts\stage-deploy.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "build"
$deploy = Join-Path $root "deploy"
$cmake = "C:\Program Files\CMake\bin\cmake.exe"
$windeployqt = "C:\Users\Max\Qt\6.8.3\msvc2022_64\bin\windeployqt.exe"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"

Write-Host "== Building Release =="
& $cmake --build $build --config Release
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host "== Staging deploy folder =="
if (Test-Path $deploy) { Remove-Item $deploy -Recurse -Force }
New-Item -ItemType Directory $deploy | Out-Null
Copy-Item (Join-Path $build "Release\Mosaic.exe") $deploy
Copy-Item (Join-Path $build "Release\Processing.NDI.Lib.x64.dll") $deploy

& $windeployqt --release --qmldir (Join-Path $root "qml") (Join-Path $deploy "Mosaic.exe")
if ($LASTEXITCODE -ne 0) { throw "windeployqt failed" }

Write-Host "== Building installer =="
& $iscc (Join-Path $root "installer\mosaic.iss")
if ($LASTEXITCODE -ne 0) { throw "ISCC failed" }

Write-Host "== Done =="
Get-ChildItem (Join-Path $root "dist")
