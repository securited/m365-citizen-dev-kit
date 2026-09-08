<#
.SYNOPSIS
    Open your own site's custom-script upload window — no tenant-admin rights.

.DESCRIPTION
    Drop this file next to your deploy script and dot-source it, or paste the
    function straight into the script:

        . "$PSScriptRoot/Enable-CustomScriptWindow.ps1"
        Enable-CustomScriptWindow -SiteUrl 'https://contoso.sharepoint.com/sites/euda-myapp'

    What happens, and why it is safe to hand to a site owner:

    * You sign in as YOURSELF. The script holds no admin rights and no secret.
    * It writes a request item to a SharePoint list. SharePoint stamps Author on
      that item — you cannot set it, and neither can this script.
    * The enablement service re-checks (Author, SiteUrl) against an
      admin-curated Grants list before it does anything. No grant for that exact
      site, and the request comes back Denied. Authorization is server-side; the
      client only asks.
    * The privileged flip runs under the service's own identity, never yours.
    * The function key read from config is anti-DoS only. It confers no
      authority, so it is configuration rather than a secret.

    Prerequisite: an EUDA admin has granted you the site. Register it yourself on
    the self-service enablement page and an admin approves with one click.

    NOTE: uploading an .aspx also needs Design or Full Control on the target
    library ("Add and Customize Pages"). The window alone is not enough — the
    service checks this when your registration is approved and warns the admin,
    but a permission change since then can still leave you short.

.PARAMETER SiteUrl
    The site whose window you want to open. Must be a site you hold a grant for.

.PARAMETER QueueSiteUrl
    Site hosting the enablement queue lists and config.

.PARAMETER PnPClientId
    Entra app client id for PnP interactive sign-in (the tenant's
    "PnP PowerShell - EUDA Deploy" app).

.PARAMETER TimeoutSeconds
    How long to wait for the window before giving up. On a timeout the request
    stays queued; a safety-net timer collects it within about 10 minutes.

.EXAMPLE
    Enable-CustomScriptWindow -SiteUrl 'https://contoso.sharepoint.com/sites/euda-myapp'
#>

#Requires -Modules PnP.PowerShell

function Get-ConfigValue {
    <#
        A caller running under Set-StrictMode -Version Latest — the example deploy
        script next to this file does — makes plain property access THROW when the
        key is absent. So ask before reading, for config objects and for a list
        item's FieldValues dictionary alike.
    #>
    param($Source, [string]$Name, $Default = $null)

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


function Enable-CustomScriptWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SiteUrl,
        [string]$SiteTitle,
        [string]$QueueSiteUrl  = 'https://contoso.sharepoint.com/sites/euda-sample',
        [string]$PnPClientId   = $(if ($env:PNP_CLIENT_ID) { $env:PNP_CLIENT_ID } else { '<your-pnp-client-id>' }),
        [int]$TimeoutSeconds   = 300,
        [int]$PollSeconds      = 5
    )

    $ErrorActionPreference = 'Stop'

    $requestsList = 'EUDA Script Enablement Requests'
    $configUrl    = ([uri]$QueueSiteUrl).AbsolutePath.TrimEnd('/') +
                    '/script-enablement/script-enablement_data/config.json'
    $SiteUrl      = $SiteUrl.TrimEnd('/')
    $title        = if ($SiteTitle) { $SiteTitle } else { $SiteUrl }

    # -ReturnConnection keeps this separate from any connection your deploy
    # script already holds, so opening a window never disturbs the rest of it.
    Write-Host "Signing in to the enablement queue at $QueueSiteUrl ..."
    $queue = Connect-PnPOnline -Url $QueueSiteUrl -Interactive -ClientId $PnPClientId -ReturnConnection

    # Read the endpoint from the same config the web page uses: one source of
    # truth, and nothing to change here when the service moves.
    $config = $null
    try   { $config = Get-PnPFile -Url $configUrl -AsString -Connection $queue | ConvertFrom-Json }
    catch { Write-Warning "Could not read the service config: $($_.Exception.Message)" }

    $item = Add-PnPListItem -List $requestsList -Connection $queue -Values @{
        Title     = $title
        SiteUrl   = $SiteUrl
        SiteTitle = $title
        Status    = 'Queued'
    }
    Write-Host "Queued request $($item.Id) for $SiteUrl."

    # Waking the service is an optimisation, not a requirement. A failed ping
    # only costs time: the safety-net timer collects the request either way.
    $wakeUrl = Get-ConfigValue -Source $config -Name 'wakeUrl'
    if ($wakeUrl) {
        $functionKey = Get-ConfigValue -Source $config -Name 'functionKey' -Default ''
        $wakeUri = $wakeUrl + '?code=' + [uri]::EscapeDataString([string]$functionKey)
        try   { Invoke-WebRequest -Uri $wakeUri -Method Post -TimeoutSec 30 -SkipHttpErrorCheck | Out-Null }
        catch { Write-Warning "Wake ping failed; the request stays queued. $($_.Exception.Message)" }
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollSeconds
        $current = Get-PnPListItem -List $requestsList -Id $item.Id -Connection $queue
        $fields  = $current.FieldValues
        $status  = [string](Get-ConfigValue -Source $fields -Name 'Status' -Default 'Queued')

        switch ($status) {
            'Done' {
                $expires = Get-ConfigValue -Source $fields -Name 'ExpiresUtc' -Default 'unknown'
                Write-Host "Window is OPEN for $SiteUrl (closes $expires UTC)." -ForegroundColor Green
                return
            }
            'Denied' {
                throw "Denied: you hold no grant for $SiteUrl. Register the site on the enablement page and ask an EUDA admin to approve it."
            }
            'Error' {
                throw ("Enablement failed: " +
                       (Get-ConfigValue -Source $fields -Name 'ErrorText' -Default 'no detail recorded'))
            }
        }
        Write-Host "  still $status ..."
    }

    throw "Timed out after $TimeoutSeconds seconds. Request $($item.Id) is still queued; the safety-net timer runs every 10 minutes, so try again shortly."
}
