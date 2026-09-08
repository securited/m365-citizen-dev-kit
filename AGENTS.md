# M365 Citizen Dev Kit

A kit of **development patterns, ready-made AI prompts, and sample apps** for building approved internal tools inside Microsoft 365 — instead of on external AI app builders (Lovable, Bolt, v0, etc.). Apps run inside the organization's M365 tenant or on the user's own machine. Content is Markdown guides, HTML/JavaScript SharePoint shells (`.aspx`), single-file Python apps (PEP 723), and PowerShell deploy tooling.

This file is the **canonical AI context** for the repo. `CLAUDE.md` imports it via `@AGENTS.md`; any other tool/pointer file must carry **no unique content** — update this file only.

> **Status:** This repo is the public, de-branded version of a private internal platform; content was ported per [docs/anonymization-plan.md](docs/anonymization-plan.md). All org-specific identifiers use Contoso placeholders. It is published at https://github.com/securited/m365-citizen-dev-kit — the anonymization scan (`deploy/Test-Anonymization.ps1`) is an ongoing gate: run it before every push.

## Folder map

| Path | Purpose | Published? |
|---|---|---|
| `README.md`, `AGENTS.md`, `CLAUDE.md` | Front door + canonical AI context | n/a |
| `patterns/` | One set per pattern: guide (`*_PATTERN.md`), starter prompt (`*_PROMPT.md`), published SharePoint page (`*_PATTERN.aspx`). Four core patterns (SharePoint App, Claude Artifacts, Packaged Python, Worker Pool) + two supporting (SharePoint Permissions & Auditing, Storage Shape & Lifecycle). Plus the hub `DEVELOPMENT_PATTERNS.aspx` and its `DEVELOPMENT_PATTERNS_data/` (`samples.json`, `versions.json`) | Yes — to a SharePoint library |
| `samples/` | Sample apps: SharePoint `.aspx` demos + `_data/` companions, and single-file Python apps (`app.py` + `launch.cmd` + `README.md`), incl. the `migrate-existing-app` example | Yes |
| `deploy/` | `Deploy-SampleLibrary.ps1` syncs `patterns/` + `samples/` to a SharePoint document library; `Test-Anonymization.ps1` is the pre-push anonymization gate | No |
| `.claude/` | Local dev: `serve.ps1` static preview server, `launch.json` run configs | No |
| `docs/` | Human docs, plans, and ADRs (`docs/decisions/`) | No |

Hard rules: this is a **public** repo — never commit a real tenant URL, owner email, Entra client-id, internal hostname, or business data. Use the Contoso placeholders defined in [docs/anonymization-plan.md](docs/anonymization-plan.md). Never add secrets to any file (see below).

## Commands

```powershell
# Anonymization gate — run before EVERY push to the public remote; non-zero exit = do not push
pwsh -NoProfile -File deploy/Test-Anonymization.ps1

# Preview SharePoint .aspx + _data shells locally (static server; serves repo root)
pwsh -NoProfile -File .claude/serve.ps1 -Port 7432

# Run a single-file Python sample (zero install; uses uv)
uv run samples/<app>/app.py

# Deploy patterns + samples to a SharePoint library (dry run first; needs PNP_CLIENT_ID)
deploy/Deploy-SampleLibrary.ps1 -WhatIf
```

`Test-Anonymization.ps1` scans every **git-tracked** file and has two halves. Structural detectors live in the script and flag the *shape* of a leaked identifier — a `*.sharepoint.com` host outside the placeholder set, an email outside the placeholder domains, a GUID (Entra client-id shape), a connection-string host that isn't a placeholder, and files that must never be tracked (`.DS_Store`, `Thumbs.db`, `.claude/settings.local.json`, anything under `.private/` or `.obsidian/`). The second half greps a literal org-token list at `.private/org-markers.txt` — one regex per line, gitignored, kept only in the maintainer's private runbook, never in this public repo. Exit **0** = clean, **1** = findings (fix before pushing), **2** = gate incomplete because the marker list is missing; pass `-NoMarkerFile` to accept a structural-only scan deliberately.

The deploy script ships **no** built-in Entra app id — pass `-PnPClientId <guid>` or set `PNP_CLIENT_ID`. `.aspx` shell uploads need a custom-script enablement window (24h, the script opens it); `_data/` file updates do not.

## Generated and do-not-touch files

| File | Rule |
|---|---|
| `samples/euda-worker_data/latest.json` | Local first-run **seed**; the deployed SharePoint copy is live runtime data. The deploy script treats it as seed-only — never overwrite on deploy. |
| Inlined minified Chart.js inside `samples/exec-summary.aspx` | Vendored — do not reformat or hand-edit. |

No build-generated files. If a section is empty after a change, state "None".

## Conventions (required)

- **Public + anonymized.** All org-specific identifiers are Contoso placeholders (`contoso.sharepoint.com` / `Contoso` / `<your-...>`). Before **every** push, run `pwsh -NoProfile -File deploy/Test-Anonymization.ps1`; it must exit 0. Never fix a finding by widening the script's allowlists — replace the identifier with a placeholder.
- **Shell + Data (SharePoint apps)** — the `.aspx` shell holds **boot logic only** (asset loading, canonical helpers, loading/error UI) and no feature code or app state; there is no size limit, but reference shells weigh ~6–8 KB and past ~15 KB logic has leaked in. Feature code, CSS, HTML, and JSON live in `<app>_data/`, so most updates avoid the custom-script enablement window. Each `.aspx` fetches its companion files from its own library folder (`PAGE_DIR`-relative), so a page and its `_data/` must stay co-located.
- **Module manifest (SharePoint apps)** — feature modules are listed in `<app>_data/manifest.json` and loaded in order by `app.js`; `FALLBACK_MODULES` in `app.js` must match that list exactly, and every named module must exist on disk (the deploy script pre-flights this). Adding a module = edit the manifest + upload the file; the shell never changes.
- **One folder per Python app** — exactly `app.py` (PEP 723 header), `launch.cmd` (canonical launcher, copied verbatim), `README.md` (owner, pattern, last-reviewed date). Dependencies declared only in the PEP 723 block.
- **Pattern versioning** — `patterns/DEVELOPMENT_PATTERNS_data/versions.json` is the single source of truth for pattern versions; each `*_PATTERN.md`/`*_PROMPT.md` carries a synced version header. Dual-bump in the same commit when a pattern changes.
- **No secrets, ever** — these files are committed, loaded into AI context, and synced to model providers. No passwords, keys, tokens, or internal URLs. Identity is the running user (Windows session / Entra sign-in); reference a secret store, never embed.

## Deeper docs

| Doc | When to read |
|---|---|
| [docs/anonymization-plan.md](docs/anonymization-plan.md) | How this kit was de-branded for publication: the Contoso naming convention, what was excluded/replaced, and the contributor rules |
| [docs/README.md](docs/README.md) | Index of project documentation |
| [docs/decisions/](docs/decisions/) | Why structural/publication decisions were made |
