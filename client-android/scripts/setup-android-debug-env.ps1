param(
    [switch] $InstallAndroidStudio,
    [switch] $InstallProjectToolchain,
    [switch] $InstallEmulator,
    [switch] $LaunchAndroidStudio,
    [switch] $RecreateAvd,
    [string] $AvdName = "OpenComputerV0"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

$repoRoot = Get-RepoRoot

if ($InstallAndroidStudio) {
    & (Join-Path $repoRoot "client-android\scripts\install-android-studio.ps1") -LaunchAfterInstall:$LaunchAndroidStudio
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($InstallProjectToolchain) {
    & (Join-Path $repoRoot "client-android\scripts\install-toolchain.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($InstallEmulator) {
    $args = @("-AvdName", $AvdName)
    if ($RecreateAvd) {
        $args += "-Recreate"
    }
    & (Join-Path $repoRoot "client-android\scripts\install-emulator.ps1") @args
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host ""
Write-Host "Android debug environment step finished."
Write-Host ""
Write-Host "Common next commands:"
Write-Host "  powershell -ExecutionPolicy Bypass -File client-android\scripts\install-debug-apk.ps1 -Launch -Logcat"
Write-Host "  powershell -ExecutionPolicy Bypass -File client-android\scripts\debug-emulator.ps1 -Logcat"
