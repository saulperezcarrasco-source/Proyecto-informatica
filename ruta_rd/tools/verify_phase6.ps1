param(
  [string]$DeviceId = 'emulator-5554',
  [string]$TargetPlatform = '',
  [ValidateSet('debug','profile','release')][string]$BuildMode = 'debug'
)
# QA only: installs a test APK and clears ONLY Ruta RD Offline's app data.
# Run after tests, with the intended source revision committed.
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$adb = Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$package = 'com.example.ruta_rd'
function Assert-Command([string]$step) {
  if ($LASTEXITCODE -ne 0) { throw "Fallo: $step" }
}
function Read-DeviceValue([string[]]$AdbArguments) {
  $result = & $adb -s $DeviceId @AdbArguments
  Assert-Command "dispositivo $DeviceId ($($AdbArguments -join ' '))"
  $value = ($result -join "`n").Trim()
  if (-not $value) { throw "El dispositivo $DeviceId no devolvio datos. Comprueba la conexion y repite QA." }
  return $value
}
Push-Location $project
try {
  if ((Read-DeviceValue @('get-state')) -ne 'device') {
    throw "El dispositivo $DeviceId no esta disponible o autorizado."
  }
  $dirty = & git status --porcelain
  if ($dirty) { throw 'Guarda los cambios en un commit antes de generar el APK de QA.' }
  $commit = (& git rev-parse HEAD).Trim()
  $safeDevice = $DeviceId -replace '[^a-zA-Z0-9_-]', '_'
  $runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssZ')
  $output = Join-Path $project "build/qa/$($commit.Substring(0,7))/$safeDevice-$BuildMode/$runId"
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  if (-not $TargetPlatform) {
    $abi = Read-DeviceValue @('shell','getprop','ro.product.cpu.abi')
    $TargetPlatform = switch ($abi) {
      'x86_64' { 'android-x64' }
      'arm64-v8a' { 'android-arm64' }
      'armeabi-v7a' { 'android-arm' }
      default { throw "Arquitectura no soportada: $abi" }
    }
  }
  & flutter build apk "--$BuildMode" --target-platform $TargetPlatform
  Assert-Command 'compilacion QA'
  $apk = Join-Path $output "ruta-rd-PRUEBAS-$BuildMode-$($commit.Substring(0,7)).apk"
  Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$BuildMode.apk" -Destination $apk
  $sha = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
  $wifi = Read-DeviceValue @('shell','settings','get','global','wifi_on')
  $data = Read-DeviceValue @('shell','settings','get','global','mobile_data')
  $networkChanged = $false
  try {
    & $adb -s $DeviceId install -r $apk
    Assert-Command 'instalacion QA'
    $installed = (Read-DeviceValue @('shell','pm','path',$package)).Replace('package:','')
    $installedHash = ((& $adb -s $DeviceId shell sha256sum $installed) -split '\s+')[0]
    if ($installedHash -ne $sha) { throw 'El APK instalado no coincide con el archivo QA.' }
    & $adb -s $DeviceId shell pm clear $package
    Assert-Command 'borrar datos de QA'
    & $adb -s $DeviceId shell am force-stop $package
    Assert-Command 'cerrar tarea previa despues de borrar datos'
    $networkChanged = $true
    & $adb -s $DeviceId shell svc wifi disable
    Assert-Command 'desactivar Wi-Fi'
    & $adb -s $DeviceId shell svc data disable
    Assert-Command 'desactivar datos'
    Start-Sleep -Seconds 2
    # Keep only connectivity status and this application's logs on real phones.
    $connectivity = (Read-DeviceValue @('shell','dumpsys','connectivity')) -split "`n" |
      Where-Object { $_ -match '^\s*Active default network:' } |
      ForEach-Object { $_.Trim() }
    $connectivity | Set-Content (Join-Path $output 'connectivity.txt')
    if ($connectivity -ne 'Active default network: none') {
      throw 'Android no confirma ausencia de red predeterminada. No se acepta esta ejecucion como offline.'
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $firstStart = & $adb -s $DeviceId shell am start -S -W -f 0x10008000 -n "$package/.MainActivity"
    Assert-Command 'primera apertura sin red'
    $firstStart | Set-Content (Join-Path $output 'first-start.txt')
    Start-Sleep -Seconds 12
    $firstCaptureMs = $watch.ElapsedMilliseconds
    & $adb -s $DeviceId shell screencap -p /sdcard/fase6-first.png
    & $adb -s $DeviceId pull -q /sdcard/fase6-first.png (Join-Path $output 'first-offline.png')
    Assert-Command 'captura primera apertura'
    $appPid = Read-DeviceValue @('shell','pidof',$package)
    if ($appPid) {
      & $adb -s $DeviceId logcat -d "--pid=$appPid" | Set-Content (Join-Path $output 'first-app-logcat.txt')
    }
    $localFiles = if ($BuildMode -eq 'debug') {
      & $adb -s $DeviceId shell run-as $package ls -l files
    } else { 'Directorio privado no inspeccionado en APK optimizado.' }
    & $adb -s $DeviceId shell am force-stop $package
    $reopen = & $adb -s $DeviceId shell am start -S -W -f 0x10008000 -n "$package/.MainActivity"
    Assert-Command 'reabrir sin red'
    $reopen | Set-Content (Join-Path $output 'reopen-start.txt')
    Start-Sleep -Seconds 8
    & $adb -s $DeviceId shell screencap -p /sdcard/fase6-reopen.png
    & $adb -s $DeviceId pull -q /sdcard/fase6-reopen.png (Join-Path $output 'reopen-offline.png')
    Assert-Command 'captura reapertura'
    $appPid = Read-DeviceValue @('shell','pidof',$package)
    if ($appPid) {
      & $adb -s $DeviceId logcat -d "--pid=$appPid" | Set-Content (Join-Path $output 'logcat.txt')
    }
    $record = [ordered]@{
      commit = $commit; apk = $apk; mode = "$BuildMode; SOLO PRUEBAS"; targetPlatform = $TargetPlatform;
      sha256 = $sha; installedSha256 = $installedHash;
      bytes = (Get-Item -LiteralPath $apk).Length;
      device = $DeviceId; model = Read-DeviceValue @('shell','getprop','ro.product.model');
      android = Read-DeviceValue @('shell','getprop','ro.build.version.release');
      wifiOn = Read-DeviceValue @('shell','settings','get','global','wifi_on');
      mobileData = Read-DeviceValue @('shell','settings','get','global','mobile_data');
      cleanData = $true; firstStart = $firstStart; reopen = $reopen;
      firstScreenshotAfterMs = $firstCaptureMs;
      timingNote = 'am start mide actividad, no mapa listo. La captura requiere revision visual.';
      privateFiles = $localFiles; utc = [DateTime]::UtcNow.ToString('o')
    }
    $record | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $output 'qa-record.json')
    Write-Output "QA guardado en $output. Revisar ambas capturas y connectivity.txt antes de aceptar."
  } finally {
    if ($networkChanged) {
      if ($wifi -eq '1') { & $adb -s $DeviceId shell svc wifi enable }
      if ($data -eq '1') { & $adb -s $DeviceId shell svc data enable }
    }
  }
} finally { Pop-Location }
