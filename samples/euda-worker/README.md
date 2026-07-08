# EUDA Worker

**App name:** EUDA Worker (coordinated multi-user automation)
**Owner:** EUDA App Platform team — `<owner-email>` *(replace when you copy this sample)*
**Pattern:** Worker Pool (reference implementation) — see `WORKER_POOL_PATTERN.md`; built on Packaged Python Pattern C
**Date last reviewed:** 2026-06-12

## Purpose

Proves that "server automation" can run with no server: several users keep this
app open in a browser tab, recurring jobs live as items in a SharePoint list,
and every open worker races to claim each due run using an **atomic
compare-and-swap** (a list item MERGE conditioned on `If-Match: <etag>`).
SharePoint guarantees exactly one writer succeeds (HTTP 204) and every other
concurrent claimer gets **412 Precondition Failed** — so each run executes on
exactly one machine, with no leader election, no lock files, and nothing to
clean up after a crash.

The demo job fetches Open-Meteo weather and overwrites
`Sample Sites/euda-worker_data/latest.json`, stamped `source: "worker"` —
`euda-worker-status.aspx` displays it as "Latest output" along with the whole
pool's coordination state, for anyone on SharePoint.

## End users: just double-click

`launch.cmd` opens the app in a browser tab. Click **Sign in & join the pool**
(browser sign-in on first run, silent afterward via the DPAPI token cache —
the lists are created automatically if missing). That's the whole contract:

> **While the tab is open, your machine is part of the worker pool.
> Close the tab, and it isn't.**

The page shows live metrics, the schedule table with due-state badges, the
recent-run history, and a personal activity feed of every claim this machine
won (🏆), lost (🤝 — by design), or ran (✅/❌).

## The visual proof

In the sidebar:

1. **🌱 Seed demo schedule** — creates the demo weather job, due immediately.
2. **🏁 Run race proof** — fires N simultaneous claims at a single etag and
   shows one card per racer: exactly one green **WON (HTTP 204)** and N−1
   yellow **412 — lost**. That 204/412 split *is* the pattern's guarantee that
   no job can ever run twice from one tick.
3. Open the app on two or more machines and watch the **Recent runs** table
   (or `euda-worker-status.aspx`): each scheduled tick is executed by exactly
   one machine, attributed to whichever user won the claim.

## How coordination works

- **Claim = CAS, not a lock.** A worker reads a due schedule item (capturing
  its etag), then writes `NextRunDue += interval`, `ClaimedBy`, `RunId` with
  `If-Match: <etag>`. One concurrent writer wins; losers get 412 and move on.
  The "lock" exists only for the instant of the update — nothing expires,
  nothing needs heartbeats, a crashed winner just means one visible missed run.
- **Fencing guard.** If execution starts suspiciously long after the claim
  (laptop slept), the worker re-reads the item and aborts unless `RunId` is
  still its own.
- **At-least-once semantics.** Jobs must be idempotent (the demo job
  overwrites one file). A lost claim response could, rarely, double-run a job.
- **Etiquette.** Polling every 30–180 s (user-set, default 60); honors
  `Retry-After` on 429/503.

## Data sources touched

| Source | Details |
|---|---|
| SharePoint `https://contoso.sharepoint.com/sites/euda-sample` | Reads/writes the `EUDA Schedules` and `EUDA JobRuns` lists; overwrites `Sample Sites/euda-worker_data/latest.json` |
| Open-Meteo public API (`api.open-meteo.com`) | Read-only weather lookup (no key, no company data sent) |
| Entra ID | Delegated sign-in as the running user via the shared **Contoso EUDA Applications** registration (`EUDA_WORKER_CLIENT_ID` / `EUDA_WORKER_TENANT_ID` env overrides); token cached with DPAPI |

## Scope note

This app is the **reference implementation of the Worker Pool pattern** —
the documented composition of the Packaged Python and SharePoint App
patterns for scheduled/background automation with no server. The pattern
guide (`WORKER_POOL_PATTERN.md`) and project prompt (`WORKER_POOL_PROMPT.md`)
in the Sample Sites library are the authoritative rules; this folder is the
working example they describe. The coordination contract (the
`EUDA Schedules` / `EUDA JobRuns` lists) is engine-agnostic: a Power Automate
flow or an IT-owned Azure Function could later service the same lists without
changing any client.
