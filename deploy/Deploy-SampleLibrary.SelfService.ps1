<#
.SYNOPSIS
    Deploys the kit's published content to a SharePoint document library, opening
    the custom-script window through the self-service enablement Function App.

.DESCRIPTION
    This is the self-service variant of Deploy-SampleLibrary.ps1, for
    organizations that run the PowerShell Function App described in
    docs/script-enablement-self-service.md. Use the plain Deploy-SampleLibrary.ps1
    instead if you do not run that service - it does the same deploy but flips
    the setting directly, which requires SharePoint tenant-admin rights.

    THE DIFFERENCE IS ONE STEP. Uploading an .aspx shell requires the target
    site's custom-script window to be open (DenyAddAndCustomizePages = $false, a
    ~24-hour window that auto-resets). Outside the window the file uploads but
    loses its executable flag, so it downloads instead of running.

      Deploy-SampleLibrary.ps1             you sign in to the admin center and
                                           flip the setting yourself. Needs
                                           SharePoint tenant-admin rights.

      Deploy-SampleLibrary.SelfService.ps1 you queue a request; the service
      (this file)                          flips it for you. Needs NO admin
                                           rights - only a grant for the site.

    HOW THE SELF-SERVICE PATH WORKS. This script writes a 'Queued' item to the
    enablement Requests list, signed in as yourself, then pings the function to
    wake it and polls the item until it reports Done, Denied or Error.

      1. Add-PnPListItem writes the request. SharePoint stamps Author on the
         item; nothing in this script can set or spoof it.
      2. The function reads the item under its own managed identity, re-checks
         (Author, SiteUrl) against the admin-curated Grants list, and only then
         flips the setting. No grant for that exact site => Denied.
      3. It stamps Done and ExpiresUtc, and this script reports the expiry.

    So no tenant-admin rights are used anywhere in this path, and no token of
    yours reaches the function. The wake ping is an optimization, not a
    requirement: if it fails, a safety-net timer sweeps the queue every ~10
    minutes and the request is collected then.

    The function key read from the service config is anti-DoS only. It confers
    no authority - a leaked key buys a no-op queue scan - so it is configuration
    rather than a secret, and this script reads it from the same config file the
    enablement page uses so there is one source of truth.

    PREREQUISITE: an admin has granted you the target site. Register the site on
    the enablement page; an admin approves with one click. Uploading also needs
    Design or Full Control on the target library - the window and the upload
    permission are separate requirements, and an open window does not
    compensate for a missing one.

    THE REQUEST IS ONLY MADE WHEN IT IS NEEDED. An .aspx shell is designed never
    to change (feature modules load from manifest.json instead), so most deploys
    touch only _data/ files - which need Contribute and no window at all. This
    script decides from the remote inventory: if no shell needs uploading it
    queues nothing and waits for nothing. Override with -ForceEnablement.

    Everything after enablement - pre-flight, cleanup, upload, status - is
    identical to Deploy-SampleLibrary.ps1: it syncs the repo's published folders
    (patterns/ and samples/) into a SharePoint document library, preserving
    folder structure, uploading data files deepest-first and .aspx shells last.
    Supports -WhatIf for a dry run. On a real run, records the outcome, UTC
    timestamp, current git commit, and file counts to deploy/last-deployment.json.

.PARAMETER SiteUrl
    Target SharePoint site. Defaults to a Contoso sample site - change it to
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

.PARAMETER EnablementSiteUrl
    Site hosting the enablement service's queue lists and its config.json.
    Defaults to the deploy site, which is the common case when one site hosts
    both. When it differs, this script signs in there separately - still as
    yourself, still with no admin rights.

.PARAMETER EnablementTimeoutSeconds
    How long to wait for the window before giving up. On a timeout the request
    stays queued and the safety-net timer collects it within about 10 minutes,
    so re-running the deploy shortly usually succeeds. Defaults to 300.

.PARAMETER PnPClientId
    Entra app registration client id for PnP.PowerShell interactive sign-in.
    There is no built-in default - supply your own tenant's app registration
    via -PnPClientId or the PNP_CLIENT_ID environment variable. See
    https://pnp.github.io/powershell/articles/registerapplication.html

.PARAMETER SkipEnablement
    Skip the enablement request entirely, even when a shell changed (e.g. when
    you know the window is already open).

.PARAMETER ForceEnablement
    Queue a request even though no .aspx changed. Only needed when the shells
    have to be re-registered - the deploy skips the request on its own for a
    _data/-only change.

.PARAMETER SkipCleanup
    Upload without removing remote files that are absent locally.

.EXAMPLE
    .\Deploy-SampleLibrary.SelfService.ps1 -WhatIf

.EXAMPLE
    .\Deploy-SampleLibrary.SelfService.ps1 -EnablementSiteUrl https://contoso.sharepoint.com/sites/euda-sample

.EXAMPLE
    .\Deploy-SampleLibrary.SelfService.ps1 -SkipEnablement -SkipCleanup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SiteUrl        = 'https://contoso.sharepoint.com/sites/euda-sample',
    [string]$LibraryName    = 'Sample Sites',
    [string]$SourcePath     = (Split-Path $PSScriptRoot -Parent),
    [string[]]$ContentDirs  = @('patterns', 'samples'),
    [string[]]$SeedOnlyFiles = @('samples/euda-worker_data/latest.json'),
    [string]$EnablementSiteUrl = '',
    [int]$EnablementTimeoutSeconds = 300,
    [string]$PnPClientId    = $env:PNP_CLIENT_ID,
    [switch]$SkipEnablement,
    [switch]$ForceEnablement,
    [switch]$SkipCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PnPModuleName    = 'PnP.PowerShell'
$RequestsListName = 'EUDA Script Enablement Requests'
$ExcludeNames     = @('.DS_Store', 'Thumbs.db')

# Path of the service's config file, relative to the enablement site. The
# enablement page reads the same file, so the endpoint has one source of truth.
$EnablementConfigPath = '/script-enablement/script-enablement_data/config.json'

# Directories that are local tooling artifacts, never content. Any file or
# folder under one of these is excluded from deployment - and because excluded
# paths are absent from the local manifest, the cleanup pass removes them from
# the library if an earlier deploy uploaded them.
$ExcludeDirs     = @('__pycache__', '.venv', '.streamlit', 'node_modules')

# -SeedOnlyFiles (parameter above) lists the files apps overwrite at runtime
# (relative paths, forward slashes). The local copy is only a first-run seed:
# uploaded when missing remotely, never overwritten by a deploy - otherwise
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

function Get-ValueOrDefault {
    <#
        Property access under Set-StrictMode -Version Latest THROWS when the
        property or key is absent, so every "if it is configured" test below has
        to ask first. Handles both a JSON-parsed object and a list item's
        FieldValues dictionary.
    #>
    param(
        $Source,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Source) { return $Default }

    if ($Source -is [System.Collections.IDictionary]) {
        # Test through Keys rather than Contains(): a list item's FieldValues is
        # a Dictionary[string,object], whose generic Contains() takes a
        # key-value pair rather than a key and does not bind to a bare name.
        if ($Source.Keys -notcontains $Name) { return $Default }
        $value = $Source[$Name]
    }
    else {
        $property = $Source.PSObject.Properties[$Name]
        if (-not $property) { return $Default }
        $value = $property.Value
    }

    if ($null -eq $value) { return $Default }
    if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Request-SelfServiceEnablement {
    <#
        Opens the custom-script window WITHOUT tenant-admin rights, by queuing a
        request to the self-service enablement service.

        The trust model matters here: SharePoint stamps Author on the request
        item, and nothing in this script can set it. The service re-checks
        (Author, SiteUrl) against an admin-curated Grants list before it acts, so
        a request for a site you hold no grant for comes back Denied. The
        function key read from config below is anti-DoS only and confers no
        authority - it is configuration, not a secret.
    #>
    param(
        [string]$TargetSiteUrl,
        [string]$QueueSiteUrl,
        [int]$TimeoutSeconds
    )

    $configUrl     = ([uri]$QueueSiteUrl).AbsolutePath.TrimEnd('/') + $EnablementConfigPath
    $TargetSiteUrl = $TargetSiteUrl.TrimEnd('/')

    # The queue often IS the site being deployed to, so reuse the connection
    # already in hand rather than prompting to sign in twice. Otherwise take a
    # separate one, which keeps queuing a request from disturbing the deploy
    # connection.
    if ($QueueSiteUrl.TrimEnd('/') -eq $SiteUrl.TrimEnd('/')) {
        Write-Skip "Reusing the deploy connection for the enablement queue at $QueueSiteUrl."
        $queue = Get-PnPConnection
    }
    else {
        Write-Notice "Signing in to the enablement queue at $QueueSiteUrl (as yourself, no admin rights)."
        $queue = Connect-PnPOnline -Url $QueueSiteUrl -Interactive -ClientId $PnPClientId -ReturnConnection -ErrorAction Stop
    }

    # Read the endpoint from the same config file the enablement page uses, so
    # there is one source of truth and nothing to update here when it moves.
    $config = $null
    try {
        $config = Get-PnPFile -Url $configUrl -AsString -Connection $queue | ConvertFrom-Json
    }
    catch {
        Write-Notice "Could not read the service config ($configUrl): $($_.Exception.Message)"
    }

    $item = Add-PnPListItem -List $RequestsListName -Connection $queue -Values @{
        Title     = $TargetSiteUrl
        SiteUrl   = $TargetSiteUrl
        SiteTitle = $TargetSiteUrl
        Status    = 'Queued'
    }
    Write-Success "Queued enablement request $($item.Id) for $TargetSiteUrl."

    # Waking the service is an optimisation, not a requirement: a failed ping
    # only means the safety-net timer collects the request within ~10 minutes.
    $wakeUrl = Get-ValueOrDefault -Source $config -Name 'wakeUrl'
    if ($wakeUrl) {
        $functionKey = Get-ValueOrDefault -Source $config -Name 'functionKey' -Default ''
        $wakeUri = $wakeUrl + '?code=' + [uri]::EscapeDataString([string]$functionKey)
        try {
            Invoke-WebRequest -Uri $wakeUri -Method Post -TimeoutSec 30 -SkipHttpErrorCheck | Out-Null
        }
        catch {
            Write-Notice "Wake ping failed; the request stays queued. $($_.Exception.Message)"
        }
    }
    else {
        Write-Notice 'No wake URL configured - the safety-net timer will pick the request up (~10 min).'
    }

    $pollSeconds = [int](Get-ValueOrDefault -Source $config -Name 'pollSeconds' -Default 5)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $pollSeconds
        $current = Get-PnPListItem -List $RequestsListName -Id $item.Id -Connection $queue
        $fields  = $current.FieldValues
        $status  = [string](Get-ValueOrDefault -Source $fields -Name 'Status' -Default 'Queued')

        switch ($status) {
            'Done' {
                Write-Success "Custom-script window is OPEN for $TargetSiteUrl."
                Write-Host ''
                Write-Host '  Window closes:' -ForegroundColor Cyan
                Write-Host "    $(Get-ValueOrDefault -Source $fields -Name 'ExpiresUtc' -Default 'unknown') UTC"
                return
            }
            'Denied' {
                throw ("Enablement denied: you hold no grant for $TargetSiteUrl. " +
                       'Register the site on the self-service enablement page and ask an admin to approve it.')
            }
            'Error' {
                throw ("Enablement failed: " +
                       (Get-ValueOrDefault -Source $fields -Name 'ErrorText' -Default 'no detail recorded'))
            }
        }
        Write-Skip "  request $($item.Id): $status ..."
    }

    throw ("Timed out after $TimeoutSeconds seconds. Request $($item.Id) is still queued - " +
           'the safety-net timer runs every 10 minutes, so re-run the deploy shortly.')
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
# The queue defaults to the deploy site, the common case when one site hosts both.
$enablementSite = if ([string]::IsNullOrWhiteSpace($EnablementSiteUrl)) { $SiteUrl } else { $EnablementSiteUrl }

#region --- Open the custom-script window (self-service enablement service) -----
# Uploading an .aspx outside the custom-script window leaves it without its
# executable flag, so it downloads instead of running. But re-uploading an
# UNCHANGED shell is pure risk with no benefit - and the shell is designed never
# to change (feature modules load from manifest.json instead). So decide from the
# inventory: if no .aspx needs uploading, this is a _data/-only deploy, which
# needs Contribute and nothing more - skip the window entirely.

$aspxNeedingUpload = @()
foreach ($relative in ($localFiles | Where-Object { $_ -like '*.aspx' })) {
    $remoteFile = $null
    if ($remoteFileIndex.ContainsKey($relative)) { $remoteFile = $remoteFileIndex[$relative] }
    if (Test-LocalFileNeedsUpload -LocalFull (Join-Path $SourcePath ($relative.Replace('/', '\'))) -RemoteFile $remoteFile) {
        $aspxNeedingUpload += $relative
    }
}

if ($SkipEnablement) {
    Write-Step 'Skipping custom-script enablement (-SkipEnablement)'
    if ($aspxNeedingUpload.Count -gt 0) {
        Write-Notice ("{0} shell(s) need uploading but the enablement check was skipped." -f $aspxNeedingUpload.Count)
        Write-Notice 'If the window is not already open they will download instead of running.'
    }
}
elseif ($aspxNeedingUpload.Count -eq 0 -and -not $ForceEnablement) {
    Write-Step 'Custom-script enablement not required'
    Write-Success 'No .aspx shell changed - this is a _data/-only deploy (Contribute is enough).'
    Write-Skip    'Override with -ForceEnablement if the shells need re-registering.'
}
else {
    if ($aspxNeedingUpload.Count -gt 0) {
        Write-Notice ("{0} shell(s) changed and must upload inside the window:" -f $aspxNeedingUpload.Count)
        $aspxNeedingUpload | ForEach-Object { Write-Notice "  - $_" }
        Write-Notice 'You also need Design or Full Control on the library, or the file will not execute.'
    }

    # The privileged flip happens server-side, under the enablement service's own
    # managed identity, and only after it re-checks that the request's Author
    # holds a grant for this exact site. No admin rights are used here.
    if ($PSCmdlet.ShouldProcess($SiteUrl, 'Request a custom-script window (self-service enablement service)')) {
        Write-Step 'Requesting a custom-script window'
        Request-SelfServiceEnablement -TargetSiteUrl $SiteUrl `
                                      -QueueSiteUrl $enablementSite `
                                      -TimeoutSeconds $EnablementTimeoutSeconds
        Write-Notice 'Upload all .aspx files within this window. Files keep their executable status after it closes.'
    }
    else {
        Write-Skip 'WhatIf: would queue a self-service enablement request and wait for the window.'
    }
}

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
