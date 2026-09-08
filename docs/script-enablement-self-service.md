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
- **A deploy script** — the platform's own script does this by default, and
  `deploy/examples/Enable-CustomScriptWindow.ps1` is a paste-in helper for an
  app's own script.

```powershell
.\Deploy-SampleLibrary.ps1
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
