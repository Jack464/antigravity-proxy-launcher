# Run on an unlocked Windows desktop. Uses a temporary test app, not the real Antigravity installation.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build.ps1') -Test
$fixtureDirectory = Join-Path $projectRoot 'build\gui-fixture'
New-Item -ItemType Directory -Path $fixtureDirectory -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$fixtureExe = Join-Path $fixtureDirectory 'Antigravity.exe'
& $compiler /nologo /target:winexe /reference:System.Windows.Forms.dll ("/out:$fixtureExe") (Join-Path $projectRoot 'tests\FixtureApp.cs')
if ($LASTEXITCODE -ne 0) { throw 'Fixture compilation failed.' }
& (Join-Path $projectRoot 'build\LauncherTests.exe') $fixtureExe
if ($LASTEXITCODE -ne 0) { throw 'GUI regression test failed.' }
