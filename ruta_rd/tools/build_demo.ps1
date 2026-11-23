$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $project
try {
  if(& git status --porcelain){throw 'Guarda el codigo en un commit antes de compilar la entrega.'}
  $commit=((& git rev-parse HEAD) -join '').Trim()
  & (Join-Path $PSScriptRoot 'run_android.ps1')
  if($LASTEXITCODE -ne 0){throw 'Fallo la compilacion o instalacion de la demo.'}
  if((((& git rev-parse HEAD) -join '').Trim()) -ne $commit -or (& git status --porcelain)) {
    throw 'El codigo cambio durante la compilacion; la entrega no se certifica.'
  }
  $apk=(Resolve-Path build/app/outputs/flutter-apk/app-release.apk).Path
  $version=([regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*(\S+)')).Groups[1].Value
  $flutterJson=(& flutter --version --machine) -join "`n"
  if($LASTEXITCODE -ne 0){throw 'No se pudo registrar la version de Flutter.'}
  $record=[ordered]@{
    codeCommit=$commit;version=$version;apk=$apk;target='android-x64';mode='release';
    signing='development; demonstration only';bytes=(Get-Item -LiteralPath $apk).Length;
    sha256=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant();
    flutter=($flutterJson | ConvertFrom-Json);utc=[DateTime]::UtcNow.ToString('o')
  }
  [IO.File]::WriteAllText((Join-Path $project 'build/demo-build.json'),($record | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
  Write-Output "APK construido e instalado desde $commit. Procedencia: build/demo-build.json"
} finally {Pop-Location}
