param([switch]$SkipBuild, [switch]$Universal)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sdk=Join-Path $env:LOCALAPPDATA 'Android/sdk'
$adb=Join-Path $sdk 'platform-tools/adb.exe'
$emulator=Join-Path $sdk 'emulator/emulator.exe'
$device='emulator-5554'
Push-Location $project
try {
  if(-not $SkipBuild) {
    # Run this AFTER tests: the Flutter tool regenerates native plugin files.
    $targets=if($Universal){'android-arm,android-arm64,android-x64'}else{'android-x64'}
    & flutter build apk --release --target-platform $targets
    if($LASTEXITCODE -ne 0){throw 'No se pudo compilar la aplicación'}
  }
  $apk=Join-Path $project 'build/app/outputs/flutter-apk/app-release.apk'
  if(-not(Test-Path -LiteralPath $apk)){throw 'Falta el APK optimizado. Ejecuta sin -SkipBuild.'}
  $devices=& $adb devices
  if(-not($devices -match '^emulator-5554\s+device')) {
    Start-Process -FilePath $emulator -ArgumentList '-avd','Pixel_10a','-no-snapshot-load' -WindowStyle Hidden
  }
  $ready=$false
  for($i=0;$i -lt 90;$i++) {
    $connections=& $adb devices
    if($connections -match '^emulator-5554\s+device') {
      $boot=& $adb -s $device shell getprop sys.boot_completed
      if($boot -match '^1$'){$ready=$true;break}
    }
    Start-Sleep -Seconds 1
  }
  if(-not $ready){throw 'El emulador no terminó de iniciar'}
  & $adb -s $device install -r $apk
  if($LASTEXITCODE -ne 0){throw 'No se pudo instalar el APK'}
  $package=& $adb -s $device shell pm path com.example.ruta_rd
  if($package -notmatch 'base.apk'){throw 'La instalación no aparece en Android'}
  & $adb -s $device shell am force-stop com.example.ruta_rd
  if($LASTEXITCODE -ne 0){throw 'No se pudo preparar el arranque en frío'}
  # NEW_TASK | CLEAR_TASK avoids stale activities surviving package updates.
  & $adb -s $device shell am start -S -W -f 0x10008000 -n com.example.ruta_rd/.MainActivity
  if($LASTEXITCODE -ne 0){throw 'No se pudo abrir la aplicación'}
  $running=& $adb -s $device shell pidof com.example.ruta_rd
  if(-not $running){throw 'Android no mantuvo el proceso de la aplicacion despues del arranque'}
  Write-Output 'Ruta RD Offline instalada y abierta en Pixel_10a. Revisar el manifiesto de entrega para las arquitecturas incluidas.'
} finally { Pop-Location }
