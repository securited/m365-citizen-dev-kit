<#
.SYNOPSIS
    Deploys the kit's published content to a SharePoint document library.

.DESCRIPTION
    Reusable deployment script for the M365 Citizen Dev Kit.

    THIS IS THE VARIANT FOR ORGANIZATIONS WITHOUT THE ENABLEMENT SERVICE. It
    opens the target site's custom-script window by signing you in to the
    SharePoint admin center and flipping the setting directly, which requires
    SharePoint tenant-admin rights.

    If your organization runs the self-service enablement Function App (see
    docs/script-enablement-self-service.md), use the sibling script
    Deploy-SampleLibrary.SelfService.ps1 instead. It performs the identical
    deploy, but queues the window request to that service - which flips the
    setting under its own managed identity after re-checking your grant - so it
    needs no admin rights from you at all. Nothing else differs between them.

    It syncs the repo's published folders (patterns/ and samples/) into a
    SharePoint document library, preserving folder structure:

    1. Enables custom script uploads on the target site when needed
       (DenyAddAndCustomizePages = $false via the SPO admin module), reporting
       the 24-hour expiration window.
    2. Connects to the site with PnP.PowerShell.
    3. Cleans up: removes files and folders in the library that are not part
       of the current local source set (stale files from earlier deployments).
    4. Deploys: uploads files that are new or changed (size or last-write time
       differs from the remote copy), preserving folder structure.

    Data files upload deepest-first and .aspx shells upload last, matching the
    SharePoint App pattern's recommended order. Supports -WhatIf for a dry run
    of all destructive and additive steps. On a real (non -WhatIf) run, records
    the outcome, UTC timestamp, current git commit, and file counts to
    deploy/last-deployment.json.

.PARAMETER SiteUrl
    Target SharePoint site. Defaults to a Contoso sample site — change it to
    your tenant's site.

.PARAMETER LibraryName
    Target document library name. Defaults to 'Sample Sites'.

.PARAMETER SourcePath
    Repo root whose content folders are deployed. Defaults to this script's
    parent folder. Only the folders listed in -ContentDirs are deployed.

.PARAMETER ContentDirs
    Top-level folders (relative to SourcePath) whose contents are published.
    Defaults to 'patterns' and 'samples'.

.PARAMETER SeedOnlyFiles
    Files an app overwrites at runtime, as paths relative to the repo root with
    forward slashes. Each is uploaded when missing remotely, never overwritten,
    and never removed as stale - the deployed copy is live data, the local copy
    only a first-run seed.

.PARAMETER AdminCenterUrl
    SharePoint Online admin center URL. Defaults to the Contoso admin center —
    change it to your tenant's admin center.

.PARAMETER PnPClientId
    Entra app registration client id for PnP.PowerShell interactive sign-in.
    There is no built-in default — supply your own tenant's app registration
    via -PnPClientId or the PNP_CLIENT_ID environment variable. See
    https://pnp.github.io/powershell/articles/registerapplication.html

.PARAMETER SkipEnablement
    Skip the custom-script enablement check (e.g. when the window is already
    open, or when only updating _data files, which never require it).

.PARAMETER SkipCleanup
    Upload without removing remote files that are absent locally.

.EXAMPLE
    .\Deploy-SampleLibrary.ps1 -WhatIf

.EXAMPLE
    .\Deploy-SampleLibrary.ps1 -SiteUrl https://contoso.sharepoint.com/sites/euda-sample -PnPClientId <guid>

.EXAMPLE
    .\Deploy-SampleLibrary.ps1 -SkipEnablement -SkipCleanup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SiteUrl        = 'https://contoso.sharepoint.com/sites/euda-sample',
    [string]$LibraryName    = 'Sample Sites',
    [string]$SourcePath     = (Split-Path $PSScriptRoot -Parent),
    [string[]]$ContentDirs  = @('patterns', 'samples'),
    [string[]]$SeedOnlyFiles = @('samples/euda-worker_data/latest.json'),
    [string]$AdminCenterUrl = 'https://contoso-admin.sharepoint.com',
    [string]$PnPClientId    = $env:PNP_CLIENT_ID,
    [switch]$SkipEnablement,
    [switch]$SkipCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SpoModuleName   = 'Microsoft.Online.SharePoint.PowerShell'
$PnPModuleName   = 'PnP.PowerShell'
$EnablementHours = 24
$ExcludeNames    = @('.DS_Store', 'Thumbs.db')

# Directories that are local tooling artifacts, never content. Any file or
# folder under one of these is excluded from deployment — and because excluded
# paths are absent from the local manifest, the cleanup pass removes them from
# the library if an earlier deploy uploaded them.
$ExcludeDirs     = @('__pycache__', '.venv', '.streamlit', 'node_modules')

# -SeedOnlyFiles (parameter above) lists the files apps overwrite at runtime
# (relative paths, forward slashes). The local copy is only a first-run seed:
# uploaded when missing remotely, never overwritten by a deploy — otherwise
# every deploy would revert live data.

#region --- Helpers -------------------------------------------------------------

function Write-Step {
    param([string]$Message)

    Write-Host ''
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)

    Write-Host "  $Message" -ForegroundColor Green
}

function Write-Notice {
    param([string]$Message)

    Write-Host "  $Message" -ForegroundColor Yellow
}

function Install-RequiredModule {
    param([string]$Name)

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Notice "Module '$Name' not found. Installing for the current user (this may take a minute)..."
        Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
}

function Get-LocalExpirationTimestamp {
    param(
        [datetime]$From,
        [int]$Hours
    )

    $expiresAt = $From.AddHours($Hours)
    $timeZone  = [System.TimeZoneInfo]::Local

    return '{0} ({1})' -f $expiresAt.ToString('dddd, MMMM d, yyyy h:mm:ss tt'), $timeZone.DisplayName
}

function Write-Skip {
    param([string]$Message)

    Write-Host "  $Message" -ForegroundColor DarkGray
}

function Test-ExcludedPath {
    param([string]$RelativePath)

    foreach ($dir in $ExcludeDirs) {
        if (($RelativePath -split '/') -contains $dir) {
            return $true
        }
    }
    return $false
}

function Test-LocalFileNeedsUpload {
    param(
        [string]$LocalFull,
        [hashtable]$RemoteFile
    )

    if (-not $RemoteFile) {
        return $true
    }

    $localInfo = Get-Item -LiteralPath $LocalFull
    if ($localInfo.Length -ne $RemoteFile.Length) {
        return $true
    }

    $remoteModifiedUtc = [datetime]$RemoteFile.TimeLastModified
    if ($remoteModifiedUtc.Kind -ne [System.DateTimeKind]::Utc) {
        $remoteModifiedUtc = $remoteModifiedUtc.ToUniversalTime()
    }

    return $localInfo.LastWriteTimeUtc -gt $remoteModifiedUtc.AddSeconds(1)
}

function Write-DeploymentStatus {
    param(
        [Parameter(Mandatory)][string]$Status,
        [int]$Uploaded = 0,
        [int]$Skipped  = 0,
        [int]$Removed  = 0,
        [string]$ErrorMessage = ''
    )

    if ($WhatIfPreference) { return }  # never record a dry run

    $commit = ''
    try { $commit = (& git -C $PSScriptRoot rev-parse HEAD 2>$null) } catch { }

    $record = [ordered]@{
        status       = $Status
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        siteUrl      = $SiteUrl
        libraryName  = $LibraryName
        gitCommit    = $commit
        uploaded     = $Uploaded
        skipped      = $Skipped
        removed      = $Removed
        error        = $ErrorMessage
    }

    $statusPath = Join-Path $PSScriptRoot 'last-deployment.json'
    ($record | ConvertTo-Json) | Set-Content -Path $statusPath -Encoding UTF8
}

#endregion

# Counters referenced by both the deployment-status writer and the failure trap.
$uploadedCount = 0
$skippedCount  = 0
$removedCount  = 0

# On any terminating error, record a 'failed' status before the script exits.
trap {
    Write-DeploymentStatus -Status 'failed' -Uploaded $uploadedCount -Skipped $skippedCount -Removed $removedCount -ErrorMessage $_.Exception.Message
    break
}

#region --- Validate inputs -----------------------------------------------------

Write-Step 'Validating inputs'

if (-not (Test-Path $SourcePath -PathType Container)) {
    throw "Source folder not found: $SourcePath"
}

if (-not $PnPClientId) {
    throw @"
PnP.PowerShell requires an Entra app registration client id for interactive sign-in.
This kit ships no built-in app id — supply your own tenant's app registration.
Pass -PnPClientId <guid> or set the PNP_CLIENT_ID environment variable.
(See https://pnp.github.io/powershell/articles/registerapplication.html)
"@
}

$SourcePath = (Resolve-Path $SourcePath).Path

# Content roots: only the published folders (patterns/, samples/) are deployed.
$contentRoots = foreach ($dir in $ContentDirs) {
    $full = Join-Path $SourcePath $dir
    if (Test-Path $full -PathType Container) { $full }
    else { Write-Notice "Content folder not found, skipping: $dir" }
}

if (-not $contentRoots) {
    throw "None of the content folders ($($ContentDirs -join ', ')) were found under $SourcePath."
}

Write-Success "Source: $SourcePath"
Write-Success "Content: $($ContentDirs -join ', ')"
Write-Success "Target: $SiteUrl / $LibraryName"

# Local manifest: relative file paths (forward slashes, keeping the patterns/
# and samples/ prefixes), data files first, .aspx shells last.
$localFiles = $contentRoots |
    ForEach-Object { Get-ChildItem -Path $_ -Recurse -File } |
    Where-Object { $ExcludeNames -notcontains $_.Name } |
    ForEach-Object { $_.FullName.Substring($SourcePath.Length + 1).Replace('\', '/') } |
    Where-Object { -not (Test-ExcludedPath $_) } |
    Sort-Object @{ Expression = { $_ -like '*.aspx' } }, { $_ }

$localFolders = $contentRoots |
    ForEach-Object { Get-ChildItem -Path $_ -Recurse -Directory } |
    ForEach-Object { $_.FullName.Substring($SourcePath.Length + 1).Replace('\', '/') } |
    Where-Object { -not (Test-ExcludedPath $_) }

# Include the content roots themselves as folders to ensure.
$localFolders = @($ContentDirs) + $localFolders | Select-Object -Unique

Write-Success ("{0} files in {1} folders to deploy." -f $localFiles.Count, $localFolders.Count)

#endregion

#region --- Enable custom script ------------------------------------------------

if ($SkipEnablement) {
    Write-Step 'Skipping custom-script enablement check (-SkipEnablement)'
}
else {
    Write-Step 'Checking custom-script enablement'

    Install-RequiredModule -Name $SpoModuleName

    $importParams = @{}
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $importParams['UseWindowsPowerShell'] = $true
    }
    Import-Module $SpoModuleName @importParams -ErrorAction Stop

    Write-Notice "Connecting to $AdminCenterUrl — sign in when prompted."
    Connect-SPOService -Url $AdminCenterUrl -ErrorAction Stop

    $site = Get-SPOSite -Identity $SiteUrl -ErrorAction Stop

    if (-not $site.DenyAddAndCustomizePages) {
        Write-Success 'Custom script uploads are already enabled on this site.'
    }
    elseif ($PSCmdlet.ShouldProcess($SiteUrl, 'Enable custom script uploads (DenyAddAndCustomizePages = $false)')) {
        Set-SPOSite -Identity $SiteUrl -DenyAddAndCustomizePages $false -ErrorAction Stop
        Write-Success 'Custom script uploads have been enabled.'
        Write-Host ''
        Write-Host '  Expected expiration (24 hours from enablement):' -ForegroundColor Cyan
        Write-Host "    $(Get-LocalExpirationTimestamp -From (Get-Date) -Hours $EnablementHours)"
        Write-Notice 'Upload all .aspx files within this window. Files keep their executable status after it closes.'
    }
}

#endregion

#region --- Connect to the site -------------------------------------------------

Write-Step "Connecting to $SiteUrl (PnP.PowerShell)"

Install-RequiredModule -Name $PnPModuleName
Import-Module $PnPModuleName -ErrorAction Stop

Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $PnPClientId -ErrorAction Stop
Write-Success 'Connected.'

$web            = Get-PnPWeb
$libraryRootUrl = "$($web.ServerRelativeUrl.TrimEnd('/'))/$LibraryName"

Write-Step 'Reading remote file inventory'

$remoteFileIndex = @{}
$remoteInventory = Get-PnPFolderItem -FolderSiteRelativeUrl $LibraryName -ItemType File -Recursive |
    Where-Object { $_.ServerRelativeUrl -notlike "$libraryRootUrl/Forms/*" }

foreach ($file in $remoteInventory) {
    $relative = $file.ServerRelativeUrl.Substring($libraryRootUrl.Length + 1)
    $remoteFileIndex[$relative] = @{
        ServerRelativeUrl = $file.ServerRelativeUrl
        Length            = $file.Length
        TimeLastModified  = $file.TimeLastModified
    }
}

Write-Success ("{0} remote file(s) indexed." -f $remoteFileIndex.Count)

#endregion

#region --- Clean up stale remote files ------------------------------------------

if ($SkipCleanup) {
    Write-Step 'Skipping remote cleanup (-SkipCleanup)'
}
else {
    Write-Step "Cleaning up files not present in the local content set"

    foreach ($relative in @($remoteFileIndex.Keys)) {
        if ($localFiles -notcontains $relative) {
            $file = $remoteFileIndex[$relative]
            if ($PSCmdlet.ShouldProcess($relative, 'Remove stale file')) {
                Remove-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Force
                Write-Notice "Removed: $relative"
                $removedCount++
                $remoteFileIndex.Remove($relative) | Out-Null
            }
        }
    }

    # Stale folders (deepest first so children empty out before parents)
    $remoteFolders = Get-PnPFolderItem -FolderSiteRelativeUrl $LibraryName -ItemType Folder -Recursive |
        Where-Object { $_.Name -ne 'Forms' -and $_.ServerRelativeUrl -notlike "$libraryRootUrl/Forms/*" } |
        Sort-Object { $_.ServerRelativeUrl.Length } -Descending

    foreach ($folder in $remoteFolders) {
        $relative = $folder.ServerRelativeUrl.Substring($libraryRootUrl.Length + 1)

        if ($localFolders -notcontains $relative) {
            if ($PSCmdlet.ShouldProcess($relative, 'Remove stale folder')) {
                Remove-PnPFolder -Name $folder.Name -Folder ($LibraryName + '/' + (Split-Path $relative -Parent).Replace('\', '/')).TrimEnd('/') -Force
                Write-Notice "Removed folder: $relative"
                $removedCount++
            }
        }
    }

    Write-Success "Cleanup complete ($removedCount item(s) removed)."
}

#endregion

#region --- Deploy ----------------------------------------------------------------

Write-Step "Syncing $($localFiles.Count) files to $LibraryName"

foreach ($folder in ($localFolders | Sort-Object { $_.Length })) {
    if ($PSCmdlet.ShouldProcess("$LibraryName/$folder", 'Ensure folder')) {
        Resolve-PnPFolder -SiteRelativePath "$LibraryName/$folder" | Out-Null
    }
}

foreach ($relative in $localFiles) {
    $localFull    = Join-Path $SourcePath ($relative.Replace('/', '\'))
    $remoteFolder = $LibraryName
    $parent       = Split-Path $relative -Parent
    if ($parent) {
        $remoteFolder = "$LibraryName/$($parent.Replace('\', '/'))"
    }

    $remoteFile = $null
    if ($remoteFileIndex.ContainsKey($relative)) {
        $remoteFile = $remoteFileIndex[$relative]
    }

    if ($remoteFile -and $SeedOnlyFiles -contains $relative) {
        Write-Skip "Skipped (seed-only; remote copy is live runtime data): $relative"
        $skippedCount++
        continue
    }

    if (-not (Test-LocalFileNeedsUpload -LocalFull $localFull -RemoteFile $remoteFile)) {
        Write-Skip "Skipped (unchanged): $relative"
        $skippedCount++
        continue
    }

    if ($PSCmdlet.ShouldProcess($relative, "Upload to $remoteFolder")) {
        Add-PnPFile -Path $localFull -Folder $remoteFolder | Out-Null
        Write-Success "Uploaded: $relative"
        $uploadedCount++
    }
}

Write-Step 'Deployment summary'
Write-Success "$uploadedCount file(s) uploaded, $skippedCount unchanged, to $SiteUrl/$LibraryName"
Write-Notice  'Reminder: .aspx files only execute if the uploader has the "Add and'
Write-Notice  'Customize Pages" permission (Design or Full Control) and the custom-script'
Write-Notice  'window was active at upload. Files in _data/ folders have no such requirement.'

Write-DeploymentStatus -Status 'success' -Uploaded $uploadedCount -Skipped $skippedCount -Removed $removedCount
Write-Success "Deployment status recorded in $(Join-Path $PSScriptRoot 'last-deployment.json')"

#endregion
