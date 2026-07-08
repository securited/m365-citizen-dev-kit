# M365 Citizen Dev Kit

Patterns, ready-made AI prompts, and sample apps for building **approved internal tools inside Microsoft 365** — instead of on external AI app builders (Lovable, Bolt, v0, Replit, and similar). Your apps run in your own M365 tenant or on your own machine: sign-in is automatic, data stays inside your boundary, and there's a documented owner.

It gives end-user / citizen developers the same "describe it and watch it appear" experience as the external builders, constrained to a few well-supported patterns:

| You want to… | Pattern |
|---|---|
| Prototype an idea or a one-off tool/visualization | **Claude Artifacts** — describe it, see it run, inside your approved AI service |
| Build a team tool (forms, dashboards, trackers with shared data) | **SharePoint App** — runs in your M365 tenant; everyone signs in automatically; data lives in SharePoint Lists |
| Automate your own work (crunch files, generate reports, query databases) | **Packaged Python** — one single file colleagues run with a double-click; nothing to install; connects to data as *you* |
| Run scheduled/background automation with no server | **Worker Pool** — Packaged Python workers coordinated through SharePoint lists |

Each pattern ships a human guide and a copy-paste starter prompt that constrains the AI to the pattern's conventions.

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
