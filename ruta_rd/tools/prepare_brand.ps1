$ErrorActionPreference='Stop'
# Compile launcher densities from the prepared symbol; keep original PNG intact.
Add-Type -AssemblyName System.Drawing
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=[Drawing.Image]::FromFile((Join-Path $project 'assets/brand/ruta_symbol.png'))
function Raster([string]$path,[int]$size,[bool]$white) {
  $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics=[Drawing.Graphics]::FromImage($bitmap)
  try {
    if($white){$graphics.Clear([Drawing.Color]::White)}else{$graphics.Clear([Drawing.Color]::Transparent)}
    $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($source,0,0,$size,$size)
    $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
  } finally {$graphics.Dispose();$bitmap.Dispose()}
}
try {
  $res=Join-Path $project 'android/app/src/main/res'
  foreach($density in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))){
    Raster (Join-Path $res "mipmap-$($density[0])/ic_launcher.png") $density[1] $true
  }
  New-Item -ItemType Directory -Path (Join-Path $res 'drawable-nodpi') -Force | Out-Null
  Raster (Join-Path $res 'drawable-nodpi/brand_symbol.png') 432 $false
  Copy-Item -LiteralPath (Join-Path $project 'assets/brand/ruta_rd.png') -Destination (Join-Path $res 'drawable-nodpi/brand_full.png')
} finally {$source.Dispose()}
