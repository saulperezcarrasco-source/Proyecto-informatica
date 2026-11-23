$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sdk=Join-Path $env:LOCALAPPDATA 'Android/sdk'
function Utf8File([string]$path,[string]$value){[IO.File]::WriteAllText($path,$value,[Text.UTF8Encoding]::new($false))}
Push-Location $project
try {
  if(& git status --porcelain){throw 'El codigo debe estar guardado antes de empaquetar.'}
  $build=Get-Content build/demo-build.json -Raw -Encoding UTF8 | ConvertFrom-Json
  $commit=((& git rev-parse HEAD) -join '').Trim()
  if($build.codeCommit -ne $commit){throw 'La compilacion corresponde a otro commit. Ejecuta tools/build_demo.ps1.'}
  $hash=(Get-FileHash -LiteralPath $build.apk -Algorithm SHA256).Hash.ToLowerInvariant()
  if($hash -ne $build.sha256){throw 'El APK cambio desde la compilacion registrada.'}
  $parts=$build.version -split '\+'
  $version=$parts[0];$buildNumber=$parts[1]
  $name="v$version"
  $output=Join-Path $project "entregables/$name"
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  $toolsDir=Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
  $signerJar=Join-Path $toolsDir.FullName 'lib/apksigner.jar'
  $java=if($env:JAVA_HOME){Join-Path $env:JAVA_HOME 'bin/java.exe'}else{(Get-Command java -ErrorAction Stop).Source}
  $aapt=Join-Path $toolsDir.FullName 'aapt.exe'
  $signatureLines=& $java --enable-native-access=ALL-UNNAMED -jar $signerJar verify --verbose --print-certs $build.apk
  if($LASTEXITCODE -ne 0){throw 'La firma del APK no es valida.'}
  $signature=$signatureLines -join "`n"
  Utf8File (Join-Path $output 'firma-verificada.txt') $signature
  if($signature -notmatch 'Android Debug'){throw 'La firma difiere de la firma de desarrollo documentada.'}
  $badging=& $aapt dump badging $build.apk
  if($LASTEXITCODE -ne 0){throw 'No se pudo inspeccionar el APK.'}
  $packageLine=($badging | Where-Object {$_ -like 'package:*'}) -join ''
  if($packageLine -notmatch "name='com.example.ruta_rd'" -or
     $packageLine -notmatch ("versionName='"+[regex]::Escape($version)+"'") -or
     $packageLine -notmatch "versionCode='$buildNumber'") {throw 'La version o paquete del APK no coincide con la entrega.'}
  # AARs can include auxiliary JNI libraries for other ABIs. Verify the actual
  # Flutter engine and AOT application, rather than the first aapt ABI label.
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($build.apk)
  try {
    $names=@($zip.Entries | ForEach-Object {$_.FullName})
    foreach($required in @('lib/x86_64/libapp.so','lib/x86_64/libflutter.so',
      'assets/flutter_assets/assets/national/dominican-republic.pmtiles',
      'assets/flutter_assets/assets/routing/dominican-walking.rdi')) {
      if($names -notcontains $required){throw "El APK no contiene el archivo requerido: $required"}
    }
    $otherEngines=$names | Where-Object {$_ -match '^lib/(?!x86_64/)[^/]+/(libapp|libflutter)\.so$'}
    if($otherEngines){throw 'El APK contiene un motor Flutter distinto del destino x64 documentado.'}
  } finally {$zip.Dispose()}
  Utf8File (Join-Path $output 'paquete-verificado.txt') ($badging -join "`n")
  $sensitive=& git ls-files | Where-Object {$_ -match '(?i)(^|/)key\.properties$|\.(jks|keystore)$'}
  if($sensitive){throw 'Hay archivos de firma registrados en Git; no se genera el archivo de fuentes.'}
  $apkName="ruta-rd-$name-android-x64.apk"
  Copy-Item -LiteralPath $build.apk -Destination (Join-Path $output $apkName)
  $sourcesName="fuentes-$name.zip"
  & git -C (Split-Path $project -Parent) archive --format=zip "--output=$(Join-Path $output $sourcesName)" $commit
  if($LASTEXITCODE -ne 0){throw 'No se pudo generar el codigo reproducible.'}
  foreach($file in @('INSTALAR.md','PRESENTACION.md','PRESENTACION.html','DATOS-Y-LICENCIAS.md')){
    Copy-Item -LiteralPath (Join-Path $project "docs/delivery/$file") -Destination (Join-Path $output $file)
  }
  Copy-Item assets/national/STYLE-LICENSE.txt (Join-Path $output 'LICENCIA-ESTILO.txt')
  Copy-Item assets/national/manifest.json (Join-Path $output 'datos-mapa.json')
  Copy-Item assets/routing/manifest.json (Join-Path $output 'datos-rutas.json')
  Copy-Item assets/regions/zona_piloto/manifest.json (Join-Path $output 'datos-piloto.json')
  $artifacts=@()
  foreach($fileName in @($apkName,$sourcesName,'respaldo.mp4','PRESENTACION.html','PRESENTACION.pdf')){
    $path=Join-Path $output $fileName
    if(Test-Path -LiteralPath $path){$artifacts+=@{file=$fileName;bytes=(Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}}
  }
  $manifest=[ordered]@{version=$version;versionCode=[int]$buildNumber;codeCommit=$commit;target='android-x64';
    signing='Android Debug; APK de demostracion, no publicacion Google Play';
    device='Pixel_10a / emulator-5554 / Android 17 API 37';flutter=$build.flutter;
    artifacts=$artifacts;utc=[DateTime]::UtcNow.ToString('o')}
  Utf8File (Join-Path $output 'manifest.json') ($manifest | ConvertTo-Json -Depth 6)
  $checksums=Get-ChildItem -LiteralPath $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
  }
  Utf8File (Join-Path $output 'SHA256SUMS.txt') (($checksums -join "`n")+"`n")
  Write-Output "Entrega preparada en $output. Probar el APK copiado; repetir empaquetado tras agregar el video."
} finally {Pop-Location}
