param(
    [string] $AvdName = "OpenComputerV0",
    [string] $Sample = "captures\opencomputer-host-v0.mp4",
    [int] $SampleSeconds = 5,
    [switch] $InstallEmulator,
    [switch] $NoWindow,
    [switch] $SkipBuild,
    [switch] $Logcat
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Wait-ForBoot {
    param(
        [string] $Adb,
        [int] $TimeoutSeconds = 180
    )

    & $Adb wait-for-device
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $boot = (& $Adb shell getprop sys.boot_completed 2>$null | Select-Object -First 1).Trim()
        if ($boot -eq "1") {
            return
        }
        Start-Sleep -Seconds 2
    }
    throw "Timed out waiting for emulator boot."
}

function Ensure-Sample {
    param(
        [string] $RepoRoot,
        [string] $SamplePath,
        [int] $DurationSeconds
    )

    if (Test-Path -LiteralPath $SamplePath) {
        return
    }

    Write-Host "Sample not found. Creating Host V0 sample:"
    Write-Host "  $SamplePath"
    & (Join-Path $RepoRoot "host-windows\scripts\capture-v0.ps1") `
        -Encoder auto `
        -DurationSeconds $DurationSeconds `
        -Output $SamplePath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$repoRoot = Get-RepoRoot
$jdkRoot = Join-Path $repoRoot "tools\jdk"
$sdkRoot = Join-Path $repoRoot "tools\android-sdk"
$adb = Join-Path $sdkRoot "platform-tools\adb.exe"
$emulator = Join-Path $sdkRoot "emulator\emulator.exe"
$apk = Join-Path $repoRoot "client-android\app\build\outputs\apk\debug\app-debug.apk"
$samplePath = if ([System.IO.Path]::IsPathRooted($Sample)) { $Sample } else { Join-Path $repoRoot $Sample }

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:PATH = "$jdkRoot\bin;$sdkRoot\emulator;$sdkRoot\platform-tools;$env:PATH"

if ($InstallEmulator) {
    & (Join-Path $repoRoot "client-android\scripts\install-emulator.ps1") -AvdName $AvdName
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path -LiteralPath $emulator)) {
    throw "Android emulator not found. Run with -InstallEmulator first."
}

if (-not $SkipBuild) {
    & (Join-Path $repoRoot "client-android\scripts\build-debug.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Ensure-Sample -RepoRoot $repoRoot -SamplePath $samplePath -DurationSeconds $SampleSeconds

$devices = & $adb devices
$hasDevice = (($devices -join "`n") -match "\bdevice\b")
if (-not $hasDevice) {
    & (Join-Path $repoRoot "client-android\scripts\start-emulator.ps1") -AvdName $AvdName -NoWindow:$NoWindow
}

Wait-ForBoot -Adb $adb

Write-Host "Installing APK..."
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Pushing sample..."
& $adb push $samplePath "/sdcard/Download/opencomputer-host-v0.mp4"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Launching app..."
& $adb shell am start -n "com.opencomputer.client/.MainActivity"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Android emulator debug session is ready."
Write-Host "  APK: $apk"
Write-Host "  Sample on device: /sdcard/Download/opencomputer-host-v0.mp4"
Write-Host "  In app: click Play path"

if ($Logcat) {
    Write-Host ""
    Write-Host "Starting logcat for OpenComputer. Press Ctrl+C to stop."
    & $adb logcat -v time "OpenComputer*:D" "AndroidRuntime:E" "*:S"
}
