param(
    [string] $Sample = "captures\opencomputer-host-v0.mp4",
    [int] $SampleSeconds = 5,
    [switch] $SkipBuild,
    [switch] $SkipSample,
    [switch] $Launch,
    [switch] $Logcat
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Resolve-Adb {
    param([string] $RepoRoot)

    $projectAdb = Join-Path $RepoRoot "tools\android-sdk\platform-tools\adb.exe"
    if (Test-Path -LiteralPath $projectAdb) {
        return $projectAdb
    }

    if ($env:ANDROID_HOME) {
        $adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $adb) {
            return $adb
        }
    }

    if ($env:ANDROID_SDK_ROOT) {
        $adb = Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $adb) {
            return $adb
        }
    }

    $command = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "adb.exe not found. Install Android Studio / platform-tools or run client-android\scripts\install-toolchain.ps1."
}

function Wait-ForDevice {
    param(
        [string] $Adb,
        [int] $TimeoutSeconds = 120
    )

    Write-Host "Waiting for Android device or emulator..."
    & $Adb wait-for-device

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $devices = & $Adb devices
        $deviceLine = $devices | Where-Object { $_ -match "\bdevice$" } | Select-Object -First 1
        if ($deviceLine) {
            Write-Host "Connected: $deviceLine"
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "No authorized Android device found. Check emulator boot state, USB debugging, and authorization prompt."
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
$adb = Resolve-Adb -RepoRoot $repoRoot
$apk = Join-Path $repoRoot "client-android\app\build\outputs\apk\debug\app-debug.apk"
$samplePath = if ([System.IO.Path]::IsPathRooted($Sample)) { $Sample } else { Join-Path $repoRoot $Sample }

if (-not $SkipBuild) {
    Write-Host "Building Android debug APK..."
    & (Join-Path $repoRoot "client-android\scripts\build-debug.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path -LiteralPath $apk)) {
    throw "APK not found: $apk"
}

if (-not $SkipSample) {
    Ensure-Sample -RepoRoot $repoRoot -SamplePath $samplePath -DurationSeconds $SampleSeconds
}

Wait-ForDevice -Adb $adb

Write-Host "Installing APK..."
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not $SkipSample) {
    Write-Host "Pushing sample..."
    & $adb push $samplePath "/sdcard/Download/opencomputer-host-v0.mp4"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($Launch) {
    Write-Host "Launching OpenComputer..."
    & $adb shell am start -n "com.opencomputer.client/.MainActivity"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host ""
Write-Host "Install complete."
Write-Host "  APK: $apk"
if (-not $SkipSample) {
    Write-Host "  Sample on device: /sdcard/Download/opencomputer-host-v0.mp4"
}
Write-Host "  In app: click Play path"

if ($Logcat) {
    Write-Host ""
    Write-Host "Starting logcat for OpenComputer. Press Ctrl+C to stop."
    & $adb logcat -v time "OpenComputerClient:D" "AndroidRuntime:E" "*:S"
}
