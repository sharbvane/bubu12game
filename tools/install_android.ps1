param(
    [string]$Apk = 'E:\资料\bubu12-tudou\release\YierBubu-Garden-v1.5.0.apk',
    [switch]$Launch
)
$ErrorActionPreference='Stop'
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if([string]::IsNullOrWhiteSpace($adb)) { $adb='C:\Windows\System32\adb.exe' }
& $adb start-server | Out-Null
$rows = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
$ready = @($rows | Where-Object { $_ -match '\bdevice\s*$' })
if($ready.Count -eq 0) {
    Write-Error 'No authorized Android device. Unlock the phone, choose File Transfer, accept USB debugging, then rerun this script.'
    exit 2
}
& $adb install -r $Apk
if($LASTEXITCODE -ne 0) { throw 'APK install failed' }
if($Launch) {
    & $adb shell monkey -p com.bubugarden.survivors 1
    if($LASTEXITCODE -ne 0) { throw 'Launch failed' }
}
Write-Output ('Installed on: ' + (($ready -split '\s+')[0] -join ', '))
