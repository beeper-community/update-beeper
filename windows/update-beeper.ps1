<#
.SYNOPSIS
    Check Beeper Desktop versions on Windows, or launch a verified installer.
.EXAMPLE
    .\update-beeper.ps1
.EXAMPLE
    .\update-beeper.ps1 -Channel nightly -Install
#>
[CmdletBinding()]
param(
    [ValidateSet('stable', 'nightly')]
    [string]$Channel = 'stable',
    [ValidateSet('auto', 'x64', 'arm64')]
    [string]$Architecture = 'auto',
    [switch]$Install,
    [switch]$DownloadOnly,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BeeperArchitecture {
    if ($Architecture -ne 'auto') { return $Architecture }
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    switch ([int]$processor.Architecture) {
        9 { return 'x64' }
        12 { return 'arm64' }
        default { throw "Unsupported Windows processor architecture: $($processor.Architecture)" }
    }
}

function Get-InstalledBeeper {
    $locations = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\BeeperTexts\Beeper.exe'),
        (Join-Path $env:ProgramFiles 'BeeperTexts\Beeper.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $locations += Join-Path ${env:ProgramFiles(x86)} 'BeeperTexts\Beeper.exe'
    }
    foreach ($location in $locations) {
        if (Test-Path -LiteralPath $location -PathType Leaf) {
            $file = Get-Item -LiteralPath $location
            return [pscustomobject]@{ Path = $location; Version = $file.VersionInfo.FileVersion }
        }
    }
    return $null
}

function Get-BeeperRelease([string]$Branch, [string]$Cpu) {
    $uri = "https://api.beeper.com/desktop/update-feed.json?bundleID=com.automattic.beeper.desktop&version=0.0.0&platform=windows&arch=$Cpu&channel=$Branch"
    $release = Invoke-RestMethod -Uri $uri -TimeoutSec 30
    if (-not $release.version -or -not $release.url -or -not $release.sha512 -or -not $release.download_size) {
        throw "Beeper's $Branch feed is missing required installer metadata."
    }
    if ([string]$release.version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Beeper's $Branch feed returned an unexpected version."
    }
    $downloadUri = [uri]$release.url
    if ($downloadUri.Scheme -ne 'https' -or
        $downloadUri.Host -ne 'beeper-desktop.download.beeper.com' -or
        -not $downloadUri.AbsolutePath.StartsWith('/builds/') -or
        -not $downloadUri.AbsolutePath.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Beeper's $Branch feed returned an unexpected download URL."
    }
    if ([long]$release.download_size -lt 100000000) {
        throw "Beeper's $Branch feed returned an unexpectedly small installer."
    }
    try {
        if ([Convert]::FromBase64String([string]$release.sha512).Length -ne 64) {
            throw 'Wrong SHA-512 length.'
        }
    } catch {
        throw "Beeper's $Branch feed returned an invalid SHA-512 value."
    }
    return $release
}

function Test-BeeperInstaller([string]$Path, $Release) {
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -ne [long]$Release.download_size) {
        throw "Installer size mismatch: got $($file.Length), expected $($Release.download_size)."
    }
    $expected = [BitConverter]::ToString([Convert]::FromBase64String([string]$Release.sha512)).Replace('-', '')
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA512).Hash
    if ($actual -ne $expected) { throw "Installer SHA-512 does not match Beeper's update feed." }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or
        -not $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch '(^|, )O=Automattic Inc\.(,|$)') {
        throw "Installer Authenticode signature is not valid for Automattic Inc. ($($signature.Status))."
    }
}

if ($Force -and -not $Install) { throw '-Force requires -Install.' }
if ($Install -and $DownloadOnly) { throw 'Choose either -Install or -DownloadOnly.' }

$cpu = Get-BeeperArchitecture
$installed = Get-InstalledBeeper
$stable = Get-BeeperRelease 'stable' $cpu
$nightly = Get-BeeperRelease 'nightly' $cpu
$target = if ($Channel -eq 'nightly') { $nightly } else { $stable }

Write-Host "Beeper Desktop for Windows ($cpu)"
Write-Host "Installed: $(if ($installed) { $installed.Version } else { 'not found' })"
Write-Host "Stable:    $($stable.version)"
Write-Host "Nightly:   $($nightly.version)"
Write-Host "Selected:  $Channel $($target.version)"
if ($installed) { Write-Host "Location:  $($installed.Path)" }

if (-not $Install -and -not $DownloadOnly) { return }
if ($Install -and $installed -and $installed.Version -eq [string]$target.version -and -not $Force) {
    Write-Host "Version $($target.version) is already installed. Use -Force to reinstall or switch channels at the same version."
    return
}
if ($Install -and (Get-Process -Name Beeper -ErrorAction SilentlyContinue)) {
    throw 'Close Beeper before installing an update, then run this command again.'
}

$downloadDir = Join-Path $env:TEMP 'update-beeper'
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
$fileName = "Beeper-$Channel-$cpu-$($target.version).exe"
$installer = Join-Path $downloadDir $fileName
$partial = "$installer.partial.exe"
try {
    if (Test-Path -LiteralPath $installer -PathType Leaf) {
        try { Test-BeeperInstaller $installer $target }
        catch { Remove-Item -LiteralPath $installer -Force }
    }
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        Write-Host "Downloading $Channel installer..."
        & curl.exe --fail --location --retry 2 --connect-timeout 15 --max-time 900 --output $partial $target.url
        if ($LASTEXITCODE -ne 0) { throw "Installer download failed (curl exit $LASTEXITCODE)." }
        Test-BeeperInstaller $partial $target
        Move-Item -LiteralPath $partial -Destination $installer -Force
    }
    Write-Host "Verified Beeper $($target.version) (SHA-512 and Automattic signature)."
    if ($DownloadOnly) {
        Write-Host "Installer: $installer"
        return
    }
    Write-Host 'Opening the official installer. Complete its prompts to finish the update.'
    $process = Start-Process -FilePath $installer -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer exited with code $($process.ExitCode)." }
    $deadline = (Get-Date).AddMinutes(2)
    do {
        $after = Get-InstalledBeeper
        if ($after -and $after.Version -eq [string]$target.version) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $after -or $after.Version -ne [string]$target.version) {
        throw "Installer finished, but Beeper $($target.version) was not detected. Check the installer result."
    }
    Write-Host "Beeper $($after.Version) is installed."
} finally {
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
}
