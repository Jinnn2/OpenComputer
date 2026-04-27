param(
    [string] $FfmpegPath,
    [switch] $TestCapture
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Find-Ffmpeg {
    param([string] $ExplicitPath)

    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    if ($env:FFMPEG_PATH -and (Test-Path -LiteralPath $env:FFMPEG_PATH)) {
        return (Resolve-Path -LiteralPath $env:FFMPEG_PATH).Path
    }

    $repoRoot = Get-RepoRoot
    $localFfmpeg = Join-Path $repoRoot "tools\ffmpeg\bin\ffmpeg.exe"
    if (Test-Path -LiteralPath $localFfmpeg) {
        return (Resolve-Path -LiteralPath $localFfmpeg).Path
    }

    $command = Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $command = Get-Command "ffmpeg" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Test-TextContains {
    param(
        [string[]] $Lines,
        [string] $Pattern
    )

    return (($Lines -join "`n") -match [regex]::Escape($Pattern))
}

function Invoke-NativeCommand {
    param(
        [string] $FilePath,
        [string[]] $Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

Write-Host "OpenComputer Host V0 preflight"
Write-Host ""

$ffmpeg = Find-Ffmpeg -ExplicitPath $FfmpegPath
if (-not $ffmpeg) {
    Write-Host "FFmpeg: missing"
    Write-Host ""
    Write-Host "Install one of these, then reopen PowerShell:"
    Write-Host "  winget install --id Gyan.FFmpeg --source winget"
    Write-Host "  choco install ffmpeg"
    Write-Host ""
    Write-Host "Alternatively put portable FFmpeg at:"
    Write-Host "  tools\ffmpeg\bin\ffmpeg.exe"
    exit 2
}

Write-Host "FFmpeg: $ffmpeg"

$version = & $ffmpeg -hide_banner -version 2>&1
Write-Host ($version | Select-Object -First 1)

$encoders = & $ffmpeg -hide_banner -encoders 2>&1
$hasNvenc = Test-TextContains -Lines $encoders -Pattern "h264_nvenc"
$hasX264 = Test-TextContains -Lines $encoders -Pattern "libx264"

Write-Host ""
Write-Host "H.264 encoders:"
Write-Host "  h264_nvenc: $hasNvenc"
Write-Host "  libx264    : $hasX264"

if (-not $hasNvenc -and -not $hasX264) {
    Write-Host ""
    Write-Host "No supported H.264 encoder found. Use another FFmpeg build."
    exit 3
}

if ($TestCapture) {
    Write-Host ""
    Write-Host "Testing one-frame gdigrab capture..."
    $testExitCode = Invoke-NativeCommand -FilePath $ffmpeg -Arguments @(
        "-hide_banner",
        "-f", "gdigrab",
        "-framerate", "1",
        "-video_size", "640x360",
        "-i", "desktop",
        "-frames:v", "1",
        "-f", "null",
        "-"
    )
    if ($testExitCode -ne 0) {
        exit $testExitCode
    }
}

Write-Host ""
Write-Host "Recommended dry run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -DryRun -Encoder $(if ($hasNvenc) { 'h264_nvenc' } else { 'libx264' })"

exit 0
