param(
    [string] $Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
    [string] $Sha256Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256",
    [switch] $Force
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

function Read-ExpectedSha256 {
    param([string] $Path)

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $match = [regex]::Match($text, "[A-Fa-f0-9]{64}")
    if (-not $match.Success) {
        throw "Could not parse SHA256 from $Path"
    }
    return $match.Value.ToLowerInvariant()
}

$repoRoot = Get-RepoRoot
$toolsRoot = Join-Path $repoRoot "tools\ffmpeg"
$binDir = Join-Path $toolsRoot "bin"
$ffmpegExe = Join-Path $binDir "ffmpeg.exe"
$downloadsDir = Join-Path $toolsRoot "downloads"
$extractDir = Join-Path $toolsRoot "extract"
$zipPath = Join-Path $downloadsDir "ffmpeg-release-essentials.zip"
$shaPath = Join-Path $downloadsDir "ffmpeg-release-essentials.zip.sha256"

Assert-ChildPath -Parent $repoRoot -Child $toolsRoot

if ((Test-Path -LiteralPath $ffmpegExe) -and -not $Force) {
    Write-Host "FFmpeg already installed: $ffmpegExe"
    & $ffmpegExe -hide_banner -version | Select-Object -First 1
    exit 0
}

New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

Write-Host "Downloading FFmpeg:"
Write-Host "  $Url"
Invoke-WebRequest -Uri $Url -OutFile $zipPath

Write-Host "Downloading SHA256:"
Write-Host "  $Sha256Url"
Invoke-WebRequest -Uri $Sha256Url -OutFile $shaPath

$expectedHash = Read-ExpectedSha256 -Path $shaPath
$actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "SHA256 expected: $expectedHash"
Write-Host "SHA256 actual  : $actualHash"

if ($actualHash -ne $expectedHash) {
    throw "FFmpeg archive SHA256 mismatch."
}

if (Test-Path -LiteralPath $extractDir) {
    Assert-ChildPath -Parent $toolsRoot -Child $extractDir
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}

New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

$extractedFfmpeg = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter "ffmpeg.exe" |
    Where-Object { $_.FullName -match "\\bin\\ffmpeg\.exe$" } |
    Select-Object -First 1

if (-not $extractedFfmpeg) {
    throw "Could not find ffmpeg.exe in extracted archive."
}

$sourceBin = Split-Path -Parent $extractedFfmpeg.FullName
Copy-Item -LiteralPath (Join-Path $sourceBin "ffmpeg.exe") -Destination $binDir -Force
Copy-Item -LiteralPath (Join-Path $sourceBin "ffprobe.exe") -Destination $binDir -Force
if (Test-Path -LiteralPath (Join-Path $sourceBin "ffplay.exe")) {
    Copy-Item -LiteralPath (Join-Path $sourceBin "ffplay.exe") -Destination $binDir -Force
}

Write-Host ""
Write-Host "FFmpeg installed:"
Write-Host "  $ffmpegExe"
& $ffmpegExe -hide_banner -version | Select-Object -First 1

exit 0
