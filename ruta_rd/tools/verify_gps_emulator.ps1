param([string]$DeviceId='emulator-5554')
$ErrorActionPreference='Stop'
if ($DeviceId -notmatch '^emulator-\d+$') { throw 'Esta prueba inyecta coordenadas y solo admite el emulador.' }
$adb=Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$package='com.example.ruta_rd'
$permissions=@('android.permission.ACCESS_COARSE_LOCATION','android.permission.ACCESS_FINE_LOCATION')
$previousLocation=((& $adb -s $DeviceId shell cmd location is-location-enabled) -join '').Trim()
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el emulador.' }
$fixJob=$null
Push-Location $project
try {
  # flutter test uninstalls test apps by default. Bootstrap a package before
  # setting Android permissions, and preserve it between the native cases.
  $installed=(& $adb -s $DeviceId shell pm path $package) -join ''
  if($installed -notmatch 'base.apk') {
    $bootstrap='build/app/outputs/flutter-apk/app-debug.apk'
    if(-not(Test-Path -LiteralPath $bootstrap)){throw 'Ejecuta primero las pruebas de integracion para generar el APK debug.'}
    $installResult=(& $adb -s $DeviceId install -t -r $bootstrap) -join "`n"
    if($LASTEXITCODE -ne 0 -or $installResult -notmatch 'Success'){throw "No se pudo preparar el APK: $installResult"}
  }
  foreach($scenario in @('denied','disabled','success')) {
    & $adb -s $DeviceId shell am force-stop $package
    & $adb -s $DeviceId shell cmd location set-location-enabled true
    if($scenario -eq 'denied') {
      foreach($permission in $permissions) {
        & $adb -s $DeviceId shell pm revoke $package $permission
        & $adb -s $DeviceId shell pm set-permission-flags $package $permission user-set user-fixed
        if($LASTEXITCODE -ne 0){throw 'No se pudo configurar el permiso nativo.'}
      }
    } elseif($scenario -eq 'disabled') {
      & $adb -s $DeviceId shell cmd location set-location-enabled false
    } else {
      foreach($permission in $permissions) {
        & $adb -s $DeviceId shell pm clear-permission-flags $package $permission user-set user-fixed
        & $adb -s $DeviceId shell pm grant $package $permission
        if($LASTEXITCODE -ne 0){throw 'No se pudo conceder el permiso nativo.'}
      }
      $fixJob=Start-Job -ArgumentList $adb,$DeviceId -ScriptBlock {
        param($adbPath,$target)
        for($i=0;$i -lt 90;$i++) {
          & $adbPath -s $target emu geo fix -69.8844 18.4737 | Out-Null
          Start-Sleep -Seconds 2
        }
      }
    }
    $log="build/fase6-gps-$scenario.log"
    & flutter test integration_test/gps_native_test.dart -d $DeviceId "--dart-define=GPS_EXPECTATION=$scenario" --no-uninstall --reporter expanded *> $log
    $testExit=$LASTEXITCODE
    Get-Content -LiteralPath $log -Tail 8
    if($testExit -ne 0){throw "Fallo GPS $scenario. Consultar $log"}
  }
} finally {
  if($fixJob){Stop-Job -Job $fixJob; Remove-Job -Job $fixJob}
  $installed=(& $adb -s $DeviceId shell pm path $package) -join ''
  if($installed -match 'base.apk') {
    foreach($permission in $permissions) {
      & $adb -s $DeviceId shell pm clear-permission-flags $package $permission user-set user-fixed
      & $adb -s $DeviceId shell pm grant $package $permission
    }
  }
  if($previousLocation -in @('true','false')) {
    & $adb -s $DeviceId shell cmd location set-location-enabled $previousLocation
  }
  Pop-Location
}
