[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '1.0.0',
    [switch]$Test,
    [switch]$Package
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot 'build'
$distRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $buildRoot, $distRoot -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $compiler)) {
    throw 'The .NET Framework C# compiler was not found. Build on Windows with .NET Framework 4.8 installed.'
}

# Original project artwork; no vendor icon is copied or distributed.
Add-Type -AssemblyName System.Drawing
$iconFrames = New-Object 'System.Collections.Generic.List[byte[]]'
$sizes = @(16, 24, 32, 48, 64, 128, 256)
foreach ($size in $sizes) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.ScaleTransform(($size / 256.0), ($size / 256.0))
    $rounded = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rounded.AddArc(8, 8, 104, 104, 180, 90)
    $rounded.AddArc(144, 8, 104, 104, 270, 90)
    $rounded.AddArc(144, 144, 104, 104, 0, 90)
    $rounded.AddArc(8, 144, 104, 104, 90, 90)
    $rounded.CloseFigure()
    $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        ([System.Drawing.Point]::new(8, 8)), ([System.Drawing.Point]::new(248, 248)),
        ([System.Drawing.Color]::FromArgb(37, 99, 235)), ([System.Drawing.Color]::FromArgb(124, 58, 237)))
    $graphics.FillPath($gradient, $rounded)
    $letter = New-Object System.Drawing.Drawing2D.GraphicsPath
    $letter.FillMode = [System.Drawing.Drawing2D.FillMode]::Alternate
    $letter.AddPolygon([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(56,190), [System.Drawing.PointF]::new(119,60),
        [System.Drawing.PointF]::new(145,60), [System.Drawing.PointF]::new(208,190),
        [System.Drawing.PointF]::new(173,190), [System.Drawing.PointF]::new(160,160),
        [System.Drawing.PointF]::new(102,160), [System.Drawing.PointF]::new(89,190)))
    $letter.AddPolygon([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(115,131), [System.Drawing.PointF]::new(147,131), [System.Drawing.PointF]::new(131,92)))
    $graphics.FillPath([System.Drawing.Brushes]::White, $letter)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 12)
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLines($pen, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(177,55), [System.Drawing.PointF]::new(209,55), [System.Drawing.PointF]::new(209,87)))
    $graphics.DrawLine($pen, 208, 56, 175, 89)
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $iconFrames.Add($stream.ToArray())
    if ($size -eq 256) { $bitmap.Save((Join-Path $buildRoot 'launcher-preview.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    $stream.Dispose(); $pen.Dispose(); $letter.Dispose(); $gradient.Dispose(); $rounded.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$iconPath = Join-Path $buildRoot 'launcher.ico'
$iconFile = [System.IO.File]::Create($iconPath)
$writer = New-Object System.IO.BinaryWriter($iconFile)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$iconFrames[$i].Length); $writer.Write([uint32]$offset)
        $offset += $iconFrames[$i].Length
    }
    foreach ($frame in $iconFrames) { $writer.Write([byte[]]$frame) }
} finally { $writer.Dispose(); $iconFile.Dispose() }

$assemblyInfo = Join-Path $buildRoot 'AssemblyInfo.cs'
$assemblyText = @"
using System.Reflection;
[assembly: AssemblyTitle("Antigravity Proxy Launcher")]
[assembly: AssemblyProduct("Antigravity Proxy Launcher")]
[assembly: AssemblyDescription("An independent, configurable Windows launcher for Antigravity.")]
[assembly: AssemblyCopyright("Copyright (c) 2026 Jack464")]
[assembly: AssemblyVersion("$Version.0")]
[assembly: AssemblyFileVersion("$Version.0")]
[assembly: AssemblyInformationalVersion("$Version")]
"@
[IO.File]::WriteAllText($assemblyInfo, $assemblyText, [Text.Encoding]::UTF8)
$sources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Filter '*.cs' -File | Sort-Object Name | Select-Object -ExpandProperty FullName)
if ($sources.Count -eq 0) { throw 'No C# source files were found.' }
$exePath = Join-Path $distRoot 'AntigravityProxyLauncher.exe'
$common = @('/nologo', '/optimize+', '/platform:anycpu', '/codepage:65001', '/utf8output', '/reference:System.Core.dll', '/reference:System.Drawing.dll', '/reference:System.Windows.Forms.dll')
& $compiler @common '/target:winexe' ("/win32icon:$iconPath") ("/out:$exePath") @sources $assemblyInfo
if ($LASTEXITCODE -ne 0) { throw "Compilation failed (exit $LASTEXITCODE)." }

if ($Test) {
    $testPath = Join-Path $buildRoot 'LauncherTests.exe'
    $testSources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*.cs' -File | Select-Object -ExpandProperty FullName)
    & $compiler @common '/target:exe' '/main:LauncherTests' ("/out:$testPath") @sources @testSources $assemblyInfo
    if ($LASTEXITCODE -ne 0) { throw "Test compilation failed (exit $LASTEXITCODE)." }
    & $testPath
    if ($LASTEXITCODE -ne 0) { throw "Tests failed (exit $LASTEXITCODE)." }
}

if ($Package) {
    $zipPath = Join-Path $distRoot "AntigravityProxyLauncher-v$Version-windows.zip"
    $packageFiles = @($exePath, (Join-Path $projectRoot 'README.md'), (Join-Path $projectRoot 'README.en.md'), (Join-Path $projectRoot 'LICENSE'))
    Compress-Archive -LiteralPath $packageFiles -DestinationPath $zipPath -Force
    $hashLines = @($exePath, $zipPath) | ForEach-Object {
        $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
        $hash.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_)
    }
    [IO.File]::WriteAllLines((Join-Path $distRoot 'SHA256SUMS.txt'), $hashLines, [Text.Encoding]::ASCII)
}
Write-Output "Built $exePath (version $Version)."
