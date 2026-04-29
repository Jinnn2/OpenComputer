param(
    [string] $AvdName = "OpenComputerV0",
    [switch] $NoWindow,
    [switch] $ColdBoot
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

$repoRoot = Get-RepoRoot
$jdkRoot = Join-Path $repoRoot "tools\jdk"
$sdkRoot = Join-Path $repoRoot "tools\android-sdk"
$emulator = Join-Path $sdkRoot "emulator\emulator.exe"

if (-not (Test-Path -LiteralPath $emulator)) {
    throw "Android emulator not found. Run client-android\scripts\install-emulator.ps1 first."
}

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:PATH = "$jdkRoot\bin;$sdkRoot\emulator;$sdkRoot\platform-tools;$env:PATH"

$args = @("-avd", $AvdName)
if ($NoWindow) {
    $args += "-no-window"
}
if ($ColdBoot) {
    $args += @("-no-snapshot-load", "-no-snapshot-save")
}

Write-Host "Starting emulator:"
Write-Host "  $emulator $($args -join ' ')"

if ($NoWindow) {
    Start-Process -FilePath $emulator -ArgumentList $args -WindowStyle Hidden
} else {
    Start-Process -FilePath $emulator -ArgumentList $args
}
