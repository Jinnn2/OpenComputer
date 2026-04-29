param(
    [switch] $InstallToolchain
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

$repoRoot = Get-RepoRoot
$jdkRoot = Join-Path $repoRoot "tools\jdk"
$sdkRoot = Join-Path $repoRoot "tools\android-sdk"
$localGradle = Join-Path $repoRoot "tools\gradle\extract\gradle-9.3.1\bin\gradle.bat"

if ($InstallToolchain) {
    & (Join-Path $repoRoot "client-android\scripts\install-toolchain.ps1")
}

if (-not (Test-Path -LiteralPath (Join-Path $jdkRoot "bin\java.exe"))) {
    throw "Project JDK not found. Run client-android\scripts\install-toolchain.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $sdkRoot "platforms\android-36"))) {
    throw "Android SDK android-36 not found. Run client-android\scripts\install-toolchain.ps1 first."
}

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:PATH = "$jdkRoot\bin;$sdkRoot\platform-tools;$env:PATH"

Push-Location $repoRoot
try {
    if (Test-Path -LiteralPath $localGradle) {
        & $localGradle :client-android:app:assembleDebug --no-daemon
    } else {
        & .\gradlew.bat :client-android:app:assembleDebug --no-daemon
    }
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
