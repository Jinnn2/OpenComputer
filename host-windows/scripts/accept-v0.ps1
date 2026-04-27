param(
    [string] $FfmpegPath,
    [ValidateSet("auto", "h264_nvenc", "libx264")]
    [string] $Encoder = "auto",
    [int] $CaptureSeconds = 5,
    [switch] $TestCapture
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Invoke-Step {
    param(
        [string] $Name,
        [string[]] $Command
    )

    Write-Host ""
    Write-Host "== $Name =="

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Command[0] $Command[1..($Command.Length - 1)] 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }

    return [pscustomobject]@{
        Name = $Name
        ExitCode = $exitCode
        Output = ($output -join "`n")
    }
}

function Add-ReportSection {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [object] $Step
    )

    $status = if ($Step.ExitCode -eq 0) { "PASS" } else { "FAIL" }
    $Lines.Add("## $($Step.Name)")
    $Lines.Add("")
    $Lines.Add("- Status: $status")
    $Lines.Add("- Exit code: $($Step.ExitCode)")
    $Lines.Add("")
    $Lines.Add('```text')
    if ($Step.Output) {
        $Lines.Add($Step.Output)
    }
    $Lines.Add('```')
    $Lines.Add("")
}

if ($CaptureSeconds -lt 1 -or $CaptureSeconds -gt 60) {
    throw "Invalid CaptureSeconds: $CaptureSeconds. Expected 1..60."
}

$repoRoot = Get-RepoRoot
$scriptDir = Join-Path $repoRoot "host-windows\scripts"
$checkScript = Join-Path $scriptDir "check-v0.ps1"
$captureScript = Join-Path $scriptDir "capture-v0.ps1"
$configPath = Join-Path $repoRoot "host-windows\config\host-v0.example.json"
$localFfprobe = Join-Path $repoRoot "tools\ffmpeg\bin\ffprobe.exe"
$reportDir = Join-Path $repoRoot "artifacts\host-v0"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDir "acceptance-$stamp.md"
$sampleOutput = Join-Path $repoRoot "captures\host-v0-acceptance-$stamp.mp4"

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$ps = "powershell"
$common = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File")
$ffmpegArg = @()
if ($FfmpegPath) {
    $ffmpegArg = @("-FfmpegPath", $FfmpegPath)
}

$steps = New-Object System.Collections.Generic.List[object]

$checkArgs = @($ps) + $common + @($checkScript) + $ffmpegArg
if ($TestCapture) {
    $checkArgs += "-TestCapture"
}
$steps.Add((Invoke-Step -Name "preflight" -Command $checkArgs))

$dryRunConfigArgs = @($ps) + $common + @($captureScript, "-DryRun", "-Config", $configPath) + $ffmpegArg
$steps.Add((Invoke-Step -Name "dry-run config" -Command $dryRunConfigArgs))

$dryRunCpuArgs = @($ps) + $common + @($captureScript, "-DryRun", "-Encoder", "libx264", "-DurationSeconds", "$CaptureSeconds", "-Output", $sampleOutput) + $ffmpegArg
$steps.Add((Invoke-Step -Name "dry-run cpu encoder" -Command $dryRunCpuArgs))

$dryRunUdpArgs = @($ps) + $common + @($captureScript, "-DryRun", "-Mode", "udp", "-Encoder", "libx264", "-DurationSeconds", "$CaptureSeconds", "-UdpUrl", "udp://127.0.0.1:5000?pkt_size=1316") + $ffmpegArg
$steps.Add((Invoke-Step -Name "dry-run udp stream" -Command $dryRunUdpArgs))

$preflightOk = ($steps[0].ExitCode -eq 0)
if ($preflightOk) {
    $captureArgs = @($ps) + $common + @($captureScript, "-Encoder", $Encoder, "-DurationSeconds", "$CaptureSeconds", "-Output", $sampleOutput) + $ffmpegArg
    $captureStep = Invoke-Step -Name "timed sample capture" -Command $captureArgs
    $steps.Add($captureStep)

    if ($captureStep.ExitCode -eq 0) {
        $ffprobe = "ffprobe.exe"
        if (Test-Path -LiteralPath $localFfprobe) {
            $ffprobe = $localFfprobe
        } elseif ($FfmpegPath) {
            $candidateFfprobe = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $FfmpegPath).Path) "ffprobe.exe"
            if (Test-Path -LiteralPath $candidateFfprobe) {
                $ffprobe = $candidateFfprobe
            }
        }

        $ffprobeArgs = @(
            $ffprobe,
            "-hide_banner",
            "-show_entries", "stream=codec_name,width,height,avg_frame_rate:format=duration,size",
            "-of", "default=noprint_wrappers=1",
            $sampleOutput
        )
        $steps.Add((Invoke-Step -Name "sample ffprobe" -Command $ffprobeArgs))
    }
} else {
    Write-Host ""
    Write-Host "Skipping timed sample capture because preflight failed."
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# OpenComputer Host V0 Acceptance")
$lines.Add("")
$lines.Add("- Generated at: $(Get-Date -Format o)")
$lines.Add("- Capture seconds: $CaptureSeconds")
$lines.Add("- Requested encoder: $Encoder")
$lines.Add("- Sample output: $sampleOutput")
$lines.Add("")

foreach ($step in $steps) {
    Add-ReportSection -Lines $lines -Step $step
}

$failedSteps = @($steps | Where-Object { $_.ExitCode -ne 0 })

if (-not $preflightOk) {
    $lines.Add("## Result")
    $lines.Add("")
    $lines.Add("BLOCKED: FFmpeg or required H.264 encoder is not available in this environment.")
    $lines.Add("")
} elseif ($failedSteps.Count -gt 0) {
    $lines.Add("## Result")
    $lines.Add("")
    $lines.Add("FAIL: one or more Host V0 checks failed.")
    $lines.Add("")
} else {
    $lines.Add("## Result")
    $lines.Add("")
    $lines.Add("PASS: Host V0 preflight, dry runs, and timed sample capture completed.")
    $lines.Add("")
}

Set-Content -LiteralPath $reportPath -Value $lines -Encoding UTF8
Write-Host ""
Write-Host "Report: $reportPath"

if (-not $preflightOk) {
    exit 2
}

if ($failedSteps.Count -gt 0) {
    exit 1
}

exit 0
