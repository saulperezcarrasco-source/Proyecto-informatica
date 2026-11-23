$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$assets = Join-Path $project 'assets/national'
New-Item -ItemType Directory -Force $assets | Out-Null
$cli = Join-Path $PSScriptRoot 'cli/pmtiles.exe'
if (-not (Test-Path -LiteralPath $cli)) {
  & curl.exe -L --fail -o (Join-Path $PSScriptRoot 'pmtiles.zip') 'https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Windows_x86_64.zip'
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar PMTiles' }
  Expand-Archive -LiteralPath (Join-Path $PSScriptRoot 'pmtiles.zip') -DestinationPath (Join-Path $PSScriptRoot 'cli')
}
$archive = Join-Path $assets 'dominican-republic.pmtiles'
if (-not (Test-Path -LiteralPath $archive)) {
  & $cli extract 'https://build.protomaps.com/20261118.pmtiles' $archive '--bbox=-72.05,17.3,-68.2,20.1'
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo extraer el mapa' }
}
$hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
$manifest=Get-Content -LiteralPath (Join-Path $assets 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($hash -ne $manifest.sha256) { throw 'El archivo no coincide con el extracto verificado' }
foreach ($name in @('light','dark')) {
  $path=Join-Path $assets "$name.json"
  & curl.exe -L --fail -o $path "https://npm-style.protomaps.dev/style.json?version=5.7.2&theme=$name&tiles=20261118&lang=es"
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar el estilo' }
  $style=Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
  $style.PSObject.Properties.Remove('glyphs'); $style.PSObject.Properties.Remove('sprite')
  $style.sources=[pscustomobject]@{protomaps=[pscustomobject]@{type='vector';url='pmtiles://assets/national/dominican-republic.pmtiles'}}
  if($name -eq 'dark') { foreach($layer in $style.layers) { if($layer.type -eq 'symbol' -and $layer.paint) { $layer.paint|Add-Member -Force -NotePropertyName 'text-color' -NotePropertyValue '#dce9e4'; $layer.paint|Add-Member -Force -NotePropertyName 'text-halo-color' -NotePropertyValue '#15241f'; $layer.paint|Add-Member -Force -NotePropertyName 'text-halo-width' -NotePropertyValue 1.2 } } }
  [IO.File]::WriteAllText($path,($style|ConvertTo-Json -Depth 70),[Text.UTF8Encoding]::new($false))
}
& $cli show $archive
