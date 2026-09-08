# deploy/

Deployment tooling for the M365 Citizen Dev Kit.

| Script | Purpose |
|---|---|
| `Deploy-SampleLibrary.ps1` | Deploy **without** the enablement service. Opens the custom-script window by signing in to the SharePoint admin center — needs tenant-admin rights. Run `-WhatIf` first. |
| `Deploy-SampleLibrary.SelfService.ps1` | Deploy **with** the enablement service. Queues the window request to the PowerShell Function App — needs no admin rights, only a grant for the site. Run `-WhatIf` first. |
| `Test-Anonymization.ps1` | Pre-push gate: scans tracked files for organization markers. Must exit 0 before any push. |
| `examples/Enable-CustomScriptWindow.ps1` | The enablement request as a standalone helper — dot-source it or paste the function into your own app's deploy script. |
| `examples/Deploy-MyApp.Example.ps1` | A complete minimal deploy script for a single app. Copy it into your app's repo. |

## Which deploy script

Both scripts perform the **identical** deploy — pre-flight, connect, read the
remote inventory, clean up stale files, upload data files deepest-first and
`.aspx` shells last, record the outcome. They differ in exactly one step: how the
target site's custom-script window gets opened.

Uploading an `.aspx` shell needs two separate things at once, and an open window
does not compensate for a missing permission:

1. **The site's custom-script window open** — `DenyAddAndCustomizePages = $false`,
   a ~24-hour window that auto-resets. Outside it the file uploads but loses its
   executable flag, so it downloads instead of running.
2. **Design or Full Control on the target library** for whoever uploads.

| | `Deploy-SampleLibrary.ps1` | `Deploy-SampleLibrary.SelfService.ps1` |
|---|---|---|
| How the window opens | You flip it: `Connect-SPOService` + `Set-SPOSite` | You queue a request; the service flips it |
| Rights you need | SharePoint **tenant admin** | **None** — a grant for the site |
| Extra infrastructure | None | The enablement Function App |
| Who holds the privilege | You, for the whole tenant, for as long as you hold the role | The service's managed identity, for one checked request |

Pick the one that matches your organization and use it; there is no flag to
learn. If you run the service, the self-service script is strictly better —
nobody needs a standing tenant-admin role to deploy a page.

## The enablement service, and how the script leverages it

The service exists so that opening a window stops being a help-desk ticket. It is
a **PowerShell Azure Function on the Flex Consumption plan** with a
system-assigned managed identity, fronted by three SharePoint lists. The full
design and its security model are in
[docs/script-enablement-self-service.md](../docs/script-enablement-self-service.md);
what matters to a deploy script is the contract.

`Deploy-SampleLibrary.SelfService.ps1` is a **client** of that service, not part
of it. Its whole integration is four steps:

```
1. Add-PnPListItem  ->  "Queued" item on the Requests list, signed in as you.
                        SharePoint stamps Author. The script cannot set it.
2. POST wakeUrl?code=<functionKey>   (read from the service's published
                        config.json — the same file the enablement page reads,
                        so there is one source of truth and nothing to update
                        here when the service moves)
3. The function, under its own managed identity, re-checks (Author, SiteUrl)
   against the admin-curated Grants list, flips the setting, and stamps
   Done + ExpiresUtc — or Denied, or Error.
4. Get-PnPListItem   ->  poll that item until it reports one of the three,
                        then report the expiry and get on with the upload.
```

Three properties of that contract are worth stating plainly, because they are
what make it safe to hand a deploy script to a site owner:

- **Identity comes from the `Author` stamp, never from the client.** SharePoint
  sets it on the request item. A deploy script is therefore just a second
  front-end to the same queue as the web page, with no extra trust and no user
  token reaching the function.
- **Authorization is re-checked server-side at processing time**, against the
  Grants list, keyed on site user id. No grant for that exact site means
  `Denied`; a grant revoked after queuing also means `Denied`.
- **The function key is anti-DoS, not authorization.** It sits in a config file
  a browser can read. It confers no authority — a leaked key buys a no-op queue
  scan — so it is configuration, not a secret.

The wake ping is an **optimization, not a requirement**. If it fails, the request
stays queued and a safety-net timer sweeps the queue every ~10 minutes, so a lost
ping delays a deploy rather than dropping it. That is also what a client-side
timeout means: `-EnablementTimeoutSeconds` elapsing leaves the request queued, and
re-running the deploy shortly afterwards usually finds the window already open.

**Prerequisite.** An admin must have granted you the target site. Register it on
the enablement page; an admin approves with one click. Without a grant the script
gets a clean `Denied` and stops before uploading anything.

## Scope: this repo deploys one library

Both scripts own exactly one target — the `Sample Sites` document library — and
nothing else. Neither uploads to, cleans up, nor otherwise manages another app's
library.

The enablement service is a **separate workstream with its own repo and its own
deploy script**, and it deploys into its own `script-enablement` library. Do not
add it here, and do not point these scripts at that library.

The two do have one deliberate link, and it runs one way: the self-service script
is a *client* of the service. Precisely, it appends one item to the service's
published request list (`EUDA Script Enablement Requests`) and reads one
published file (`config.json`). It uploads nothing to the `script-enablement`
library and never runs its cleanup pass against it. That is consuming a published
service — the [Cross-Application Communication](../patterns/CROSS_APP_COMMUNICATION_PATTERN.md)
pattern in practice — not deploying it.
