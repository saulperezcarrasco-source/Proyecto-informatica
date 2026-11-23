param([Parameter(Mandatory=$true)][string]$Apk)
$ErrorActionPreference='Stop'
$Apk=(Resolve-Path -LiteralPath $Apk).Path
$sdk=Join-Path $env:LOCALAPPDATA 'Android/sdk'
$buildTools=Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$java=Join-Path $env:JAVA_HOME 'bin/java.exe'
& $java --enable-native-access=ALL-UNNAMED -jar (Join-Path $buildTools.FullName 'lib/apksigner.jar') verify --verbose --print-certs $Apk
if($LASTEXITCODE -ne 0){throw 'Firma invalida.'}
& (Join-Path $buildTools.FullName 'zipalign.exe') -c -P 16 4 $Apk
if($LASTEXITCODE -ne 0){throw 'Alineacion ZIP de 16 KB invalida.'}
Write-Output 'ZIP alignment 16 KB: PASS'
& (Join-Path $buildTools.FullName 'aapt.exe') dump badging $Apk
if($LASTEXITCODE -ne 0){throw 'No se pudo leer el manifiesto Android.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($Apk)
try {
  foreach($abi in @('armeabi-v7a','arm64-v8a','x86_64')) {
    foreach($lib in @('libapp.so','libflutter.so')) {
      if(-not $zip.GetEntry("lib/$abi/$lib")){throw "Falta motor completo: $abi/$lib"}
    }
    Write-Output "Flutter engine + AOT $abi : PASS"
  }
    foreach($asset in @('assets/flutter_assets/assets/national/dominican-republic.pmtiles','assets/flutter_assets/assets/national/label-interior.geojson','assets/flutter_assets/assets/routing/dominican-walking.rdi','assets/flutter_assets/assets/routing/dominican-bicycle.rdi','assets/flutter_assets/assets/routing/dominican-motorcar.rdi','assets/flutter_assets/assets/routing/dominican-motorcycle.rdi','assets/flutter_assets/assets/brand/ruta_rd.png','assets/flutter_assets/assets/search/places.rds','assets/flutter_assets/assets/search/manifest.json')) {
    if(-not $zip.GetEntry($asset)){throw "Falta cartografia: $asset"}
  }
  $metadataReader=[IO.StreamReader]::new($zip.GetEntry('assets/flutter_assets/assets/search/manifest.json').Open())
  try {$catalog=$metadataReader.ReadToEnd() | ConvertFrom-Json} finally {$metadataReader.Dispose()}
  $catalogStream=$zip.GetEntry('assets/flutter_assets/assets/search/places.rds').Open()
  $sha=[Security.Cryptography.SHA256]::Create()
  try {$catalogHash=([BitConverter]::ToString($sha.ComputeHash($catalogStream))).Replace('-','').ToLowerInvariant()}
  finally {$catalogStream.Dispose();$sha.Dispose()}
  if($catalogHash -ne $catalog.sha256){throw 'El catalogo nacional no coincide con su manifiesto.'}
  Write-Output "National catalogue: $($catalog.count) records; SHA256 PASS"
  foreach($mode in @('bicycle','motorcar','motorcycle')) {
    $metadata=$zip.GetEntry("assets/flutter_assets/assets/routing/manifest-$mode.json")
    if(-not $metadata){throw "Falta manifiesto de rutas: $mode"}
    $metadataReader=[IO.StreamReader]::new($metadata.Open())
    try {$graph=$metadataReader.ReadToEnd() | ConvertFrom-Json} finally {$metadataReader.Dispose()}
    $stream=$zip.GetEntry("assets/flutter_assets/assets/routing/dominican-$mode.rdi").Open()
    $sha=[Security.Cryptography.SHA256]::Create()
    try {$hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}
    finally {$stream.Dispose();$sha.Dispose()}
    if($hash -ne $graph.sha256 -or $graph.temporalFilterRevision -ne 1){throw "Grafo de rutas invalido: $mode"}
    Write-Output "Routing $mode : $($graph.directedEdges) directed edges; SHA256 PASS"
  }
  # Check ELF PT_LOAD alignment independently of the ZIP container.
  foreach($entry in $zip.Entries | Where-Object {$_.FullName -match '^lib/(arm64-v8a|x86_64)/.*\.so$'}) {
    $memory=[IO.MemoryStream]::new()
    $stream=$entry.Open()
    try {$stream.CopyTo($memory)} finally {$stream.Dispose()}
    $reader=[IO.BinaryReader]::new($memory)
    try {
      $memory.Position=0
      if($reader.ReadUInt32() -ne 0x464c457f -or $reader.ReadByte() -ne 2 -or $reader.ReadByte() -ne 1){throw "ELF64 invalido: $($entry.FullName)"}
      $memory.Position=32; $offset=$reader.ReadUInt64()
      $memory.Position=54; $size=$reader.ReadUInt16(); $count=$reader.ReadUInt16()
      $loads=0
      for($i=0;$i -lt $count;$i++) {
        $memory.Position=[long]($offset+$i*$size)
        if($reader.ReadUInt32() -eq 1) {
          $loads++
          $memory.Position=[long]($offset+$i*$size+48)
          if($reader.ReadUInt64() -lt 16384){throw "PT_LOAD <16 KB: $($entry.FullName)"}
        }
      }
      if($loads -eq 0){throw "ELF sin PT_LOAD: $($entry.FullName)"}
      Write-Output "ELF 16 KB $($entry.FullName): PASS ($loads LOAD segments)"
    } finally {$reader.Dispose();$memory.Dispose()}
  }
} finally {$zip.Dispose()}
