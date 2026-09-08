# deploy/

Deployment tooling for the EUDA App Platform.

| Script | Purpose |
|---|---|
| `Deploy-SampleLibrary.ps1` | The platform's own deploy: pre-flight, connect, enable (only when a shell changed), clean up stale files, upload. Run `-WhatIf` first. |
| `examples/Enable-CustomScriptWindow.ps1` | Reusable helper — open your own site's custom-script window with no admin rights. Dot-source it or paste the function into your script. |
| `examples/Deploy-MyApp.Example.ps1` | A complete minimal deploy script for a single app, with self-service enablement wired in. Copy it into your app's repo. |

## Opening the custom-script window

Uploading an `.aspx` shell needs two things at once: the site's custom-script
window open, and Design or Full Control for whoever uploads. There are two ways
to get the window.

**Self-service (no admin rights) — the default.** `euda-sample` holds a grant
with the enablement service, so the script opens its own window as the
signed-in user. Nothing to pass:

```powershell
.\Deploy-SampleLibrary.ps1
```

The request is authorized server-side against an admin-curated Grants list,
keyed on the `Author` SharePoint stamps on the request item — which no client
can set. A request for a site you hold no grant for comes back `Denied`. Ask for
a grant by registering the site on the enablement page; an admin approves it
with one click.

**Tenant admin (the fallback).** `-TenantAdminEnablement` switches back to
`Connect-SPOService` + `Set-SPOSite`. Needs SharePoint admin rights on the
tenant. Use it only if the enablement service is down, or for a site that holds
no grant.

Either way the window is skipped entirely when no `.aspx` actually changed —
a `_data/`-only deploy needs Contribute and nothing more. See
[docs/script-enablement-self-service.md](../docs/script-enablement-self-service.md).

## Scope: this repo deploys one library

`Deploy-SampleLibrary.ps1` owns exactly one target — the
`Sample Sites` document library — and nothing else. It never uploads to,
cleans up, or otherwise manages another app's library.

The self-service enablement app is a **separate workstream with its own repo and
its own deploy script**, and it deploys into the `script-enablement` library.
Do not add it here, and do not point this script at that library.

The two do have one deliberate link, and it runs one way: this script is a
*client* of the enablement service. To upload an `.aspx` shell it needs a
custom-script window, so it queues a request on the service's list and reads
`wakeUrl` from that app's published `config.json`. That is consuming a published
service — the [Cross-Application Communication](../patterns/CROSS_APP_COMMUNICATION_PATTERN.md)
pattern in practice — not deploying it. Precisely: it appends one item to the
service's published request list (`EUDA Script Enablement Requests`) and reads
one published file. It uploads nothing to the `script-enablement` library and
never runs its cleanup pass against it.

There was previously a `-PreservePaths` parameter, added when both apps shared
one library so the cleanup sweep would not delete the other's files. The
libraries are separate now, so it has been removed. If a library is ever shared
again, bring it back deliberately rather than leaving a dormant hook that
invites re-entangling the two.
