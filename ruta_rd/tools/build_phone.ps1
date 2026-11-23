$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sdk=Join-Path $env:LOCALAPPDATA 'Android/sdk'
function Utf8File([string]$path,[string]$value){[IO.File]::WriteAllText($path,$value,[Text.UTF8Encoding]::new($false))}
Push-Location $project
try {
  if(& git status --porcelain){throw 'Guarda el codigo antes de construir la entrega.'}
  $commit=((& git rev-parse HEAD) -join '').Trim()
  $version=([regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*(\S+)')).Groups[1].Value
  $name=($version -split '\+')[0]
  $output=Join-Path $project "entregables/v$name"
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  # The emulator-only delivery intentionally contains no ARM Flutter engine.
  # Build ONE universal APK so Android chooses a complete matching ABI.
  & flutter build apk --release --target-platform android-arm,android-arm64,android-x64
  if($LASTEXITCODE -ne 0){throw 'Fallo la compilacion universal.'}
  if((& git status --porcelain) -or (((& git rev-parse HEAD) -join '').Trim() -ne $commit)) {
    throw 'El codigo cambio durante la compilacion.'
  }
  $apk=(Resolve-Path build/app/outputs/flutter-apk/app-release.apk).Path
  $report=& (Join-Path $PSScriptRoot 'verify_phone_apk.ps1') -Apk $apk
  Utf8File (Join-Path $output 'verificacion.txt') ($report -join "`n")
  $dest=Join-Path $output "ruta-rd-v$name-android-universal.apk"
  Copy-Item -LiteralPath $apk -Destination $dest
  $sensitive=& git ls-files | Where-Object {$_ -match '(?i)(^|/)(key\.properties|local\.properties|\.env)$|\.(jks|keystore)$'}
  if($sensitive){throw 'Configuracion privada registrada en Git; no se archivan fuentes.'}
  $sourceName="fuentes-v$name.zip"
  & git -C (Split-Path $project -Parent) archive --format=zip "--output=$(Join-Path $output $sourceName)" $commit
  if($LASTEXITCODE -ne 0){throw 'No se pudo crear el ZIP de fuentes.'}
  $record=[ordered]@{version=$version;codeCommit=$commit;file=[IO.Path]::GetFileName($dest);
    sourceArchive=$sourceName;sourceArchiveSha256=(Get-FileHash -LiteralPath (Join-Path $output $sourceName) -Algorithm SHA256).Hash.ToLowerInvariant();
    bytes=(Get-Item -LiteralPath $dest).Length;sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant();
    architectures=@('armeabi-v7a','arm64-v8a','x86_64');signing='Android Debug; demonstration';
    validation='Static APK checks passed; runtime devices, modes and GPS scope recorded separately in delivery evidence';utc=[DateTime]::UtcNow.ToString('o')}
  Utf8File (Join-Path $output 'manifest.json') ($record | ConvertTo-Json -Depth 5)
  Copy-Item docs/delivery/TELEFONOS.md (Join-Path $output 'INSTALAR.md')
  Copy-Item CONTINUAR.md (Join-Path $output 'CONTINUAR.md')
  Copy-Item docs/delivery/NAVEGACION.md (Join-Path $output 'NAVEGACION.md')
  Copy-Item assets/search/manifest.json (Join-Path $output 'datos-busqueda.json')
  foreach($mode in @('bicycle','motorcar','motorcycle')) {
    Copy-Item "assets/routing/manifest-$mode.json" (Join-Path $output "datos-rutas-$mode.json")
  }
  Copy-Item docs/delivery/DATOS-Y-LICENCIAS.md (Join-Path $output 'DATOS-Y-LICENCIAS.md')
  $checks=Get-ChildItem -LiteralPath $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
  }
  Utf8File (Join-Path $output 'SHA256SUMS.txt') (($checks -join "`n")+"`n")
  Write-Output "APK universal preparado: $dest"
  # Run the SAME APK through the standard deployment path, without rebuilding.
  & (Join-Path $PSScriptRoot 'run_android.ps1') -SkipBuild
} finally {Pop-Location}
