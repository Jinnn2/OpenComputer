param(
    [string] $AvdName = "OpenComputerV0",
    [string] $SystemImage = "system-images;android-36;google_apis;x86_64",
    [string] $Device = "pixel_6",
    [switch] $Recreate
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Set-AndroidEnv {
    param([string] $RepoRoot)

    $jdkRoot = Join-Path $RepoRoot "tools\jdk"
    $sdkRoot = Join-Path $RepoRoot "tools\android-sdk"
    $cmdlineTools = Join-Path $sdkRoot "cmdline-tools\latest\bin"

    if (-not (Test-Path -LiteralPath (Join-Path $jdkRoot "bin\java.exe"))) {
        throw "Project JDK not found. Run client-android\scripts\install-toolchain.ps1 first."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cmdlineTools "sdkmanager.bat"))) {
        throw "Android command-line tools not found. Run client-android\scripts\install-toolchain.ps1 first."
    }

    $env:JAVA_HOME = $jdkRoot
    $env:ANDROID_HOME = $sdkRoot
    $env:ANDROID_SDK_ROOT = $sdkRoot
    $env:PATH = "$jdkRoot\bin;$cmdlineTools;$sdkRoot\emulator;$sdkRoot\platform-tools;$env:PATH"

    return [pscustomobject]@{
        JdkRoot = $jdkRoot
        SdkRoot = $sdkRoot
        SdkManager = Join-Path $cmdlineTools "sdkmanager.bat"
        AvdManager = Join-Path $cmdlineTools "avdmanager.bat"
        Emulator = Join-Path $sdkRoot "emulator\emulator.exe"
    }
}

$repoRoot = Get-RepoRoot
$envInfo = Set-AndroidEnv -RepoRoot $repoRoot

Write-Host "Installing emulator packages..."
& $envInfo.SdkManager --sdk_root=$($envInfo.SdkRoot) `
    "emulator" `
    $SystemImage
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$avdList = & $envInfo.AvdManager list avd
$exists = (($avdList -join "`n") -match "Name:\s+$([regex]::Escape($AvdName))\b")

if ($exists -and $Recreate) {
    Write-Host "Deleting existing AVD: $AvdName"
    & $envInfo.AvdManager delete avd -n $AvdName
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $exists = $false
}

if (-not $exists) {
    Write-Host "Creating AVD: $AvdName"
    "no" | & $envInfo.AvdManager create avd `
        -n $AvdName `
        -k $SystemImage `
        -d $Device `
        --force
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} else {
    Write-Host "AVD already exists: $AvdName"
}

Write-Host ""
Write-Host "Emulator ready"
Write-Host "  AVD: $AvdName"
Write-Host "  System image: $SystemImage"
Write-Host "  Emulator: $($envInfo.Emulator)"
