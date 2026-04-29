param(
    [string] $JdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk",
    [string] $CommandLineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip",
    [string] $CompileSdk = "android-36",
    [string] $BuildTools = "36.0.0"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Assert-ChildPath {
    param(
        [string] $Parent,
        [string] $Child
    )

    $parentPath = [System.IO.Path]::GetFullPath($Parent)
    $childPath = [System.IO.Path]::GetFullPath($Child)
    if (-not $childPath.StartsWith($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved path escapes expected parent. Parent=$parentPath Child=$childPath"
    }
}

function Find-JavaHome {
    param([string] $JdkRoot)

    $java = Get-ChildItem -LiteralPath $JdkRoot -Recurse -Filter "java.exe" |
        Where-Object { $_.FullName -match "\\bin\\java\.exe$" } |
        Select-Object -First 1
    if (-not $java) {
        throw "Could not find java.exe under $JdkRoot"
    }
    return (Split-Path -Parent (Split-Path -Parent $java.FullName))
}

function Save-Url {
    param(
        [string] $Url,
        [string] $OutFile
    )

    if (Test-Path -LiteralPath $OutFile) {
        Remove-Item -LiteralPath $OutFile -Force
    }

    $curl = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -L --retry 5 --retry-delay 3 --fail -o $OutFile $Url
        if ($LASTEXITCODE -eq 0) {
            return
        }
        if (Test-Path -LiteralPath $OutFile) {
            Remove-Item -LiteralPath $OutFile -Force
        }
    }

    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt += 1) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile
            return
        } catch {
            $lastError = $_
            if (Test-Path -LiteralPath $OutFile) {
                Remove-Item -LiteralPath $OutFile -Force
            }
            Start-Sleep -Seconds (3 * $attempt)
        }
    }

    throw $lastError
}

$repoRoot = Get-RepoRoot
$toolsRoot = Join-Path $repoRoot "tools"
$jdkRoot = Join-Path $toolsRoot "jdk"
$sdkRoot = Join-Path $toolsRoot "android-sdk"
$downloads = Join-Path $toolsRoot "android-downloads"
$jdkZip = Join-Path $downloads "jdk17.zip"
$cmdlineZip = Join-Path $downloads "commandlinetools-win-latest.zip"
$cmdlineLatest = Join-Path $sdkRoot "cmdline-tools\latest"

Assert-ChildPath -Parent $repoRoot -Child $toolsRoot
New-Item -ItemType Directory -Path $downloads -Force | Out-Null
New-Item -ItemType Directory -Path $jdkRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $jdkRoot "bin\java.exe"))) {
    if (-not (Test-Path -LiteralPath $jdkZip)) {
        Write-Host "Downloading JDK 17:"
        Write-Host "  $JdkUrl"
        Save-Url -Url $JdkUrl -OutFile $jdkZip
    } else {
        Write-Host "Using downloaded JDK archive: $jdkZip"
    }

    $jdkExtract = Join-Path $jdkRoot "extract"
    if (Test-Path -LiteralPath $jdkExtract) {
        Assert-ChildPath -Parent $jdkRoot -Child $jdkExtract
        Remove-Item -LiteralPath $jdkExtract -Recurse -Force
    }
    Expand-Archive -LiteralPath $jdkZip -DestinationPath $jdkExtract -Force
    $javaHome = Find-JavaHome -JdkRoot $jdkExtract
    Copy-Item -Path (Join-Path $javaHome "*") -Destination $jdkRoot -Recurse -Force
    Remove-Item -LiteralPath $jdkExtract -Recurse -Force
} else {
    Write-Host "JDK already installed: $jdkRoot"
}

if (-not (Test-Path -LiteralPath (Join-Path $cmdlineLatest "bin\sdkmanager.bat"))) {
    if (-not (Test-Path -LiteralPath $cmdlineZip)) {
        Write-Host "Downloading Android command-line tools:"
        Write-Host "  $CommandLineToolsUrl"
        Save-Url -Url $CommandLineToolsUrl -OutFile $cmdlineZip
    } else {
        Write-Host "Using downloaded Android command-line tools archive: $cmdlineZip"
    }

    $cmdlineExtract = Join-Path $sdkRoot "cmdline-tools-extract"
    if (Test-Path -LiteralPath $cmdlineExtract) {
        Assert-ChildPath -Parent $sdkRoot -Child $cmdlineExtract
        Remove-Item -LiteralPath $cmdlineExtract -Recurse -Force
    }
    New-Item -ItemType Directory -Path $cmdlineExtract -Force | Out-Null
    Expand-Archive -LiteralPath $cmdlineZip -DestinationPath $cmdlineExtract -Force
    New-Item -ItemType Directory -Path (Split-Path -Parent $cmdlineLatest) -Force | Out-Null
    if (Test-Path -LiteralPath $cmdlineLatest) {
        Assert-ChildPath -Parent $sdkRoot -Child $cmdlineLatest
        Remove-Item -LiteralPath $cmdlineLatest -Recurse -Force
    }
    Move-Item -LiteralPath (Join-Path $cmdlineExtract "cmdline-tools") -Destination $cmdlineLatest
    Remove-Item -LiteralPath $cmdlineExtract -Recurse -Force
} else {
    Write-Host "Android command-line tools already installed: $cmdlineLatest"
}

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:PATH = "$jdkRoot\bin;$cmdlineLatest\bin;$sdkRoot\platform-tools;$env:PATH"

$sdkmanager = Join-Path $cmdlineLatest "bin\sdkmanager.bat"

Write-Host ""
Write-Host "Accepting Android SDK licenses..."
$yesOutput = "y`n" * 200
$yesOutput | & $sdkmanager --sdk_root=$sdkRoot --licenses | Out-Host

Write-Host ""
Write-Host "Installing Android SDK packages..."
& $sdkmanager --sdk_root=$sdkRoot `
    "platform-tools" `
    "platforms;$CompileSdk" `
    "build-tools;$BuildTools"

Write-Host ""
Write-Host "Toolchain ready"
Write-Host "  JAVA_HOME=$jdkRoot"
Write-Host "  ANDROID_HOME=$sdkRoot"
& (Join-Path $jdkRoot "bin\java.exe") -version
