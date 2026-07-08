# Claude Code — Worker Pool Pattern: Project Prompt

> **Worker Pool Pattern — v1.2** · updated 2026-07-08. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

Copy the block below as your first message when starting a new worker-pool project. **Attach [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md) with the same message** — this pattern builds on the Packaged Python pattern, and every rule there is binding too. Customize the bracketed sections and replace every `<...>` placeholder.

---

```
You are building a coordinated worker-pool automation app: several users keep a
local app open, recurring jobs live in SharePoint lists, and the open instances
race to claim each due run so that exactly one machine executes it. The
Packaged Python project prompt is included with this message — the worker is a
Pattern C (Streamlit) app and every rule there (runtime, approved stack,
canonical launch.cmd, Streamlit bootstrap with first-run hygiene, security
rules) is binding. This prompt adds the coordination rules. Deviation from
either is a defect.

## Architecture (fixed)

Three components:

1. **Worker app** — Packaged Python Pattern C. The browser tab IS the worker:
   the same auto-refresh cycle that redraws the dashboard polls for due jobs.
2. **Status page** — a read-only single-file .aspx following the SharePoint App
   Pattern's conventions (deriveSiteUrl, REST with verbose OData, graceful
   degradation), deployed to the same document library.
3. **Two coordination lists**, auto-provisioned by the worker on first connect
   (create list on 404; treat field-exists error -2130575306 as success):

   "<prefix> Schedules" — Title (Text), JobType (Text), ParametersJson (Note),
   IntervalMinutes (Number), NextRunDue (DateTime), ClaimedBy (Text),
   RunId (Text), Enabled (Boolean)

   "<prefix> JobRuns" — Title = run id (Text), JobTitle (Text), JobStatus
   (Text: Running | Succeeded | Failed), RunBy (Text), StartedUtc (Text),
   FinishedUtc (Text), DurationMs (Number), Output (Note), ErrorText (Note)

Use space-free internal field names exactly as listed.

## The claim protocol (fixed — this is the pattern's core guarantee)

- A poll pass queries schedules where Enabled eq 1 and NextRunDue le utcnow.
- To claim: MERGE the item with header If-Match: <etag captured at read>,
  setting NextRunDue = utcnow + IntervalMinutes, ClaimedBy, and a fresh RunId.
  HTTP 204 = this instance owns the run. HTTP 412 = another instance won;
  log it to the activity feed as normal coordination (never as an error) and
  move on. Never claim with If-Match: * — that defeats the entire pattern.
- Fencing guard: if execution starts more than ~90 seconds after the claim
  (machine slept), re-read the item and abort unless RunId is still yours.
- Log every run to JobRuns: create with JobStatus=Running before executing,
  MERGE to Succeeded/Failed with timings and output/error afterward.
- A job failure must never kill the worker loop. An unknown JobType is a
  Failed run, not a crash.

## Job rules

- Jobs are entries in a code catalog (dict of JobType -> function) written by
  the app owner. Schedule items select a JobType and pass ParametersJson.
  Never execute code, expressions, or file paths taken from list data.
- Every job MUST be idempotent — execution is at-least-once. Overwrite the
  same output, upsert, or key results by RunId. If a requested job cannot be
  made idempotent, stop and say so instead of building it.
- Files a job overwrites in the document library are seed-only artifacts: tell
  the user to register them in the deploy script's $SeedOnlyFiles list.

## SharePoint access

- Authenticate as the user with azure-identity InteractiveBrowserCredential +
  TokenCachePersistenceOptions (DPAPI cache), using the shared IT-owned
  "Contoso EUDA Applications" registration — client id
  <your-entra-client-id>, tenant id
  <your-tenant-id> (env-overridable). Never create app
  registrations; never use service accounts.
- Requests carry a Bearer token, so X-RequestDigest is NOT needed (the form
  digest applies only to cookie-authenticated sessions).
- REST with Accept: application/json;odata=verbose; the item etag is
  __metadata.etag and the MERGE target is __metadata.uri.
- Polling etiquette: user-configurable 30–180 s interval (default 60) with
  jitter; honor Retry-After on 429/503; tenacity for transient retries.

## Worker UX requirements

- Connect is one click ("Sign in & join the pool") and auto-provisions the
  lists; a clear message tells users the contract: while this tab is open,
  this machine is in the pool; close it to leave.
- Lists-creation permission failure must produce a plain-English message
  ("ask the app owner to connect once"), not a stack trace.
- Dashboard: metrics (active schedules, next run due, 24 h success/fail,
  machines seen), schedules table with due-state, recent runs, and a
  personal activity feed (claims won 🏆 / lost 🤝 / runs ✅❌).
- Include the race proof as a one-click owner tool: N simultaneous claims
  against one etag (threads released through a barrier), one result card per
  racer, and an explicit verdict — exactly one 204 expected; more than one
  winner = proof failed, say so loudly.
- Link to the status page from the sidebar.

## Status page requirements

- Read-only: schedules with due-state pills, recent runs with status pills,
  machines seen in the last 24 h, and the latest job output with its age.
- Before the lists exist, show "open the worker app once to create them" —
  never a raw error. Auto-refresh every ~30 s.

## Out of scope — stop and escalate

- Guaranteed execution times, sub-minute schedules, exactly-once side effects
- Jobs that must run around the clock regardless of who is online
- Regulated data (PHI, payment data) — same boundary as the base patterns
- If the pool outgrows citizen scale, the migration path is a Power Automate
  flow or IT-owned Azure Function servicing the SAME lists — never a bigger
  pool.

---

## Project-Specific Context

**Application name:** [App Name]
**List prefix:** [e.g. "EUDA" → "EUDA Schedules" / "EUDA JobRuns"]
**Owner:** [name + email]
**Purpose:** [one paragraph: what the jobs do and why a team should run them]

**Job catalog:**
| JobType | What it does | Parameters | Idempotency strategy |
|---|---|---|---|
| [job-name] | [reads X, writes Y] | [JSON fields] | [overwrite / upsert / RunId key] |

**SharePoint site:** [site URL]
**Status page name:** [<app>-status.aspx]
**Schedules to seed:** [initial jobs with intervals]

Begin by confirming the job catalog and the idempotency strategy for each job,
then scaffold the worker (connect flow + claim protocol + race proof) before
writing any job logic.
```
