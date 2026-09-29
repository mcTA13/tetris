# Windows 用に書き出して、配布用の zip を作る。
# 使い方（プロジェクトのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\export.ps1
# 必要なもの: Godot 4.7.2 と、その export templates
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe"
$build = Join-Path $root "build"
$dist = Join-Path $root "dist"

Set-Location $root
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force $build, $dist | Out-Null

& $godot --headless --path $root --export-release "Windows Desktop" (Join-Path $build "Tetris.exe")
if (-not (Test-Path (Join-Path $build "Tetris.exe"))) { throw "export failed" }

# CPU 対戦の思考エンジンと、同梱物のライセンスは exe と同じフォルダに置く
Copy-Item (Join-Path $root "bin\cold-clear-2.exe") $build
New-Item -ItemType Directory -Force (Join-Path $build "licenses") | Out-Null
Copy-Item (Join-Path $root "bin\COLD-CLEAR-2-LICENSE-*") (Join-Path $build "licenses")
Copy-Item (Join-Path $root "assets\fonts\OFL.txt") (Join-Path $build "licenses\M-PLUS-ROUNDED-1C-OFL.txt")

$zip = Join-Path $dist "Tetris-windows-x86_64.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $build "*") -DestinationPath $zip
Write-Output "done: $zip"
