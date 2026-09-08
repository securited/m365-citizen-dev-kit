<#
.SYNOPSIS
    A complete, minimal deploy script for one SharePoint App Pattern app —
    self-service enablement included. Copy it into your app's repo and rename.

.DESCRIPTION
    This is the smallest script that deploys an app correctly. It exists because
    the two things people get wrong are both invisible until later:

    1. The .aspx shell must upload while the custom-script window is open, or it
       downloads instead of running. This script opens the window itself, as
       you, with no help desk ticket and no tenant admin — see
       Enable-CustomScriptWindow.ps1 next to this file.
    2. Upload order matters: _data/ files first (deepest first), the shell last.
       The shell fetches its assets on first load, so it should never be the
       thing that is there first.

    It also refuses to open a window it does not need. A _data/-only change —
    which, with runtime module loading, is nearly every deploy — needs Contribute
    and nothing else, so the enablement step is skipped when no shell changed.

    What this example deliberately leaves out, because it is one app's script and
    not the platform's: stale-file cleanup, seed-only file handling, manifest
    pre-flight, and deployment status recording. If you want those, start from
    ../Deploy-SampleLibrary.ps1 instead of this file.

.PARAMETER SiteUrl
    Your app's own site. One site per app — the enablement window, the ACLs, and
    the capacity ceilings are all per site.

.PARAMETER LibraryName
    A dedicated document library named for the app. NOT Site Pages: its
    publishing pipeline conflicts with this pattern and the app fails to load
    its assets. Using the site's default "Documents" library is not recommended
    either -- it is where people drop unrelated files, which puts them in reach
    of a cleanup sweep and widens the Design/Full Control grant the deployer
    needs. Create a library named for the app instead -- once, before the first
    deploy: New-PnPList -Title 'myapp' -Template DocumentLibrary

.PARAMETER SourcePath
    Local folder holding <app>.aspx and <app>_data/.

.PARAMETER SelfServiceEnablement
    Open the window through the EUDA self-service service (needs a grant, no
    admin rights). Without it, you must already hold an open window — or open one
    another way.

.EXAMPLE
    ./Deploy-MyApp.Example.ps1 -WhatIf

.EXAMPLE
    ./Deploy-MyApp.Example.ps1 -SelfServiceEnablement
#>

#Requires -Modules PnP.PowerShell

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SiteUrl     = 'https://contoso.sharepoint.com/sites/euda-myapp',
    [string]$LibraryName = 'myapp',
    [string]$SourcePath  = (Join-Path $PSScriptRoot 'myapp'),
    [string]$PnPClientId = $(if ($env:PNP_CLIENT_ID) { $env:PNP_CLIENT_ID } else { '<your-pnp-client-id>' }),
    [switch]$SelfServiceEnablement
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Enable-CustomScriptWindow.ps1"

$SourcePath = (Resolve-Path $SourcePath).Path

# --- Local inventory ---------------------------------------------------------
# Deepest first so a folder's contents land before anything references them,
# and .aspx last so the shell never arrives before the assets it fetches.
$localFiles = Get-ChildItem -Path $SourcePath -Recurse -File |
    Where-Object { $_.Name -notin @('.DS_Store', 'Thumbs.db', 'README.md') } |
    Sort-Object { $_.Extension -eq '.aspx' }, { -($_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count) }

if (-not $localFiles) { throw "Nothing to deploy: $SourcePath is empty." }

Write-Host ">> Connecting to $SiteUrl" -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $PnPClientId

# --- Enablement: only when a shell actually changes --------------------------
# Read the remote inventory FIRST, so the decision comes from evidence rather
# than from a switch someone remembered to pass.
$web            = Get-PnPWeb
$libraryRootUrl = "$($web.ServerRelativeUrl.TrimEnd('/'))/$LibraryName"
$remoteIndex    = @{}
Get-PnPFolderItem -FolderSiteRelativeUrl $LibraryName -ItemType File -Recursive |
    Where-Object { $_.ServerRelativeUrl -notlike "$libraryRootUrl/Forms/*" } |
    ForEach-Object { $remoteIndex[$_.ServerRelativeUrl.Substring($libraryRootUrl.Length + 1)] = $_ }

function Test-NeedsUpload {
    param([IO.FileInfo]$Local, [string]$Relative)

    if (-not $remoteIndex.ContainsKey($Relative)) { return $true }
    $remote = $remoteIndex[$Relative]
    if ($Local.Length -ne $remote.Length) { return $true }

    $remoteUtc = [datetime]$remote.TimeLastModified
    if ($remoteUtc.Kind -ne [System.DateTimeKind]::Utc) { $remoteUtc = $remoteUtc.ToUniversalTime() }
    return $Local.LastWriteTimeUtc -gt $remoteUtc.AddSeconds(1)
}

function Get-RelativePath {
    param([IO.FileInfo]$File)

    return $File.FullName.Substring($SourcePath.Length + 1).Replace('\', '/')
}

$shellsToUpload = @($localFiles | Where-Object {
    $_.Extension -eq '.aspx' -and (Test-NeedsUpload -Local $_ -Relative (Get-RelativePath -File $_))
})

if ($shellsToUpload.Count -eq 0) {
    Write-Host "  No shell changed — _data/-only deploy, no window needed." -ForegroundColor DarkGray
}
elseif ($SelfServiceEnablement) {
    Write-Host ">> Opening the custom-script window ($($shellsToUpload.Count) shell(s) to upload)" -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess($SiteUrl, 'Request a custom-script window')) {
        Enable-CustomScriptWindow -SiteUrl $SiteUrl
    }
}
else {
    Write-Warning "$($shellsToUpload.Count) shell(s) need uploading, but -SelfServiceEnablement was not passed."
    Write-Warning 'If the window is not already open, they will download instead of running.'
}

# --- Upload ------------------------------------------------------------------
foreach ($file in $localFiles) {
    $relative     = Get-RelativePath -File $file
    $parent       = Split-Path $relative -Parent
    $remoteFolder = if ($parent) { "$LibraryName/$($parent.Replace('\', '/'))" } else { $LibraryName }

    if (-not (Test-NeedsUpload -Local $file -Relative $relative)) {
        Write-Host "  Skipped (unchanged): $relative" -ForegroundColor DarkGray
        continue
    }

    if ($PSCmdlet.ShouldProcess($relative, "Upload to $remoteFolder")) {
        Resolve-PnPFolder -SiteRelativePath $remoteFolder | Out-Null
        Add-PnPFile -Path $file.FullName -Folder $remoteFolder | Out-Null
        Write-Host "  Uploaded: $relative" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host "Done. Open the app and test now, while the window is still open." -ForegroundColor Cyan
