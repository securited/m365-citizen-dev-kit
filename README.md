# M365 Citizen Dev Kit

Patterns, ready-made AI prompts, and sample apps for building **approved internal tools inside Microsoft 365** — instead of on external AI app builders (Lovable, Bolt, v0, Replit, and similar). Your apps run in your own M365 tenant or on your own machine: sign-in is automatic, data stays inside your boundary, and there's a documented owner.

It gives end-user / citizen developers the same "describe it and watch it appear" experience as the external builders, constrained to a few well-supported patterns:

| You want to… | Pattern (click for the guide) |
|---|---|
| Prototype an idea or a one-off tool/visualization | **[Claude Artifacts](patterns/CLAUDE_ARTIFACTS_PATTERN.md)** — describe it, see it run, inside your approved AI service |
| Build a team tool (forms, dashboards, trackers with shared data) | **[SharePoint App](patterns/SHAREPOINT_APP_PATTERN.md)** — runs in your M365 tenant; everyone signs in automatically; data lives in SharePoint Lists |
| Automate your own work (crunch files, generate reports, query databases) | **[Packaged Python](patterns/PACKAGED_PYTHON_PATTERN.md)** — one single file colleagues run with a double-click; nothing to install; connects to data as *you* |
| Run scheduled/background automation with no server | **[Worker Pool](patterns/WORKER_POOL_PATTERN.md)** — Packaged Python workers coordinated through SharePoint lists |

Three **supporting patterns** apply across the others — read them alongside the pattern you're building in, not instead of it:

| Concern | Supporting pattern |
|---|---|
| Who can see and change what, and proving who did what | **[SharePoint Permissions & Auditing](patterns/SHAREPOINT_PERMISSIONS_PATTERN.md)** — site/list/folder/file permissions *as* the app's authorization layer, and an audit trail you don't have to write |
| Designing data that will grow, and what happens when it gets old | **[Storage Shape & Lifecycle](patterns/SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.md)** — how many objects the storage layer creates, which mechanism can carry them, and archiving |
| One app needing data or work from another | **[Cross-Application Communication](patterns/CROSS_APP_COMMUNICATION_PATTERN.md)** — a SharePoint list standing in for an API, behind a published contract that says what may be depended on |

**Reading the patterns.** Each pattern in [`patterns/`](patterns/) has three files: the guide **`*_PATTERN.md`** (start here — it renders on GitHub, and the tables above link straight to it), a copy-paste **`*_PROMPT.md`** starter prompt that constrains the AI to the pattern's conventions, and **`*_PATTERN.aspx`** — the same guide published as a SharePoint page.

**Pointing an AI assistant at this repo?** Start it on **[patterns/PATTERN_INDEX.md](patterns/PATTERN_INDEX.md)** — a routing guide that says which two or three of the seven guides a given task actually needs, rather than having it read all of them badly.

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

## Deploying to SharePoint, and the wall you hit first

Publishing an `.aspx` page runs into one obstacle that has nothing to do with your
app: SharePoint requires the target site's **custom-script window** to be open
(`DenyAddAndCustomizePages = $false`, a ~24-hour setting that auto-resets). Upload
outside the window and the file lands but loses its executable flag — it downloads
instead of running, which looks like a broken app rather than a permissions problem.

Flipping that setting is a **tenant-admin operation**, which leaves most
organizations choosing between two bad answers: route every deploy through a help
desk ticket — hours, or days over a weekend, for a change that takes seconds — or
hand standing SharePoint admin rights to people whose job is building forms.

The kit documents a third answer, as **optional** infrastructure: a small
**PowerShell Azure Function** on the Flex Consumption plan, holding a
system-assigned managed identity that owns the privilege. Nobody else gets it. A
vetted site owner queues a request — from a SharePoint page, or straight from their
deploy script — and the function re-checks, server-side, that this person holds a
grant for that exact site before flipping anything. Identity comes from the `Author`
stamp SharePoint puts on the request, which no client can set or spoof, so a deploy
script is just a second front door to the same queue and carries no extra trust.

The result: seconds instead of days, and **no admin rights are delegated to
anyone**. The privilege stays with the service and is exercised one checked request
at a time, with every action logged. Flex scales to zero, so infrequent use costs
almost nothing to keep running.

You do not need any of it to use this kit. There are two deploy scripts — pick the
one that matches your organization:

| Your setup | Script |
|---|---|
| No enablement service | [`deploy/Deploy-SampleLibrary.ps1`](deploy/Deploy-SampleLibrary.ps1) — you flip the setting yourself; needs SharePoint tenant admin |
| Running the service | [`deploy/Deploy-SampleLibrary.SelfService.ps1`](deploy/Deploy-SampleLibrary.SelfService.ps1) — queues a request; needs no admin rights, only a grant |

Everything else about the two is identical, and both skip the step entirely when no
`.aspx` actually changed. The architecture and security model are in
[docs/script-enablement-self-service.md](docs/script-enablement-self-service.md);
which script to use and how the client contract works are in
[deploy/README.md](deploy/README.md).

## Documentation

- Project docs and plans: [`docs/`](docs/)
- AI agents: see [`AGENTS.md`](AGENTS.md) — the canonical agent context
- Decisions: [`docs/decisions/`](docs/decisions/)
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md) · Security: [`SECURITY.md`](SECURITY.md)

## License

[MIT](LICENSE).
