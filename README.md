# M365 Citizen Dev Kit

Patterns, ready-made AI prompts, and sample apps for building **approved internal tools inside Microsoft 365** — instead of on external AI app builders (Lovable, Bolt, v0, Replit, and similar). Your apps run in your own M365 tenant or on your own machine: sign-in is automatic, data stays inside your boundary, and there's a documented owner.

It gives end-user / citizen developers the same "describe it and watch it appear" experience as the external builders, constrained to a few well-supported patterns:

| You want to… | Pattern (click for the guide) |
|---|---|
| Prototype an idea or a one-off tool/visualization | **[Claude Artifacts](patterns/CLAUDE_ARTIFACTS_PATTERN.md)** — describe it, see it run, inside your approved AI service |
| Build a team tool (forms, dashboards, trackers with shared data) | **[SharePoint App](patterns/SHAREPOINT_APP_PATTERN.md)** — runs in your M365 tenant; everyone signs in automatically; data lives in SharePoint Lists |
| Automate your own work (crunch files, generate reports, query databases) | **[Packaged Python](patterns/PACKAGED_PYTHON_PATTERN.md)** — one single file colleagues run with a double-click; nothing to install; connects to data as *you* |
| Run scheduled/background automation with no server | **[Worker Pool](patterns/WORKER_POOL_PATTERN.md)** — Packaged Python workers coordinated through SharePoint lists |

Two **supporting patterns** apply across the others — read them alongside the pattern you're building in, not instead of it:

| Concern | Supporting pattern |
|---|---|
| Who can see and change what, and proving who did what | **[SharePoint Permissions & Auditing](patterns/SHAREPOINT_PERMISSIONS_PATTERN.md)** — site/list/folder/file permissions *as* the app's authorization layer, and an audit trail you don't have to write |
| Designing data that will grow, and what happens when it gets old | **[Storage Shape & Lifecycle](patterns/SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.md)** — how many objects the storage layer creates, which mechanism can carry them, and archiving |

**Reading the patterns.** Each pattern in [`patterns/`](patterns/) has three files: the guide **`*_PATTERN.md`** (start here — it renders on GitHub, and the tables above link straight to it), a copy-paste **`*_PROMPT.md`** starter prompt that constrains the AI to the pattern's conventions, and **`*_PATTERN.aspx`** — the same guide published as a SharePoint page.

**Fixed vs Default.** Every guide labels its rules: **Fixed** means deviating breaks the platform, its security model, or its audit trail; **Default** means it's the right answer absent a specific reason — a judgement call you're expected to make, and to record when you depart from it.

**Why `.aspx`?** The kit is built to be hosted *inside SharePoint* — it dogfoods its own SharePoint App Pattern — so the pattern pages and sample apps are `.aspx` that run as live pages in a document library. To read one outside SharePoint, open the matching `*_PATTERN.md`, or rename/serve the `.aspx` as `.html` (the markup is plain HTML/JavaScript) — for example with the local preview server below.

> **Status:** This repo is the public, de-branded version of a private internal platform. See [docs/anonymization-plan.md](docs/anonymization-plan.md) for how it was de-branded.

## Quick start

```powershell
# Preview the SharePoint .aspx + _data shells locally (static server)
pwsh -NoProfile -File .claude/serve.ps1 -Port 7432

# Run a single-file Python sample with zero install (requires uv)
uv run samples/csv-merge-report/app.py
```

## Documentation

- Project docs and plans: [`docs/`](docs/)
- AI agents: see [`AGENTS.md`](AGENTS.md) — the canonical agent context
- Decisions: [`docs/decisions/`](docs/decisions/)
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md) · Security: [`SECURITY.md`](SECURITY.md)

## License

[MIT](LICENSE).
