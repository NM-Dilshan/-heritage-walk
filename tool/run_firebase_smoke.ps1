# Invoke inside: firebase emulators:exec --project demo-heritagewalk --only auth,firestore "powershell -NoProfile -File tool/run_firebase_smoke.ps1"
# Uses the Android emulator, not any physical device or production Firebase data.
$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adbPath -s emulator-5554 logcat -c
flutter run -d emulator-5554 --no-resident --target tool/firebase_emulator_smoke.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
for ($attempt = 0; $attempt -lt 45; $attempt++) {
    $appLogs = & $adbPath -s emulator-5554 logcat -d -s flutter:I
    if ($appLogs -match 'PART7_SDK_SMOKE_FAIL') { $appLogs | Select-Object -Last 25; exit 1 }
    if ($appLogs -match 'PART7_SDK_SMOKE_PASS') { $appLogs | Select-String 'PART7_SDK_SMOKE_PASS'; exit 0 }
    Start-Sleep -Seconds 2
}
Write-Error 'Timed out waiting for local SDK persistence smoke results.'
exit 1
