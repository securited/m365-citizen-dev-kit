# Building Applications with the Packaged Python Pattern

> **Packaged Python Pattern — v1.2** · updated 2026-07-06. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

A guide for building self-contained Python applications that run on the user's own computer — no server, no hosting, no installer, and no Python setup for the person receiving the app.

> **Starting a new app?** See [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md) for a complete prompt you can give Claude to constrain development to this pattern's conventions. Copy it as your first message when beginning a new project.

---

## Executive Summary

This pattern packages a complete application as a **single Python file** that anyone at Contoso can run with one command. It relies on two pieces of modern Python tooling:

**uv** is a fast Python runtime and package manager. Once installed on a machine, `uv run app.py` downloads the right Python version, resolves the app's dependencies, builds an isolated environment, and runs the script — automatically, on every machine, with zero manual setup.

**PEP 723 inline script metadata** lets the script declare its own Python version and dependencies in a comment block at the top of the file. The script **is** the project — there is no `requirements.txt`, no `pyproject.toml`, no virtual environment to manage, and nothing to install by hand.

Together these mean distribution is just **copying a folder**. The recipient double-clicks `launch.cmd`, and the app runs. For a team of users, a SharePoint site plus a `version.json` makes a self-service release channel (see Distributing Your Application). Two app shapes are supported:

- **Pattern B — Script**: no UI; runs to completion and writes a file, sends an email, or updates a database. The default for automations, reports, and ETL-shaped work.
- **Pattern C — Streamlit app**: an interactive UI in the user's browser at localhost. For dashboards, multi-step forms, and anything that needs input mid-run.

**Identity is the user.** Database and Microsoft 365 access authenticate as the person running the app — their Windows session for on-prem servers, an Entra browser sign-in for cloud services. There are no service accounts, no passwords in connection strings, and no secrets in files.

**IT supports exactly one stack.** Every job — HTTP, database, Excel, Graph, config, retries — has one approved library. This keeps every citizen app reviewable, predictable, and supportable by people who didn't write it.

---

## What This Pattern Is

The SharePoint App Pattern serves browser-based team tools; the Claude Artifacts pattern serves prototypes and one-off visuals. The Packaged Python pattern fills the third niche: **work that belongs on a local machine** — crunching files, moving data between systems, producing reports, automating a sequence of steps a person currently does by hand.

It is a **citizen developer** tier. The person building the app may be technical; the person running it is not. Everything about the pattern — single file, one launcher, zero install, one approved library per job — exists to keep the app simple enough to hand to a colleague and supportable by IT.

---

## Core Concepts

### One File, Zero Install

Every app is one Python file with its requirements declared inline at the top:

```python
# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "pandas",
#   "openpyxl",
# ]
# ///
```

When the user runs `uv run app.py` (or double-clicks `launch.cmd`, which contains exactly that command), uv reads this block, provisions Python 3.12 if needed, installs the dependencies into a cached, isolated environment, and executes the script. The first run takes a few seconds longer; subsequent runs start instantly from cache.

Because the metadata travels inside the file, the app cannot drift from its requirements — the script and its environment are one artifact.

### Two App Shapes

Pick exactly one shape per app — never both in the same file. (There is no "Pattern A" in this guide — that slot belongs to the browser-based [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.md); the lettering is shared across the platform's pattern family.)

| Aspect | Pattern B — Script | Pattern C — Streamlit |
|---|---|---|
| UI | None — runs to completion | Browser UI at localhost |
| Best for | Automations, reports, ETL | Dashboards, forms, interactive tools |
| Output | Files, emails, database writes | On-screen, plus files/database |
| Terminal polish | Optional `rich` progress/output | n/a |
| Launcher | canonical `launch.cmd` | canonical `launch.cmd` (script self-bootstraps Streamlit — see below) |

### Identity Is the User

There are no service accounts and no stored passwords anywhere in this pattern. Every external system authenticates as the person running the app:

- **SQL Server / Azure SQL** — on Entra-enabled servers, `Authentication=ActiveDirectoryInteractive` opens a browser sign-in through the normal Conditional Access flow; on on-prem domain servers (e.g. <your-sql-server-hostname>), `Trusted_Connection=yes` uses the Windows session directly. Both authenticate as the person running the app.
- **Microsoft Graph and SharePoint REST** — `InteractiveBrowserCredential` with a persistent token cache; every app signs in through the shared, IT-owned **Contoso EUDA Applications** registration (see The Shared App Registration below).
- **The app inherits the user's permissions.** If the user can't read a table or site, neither can the app. This is a feature: a citizen app can never escalate anyone's access.

### One Approved Library Per Job

| Purpose | Library |
|---|---|
| HTTP client | `httpx` |
| ORM (local SQLite data) | `sqlalchemy` |
| SQL Server driver | `mssql-python` (used directly — see SQL Server Access) |
| DB2 access | SQL Server linked server only |
| SharePoint Lists (app-owned data — preferred store) | `httpx` + `azure-identity` Bearer token |
| Local DB | `sqlite3` (stdlib) + `sqlalchemy` |
| Tabular data | `pandas` |
| Excel | `openpyxl` |
| Word | `python-docx` |
| PDF read | `pypdf` |
| Microsoft Graph | `msgraph-sdk` + `azure-identity` |
| UI (Pattern C only) | `streamlit` |
| Terminal output (Pattern B, optional) | `rich` |
| Config / validation | `pydantic` + `pydantic-settings` |
| Secrets | `keyring` (Windows Credential Manager) |
| Logging, dates, paths | stdlib: `logging`, `datetime` + `zoneinfo`, `pathlib` |
| HTTP retries / backoff | `tenacity` |

If a job isn't covered, ask before adding a library. The full prohibited list (with the approved replacement for each) is in the [project prompt](PACKAGED_PYTHON_PROMPT.md).

---

## Designing Your Application

### Start With the Data Path

Before writing code, answer: where does the data live, and where do the results go?

- **Data the app itself creates and owns** (state, results, shared team records) — **SharePoint Lists are the preferred store**, following the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.md). A SQL Server database is **not** the preferred home for app-owned data: provisioning tables and permissions requires DBA involvement, while any Contoso user can create a SharePoint site and lists today, self-service. See SharePoint Lists for App Data below.
- Reading or writing **existing SQL Server / Azure SQL data** — connect with the user's identity via `mssql-python`; the app uses the user's existing database permissions. Use SQL Server to reach data that already lives there, not to store new app data.
- Reading **DB2** — never directly. DB2 tables are reached through the IT-managed SQL Server linked server, queried as if they were SQL Server objects (or via `OPENQUERY` for pass-through).
- Reading or writing **M365 content** (mail, SharePoint, profiles) — Microsoft Graph through `msgraph-sdk`.
- Local scratch data — `sqlite3` + SQLAlchemy, stored under `%LOCALAPPDATA%\<appname>\`.

### SharePoint Lists for App Data

When the app needs to persist its own data, use SharePoint Lists — columns are fields, items are rows, the REST API gives full OData querying, and lists auto-provision on first use. Everything the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.md) says about list design applies. From Python, call the list REST API with `httpx` and a Bearer token from the same Entra sign-in used for Graph:

```python
from azure.identity import InteractiveBrowserCredential, TokenCachePersistenceOptions
import httpx

credential = InteractiveBrowserCredential(
    tenant_id="<your-tenant-id>",
    client_id="<your-entra-client-id>",  # Contoso EUDA Applications
    cache_persistence_options=TokenCachePersistenceOptions(name="<appname>"),
)
token = credential.get_token("https://contoso.sharepoint.com/.default")

site = "https://contoso.sharepoint.com/sites/<your-site>"
headers = {
    "Authorization": f"Bearer {token.token}",
    "Accept": "application/json;odata=nometadata",
}
items = httpx.get(
    f"{site}/_api/web/lists/getbytitle('MyList')/items?$top=100",
    headers=headers,
).json()["value"]
```

Because requests authenticate with a Bearer token rather than browser cookies, the form digest is not required for writes. Reads and writes run as the user — if the user can't write to the list, neither can the app. The [Worker Pool Pattern](WORKER_POOL_PATTERN.md) is the reference implementation of this access path, including etag-conditioned writes and 429/503 backoff etiquette.

### The Shared App Registration

Interactive Entra sign-in (Graph, SharePoint REST) requires an app registration. IT has already created one, shared by all packaged Python apps — use it; never create your own:

| | |
|---|---|
| Display name | Contoso EUDA Applications |
| Client ID | `<your-entra-client-id>` |
| Tenant ID | `<your-tenant-id>` |
| Object ID | `<your-entra-object-id>` |
| Redirect URI | `http://localhost` |

**Releases never touch this registration.** The registration is tenant-side state keyed by the client ID; distributing a new `app.py` changes nothing in Entra, so shipping a release does not re-trigger any enterprise app registration process. The only event that involves IT is requesting a **delegated scope that has not yet been admin-consented** — a one-time grant per new scope (handled quickly), not per release. Keep the app on already-consented scopes and releases are entirely self-service.

### SQL Server Access

The `mssql-python` driver (Microsoft's official Python driver) ships its own driver binaries — no OLE DB or ODBC prerequisite on the machine. Use its DB-API interface directly, with the authentication that matches the server:

```python
from mssql_python import connect

# Entra-enabled servers (Azure SQL, Entra-joined SQL Server) — browser sign-in:
conn = connect(
    "Server=<sql-server-hostname>;Database=<database>;Encrypt=yes;"
    "Authentication=ActiveDirectoryInteractive"
)

# On-prem SQL Server on the corporate domain — the Windows session is the identity:
conn = connect(
    "Server=<sql-server-hostname>;Database=<database>;Encrypt=yes;"
    "Trusted_Connection=yes"
)

cur = conn.cursor()
cur.execute("SELECT ... FROM dbo.Orders WHERE StatusId = ?", [status_id])
```

Add `TrustServerCertificate=yes` only for servers with self-signed certificates (common on dev servers); omit it in production.

A note on SQLAlchemy: its `mssql+mssqlpython` dialect ships in **SQLAlchemy 2.1, which is still in beta** (as of June 2026). Until 2.1 is stable, query SQL Server through `mssql-python` directly as shown above; `sqlalchemy` remains the approved tool for local SQLite data.

SQL safety rules are absolute: use parameterized queries (`?` placeholders) — never build SQL with f-strings, `%` formatting, or concatenation. Never request elevated database roles; the app runs with whatever access the user already has.

### Streamlit Apps Bootstrap Themselves

A subtle but critical detail: `uv run streamlit run app.py` does **not** work with this pattern. When the run target is the `streamlit` command instead of the script, uv never reads the script's PEP 723 metadata, so no dependencies get installed. Instead, the script detects whether it is running under the Streamlit runtime and re-launches itself if not:

```python
if __name__ == "__main__":
    from streamlit import runtime
    if runtime.exists():
        main()
    else:
        import os
        import sys
        from pathlib import Path

        # First-run hygiene before the Streamlit runtime starts: pre-seed
        # credentials.toml so end users never see the "Welcome / Email:"
        # prompt, send no usage telemetry, and hide the Deploy button and
        # developer menu items (Streamlit Community Cloud is not approved).
        creds = Path.home() / ".streamlit" / "credentials.toml"
        if not creds.exists():
            creds.parent.mkdir(parents=True, exist_ok=True)
            creds.write_text('[general]\nemail = ""\n', encoding="utf-8")
        os.environ.setdefault("STREAMLIT_BROWSER_GATHER_USAGE_STATS", "false")
        os.environ.setdefault("STREAMLIT_CLIENT_TOOLBAR_MODE", "viewer")

        from streamlit.web import cli as stcli
        sys.argv = ["streamlit", "run", sys.argv[0], "--server.address", "localhost"]
        sys.exit(stcli.main())
```

This keeps the launcher identical for both shapes — the canonical `launch.cmd` always ends in `uv run app.py`. The first-run hygiene block also gives end users a clean experience out of the box: no Streamlit email prompt, no usage telemetry, and no Deploy button (which advertises Streamlit's external hosting service — not approved for company tools). The server binds to localhost only; the user's Windows session is the authentication, so never build an in-app login.

### Security Rules

- **No hardcoded secrets** — no passwords, API keys, or tokens in code or config. If a secret is unavoidable, store it with `keyring` (Windows Credential Manager).
- **No shell interpolation** — `subprocess` only in list form, never `shell=True`.
- **No runtime code download or execution** — nothing fetched gets `exec()`ed; no `pip install` calls from inside the app.
- **Writes stay in user space** — logs and temp files under `%LOCALAPPDATA%\<appname>\`, never system locations.
- **No PII or PHI in local files** — regulated data is out of scope for this tier entirely; escalate.

---

## Project Layout

```
<app-name>/
  app.py        # the only Python file
  launch.cmd    # the canonical launcher — copy verbatim, never edit
  README.md     # what it does, who owns it, what data it touches
```

No `src/`, no `tests/`, no module split — unless the script exceeds ~500 lines with a clear reason. The `README.md` must name the app, its owner (name + email), its purpose, every data source it touches (databases, SharePoint sites, Graph scopes), and the date last reviewed. This file is what makes the app supportable after its author changes roles.

### The Canonical Launcher

`launch.cmd` is the same file in every app — copy it verbatim and never modify it. It finds uv on the machine, installs it if missing (winget first, the official installer as fallback — both user-space, no admin), and then runs the app:

```
@echo off
setlocal
cd /d "%~dp0"

rem EUDA canonical launcher - copy verbatim, do not edit.
rem Finds uv, installs it if missing (no admin needed), then runs the app.
set "UV=uv"
where uv >nul 2>nul && goto :run
if exist "%USERPROFILE%\.local\bin\uv.exe" set "UV=%USERPROFILE%\.local\bin\uv.exe" && goto :run
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" set "UV=%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" && goto :run

echo uv is not installed - installing now (one-time, no admin needed)...
winget install --id=astral-sh.uv -e --silent --accept-source-agreements --accept-package-agreements
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" set "UV=%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" && goto :run
where uv >nul 2>nul && goto :run

echo winget install did not succeed - trying the official installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
if exist "%USERPROFILE%\.local\bin\uv.exe" set "UV=%USERPROFILE%\.local\bin\uv.exe" && goto :run

echo Could not install uv automatically. Ask IT to install "uv" from the software catalog.
pause
exit /b 1

:run
"%UV%" run app.py
```

Why it works this way: a freshly installed uv is not on the *current* session's PATH, so the launcher calls it by its known install location; winget comes first because it installs a Microsoft-validated, signed package; both install paths are user-space. Because every app ships the identical file, reviewing a launcher means diffing it against this canonical text — any difference is a defect.

---

## Distributing Your Application

- There are **no prerequisites** for the recipient — not even uv. The canonical `launch.cmd` installs uv automatically on first run (user-space, no admin) before running the app.
- Share the app folder however files normally move — SharePoint, Teams, a network share.
- The recipient double-clicks `launch.cmd`. First run: uv is installed if missing, the environment is provisioned, and a browser window may open for sign-in. Every run after that is instant and silent.
- Updates are just a new copy of `app.py` — because dependencies live inside the file, there is nothing else to synchronize.

### Team Distribution: a SharePoint Site as the Release Channel

Ad-hoc copying works for handing an app to one colleague; for a *team* of users it drifts — nobody knows which copy is current. The fix is a SharePoint site as the single distribution point:

- **Site creation is open at Contoso** — any user can create a SharePoint site, no ticket required. Create one (or reuse the team's existing site), and put the release folder (`app.py`, `launch.cmd`, `README.md`) in a document library.
- **Publish a `version.json` alongside the folder** so both people and the app itself can tell what's current:

```json
{
  "version": "1.3.0",
  "released": "2026-07-02",
  "notes": "Adds the export tab",
  "url": "https://contoso.sharepoint.com/sites/<your-site>/Shared%20Documents/my-app"
}
```

- **The app checks `version.json` at startup** — one `httpx` GET with the same Bearer token used for list access, compared against a `__version__` constant in `app.py`. If a newer release exists, tell the user and point them at the download URL. Keep the check non-blocking: if the site is unreachable, log it and run anyway.
- **Publishing a release is just uploading files** — a new `app.py` plus an updated `version.json`. This never touches Entra (see The Shared App Registration), so releases are entirely self-service.
- **This pairs naturally with the [Worker Pool Pattern](WORKER_POOL_PATTERN.md)**: the same SharePoint site that hosts the pool's coordination lists and status page can host the worker's distributable and `version.json`, and the worker's dashboard can surface "a newer version is available" so the whole pool converges on the current release.

---

## Out of Scope — Stop and Escalate

If a requirement includes any of these, the app needs IT-supported hosting, not the citizen tier:

- Scheduled or unattended execution (Task Scheduler, services, cron-style runs)
- Listening sockets, webhooks, or any inbound network exposure
- Multi-user concurrent writes beyond what SharePoint Lists or SQL handle natively
- Data classified above Internal — PHI, payment data, any regulated data
- Distribution outside Contoso
- Modifying Active Directory, Entra ID, or Intune state

---

## What This Pattern Is Good For

- **File crunching** — merge, clean, split, and reshape Excel/CSV files that are painful by hand
- **Report generation** — query SQL Server, produce a formatted Excel or Word deliverable
- **Data movement** — pull from one system, transform, write to another, on demand
- **Personal dashboards** — a Streamlit view over data the user already has access to
- **Interactive utilities** — lookup tools, calculators, guided multi-step processes
- **One-person automations** — replacing a manual sequence someone runs at their desk

## What It Is Not Good For

- Anything that must run while no one is at the keyboard (scheduled jobs need IT hosting)
- Tools serving many simultaneous users (use the SharePoint App Pattern or IT hosting)
- Anything reachable from the network (no webhooks, no APIs, no listening ports)
- Regulated data — PHI, payment data (out of scope for the citizen tier)
- Long-lived shared state (persistent state belongs in SharePoint Lists — preferred — or an existing SQL Server database)

---

## Quick Reference

| Need | Use |
|---|---|
| Run the app | double-click `launch.cmd` (canonical launcher — installs uv if missing) or `uv run app.py` |
| Declare dependencies | PEP 723 block at the top of `app.py` — nowhere else |
| Python version | 3.12 only: `requires-python = ">=3.12,<3.13"` |
| App-owned persistent data | SharePoint Lists (preferred — not a SQL Server database), via `httpx` + Bearer token |
| SQL Server | `mssql-python` directly, as the signed-in user — `Authentication=ActiveDirectoryInteractive` (Entra) or `Trusted_Connection=yes` (on-prem); for existing data, not app storage |
| SQLAlchemy + SQL Server | not yet — the `mssql+mssqlpython` dialect needs SQLAlchemy 2.1 (beta); `sqlalchemy` is for local SQLite |
| DB2 data | SQL Server linked server / `OPENQUERY` — never IBM drivers |
| Graph / M365 | `msgraph-sdk` + `InteractiveBrowserCredential` with persistent token cache |
| Entra app registration | shared **Contoso EUDA Applications** — client `<your-entra-client-id>`, tenant `<your-tenant-id>`, redirect `http://localhost`; never create your own |
| Team distribution | SharePoint site as the release channel + `version.json` — releases never touch Entra |
| UI | `streamlit`, localhost only, self-bootstrapping launcher |
| Secrets | `keyring` — never in code, config, or connection strings |
| Logs and temp files | `%LOCALAPPDATA%\<appname>\` |
| Layout | `app.py` + `launch.cmd` + `README.md` — nothing else |
| Anything unattended, networked, or regulated | Stop and escalate to IT |
