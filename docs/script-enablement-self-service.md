# Self-Service Custom-Script Enablement — Implementation Plan

**Status:** Design complete; implementation not started
**Owner:** EUDA App Platform team — `<owner-email>`
**Last updated:** 2026-06-13
**Tier:** IT-owned graduation-tier infrastructure (not citizen tier)

> Working doc. Check off tasks as they land. Phases marked **‖ parallel** can run alongside others; see _Phase dependencies_ at the end.

---

## Problem

SharePoint site owners who want to deploy EUDA apps must have custom script uploads enabled on their site (`DenyAddAndCustomizePages = $false`, which opens a ~24-hour upload window before auto-resetting). Today that requires a **help desk ticket**: a staff member picks it up and runs a PnP PowerShell script by hand. The delay from submission to execution is **hours — up to several days over a weekend.**

## Goal

Let a vetted site owner enable their **own** site's upload window themselves, end-to-end in **under 5 minutes**, with no help desk involvement. This is the "self-service process" already promised in [SHAREPOINT_APP_PATTERN.md](../patterns/SHAREPOINT_APP_PATTERN.md). Because the activity is infrequent and self-service, slow cold starts (including heavy PnP module load) are acceptable and need no optimization.

## Solution overview

A SharePoint page (the UI) + two SharePoint lists (the data) + a PowerShell Azure Function (the only privileged action). The owner's request travels through a SharePoint list queue; a function with an administrative managed identity picks it up and flips the setting. No user tokens ever reach the function.

```
Owner ──Enable──▶ writes "Queued" request item        EUDA Admin ──manages──▶ Grants list
                  (SharePoint stamps Author)                                 (owner → site map)
   │                                                                              ▲
   └──keyed wake-ping──▶ Azure Function (Flex Consumption, PowerShell, managed identity)
                          1. read Queued requests
                          2. authorize: Author (non-forgeable) ∈ Grants for that site?
                          3. if yes → Set-PnPSite -NoScriptSite:$false  → stamp Done + ExpiresUtc
                             if no  → stamp Denied   │  on failure → Error
                          4. log every action
   ◀──poll status── page shows "Enabled until 3:42 PM" / Denied / Error
```

## Authorization model (the crux)

Three layers, each with a distinct job. The earlier "any group member could enable any site" hole is closed by the admin-maintained mapping plus a server-side re-check.

1. **Help-desk-gated security group** — coarse "is this a vetted EUDA builder at all?" gate. Enforced as the **create permission on the Requests list**, so only group members can file a request. (Membership is added via help desk ticket — _not_ self-service.)
2. **Admin-maintained owner→site mapping** (Grants list) — fine-grained "which sites may this builder enable?" An EUDA-site admin makes each association explicitly. The owner UI only shows sites from this mapping.
3. **Function server-side re-check** — the function trusts the request item's SharePoint-stamped `Author` (non-forgeable) and re-verifies `(Author, SiteUrl)` against the Grants list before acting. It never trusts a site value sent by the client.

**Consequence of the queue model:** because authorization is entirely SharePoint-side and the function acts on its own re-check, **no Entra app registration / app role / user token / MSAL is required.** The wake-ping endpoint is protected only by an Azure Functions **function key** (a shared secret in the URL, identical to the Power Automate SAS pattern the platform already uses) — it confers no authority, so a leaked key only lets someone trigger a no-op queue scan. The function key is anti-DoS, not authorization.

**Blast radius:** flipping `DenyAddAndCustomizePages` is a SharePoint **tenant-admin** operation, so the function's managed identity is tenant-admin-equivalent for this setting. The function's `Author`+mapping check and the Grants-list write lockdown are therefore security-critical, and every action must be logged immutably.

## Data model

**`EUDA Script Enablement Grants`** (the mapping) — _write-restricted to the EUDA site Owners group_:

| Field | Type | Purpose |
|---|---|---|
| `Owner` | Person | The vetted owner who may enable |
| `SiteUrl` | Text | Site they may enable |
| `SiteTitle` | Text | Display |
| `Author`, `Created` | auto | Audit: which admin granted it, when |

**`EUDA Script Enablement Requests`** (the queue) — _create-restricted to the security group; item-level read = own items_:

| Field | Type | Purpose |
|---|---|---|
| `Author` | auto (SharePoint-stamped) | Non-forgeable caller identity used for authorization |
| `SiteUrl`, `SiteTitle` | Text | Target site |
| `Status` | Choice | Queued / Done / Denied / Error |
| `ExpiresUtc` | Text | When the enabled window closes (set on Done) |
| `ErrorText` | Note | Failure detail |

---

## Phase 1 — De-risk: permission spike & feasibility  ‖ parallel

The single riskiest unknown. Gates the function (Phase 5) only; the SharePoint UI does not depend on it.

- [ ] In a test/dev tenant, confirm the **minimal permission** that lets a non-interactive managed identity set `DenyAddAndCustomizePages = $false`: test Graph/SharePoint `Sites.FullControl.All` (app) vs. the SPO admin-endpoint path; determine whether a system-assigned MI works app-only or whether an Entra app + certificate in Key Vault is required.
- [ ] Confirm `Set-PnPSite -NoScriptSite:$false` (or the equivalent admin call) succeeds under that identity against an arbitrary target site.
- [ ] Confirm/observe the ~24-hour auto-reset so the "re-enable on demand each time" assumption holds.
- [ ] Measure PnP.PowerShell cold-start time on Flex Consumption (record it; no optimization needed).
- [ ] Document the confirmed permission + auth method as the basis for Phases 2 and 5.

**Done when:** there is a documented, reproducible way for a non-interactive identity to flip NoScript on a given site.

## Phase 2 — Identity & Azure foundation

Depends on Phase 1 (for the permission grant).

- [ ] Create the security group (e.g. `EUDA Script Enablement Users`).
- [ ] Write the **help desk runbook** for adding an owner to that group (the one remaining manual step) and the intake form/fields.
- [ ] Provision the Flex Consumption Function App (PowerShell), enable scale-to-zero, system-assigned managed identity, Application Insights, and Key Vault (only if Phase 1 found a cert is required).
- [ ] Grant the MI the permission confirmed in Phase 1; complete admin consent.
- [ ] Generate the **function key** for the wake endpoint; store it for the page config.
- [ ] Configure **CORS** to allow the `https://*.sharepoint.com` origin.

**Done when:** the function app exists with its MI rights, and a stub endpoint returns 200 when called with the function key from a SharePoint-origin browser request.

## Phase 3 — SharePoint lists & admin UI  ‖ parallel

Pure SharePoint App Pattern; no Azure dependency. Can start immediately.

- [ ] Auto-provision the **Grants** list with its fields; break inheritance — write = EUDA site Owners, read = security group.
- [ ] Auto-provision the **Requests** list with its fields; break inheritance — create = security group, item-level read = "items created by the user", read/write for the function MI.
- [ ] Build the **admin view** (single page, admin tab gated by `effectiveBasePermissions`/ManageWeb on the EUDA site): list, add, and remove grants; people picker for `Owner` (optionally validate the picked user is a group member); site picker or validated URL entry.
- [ ] Verify a non-admin cannot write the Grants list (UI hidden _and_ list ACL enforced).

**Done when:** an EUDA admin can create/remove grants, permissions are verified by test, and both lists auto-provision on first page load.

## Phase 4 — Owner UI & request flow  ‖ parallel (after Phase 3 lists)

- [ ] Owner view: query Grants where `Owner eq [me]`; render each granted site with an **Enable** button.
- [ ] On Enable: write a `Queued` Requests item; fire the keyed wake-ping (config URL + function key); show a "Working — this can take a few minutes" state.
- [ ] Poll the request item's `Status`; render **Done** (with `ExpiresUtc` as a friendly local time), **Denied**, or **Error**.
- [ ] Add a config block for the wake-ping URL + function key, left blank until the function is deployed, with a graceful "enablement service not yet configured" message.

**Done when:** the full owner flow works end-to-end on SharePoint, using a manually-run enablement (or a function stub) to stand in for Phase 5 — request appears, status transitions, UI reflects it.

## Phase 5 — The function (engine)

Depends on Phase 1 (permission), Phase 2 (infra), Phase 3 (lists).

- [ ] Scaffold the PowerShell function with an HTTP trigger `POST /api/process-requests` (`authLevel: function`).
- [ ] Read `Queued` requests via the MI; for each: read `Author`, re-check the Grants mapping for `(Author, SiteUrl)`.
- [ ] Authorized → flip NoScript (the Phase 1 call) → stamp `Done` + `ExpiresUtc`. Unauthorized → `Denied`. Failure → `Error` with detail.
- [ ] Make it idempotent/debounced: skip items already in progress; safe to re-run; one missed wake-ping never double-enables harmfully.
- [ ] Structured logging to App Insights (caller, site, result, timing); the request item is itself an audit record.
- [ ] Un-stub the actual enablement call using the Phase 1 result; reuse the existing help-desk PnP script logic, parameterized by site URL.

**Done when:** clicking Enable results in NoScript enabled within ~5 minutes with `Status=Done` + expiry; an unmapped or forged site yields `Denied`; all actions are logged.

## Phase 6 — Hardening & ops

- [ ] Negative-path tests: request for an unmapped site (Denied); request by a non-group member (blocked at list create); a revoked grant (Denied); function unavailable (page timeout message; optional safety-net catches it later).
- [ ] Optional **sparse safety-net timer** trigger (catches requests where the wake-ping failed to wake the app).
- [ ] Handle SPO admin throttling (honor `Retry-After`); confirm behavior under repeated requests.
- [ ] Confirm the audit trail is complete and retained (list versioning + App Insights retention).
- [ ] Optional ops/status view: recent enablements (who / which site / when / result).

**Done when:** each negative path has a documented test result and the audit is demonstrably complete.

## Phase 7 — Pilot, docs, rollout & decommission

- [ ] Pilot with 2–3 friendly owners; confirm the under-5-minute experience; collect feedback.
- [ ] Update [SHAREPOINT_APP_PATTERN.md](../patterns/SHAREPOINT_APP_PATTERN.md) and its `.aspx`: replace the "file a help desk ticket" enablement guidance with the self-service page link. Bump the pattern version per the **dual-bump rule** (update `versions.json` _and_ the synced version headers — see the patternVersioning convention in [AGENTS.md](../AGENTS.md)).
- [ ] Add the new page(s) to the [deploy script](../deploy/Deploy-SampleLibrary.ps1) flow; the enablement page is an `.aspx` shell, so the custom-script window applies to deploying it.
- [ ] Publish the help desk runbook for group adds (the remaining manual step).
- [ ] Decommission the old manual PnP-script ticket process; communicate the change to owners.

**Done when:** the feature is live, the pattern docs point to it, and the old ticket process is retired.

---

## Phase dependencies

```
Phase 1 (spike) ───────────────┐
                                ├──▶ Phase 5 (function) ──▶ Phase 6 ──▶ Phase 7
Phase 2 (Azure infra) ─────────┤
                                │
Phase 3 (lists + admin UI) ────┴──▶ Phase 4 (owner UI) ───────────────▶ (verifies against Phase 5)
```

- **Start in parallel:** Phase 1 (spike) and Phase 3 (SharePoint lists + admin UI). Neither blocks the other.
- Phase 4 needs the Phase 3 lists. Phase 5 needs Phases 1, 2, and 3.
- The SharePoint UI (Phases 3–4) is fully buildable and verifiable in the local preview before any Azure work exists — using a manual enablement to stand in for the function.

## Open risks

| Risk | Mitigation |
|---|---|
| Exact MI permission to flip NoScript is unconfirmed | Phase 1 spike — the gating task |
| Tenant-admin blast radius on the function identity | SharePoint-side authz + Author/mapping re-check + immutable logging |
| Grants list write-lockdown is the security linchpin | Break inheritance; restrict write to EUDA Owners; verify by test in Phase 3 |
| Function key in page is readable | Acceptable — confers no authority (same model as Power Automate SAS); anti-DoS only |
| Cold start latency | Accepted by design — infrequent, self-service, <5 min SLA vs. hours/days today |
