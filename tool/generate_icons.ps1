$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $projectRoot 'assets/icon'
$foreground = [Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'sometime_foreground.png'))
$background = [Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'sometime_background.png'))
$monochrome = [Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'sometime_monotone_foreground.png'))

function New-Canvas([int]$Size, [bool]$Opaque) {
    $format = if ($Opaque) { [Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [Drawing.Imaging.PixelFormat]::Format32bppArgb }
    return [Drawing.Bitmap]::new($Size, $Size, $format)
}
function Draw-Layer($Canvas, $Layer, [double]$Fraction) {
    $graphics = [Drawing.Graphics]::FromImage($Canvas)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $side = [single]($Canvas.Width * $Fraction)
    $offset = [single](($Canvas.Width - $side) / 2)
    $graphics.DrawImage($Layer, $offset, $offset, $side, $side)
    $graphics.Dispose()
}
function Save-Icon($Bitmap, [string]$Path) {
    $target = Join-Path $projectRoot $Path
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    $Bitmap.Save($target, [Drawing.Imaging.ImageFormat]::Png)
}

$source = New-Canvas 1024 $true
Draw-Layer $source $background 1
Draw-Layer $source $foreground 0.86
Save-Icon $source 'assets/icon/sometime_full.png'
function Write-AppIcon([string]$Path, [int]$Size) {
    $bitmap = New-Canvas $Size $true
    Draw-Layer $bitmap $source 1
    Save-Icon $bitmap $Path
    $bitmap.Dispose()
}

$iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$contents = Get-Content -LiteralPath (Join-Path $projectRoot "$iconSet/Contents.json") -Raw | ConvertFrom-Json
foreach ($entry in $contents.images) {
    if ($entry.filename) {
        $points = [double]::Parse($entry.size.Split('x')[0], [Globalization.CultureInfo]::InvariantCulture)
        Write-AppIcon "$iconSet/$($entry.filename)" ([int]($points * [int]$entry.scale.TrimEnd('x')))
    }
}
$densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
foreach ($density in $densities.GetEnumerator()) {
    Write-AppIcon "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher.png" $density.Value
}

# Keep the card stack and droplet inside the central 66 dp safe circle.
$layerRoot = 'android/app/src/main/res/drawable-nodpi'
foreach ($entry in @(@{Name='sometime_foreground'; Image=$foreground}, @{Name='sometime_monochrome'; Image=$monochrome})) {
    $layer = New-Canvas 432 $false
    Draw-Layer $layer $entry.Image 0.60
    Save-Icon $layer "$layerRoot/$($entry.Name).png"
    $layer.Dispose()
}
$layer = New-Canvas 432 $true
Draw-Layer $layer $background 1
Save-Icon $layer "$layerRoot/sometime_background.png"
$layer.Dispose()
Write-AppIcon 'web/favicon.png' 32
foreach ($size in @(192, 512)) {
    Write-AppIcon "web/icons/Icon-$size.png" $size
    Write-AppIcon "web/icons/Icon-maskable-$size.png" $size
}
$source.Dispose()
$foreground.Dispose()
$background.Dispose()
$monochrome.Dispose()
Write-Output 'The Sometime platform icons are complete.'
