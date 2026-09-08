<#
.SYNOPSIS
    Pre-push gate: scans tracked files for organization markers.

.DESCRIPTION
    Implements the pre-publish scan described in docs/anonymization-plan.md.
    This repo is public, so nothing here may carry a real tenant host, owner
    email, Entra client-id, internal SQL hostname, or business data. Run this
    before every push; a non-zero exit means do not push.

    The scan has two halves:

    1. Structural detectors (always run, defined in this file). They flag the
       *shape* of a leaked identifier rather than any literal value, so this
       script itself stays publishable: tenant hosts outside the placeholder
       set, emails outside the placeholder domains, GUIDs (Entra client-id
       shape), connection-string hosts that are not placeholders, and files
       that should never be tracked.

    2. A literal marker list (-MarkerFile, default .private/org-markers.txt).
       Per the plan, the exact upstream tokens live only in the maintainer's
       private runbook, never in this public file. .private/ is gitignored.
       One pattern per line, regex, case-insensitive; # starts a comment.

    Without the marker list only half the gate has run, so the script exits 2
    unless you pass -NoMarkerFile to acknowledge a structural-only scan.

.PARAMETER Root
    Repo root to scan. Defaults to the parent of this script's folder.

.PARAMETER MarkerFile
    Literal marker list, relative to Root (or absolute).

.PARAMETER NoMarkerFile
    Acknowledge running the structural detectors only, with no marker list.

.OUTPUTS
    Exit 0 = clean. 1 = findings, do not push. 2 = gate incomplete.

.EXAMPLE
    pwsh -NoProfile -File deploy/Test-Anonymization.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = "$PSScriptRoot\..",
    [string]$MarkerFile = '.private/org-markers.txt',
    [switch]$NoMarkerFile
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

# Placeholder vocabulary defined by docs/anonymization-plan.md. Anything that
# looks like an identifier but is NOT one of these is a finding.
$AllowedTenantHosts   = @('contoso', 'contoso-admin', 'tenant', 'yourtenant', 'your-tenant')
$AllowedEmailDomains  = @('contoso.com', 'company.com', 'example.com', 'example.org')
$AllowedDbHostPattern = '(?i)^(?:[{<%$]|\(local\)$|localhost$|\.[\\/]|[a-z0-9.-]*\.contoso\.com$)'
$NeverTrackPattern    = '(?i)(^|/)(\.DS_Store|Thumbs\.db)$|^\.private/|^\.claude/settings\.local\.json$'

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding($Check, $File, $Line, $Text) {
    $findings.Add([pscustomobject]@{
        Check = $Check
        File  = $File
        Line  = $Line
        Text  = $Text.Trim()
    })
}

Push-Location $Root
try {
    $tracked = @(git ls-files)
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed - is $Root a git repo?" }
    Write-Host "Scanning $($tracked.Count) tracked files in $Root" -ForegroundColor Cyan

    # --- Check: files that must never be tracked -------------------------
    foreach ($path in $tracked) {
        if ($path -match $NeverTrackPattern) {
            Add-Finding 'Never-track file' $path 0 $path
        }
    }

    # --- Load the private marker list ------------------------------------
    $markers = @()
    $markerPath = if ([System.IO.Path]::IsPathRooted($MarkerFile)) { $MarkerFile }
                  else { Join-Path $Root $MarkerFile }
    $haveMarkers = Test-Path $markerPath -PathType Leaf
    if ($haveMarkers) {
        $markers = @(Get-Content $markerPath |
            ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
            Where-Object { $_ })
        Write-Host "Marker list: $MarkerFile ($($markers.Count) patterns)" -ForegroundColor Cyan
    }

    # --- Content scan, one pass per file ---------------------------------
    foreach ($path in $tracked) {
        if (-not (Test-Path $path -PathType Leaf)) { continue }
        $lines = Get-Content -LiteralPath $path -ErrorAction SilentlyContinue
        if ($null -eq $lines) { continue }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $n = $i + 1

            foreach ($m in [regex]::Matches($line, '(?i)\b([a-z0-9-]+)\.sharepoint\.com\b')) {
                if ($AllowedTenantHosts -notcontains $m.Groups[1].Value.ToLower()) {
                    Add-Finding 'Tenant host' $path $n $m.Value
                }
            }

            foreach ($m in [regex]::Matches($line, '(?i)\b[a-z0-9._%+-]+@([a-z0-9.-]+\.[a-z]{2,})\b')) {
                if ($AllowedEmailDomains -notcontains $m.Groups[1].Value.ToLower()) {
                    Add-Finding 'Email address' $path $n $m.Value
                }
            }

            foreach ($m in [regex]::Matches($line, '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b')) {
                if ($m.Value -notmatch '^0{8}-0{4}-0{4}-0{4}-0{12}$') {
                    Add-Finding 'GUID (client-id shape)' $path $n $m.Value
                }
            }

            foreach ($m in [regex]::Matches($line, '(?i)\b(?:server|data source)=([^;,"''\s>)]{1,80})')) {
                if ($m.Groups[1].Value -notmatch $AllowedDbHostPattern) {
                    Add-Finding 'DB host' $path $n $m.Value
                }
            }

            foreach ($marker in $markers) {
                if ($line -match $marker) {
                    Add-Finding 'Org marker' $path $n $line
                }
            }
        }
    }
}
finally {
    Pop-Location
}

# --- Report --------------------------------------------------------------
if ($findings.Count -gt 0) {
    Write-Host ''
    Write-Host "ANONYMIZATION SCAN FAILED - $($findings.Count) finding(s). Do not push." -ForegroundColor Red
    foreach ($group in $findings | Group-Object Check | Sort-Object Name) {
        Write-Host ''
        Write-Host "  $($group.Name) ($($group.Count))" -ForegroundColor Yellow
        foreach ($f in $group.Group) {
            $text = if ($f.Text.Length -gt 110) { $f.Text.Substring(0, 110) + '...' } else { $f.Text }
            $loc = if ($f.Line -gt 0) { "$($f.File):$($f.Line)" } else { $f.File }
            Write-Host "    $loc  $text"
        }
    }
    Write-Host ''
    Write-Host "Replace with the Contoso placeholders in docs/anonymization-plan.md, then re-run." -ForegroundColor Red
    exit 1
}

if (-not $haveMarkers -and -not $NoMarkerFile) {
    Write-Host ''
    Write-Host "GATE INCOMPLETE - structural detectors passed, but the literal marker list" -ForegroundColor Yellow
    Write-Host "was not found at $MarkerFile, so the org-token half of the scan did not run." -ForegroundColor Yellow
    Write-Host "Restore it from the maintainer's private runbook, or pass -NoMarkerFile to" -ForegroundColor Yellow
    Write-Host "accept a structural-only scan." -ForegroundColor Yellow
    exit 2
}

Write-Host ''
if ($haveMarkers) {
    Write-Host "ANONYMIZATION SCAN CLEAN - structural detectors and marker list both passed." -ForegroundColor Green
} else {
    Write-Host "ANONYMIZATION SCAN CLEAN - structural detectors only (no marker list)." -ForegroundColor Green
}
exit 0
