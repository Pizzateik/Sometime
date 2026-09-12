$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $projectRoot 'assets\icon'
$appleMaster = [Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'Apple_Full_Icon.png'))
$androidMaster = [Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'Android_Full_Icon.png'))

function Save-Icon {
    param(
        [Parameter(Mandatory = $true)][Drawing.Bitmap]$Source,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$Size
    )

    $target = Join-Path $projectRoot $Path
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    $bitmap = [Drawing.Bitmap]::new($Size, $Size, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $graphics.Dispose()
    $bitmap.Save($target, [Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$iconSet = 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
$contentsPath = Join-Path $projectRoot "$iconSet\Contents.json"
$contents = Get-Content -LiteralPath $contentsPath -Raw | ConvertFrom-Json
foreach ($entry in $contents.images) {
    if ($entry.filename) {
        $points = [double]::Parse(
            $entry.size.Split('x')[0],
            [Globalization.CultureInfo]::InvariantCulture
        )
        $size = [int]($points * [int]$entry.scale.TrimEnd('x'))
        Save-Icon $appleMaster "$iconSet\$($entry.filename)" $size
    }
}

$densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
foreach ($density in $densities.GetEnumerator()) {
    Save-Icon $androidMaster "android\app\src\main\res\mipmap-$($density.Key)\ic_launcher.png" $density.Value
}

Save-Icon $appleMaster 'web\favicon.png' 32
foreach ($size in @(192, 512)) {
    Save-Icon $appleMaster "web\icons\Icon-$size.png" $size
    Save-Icon $appleMaster "web\icons\Icon-maskable-$size.png" $size
}

Copy-Item -LiteralPath (Join-Path $assetRoot 'Android_Full_Icon.png') -Destination (Join-Path $projectRoot 'store\google-play-icon.png') -Force
$appleMaster.Dispose()
$androidMaster.Dispose()
Write-Output 'The Sometime platform icons are complete.'
