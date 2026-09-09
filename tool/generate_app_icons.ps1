$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$iconColor = [System.Drawing.Color]::FromArgb(255, 171, 209, 181)
$workspace = Split-Path -Parent $PSScriptRoot
$foregroundPath = Join-Path $workspace 'assets\icon\sometime_foreground.png'

function Write-SometimeIcon {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$Size
    )

    $foreground = [System.Drawing.Image]::FromFile($foregroundPath)
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($iconColor)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($foreground, 0, 0, $Size, $Size)
    $graphics.Dispose()
    $foreground.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

Write-SometimeIcon -Path (Join-Path $workspace 'assets\icon\sometime_full.png') -Size 1024

$androidSizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($entry in $androidSizes.GetEnumerator()) {
    $path = Join-Path $workspace "android\app\src\main\res\$($entry.Key)\ic_launcher.png"
    Write-SometimeIcon -Path $path -Size $entry.Value
}

$iosDirectory = Join-Path $workspace 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
Get-ChildItem $iosDirectory -Filter '*.png' | ForEach-Object {
    $image = [System.Drawing.Image]::FromFile($_.FullName)
    $size = $image.Width
    $image.Dispose()
    Write-SometimeIcon -Path $_.FullName -Size $size
}

Write-SometimeIcon -Path (Join-Path $workspace 'web\favicon.png') -Size 32
Write-SometimeIcon -Path (Join-Path $workspace 'web\icons\Icon-192.png') -Size 192
Write-SometimeIcon -Path (Join-Path $workspace 'web\icons\Icon-512.png') -Size 512
Write-SometimeIcon -Path (Join-Path $workspace 'web\icons\Icon-maskable-192.png') -Size 192
Write-SometimeIcon -Path (Join-Path $workspace 'web\icons\Icon-maskable-512.png') -Size 512
