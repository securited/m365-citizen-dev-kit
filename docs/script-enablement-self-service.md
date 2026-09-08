# Self-Service Custom-Script Enablement

**Status:** Live and verified (2026-08-25). Pilot and rollout in progress.
**Owner:** EUDA App Platform team — `<owner-email>`
**Implementation:** a separate internal repo, not published here — this page describes the design and its security model.
**Tier:** IT-owned graduation-tier infrastructure (not citizen tier)

Deploying an `.aspx` shell requires the target site's custom-script window to be
open (`DenyAddAndCustomizePages = $false`, a ~24-hour window that auto-resets).
That used to mean a help desk ticket and a wait of hours — days over a weekend.
A vetted site owner now opens their own window in **seconds**, from a SharePoint
page or from their deploy script.

This document is the platform-side summary: what it changes for people building
EUDA apps. The design, phase history, and live findings live in the sibling repo.

## How an owner uses it

**Once per site:** register the site on the enablement page. An EUDA admin
approves with one click, which writes the grant. Several people can each hold
their own grant for the same site and enable it independently.

**Every deploy after that,** either front door:

- **The page** — open the enablement page, click **Enable** next to the site,
  and it reports the window's expiry. Measured end to end at 12 seconds.
- **A deploy script** — `deploy/Deploy-SampleLibrary.SelfService.ps1` is the
  kit's own deploy wired to this service, and
  `deploy/examples/Enable-CustomScriptWindow.ps1` is the same request as a
  paste-in helper for an app's own script.

```powershell
.\Deploy-SampleLibrary.SelfService.ps1
```

Both clients queue the same request and are authorized identically. Neither needs
SharePoint admin rights.

**Uploading still needs Design or Full Control** on the target library. The
window and the upload permission are separate requirements, and an open window
does not compensate for a missing one — the file uploads and then downloads
instead of running. The service checks this when a registration is approved and
warns the admin, but rights can change after that.

## How it works

A SharePoint page or a PowerShell client writes a `Queued` request item; a
PowerShell Azure Function (Flex Consumption) with an administrative managed
identity picks it up, re-checks authorization, and flips the setting.

```
Owner ──Enable──▶ "Queued" request item          EUDA Admin ──approves──▶ Grants list
                  (SharePoint stamps Author)                              (owner -> site)
   │                                                                            ▲
   └──keyed wake-ping──▶ Azure Function (managed identity)
                          1. read Queued requests
                          2. authorize: is (Author, SiteUrl) in Grants?
                          3. yes -> flip NoScript, stamp Done + ExpiresUtc
                             no  -> stamp Denied     failure -> Error
                          4. log every action
   ◀──poll status── "Enabled until 3:42 PM" / Denied / Error
```

Three lists carry it: **Grants** (the admin-curated `(Owner, SiteUrl)` mapping),
**Requests** (the queue), and **Registrations** (self-service asks awaiting
approval). A safety-net timer sweeps the queue every 10 minutes, so a lost wake
ping delays a request rather than dropping it.

## The Function App itself

The privileged half is one **PowerShell Azure Function on the Flex Consumption
plan** (PowerShell 7.4), with a **system-assigned managed identity**. Flex scales
to zero, so a service that runs a handful of times a day costs almost nothing
idle — and the cold start it pays in exchange is acceptable precisely because
enabling a site is infrequent and interactive.

| Piece | What it is, and why |
|---|---|
| HTTP trigger, `authLevel: function` | The wake ping. Called by a browser from the enablement page and by a deploy script. The key it requires is anti-DoS only — see the security model below |
| System-assigned managed identity | The only holder of privilege. Gets SharePoint `Sites.FullControl.All` (tenant-wide, app-only) so it can flip `DenyAddAndCustomizePages`, plus `Storage Blob Data Owner` on the app's storage account, because Flex pulls its own deployment package from a blob container using that identity |
| Bundled `PnP.PowerShell` under `Modules/` | Flex Consumption has **no** PowerShell managed dependencies, so `host.json` keeps `managedDependency` off and the module ships inside the deployment package instead of being resolved at runtime |
| CORS allowing the SharePoint origin | The wake ping from the enablement page is a browser `fetch`, so the origin has to be allowed explicitly |
| Application Insights, sampling disabled | Every privileged action is logged, and sampling is off so no audit line is dropped |
| `functionTimeout: 00:10:00` | One invocation drains the whole queue; ten minutes is far more headroom than a sweep needs |
| Safety-net timer | Sweeps the queue every ~10 minutes, so a wake ping that never lands delays a request instead of losing it |

There is no database and no app-owned state: the three SharePoint lists *are* the
state, which is what keeps the function itself stateless, disposable, and
re-deployable without migration.

**The order the grant is armed in matters.** Provisioning stands up only the
harmless infrastructure — app, identity, App Insights, storage role, CORS. The
tenant-wide `Sites.FullControl.All` grant is armed separately, once the real
function logic is ready to receive it, to keep the window in which a
half-finished function holds tenant-wide rights as close to zero as possible.

## The security model, in three facts

**Identity comes from the `Author` stamp, never from the client.** SharePoint
stamps it on the request item and no client can set it — which is exactly why a
deploy script is just a second front-end to the same queue, with no extra trust
and no user token reaching the function.

**Authorization is re-checked server-side, at processing time.** The function
verifies `(Author, SiteUrl)` against the Grants list before acting, keyed on the
site user id rather than a name or email. A request for an unmapped site is
`Denied`; so is one whose grant was revoked after it was queued. The Requests
list is open to any authenticated user by design — the worst a forged request
achieves is a `Denied` row.

**The function key is anti-DoS, not authorization.** It is in the page's config
where a browser can read it, exactly like the platform's Power Automate SAS URLs.
It confers no authority: a leaked key buys a no-op queue scan.

The consequence to respect: flipping this setting is a tenant-admin operation, so
the function's managed identity holds tenant-wide SharePoint
`Sites.FullControl.All`. **The Grants-list write lockdown is the security
linchpin** — anyone who can write that list can authorize enabling any site. It
is restricted to the admin site's Owners group, verified by test with a real
non-admin account, and every privileged action is logged immutably (list
versioning plus App Insights, with sampling disabled so no audit line is dropped).

## For admins

Grants are managed on the same page's admin view, which is gated on `ManageWeb`.
Approving a registration takes the owner from the registration's stamped `Author`,
never from a user-supplied field, and is idempotent — a double-click cannot
create a duplicate grant. The function verifies each pending registration's
site rights and stamps a verdict (`Owner` / `Designer` / `Insufficient` /
`Unknown`) so an admin can see, before approving, whether the grant would
actually be usable. The verdict is advisory: it grants nothing on its own.

Removing a grant hard-deletes the row, so revocations are not audited beyond the
site recycle bin. Accepted: grants are effectively permanent for the life of this
tooling, with no routine revoke churn.

## Still open

- Pilot with a wider set of owners, then retire the help-desk ticket process and
  communicate the change.
- Throttling retry logic is written and reviewed but has never been exercised
  against real SPO throttling — this volume does not reach it.
