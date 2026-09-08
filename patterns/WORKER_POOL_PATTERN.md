# Building Automation with the Worker Pool Pattern

> **Worker Pool Pattern — v1.6** · updated 2026-08-27. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A guide for running scheduled and background automation — "server work" — with **no server, no service account, and no premium licensing**, by combining two patterns you already know: a [Packaged Python](PACKAGED_PYTHON_PATTERN.aspx) app on each participant's machine, coordinated through [SharePoint](SHAREPOINT_APP_PATTERN.aspx) lists.

> **Starting a new worker pool?** See [WORKER_POOL_PROMPT.md](WORKER_POOL_PROMPT.md) for a complete prompt you can give Claude to constrain development to this pattern's conventions. Attach it **together with** [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md) as your first message — this pattern builds on that one.

---

## Executive Summary

This pattern answers a question the other patterns can't: *how do we run a recurring job when no single machine is reliably on, and we don't have a server?*

The answer is a **worker pool**:

- **Jobs live in SharePoint** as items in a Schedules list — what to run, with what parameters, how often, and when the next run is due.
- **Everyone who keeps the worker app open is a worker.** The app is a normal Packaged Python Pattern C (Streamlit) app — double-click, sign in once, leave the tab open. Close the tab and you leave the pool.
- **Exactly one worker wins each run.** Claiming a job is a single conditional write that SharePoint accepts from one caller and rejects for the rest. No lock files, no leader election, nothing to clean up after a crash.
- **Every run is logged** to a JobRuns list — who ran it, when, how long, what happened — and a read-only status page shows the whole pool's activity to anyone in the tenant.
- **Identity is each participant.** Every claim, run, and output is attributed to the user whose machine won it. No service accounts, no shared credentials.

As long as *someone* on the team has the app open, the automation runs. That is the pattern's promise — and its honest limitation.

---

## When to Choose This Pattern

This is a composition pattern: read the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx) and [Packaged Python Pattern](PACKAGED_PYTHON_PATTERN.aspx) guides first; everything there applies here. Choose the scheduling option deliberately:

| Your situation | Use |
|---|---|
| The work is connector-shaped (read a list, send an email, post to Teams) and fully tenant-side | **Power Automate scheduled flow** — simpler, always-on, no pool needed |
| The work calls an external API and premium licensing is available | **Power Automate scheduled flow** — the generic HTTP action is a premium connector, so confirm the licence first |
| The work calls an external API and premium licensing is **not** available | **This pattern, or Pattern B + Task Scheduler** — no premium licence needed, and the call runs as a named person |
| One person's machine is reliably on and the job is theirs alone | **Packaged Python Pattern B + Task Scheduler** |
| The work needs Python, the user's own data permissions, or local resources — and the *team* should keep it running rather than one machine | **This pattern** |
| The schedule must be guaranteed, sub-minute, exactly-once, or involves regulated data | **None of the citizen tiers** — escalate to IT-supported hosting |

---

## Core Concepts

### The Coordination Lists

Two SharePoint lists are the entire coordination layer. The worker auto-provisions them on first connect, following the [SharePoint App Pattern's auto-provisioning convention](SHAREPOINT_APP_PATTERN.aspx) (create on 404; treat the "field already exists" error `-2130575306` as success).

**Schedules list** — one item per recurring job:

| Field | Type | Purpose |
|---|---|---|
| `Title` | Text | Human-readable job name |
| `JobType` | Text | Key into the worker's job catalog (the code that runs) |
| `ParametersJson` | Note | Job parameters as JSON — data, not code |
| `IntervalMinutes` | Number | How often the job recurs |
| `NextRunDue` | DateTime | When the next run becomes claimable |
| `ClaimedBy` | Text | Who won the most recent claim (display/audit) |
| `RunId` | Text | Unique id of the current claim — the fencing token |
| `Enabled` | Boolean | Pause switch |

**JobRuns list** — one item per execution: `Title` (run id), `JobTitle`, `JobStatus` (Running / Succeeded / Failed), `RunBy`, `StartedUtc`, `FinishedUtc`, `DurationMs`, `Output`, `ErrorText`.

### Claiming Is a Conditional Write, Not a Lock (Fixed)

The heart of the pattern is SharePoint's optimistic concurrency: every list item carries an **etag**, and an update sent with `If-Match: <etag>` succeeds only if the item hasn't changed since you read it. That atomic compare-and-swap turns "who runs this job?" into a race SharePoint referees:

1. A worker reads a due schedule (`Enabled` and `NextRunDue` in the past), capturing its etag.
2. It writes `NextRunDue += IntervalMinutes`, `ClaimedBy`, and a fresh `RunId` — conditioned on that etag.
3. SharePoint answers one concurrent claimer with **204** (you own this run) and everyone else with **412 Precondition Failed** (move on — this is the system working, not an error).

There is nothing to unlock: the "lock" exists only for the instant of the update. A crashed winner means one visible missed run in JobRuns, not a stuck lock requiring cleanup. Hence **no lock files and no leases** — they would add expiry, heartbeats, and recovery logic for no benefit.

### Jobs Are Code, Schedules Are Data

The worker ships a **job catalog**: a dictionary mapping `JobType` to a Python function the app owner wrote and reviewed. Schedule items select from that catalog and pass parameters as JSON. Citizens add *schedules* (list items, governed by list permissions); only the owner adds *job types* (code, governed by review). An unknown `JobType` is logged as a failed run and skipped — it must never crash the worker.

### At-Least-Once Execution — Jobs Must Be Idempotent (Fixed)

Claiming is exactly-once, but execution is **at-least-once**: a winner can crash mid-run, and in one rare edge (the claim succeeded but the response was lost in transit) a job could run twice. Every job must be safe to repeat — overwrite the same output file, key results by `RunId`, upsert rather than append. If a job cannot be made idempotent, it does not belong in this pattern.

### The Fencing Guard

Laptops sleep. A worker that claims a job, sleeps, and wakes an hour later must not blindly resume side effects. Rule: if execution begins suspiciously long after the claim (90 seconds is the reference grace), re-read the schedule item and proceed only if `RunId` is still yours.

### Liveness Is Community-Powered

If nobody has the app open — weekends, holidays, an all-hands — nothing runs. That is inherent and acceptable *only if surfaced*: the status page shows when each schedule last ran and who is in the pool, and anything displaying job output should show its age. Jobs must tolerate gaps (catch up on the next run, or produce fresher output).

### Etiquette Toward SharePoint

- Poll on a user-configurable 30–180 second interval; the reference default is 60 seconds with jitter so workers don't synchronize.
- Honor `Retry-After` on 429/503 responses and back off (the approved `tenacity` library handles the retry loop).
- Requests authenticate with a Bearer token (Entra sign-in as the user, per the Packaged Python pattern's Graph/M365 auth rules), so the [form digest](SHAREPOINT_APP_PATTERN.aspx) is **not** required — it applies only to cookie-authenticated browser sessions.

---

## The Three Components

**1. The worker app** — a standard [Packaged Python Pattern C](PACKAGED_PYTHON_PATTERN.aspx) app: one `app.py`, the canonical `launch.cmd`, a README. Everything that pattern mandates (PEP 723, approved stack, Streamlit bootstrap with first-run hygiene, localhost-only) applies unchanged. On top, this pattern requires: a one-click **"Sign in & join the pool"** connect flow that auto-provisions the lists; a live dashboard where the same auto-refresh cycle that redraws the screen also polls and claims; an activity feed that shows lost claims as the system working; and the race proof (below).

**2. The status page** — a read-only, single-file `.aspx` page following the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx), so anyone in the tenant can watch the pool without running anything: schedules with due-state, recent runs, machines seen recently, and the latest job output. Before the lists exist it must say so helpfully, not error.

**3. The lists** — the engine-agnostic contract. Nothing in the schema knows the worker is Python: a Power Automate flow or IT-owned Azure Function could service the *same* Schedules/JobRuns lists later using the same etag protocol. That is the built-in graduation path — if the pool outgrows citizen scale, replace the engine with no client changes.

---

## Verifying an Implementation: the Race Proof

Every implementation must demonstrate its core guarantee on demand: fire **N simultaneous claims at one etag** (threads released through a barrier) and show exactly one 204 and N−1 412s. The reference app ships this as a one-click "Race proof" with one result card per racer. If the proof ever shows more than one winner, stop trusting the implementation and investigate — the entire pattern rests on that split.

---

## Deployment

- The worker folder and status page deploy like any other sample via the platform deploy script; the status page is an `.aspx` shell, so the [custom-script enablement window](SHAREPOINT_APP_PATTERN.aspx) applies to it (not to the worker folder).
- The coordination lists are *not* deployed — the first worker to connect creates them. An owner with list-creation rights should connect once before wide rollout. The shared app registration is consented for the scope this needs (`Sites.Manage.All`), so provisioning is a permissions question about the *user*: the connecting owner needs list-creation rights on the site.
- Job output files that workers overwrite at runtime must be registered as **seed-only** in the deploy script (`$SeedOnlyFiles`): uploaded when missing, never overwritten by a redeploy.
- **Distributing the worker to pool participants** follows the [Packaged Python pattern's team-distribution guidance](PACKAGED_PYTHON_PATTERN.aspx): the SharePoint site hosting the coordination lists and status page also hosts the worker's release folder and a `version.json`. A mixed-version pool is the failure mode this prevents, so the worker should carry the staged-update block — at startup it offers the new release, stages it, and lets `launch.cmd` swap and restart, converging the pool on one release for a single keystroke per participant. Keep the dashboard's "a newer version is available" banner as well: it covers a release published while a worker is already running.
- **The release library ACL is a pool-wide trust decision.** Write access to it is equivalent to code execution on every participant's machine. Break inheritance on the library, Owners Edit and everyone else Read, external sharing off — see the Packaged Python guidance for the full list.

---

## What This Pattern Is Good For

- Recurring reports and data refreshes that need Python and the team's own data permissions
- Keeping a shared dataset, cache, or dashboard feed current during working hours
- Queue-shaped chores: process whatever accumulated, on whoever's machine is available
- Any Packaged Python automation a *team* should own rather than one person's Task Scheduler

## What It Is Not Good For

- Guaranteed execution times or sub-minute schedules (polling and liveness gaps forbid both)
- Exactly-once side effects — payments, ticket creation without dedup keys, anything unsafe to repeat
- Around-the-clock duty cycles nobody's machine can honor — if it must *always* run, it needs IT hosting
- Regulated data (PHI, payment data) — out of scope for the citizen tier, same as the base patterns

---

## Reference Implementation

| Piece | Where |
|---|---|
| Worker app (Pattern C, with race proof) | `euda-worker/` in the `Sample Sites` library |
| Status page | [euda-worker-status.aspx](euda-worker-status.aspx) |
| Coordination lists | `EUDA Schedules`, `EUDA JobRuns` (auto-provisioned on the sample site) |
| Demo job | `weather-to-json` — fetches a public API and overwrites `euda-worker_data/latest.json` |

## Quick Reference

| Need | Use |
|---|---|
| Define a recurring job | Item in the Schedules list (`JobType` + `ParametersJson` + `IntervalMinutes`) |
| Win a run safely | MERGE with `If-Match: <etag>`; 204 = yours, 412 = someone else's |
| Survive laptop sleep | Re-read and verify `RunId` before side effects after a grace period |
| Make double-runs harmless | Idempotent jobs only — overwrite, upsert, key by `RunId` |
| See pool activity | Status page; JobRuns list (native SharePoint views work too) |
| Pause a job | `Enabled = No` on the schedule item |
| Add a job type | New catalog function in the worker (owner-reviewed code), then publish a release (upload the folder, bump `version.json` with the new version and sha256) |
| Prove correctness | Race proof: N simultaneous claims → exactly one 204 |
| Outgrow the pool | Same lists, new engine: Power Automate flow or IT-owned Azure Function |
