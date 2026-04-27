param(
    [string] $Config,
    [ValidateSet("file", "udp")]
    [string] $Mode = "file",
    [string] $Output,
    [string] $UdpUrl = "udp://127.0.0.1:5000?pkt_size=1316",
    [int] $Fps = 30,
    [int] $Width = 1920,
    [int] $Height = 1080,
    [int] $OffsetX = 0,
    [int] $OffsetY = 0,
    [int] $VideoBitrateKbps = 12000,
    [int] $DurationSeconds = 0,
    [ValidateSet("auto", "h264_nvenc", "libx264")]
    [string] $Encoder = "auto",
    [string] $FfmpegPath,
    [switch] $NoDrawMouse,
    [switch] $DryRun,
    [switch] $ListEncoders
)

$ErrorActionPreference = "Stop"
$script:InitialBoundParameters = @{} + $PSBoundParameters

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Set-FromConfig {
    param(
        [object] $ConfigObject,
        [string] $PropertyName,
        [string] $VariableName
    )

    if ($null -eq $ConfigObject) {
        return
    }
    if (-not ($ConfigObject.PSObject.Properties.Name -contains $PropertyName)) {
        return
    }
    if ($script:InitialBoundParameters.ContainsKey($VariableName)) {
        return
    }

    Set-Variable -Name $VariableName -Scope 1 -Value $ConfigObject.$PropertyName
}

function Resolve-FfmpegPath {
    param([string] $ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "FFmpeg path does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    if ($env:FFMPEG_PATH) {
        if (-not (Test-Path -LiteralPath $env:FFMPEG_PATH)) {
            throw "FFMPEG_PATH does not exist: $env:FFMPEG_PATH"
        }
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

    if ($DryRun) {
        return "ffmpeg"
    }

    throw @"
FFmpeg was not found.

Install FFmpeg and make it available in one of these ways:
  1. Add ffmpeg.exe to PATH.
  2. Set FFMPEG_PATH to the full ffmpeg.exe path.
  3. Put portable FFmpeg at tools\ffmpeg\bin\ffmpeg.exe.
"@
}

function Test-Encoder {
    param(
        [string] $ResolvedFfmpeg,
        [string] $EncoderName
    )

    if ($DryRun) {
        return $true
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $encoders = & $ResolvedFfmpeg -hide_banner -encoders 2>&1
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return (($encoders -join "`n") -match [regex]::Escape($EncoderName))
}

function Resolve-Encoder {
    param(
        [string] $ResolvedFfmpeg,
        [string] $RequestedEncoder
    )

    if ($RequestedEncoder -ne "auto") {
        if (-not (Test-Encoder -ResolvedFfmpeg $ResolvedFfmpeg -EncoderName $RequestedEncoder)) {
            throw "Requested encoder is not available in this FFmpeg build: $RequestedEncoder"
        }
        return $RequestedEncoder
    }

    if (Test-Encoder -ResolvedFfmpeg $ResolvedFfmpeg -EncoderName "h264_nvenc") {
        return "h264_nvenc"
    }

    if (Test-Encoder -ResolvedFfmpeg $ResolvedFfmpeg -EncoderName "libx264") {
        return "libx264"
    }

    throw "No supported H.264 encoder found. Expected h264_nvenc or libx264."
}

function Assert-CaptureParameters {
    if ($Fps -lt 1 -or $Fps -gt 240) {
        throw "Invalid fps: $Fps. Expected 1..240."
    }
    if ($Width -lt 320 -or $Width -gt 7680) {
        throw "Invalid width: $Width. Expected 320..7680."
    }
    if ($Height -lt 240 -or $Height -gt 4320) {
        throw "Invalid height: $Height. Expected 240..4320."
    }
    if ($VideoBitrateKbps -lt 500 -or $VideoBitrateKbps -gt 200000) {
        throw "Invalid video bitrate: $VideoBitrateKbps. Expected 500..200000 Kbps."
    }
    if ($DurationSeconds -lt 0) {
        throw "Invalid duration: $DurationSeconds. Expected 0 for unlimited or a positive second count."
    }
}

function New-FfmpegArgs {
    param(
        [string] $ResolvedEncoder
    )

    $bitrate = "${VideoBitrateKbps}k"
    $size = "${Width}x${Height}"
    $drawMouse = if ($NoDrawMouse) { "0" } else { "1" }

    $args = @(
        "-hide_banner",
        "-loglevel", "info",
        "-f", "gdigrab",
        "-draw_mouse", $drawMouse,
        "-framerate", "$Fps",
        "-offset_x", "$OffsetX",
        "-offset_y", "$OffsetY",
        "-video_size", $size,
        "-i", "desktop"
    )

    if ($ResolvedEncoder -eq "h264_nvenc") {
        $args += @(
            "-c:v", "h264_nvenc",
            "-preset", "p1",
            "-tune", "ll",
            "-rc", "cbr",
            "-b:v", $bitrate,
            "-maxrate", $bitrate,
            "-bufsize", "$([Math]::Max([int]($VideoBitrateKbps / 2), 1000))k",
            "-g", "$Fps",
            "-bf", "0",
            "-pix_fmt", "yuv420p"
        )
    } else {
        $args += @(
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-b:v", $bitrate,
            "-maxrate", $bitrate,
            "-bufsize", "$([Math]::Max([int]($VideoBitrateKbps / 2), 1000))k",
            "-g", "$Fps",
            "-pix_fmt", "yuv420p"
        )
    }

    if ($DurationSeconds -gt 0) {
        $args += @(
            "-t", "$DurationSeconds"
        )
    }

    if ($Mode -eq "file") {
        $outputDir = Split-Path -Parent $Output
        if ($outputDir -and -not (Test-Path -LiteralPath $outputDir) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }

        $args += @(
            "-movflags", "+faststart",
            "-y",
            $Output
        )
    } else {
        $args += @(
            "-f", "mpegts",
            "-muxdelay", "0",
            "-muxpreload", "0",
            $UdpUrl
        )
    }

    return $args
}

if ($Config) {
    if (-not (Test-Path -LiteralPath $Config)) {
        throw "Config file does not exist: $Config"
    }

    $configObject = Get-Content -Raw -Encoding UTF8 -LiteralPath $Config | ConvertFrom-Json
    Set-FromConfig -ConfigObject $configObject -PropertyName "mode" -VariableName "Mode"
    Set-FromConfig -ConfigObject $configObject -PropertyName "output" -VariableName "Output"
    Set-FromConfig -ConfigObject $configObject -PropertyName "udpUrl" -VariableName "UdpUrl"
    Set-FromConfig -ConfigObject $configObject -PropertyName "fps" -VariableName "Fps"
    Set-FromConfig -ConfigObject $configObject -PropertyName "width" -VariableName "Width"
    Set-FromConfig -ConfigObject $configObject -PropertyName "height" -VariableName "Height"
    Set-FromConfig -ConfigObject $configObject -PropertyName "offsetX" -VariableName "OffsetX"
    Set-FromConfig -ConfigObject $configObject -PropertyName "offsetY" -VariableName "OffsetY"
    Set-FromConfig -ConfigObject $configObject -PropertyName "videoBitrateKbps" -VariableName "VideoBitrateKbps"
    Set-FromConfig -ConfigObject $configObject -PropertyName "durationSeconds" -VariableName "DurationSeconds"
    Set-FromConfig -ConfigObject $configObject -PropertyName "encoder" -VariableName "Encoder"
    if (($configObject.PSObject.Properties.Name -contains "drawMouse") -and -not $script:InitialBoundParameters.ContainsKey("NoDrawMouse")) {
        $NoDrawMouse = -not [bool] $configObject.drawMouse
    }
}

if (@("file", "udp") -notcontains $Mode) {
    throw "Invalid mode: $Mode. Expected file or udp."
}
if (@("auto", "h264_nvenc", "libx264") -notcontains $Encoder) {
    throw "Invalid encoder: $Encoder. Expected auto, h264_nvenc, or libx264."
}
Assert-CaptureParameters

$ffmpeg = Resolve-FfmpegPath -ExplicitPath $FfmpegPath

if ($ListEncoders) {
    & $ffmpeg -hide_banner -encoders
    exit $LASTEXITCODE
}

$resolvedEncoder = Resolve-Encoder -ResolvedFfmpeg $ffmpeg -RequestedEncoder $Encoder

if ($Mode -eq "file" -and -not $Output) {
    $repoRoot = Get-RepoRoot
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Output = Join-Path $repoRoot "captures\host-v0-$stamp.mp4"
}
if ($Mode -eq "file" -and $Output -and -not [System.IO.Path]::IsPathRooted($Output)) {
    $repoRoot = Get-RepoRoot
    $Output = Join-Path $repoRoot $Output
}

$ffmpegArgs = New-FfmpegArgs -ResolvedEncoder $resolvedEncoder

Write-Host "OpenComputer Host V0 capture"
Write-Host "  FFmpeg : $ffmpeg"
Write-Host "  Mode   : $Mode"
Write-Host "  Encoder: $resolvedEncoder"
Write-Host "  Size   : ${Width}x${Height} @ ${Fps}fps"
if ($DurationSeconds -gt 0) {
    Write-Host "  Duration: ${DurationSeconds}s"
} else {
    Write-Host "  Duration: unlimited"
}

if ($Mode -eq "file") {
    Write-Host "  Output : $Output"
} else {
    Write-Host "  UDP    : $UdpUrl"
}

Write-Host ""
Write-Host "Command:"
Write-Host ("  " + $ffmpeg + " " + ($ffmpegArgs -join " "))

if ($DryRun) {
    exit 0
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    & $ffmpeg @ffmpegArgs
    $ffmpegExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

exit $ffmpegExitCode
