# Windows 用に書き出して、配布用の zip とインストーラーを作る。
# 使い方（プロジェクトのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\export.ps1
# 必要なもの: Godot 4.7.2 と、その export templates、Inno Setup 6（winget install JRSoftware.InnoSetup）
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe"
$build = Join-Path $root "build"
$dist = Join-Path $root "dist"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"

Set-Location $root
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force $build, $dist | Out-Null

& $godot --headless --path $root --export-release "Windows Desktop" (Join-Path $build "Tetris.exe")
if (-not (Test-Path (Join-Path $build "Tetris.exe"))) { throw "export failed" }

# CPU 対戦の思考エンジンは lib/ に、同梱物のライセンスは licenses/ に置く。
New-Item -ItemType Directory -Force (Join-Path $build "lib"), (Join-Path $build "licenses") | Out-Null
Copy-Item (Join-Path $root "lib\cold-clear-2.exe") (Join-Path $build "lib")
Copy-Item (Join-Path $root "lib\cold-clear-2-six-three.json") (Join-Path $build "lib")
Copy-Item (Join-Path $root "lib\COLD-CLEAR-2-LICENSE-*") (Join-Path $build "licenses")
Copy-Item (Join-Path $root "assets\fonts\OFL.txt") (Join-Path $build "licenses\M-PLUS-ROUNDED-1C-OFL.txt")
Copy-Item (Join-Path $root "assets\fonts\OFL-MPLUS1p.txt") (Join-Path $build "licenses\M-PLUS-1P-OFL.txt")

$zip = Join-Path $dist "Tetris-windows-x86_64.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
# Compress-Archive（PowerShell 5.1）は区切りが \ になり、展開ツールによってはフォルダにならないので tar で作る
Push-Location $build
tar -a -c -f $zip *
Pop-Location

# インストーラー。バージョンは project.godot の config/version
$version = (Select-String -Path (Join-Path $root "project.godot") -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
& $iscc /Q "/DAppVersion=$version" (Join-Path $PSScriptRoot "installer.iss")
if ($LASTEXITCODE -ne 0) { throw "installer build failed" }
Write-Output "done: $zip"
Write-Output "done: $(Join-Path $dist "Tetris-Setup-v$version.exe")"
