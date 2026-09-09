param(
    [string]$OutputPath = "android/app/src/main/res/drawable-nodpi/sometime_widget_preview.png",
    [switch]$Dark
)

Add-Type -AssemblyName System.Drawing

$bitmap = [System.Drawing.Bitmap]::new(560, 500)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.Color]::Transparent)

$fonts = [System.Drawing.Text.PrivateFontCollection]::new()
$fonts.AddFontFile((Resolve-Path "assets/fonts/Geist-Variable.ttf"))
$family = $fonts.Families[0]

function New-RoundedPath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$backgroundColor = if ($Dark) { [System.Drawing.Color]::FromArgb(255, 18, 18, 18) } else { [System.Drawing.Color]::FromArgb(255, 250, 250, 248) }
$inkColor = if ($Dark) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }
$textColor = if ($Dark) { [System.Drawing.Color]::FromArgb(255, 239, 239, 234) } else { [System.Drawing.Color]::FromArgb(255, 52, 56, 52) }
$secondaryColor = if ($Dark) { [System.Drawing.Color]::FromArgb(255, 169, 170, 164) } else { [System.Drawing.Color]::FromArgb(255, 105, 109, 102) }
$outlineColor = if ($Dark) { [System.Drawing.Color]::FromArgb(255, 119, 122, 115) } else { [System.Drawing.Color]::FromArgb(255, 146, 150, 142) }
$background = [System.Drawing.SolidBrush]::new($backgroundColor)
$surfacePath = New-RoundedPath 4 4 552 492 44
$graphics.FillPath($background, $surfacePath)

$ink = [System.Drawing.SolidBrush]::new($inkColor)
$text = [System.Drawing.SolidBrush]::new($textColor)
$secondary = [System.Drawing.SolidBrush]::new($secondaryColor)
$outline = [System.Drawing.Pen]::new($outlineColor, 3)
$outline.DashPattern = [float[]](4, 4)
$titleFont = [System.Drawing.Font]::new($family, 32, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sectionFont = [System.Drawing.Font]::new($family, 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$taskFont = [System.Drawing.Font]::new($family, 26, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$descriptionFont = [System.Drawing.Font]::new($family, 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

$graphics.DrawString("Sometime", $titleFont, $ink, 32, 28)
$graphics.DrawString("TODAY", $sectionFont, $secondary, 32, 88)

foreach ($row in @(
    @{ Y = 132; Title = "Plan the week"; Description = "Choose three priorities" },
    @{ Y = 230; Title = "Call Sam"; Description = "" }
)) {
    $control = New-RoundedPath 34 ($row.Y + 5) 38 32 10
    $graphics.DrawPath($outline, $control)
    $graphics.DrawString($row.Title, $taskFont, $text, 92, $row.Y)
    if ($row.Description.Length -gt 0) {
        $graphics.DrawString($row.Description, $descriptionFont, $secondary, 92, ($row.Y + 38))
    }
}

$plusPath = New-RoundedPath 444 380 80 80 24
$graphics.FillPath($ink, $plusPath)
$plusPen = [System.Drawing.Pen]::new($(if ($Dark) { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::White }), 6)
$plusPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$plusPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($plusPen, 466, 420, 502, 420)
$graphics.DrawLine($plusPen, 484, 402, 484, 438)

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$plusPen.Dispose()
$outline.Dispose()
$titleFont.Dispose()
$sectionFont.Dispose()
$taskFont.Dispose()
$descriptionFont.Dispose()
$ink.Dispose()
$text.Dispose()
$secondary.Dispose()
$background.Dispose()
$surfacePath.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
$fonts.Dispose()
