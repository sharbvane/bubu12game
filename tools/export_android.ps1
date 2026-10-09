param(
    [string]$Godot = $env:GODOT_BIN,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AndroidSdk = $env:ANDROID_HOME
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent

if(-not $Godot) {
    $command=Get-Command godot -ErrorAction SilentlyContinue
    if($command) { $Godot=$command.Source }
}
if(-not $AndroidSdk) { $AndroidSdk=$env:ANDROID_SDK_ROOT }
if(-not $AndroidSdk) { $AndroidSdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if(-not $JavaHome) {
    $java=Get-Command java -ErrorAction SilentlyContinue
    if($java) { $JavaHome=Split-Path (Split-Path $java.Source -Parent) -Parent }
}
if(-not $Godot -or -not (Test-Path -LiteralPath $Godot)) { throw 'Set GODOT_BIN or pass -Godot to the Godot 4 console executable.' }
if(-not $JavaHome -or -not (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) { throw 'Set JAVA_HOME or pass -JavaHome to JDK 17.' }
if(-not (Test-Path (Join-Path $AndroidSdk 'platform-tools\adb.exe'))) { throw 'Set ANDROID_HOME or pass -AndroidSdk to the Android SDK.' }

$settingsPath=Join-Path $env:APPDATA 'Godot\editor_settings-4.7.tres'
if(-not (Test-Path -LiteralPath $settingsPath)) { throw 'Open Godot 4.7 once so its Android export settings file exists.' }
$settings=Get-Content -LiteralPath $settingsPath -Raw
foreach($entry in @{'export/android/java_sdk_path'=$JavaHome; 'export/android/android_sdk_path'=$AndroidSdk}.GetEnumerator()) {
    $line=$entry.Key+' = "'+$entry.Value.Replace('\','/')+'"'
    $pattern='(?m)^'+[regex]::Escape($entry.Key)+' = .*'
    if([regex]::IsMatch($settings,$pattern)) { $settings=[regex]::Replace($settings,$pattern,$line) }
    else { $settings=$settings.TrimEnd()+[Environment]::NewLine+$line+[Environment]::NewLine }
}
Set-Content -LiteralPath $settingsPath -Value $settings -Encoding utf8

$preset=Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw
$version=[regex]::Match($preset,'(?m)^version/name="([0-9]+\.[0-9]+\.[0-9]+)"').Groups[1].Value
if(-not $version) { throw 'Could not read Android version/name from export_presets.cfg.' }
$apk=Join-Path $projectRoot "release\YierBubu-Garden-v$version.apk"
New-Item -ItemType Directory -Force -Path (Split-Path $apk -Parent) | Out-Null

$signingRoot=Join-Path $env:LOCALAPPDATA 'BubuGarden\signing'
$secretFile=Join-Path $signingRoot 'password.dpapi'
$keyFile=Join-Path $signingRoot 'garden-release.keystore'
if(-not (Test-Path -LiteralPath $secretFile) -or -not (Test-Path -LiteralPath $keyFile)) {
    throw 'The original release keystore is missing. Restore that exact key or build through the configured GitHub Actions Secrets; do not generate a replacement key.'
}
$secure=(Get-Content -LiteralPath $secretFile -Raw).Trim() | ConvertTo-SecureString
$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $env:BUBU_KEY_PASSWORD=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
try {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$keyFile
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER='bubugarden'
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$env:BUBU_KEY_PASSWORD
    $env:JAVA_HOME=$JavaHome
    $env:ANDROID_HOME=$AndroidSdk
    $env:ANDROID_SDK_ROOT=$AndroidSdk
    & $Godot --headless --path $projectRoot --export-release Android $apk
    if($LASTEXITCODE -ne 0) { throw 'Godot Android export failed' }
    $buildTools=Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'apksigner.bat') } |
        Sort-Object Name -Descending | Select-Object -First 1
    if(-not $buildTools) { throw 'Android Build Tools with apksigner were not found.' }
    & (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose $apk
    if($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
} finally {
    Remove-Item Env:BUBU_KEY_PASSWORD,Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
