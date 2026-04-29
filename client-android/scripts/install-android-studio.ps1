param(
    [ValidateSet("stable", "beta", "canary")]
    [string] $Channel = "stable",
    [string] $InstallerPath,
    [string] $DownloadUrl,
    [switch] $Silent,
    [switch] $Force,
    [switch] $LaunchAfterInstall
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Find-AndroidStudio {
    $candidates = @(
        "$env:ProgramFiles\Android\Android Studio\bin\studio64.exe",
        "${env:ProgramFiles(x86)}\Android\Android Studio\bin\studio64.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\bin\studio64.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Resolve-WingetId {
    param([string] $RequestedChannel)

    switch ($RequestedChannel) {
        "stable" { return "Google.AndroidStudio" }
        "beta" { return "Google.AndroidStudio.Beta" }
        "canary" { return "Google.AndroidStudio.Canary" }
    }
}

function Find-Winget {
    $command = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $windowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $windowsApps) {
        return (Resolve-Path -LiteralPath $windowsApps).Path
    }

    $desktopAppInstaller = Get-ChildItem -LiteralPath "C:\Program Files\WindowsApps" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($desktopAppInstaller) {
        $winget = Join-Path $desktopAppInstaller.FullName "winget.exe"
        if (Test-Path -LiteralPath $winget) {
            return $winget
        }
    }

    return $null
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

    Invoke-WebRequest -Uri $Url -OutFile $OutFile
}

$existing = Find-AndroidStudio
if ($existing -and -not $Force) {
    Write-Host "Android Studio already installed:"
    Write-Host "  $existing"
    if ($LaunchAfterInstall) {
        Start-Process -FilePath $existing
    }
    exit 0
}

$repoRoot = Get-RepoRoot
$downloadDir = Join-Path $repoRoot "tools\android-studio-downloads"
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

if (-not $InstallerPath -and -not $DownloadUrl) {
    $winget = Find-Winget
    if ($winget) {
        $packageId = Resolve-WingetId -RequestedChannel $Channel
        $wingetArgs = @(
            "install",
            "--exact",
            "--id", $packageId,
            "--source", "winget",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        if ($Silent) {
            $wingetArgs += "--silent"
        }

        Write-Host "Installing Android Studio via winget:"
        Write-Host "  winget $($wingetArgs -join ' ')"
        & $winget @wingetArgs
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    } else {
        throw @"
winget.exe was not found.

This usually means Windows App Installer / winget is not installed, disabled, or not visible in this shell.

Options:
  1. Install/update "App Installer" from Microsoft Store, then reopen PowerShell.
  2. Install Android Studio manually from:
  https://developer.android.com/studio
  3. Download the Android Studio installer manually, then rerun:
     powershell -ExecutionPolicy Bypass -File client-android\scripts\install-android-studio.ps1 -InstallerPath "D:\Downloads\android-studio.exe"
  4. Rerun this script with -DownloadUrl if you have a direct installer URL.
"@
    }
}

if ($DownloadUrl) {
    $InstallerPath = Join-Path $downloadDir "android-studio-installer.exe"
    Write-Host "Downloading Android Studio installer:"
    Write-Host "  $DownloadUrl"
    Save-Url -Url $DownloadUrl -OutFile $InstallerPath
}

if ($InstallerPath) {
    if (-not (Test-Path -LiteralPath $InstallerPath)) {
        throw "InstallerPath does not exist: $InstallerPath"
    }

    $args = @()
    if ($Silent) {
        $args = @("/S")
    }

    Write-Host "Running Android Studio installer:"
    Write-Host "  $InstallerPath $($args -join ' ')"
    $process = Start-Process -FilePath $InstallerPath -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}

$installed = Find-AndroidStudio
if ($installed) {
    Write-Host ""
    Write-Host "Android Studio ready:"
    Write-Host "  $installed"
    if ($LaunchAfterInstall) {
        Start-Process -FilePath $installed
    }
} else {
    Write-Host ""
    Write-Host "Android Studio installer finished, but studio64.exe was not found in standard locations."
    Write-Host "If you used a custom path, launch Android Studio manually once to finish setup."
}
