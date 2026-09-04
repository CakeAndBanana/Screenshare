<#
.SYNOPSIS
    Regenerates repo.json (the Dalamud plugin master list) from a freshly packaged plugin manifest.

.DESCRIPTION
    Dalamud's custom-repository format is the plugin's own manifest plus a handful of
    repository-only fields (download links, timestamps, counters). Rather than hand-maintaining a
    second copy of Name/Description/AssemblyVersion/DalamudApiLevel here - which silently drifts the
    moment the plugin changes - this takes the manifest DalamudPackager emitted next to latest.zip
    and layers the repository fields on top.

    Called by the release workflow in the (private) ScreenShare.Plugin repo after it has published
    the release that DownloadUrl points at. Safe to run by hand too.

.PARAMETER ManifestPath
    The packaged ScreenShare.Plugin.json produced by DalamudPackager (NOT the hand-written one in
    the plugin's source root - that one lacks InternalName, AssemblyVersion and DalamudApiLevel).

.PARAMETER DownloadUrl
    Direct download URL of the release asset, e.g.
    https://github.com/CakeAndBanana/Screenshare/releases/download/v0.0.1.0/ScreenShare.Plugin.zip

.PARAMETER Changelog
    Optional release notes shown in the Dalamud plugin installer.
#>
#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $DownloadUrl,
    [string] $RepoJsonPath = (Join-Path $PSScriptRoot '..\..\repo.json'),
    [string] $RepoUrl = 'https://github.com/CakeAndBanana/Screenshare',
    [string] $Changelog = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Packaged manifest not found at '$ManifestPath'."
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

foreach ($required in 'InternalName', 'AssemblyVersion', 'DalamudApiLevel') {
    if (-not $manifest.PSObject.Properties[$required] -or -not "$($manifest.$required)") {
        throw "Manifest '$ManifestPath' has no '$required'. Point -ManifestPath at the packaged manifest next to latest.zip, not the source one."
    }
}

# Preserve the download counter across regenerations - it is the only field in repo.json that
# isn't derived from the build, and Dalamud's installer surfaces it.
$existingDownloads = 0
if (Test-Path -LiteralPath $RepoJsonPath) {
    $existing = Get-Content -LiteralPath $RepoJsonPath -Raw
    if ($existing.Trim()) {
        $prior = @($existing | ConvertFrom-Json) | Where-Object { $_.InternalName -eq $manifest.InternalName }
        if ($prior -and $prior[0].PSObject.Properties['DownloadCount']) {
            $existingDownloads = [int] $prior[0].DownloadCount
        }
    }
}

function Get-ManifestValue {
    param([string] $Name, $Default)
    if ($manifest.PSObject.Properties[$Name]) { return $manifest.$Name }
    return $Default
}

$entry = [ordered] @{
    Author              = Get-ManifestValue 'Author' ''
    Name                = Get-ManifestValue 'Name' $manifest.InternalName
    InternalName        = $manifest.InternalName
    AssemblyVersion     = $manifest.AssemblyVersion
    Description         = Get-ManifestValue 'Description' ''
    Punchline           = Get-ManifestValue 'Punchline' ''
    Changelog           = $Changelog
    ApplicableVersion   = Get-ManifestValue 'ApplicableVersion' 'any'
    DalamudApiLevel     = [int] $manifest.DalamudApiLevel
    Tags                = @(Get-ManifestValue 'Tags' @())
    RepoUrl             = $RepoUrl
    IsHide              = $false
    IsTestingExclusive  = $false
    LastUpdate          = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    DownloadCount       = $existingDownloads
    DownloadLinkInstall = $DownloadUrl
    DownloadLinkUpdate  = $DownloadUrl
    DownloadLinkTesting = $DownloadUrl
    AcceptsFeedback     = [bool] (Get-ManifestValue 'AcceptsFeedback' $true)
    LoadRequiredState   = [int] (Get-ManifestValue 'LoadRequiredState' 0)
    LoadSync            = [bool] (Get-ManifestValue 'LoadSync' $false)
    CanUnloadAsync      = [bool] (Get-ManifestValue 'CanUnloadAsync' $false)
    LoadPriority        = [int] (Get-ManifestValue 'LoadPriority' 0)
}

# Only advertise an icon once one actually exists - Dalamud fetches IconUrl eagerly and logs a
# failure for every plugin in the list when it 404s.
$iconPath = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $RepoJsonPath).Path) 'images/icon.png'
if (Test-Path -LiteralPath $iconPath) {
    $entry.Insert([Array]::IndexOf(@($entry.Keys), 'IsHide'), 'IconUrl', "$RepoUrl/raw/main/images/icon.png")
}

# -AsArray matters: Dalamud expects a JSON array even with a single plugin, and ConvertTo-Json
# would otherwise unwrap a one-element collection into a bare object.
$json = @($entry) | ConvertTo-Json -Depth 10 -AsArray

# Normalise to LF so the CI commit that lands this file produces a readable diff regardless of
# which platform generated it (ConvertTo-Json emits CRLF on Windows).
$json = $json -replace "`r`n", "`n"

Set-Content -LiteralPath $RepoJsonPath -Value $json -Encoding utf8NoBOM -NoNewline
Add-Content -LiteralPath $RepoJsonPath -Value "`n" -Encoding utf8NoBOM -NoNewline

Write-Host "repo.json updated: $($entry.InternalName) $($entry.AssemblyVersion) (API $($entry.DalamudApiLevel)) -> $DownloadUrl"
