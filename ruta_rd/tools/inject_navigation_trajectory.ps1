# From ruta_rd, run alongside flutter drive targeting offline_gnss_test.dart.
# Reads GNSS_READY from build/gnss-native.log. Emulator only; never a phone.
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$device='emulator-5554'
if($device -notmatch '^emulator-'){throw 'Solo se inyecta GPS en emulador'}
function Allow-Gps {
  & $adb -s $device shell uiautomator dump /sdcard/gnss-permissions.xml | Out-Null
  [xml]$ui=(& $adb -s $device shell cat /sdcard/gnss-permissions.xml) -join "`n"
  $allow=$ui.SelectSingleNode('//node[@text="While using the app"]')
  if($allow){
    $b=[regex]::Matches($allow.bounds,'\d+') | ForEach-Object {[int]$_.Value}
    & $adb -s $device shell input tap ([int](($b[0]+$b[2])/2)) ([int](($b[1]+$b[3])/2))
  }
}
$timer=[Diagnostics.Stopwatch]::StartNew()
$coordinates=$null
$singleHandled=$false
while($timer.Elapsed.TotalSeconds -lt 300){
  if(Test-Path build/gnss-native.log){
    $log=[string](Get-Content build/gnss-native.log -Raw -Encoding UTF8)
    if(-not $singleHandled -and $log -match 'GNSS_SINGLE_WAIT'){
      Allow-Gps
      & $adb -s $device emu geo fix -69.8844188 18.4737075 0 8 0 | Out-Null
      $singleHandled=$true
    }
    $ready=[regex]::Match($log,'GNSS_READY (\{[^\r\n]+\})')
    if($ready.Success){$coordinates=$ready.Groups[1].Value | ConvertFrom-Json;break}
    if($log -match 'BUILD FAILED|Compilation failed|Error:'){throw 'Fallo la compilacion de la prueba Android'}
  }
  Start-Sleep -Milliseconds 500
}
if(-not $coordinates){throw 'La prueba no inicio el seguimiento GNSS'}
# flutter drive reinstalls the fixture and may reset location permission.
Allow-Gps
# Wait beyond the former 15 second startup gate before supplying the route.
Start-Sleep -Seconds 18
& $adb -s $device shell dumpsys location | Out-File build/gnss-native-providers.txt -Encoding utf8
function Fix([double]$lat,[double]$lon){
  & $adb -s $device emu geo fix ($lon.ToString('R',[Globalization.CultureInfo]::InvariantCulture)) ($lat.ToString('R',[Globalization.CultureInfo]::InvariantCulture)) 0 8 6 | Out-Null
  Start-Sleep -Seconds 1
}
$path=@($coordinates.path)
$samples=[Collections.Generic.List[object]]::new()
$samples.Add($path[0])
for($i=1;$i -lt $path.Count;$i++){
  $a=$path[$i-1];$b=$path[$i]
  $dy=([double]$b.lat-[double]$a.lat)*111320
  $dx=([double]$b.lon-[double]$a.lon)*111320*[Math]::Cos([double]$a.lat*[Math]::PI/180)
  $steps=[Math]::Max(1,[Math]::Ceiling([Math]::Sqrt($dx*$dx+$dy*$dy)/9))
  for($j=1;$j -le $steps;$j++){
    $samples.Add(@{lat=[double]$a.lat+([double]$b.lat-[double]$a.lat)*$j/$steps;lon=[double]$a.lon+([double]$b.lon-[double]$a.lon)*$j/$steps})
  }
}
[IO.File]::WriteAllText((Join-Path (Get-Location) 'build/gnss-trajectory.json'),($samples | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
for($i=0;$i -lt $samples.Count;$i++){
  Fix $samples[$i].lat $samples[$i].lon
  if($i -eq 0 -or $i -eq [int]($samples.Count/2) -or $i -eq $samples.Count-1){
    $stage=if($i -eq 0){'start'}elseif($i -eq $samples.Count-1){'end'}else{'middle'}
    & $adb -s $device shell screencap -p "/sdcard/gnss-native-$stage.png"
    & $adb -s $device pull -q "/sdcard/gnss-native-$stage.png" "build/gnss-native-$stage.png"
    Write-Output "GNSS_INJECT $stage sample=$i"
  }
}
Write-Output "GNSS_INJECT COMPLETE samples=$($samples.Count)"
