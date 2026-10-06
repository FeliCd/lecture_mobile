# Generate original geometric app icons, without image-processing dependencies.
# Run from the repository root on Windows. All output stays in this repository.
Add-Type -AssemblyName System.Drawing
function Write-CompanionIcon([string] $target, [int] $size) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#AA4100'))
    $graphics.ScaleTransform($size / 1024.0, $size / 1024.0)
    $paper = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#FFF9F5'))
    $right = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#FFEADB'))
    $graphics.FillRectangle($paper, 224, 272, 280, 432)
    $graphics.FillRectangle($right, 528, 272, 272, 432)
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#AA4100'), 44)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($pen, 576, 464, 640, 528)
    $graphics.DrawLine($pen, 640, 528, 752, 400)
    $bitmap.Save((Join-Path (Get-Location).Path $target), [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose(); $paper.Dispose(); $right.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$densities = @{ 'mdpi'=48; 'hdpi'=72; 'xhdpi'=96; 'xxhdpi'=144; 'xxxhdpi'=192 }
foreach ($density in $densities.Keys) {
    Write-CompanionIcon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
}
$icons = Get-Content ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json -Raw | ConvertFrom-Json
foreach ($icon in $icons.images) {
    $size = [int]([double]($icon.size -split 'x')[0] * [double]($icon.scale -replace 'x', ''))
    Write-CompanionIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($icon.filename)" $size
}
