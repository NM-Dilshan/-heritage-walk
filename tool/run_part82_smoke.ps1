# Run inside firebase emulators:exec --project demo-heritagewalk --only auth,firestore.
$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adbPath -s emulator-5554 logcat -c
flutter run -d emulator-5554 --no-resident --target tool/part82_emulator_smoke.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
for ($attempt = 0; $attempt -lt 45; $attempt++) {
    $appLogs = & $adbPath -s emulator-5554 logcat -d -s flutter:I
    if ($appLogs -match 'PART82_SDK_SMOKE_FAIL') { $appLogs | Select-Object -Last 30; exit 1 }
    if ($appLogs -match 'PART82_SDK_SMOKE_PASS') { $appLogs | Select-String 'PART82_SDK_SMOKE_PASS'; exit 0 }
    Start-Sleep -Seconds 2
}
Write-Error 'Timed out waiting for Part 8.2 local SDK verification.'
exit 1
