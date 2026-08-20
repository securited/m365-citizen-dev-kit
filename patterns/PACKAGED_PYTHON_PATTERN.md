# Building Applications with the Packaged Python Pattern

> **Packaged Python Pattern — v1.6** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A guide for building self-contained Python applications that run on the user's own computer — no server, no hosting, no installer, and no Python setup for the person receiving the app.

> **Starting a new app?** See [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md) for a complete prompt you can give Claude to constrain development to this pattern's conventions. Copy it as your first message when beginning a new project.

---

## Executive Summary

This pattern packages a complete application as a **single Python file** that anyone at your organization can run with one command. It relies on two pieces of modern Python tooling:

**uv** is a fast Python runtime and package manager. Once installed, `uv run app.py` downloads the right Python version, resolves dependencies, builds an isolated environment, and runs the script — automatically, on every machine, with zero manual setup.

**PEP 723 inline script metadata** lets the script declare its own Python version and dependencies in a comment block at the top of the file. The script **is** the project — no `requirements.txt`, no `pyproject.toml`, no virtual environment, nothing to install by hand.

Distribution is therefore just **copying a folder**. The recipient double-clicks `launch.cmd`, and the app runs. For a team, a SharePoint site plus a `version.json` makes a self-service release channel (see Distributing Your Application). Two app shapes are supported:

- **Pattern B — Script**: no UI; runs to completion and writes a file, sends an email, or updates a database. The default for automations, reports, and ETL-shaped work.
- **Pattern C — Streamlit app**: an interactive UI in the user's browser at localhost. For dashboards, multi-step forms, and anything that needs input mid-run.

**Identity is the user.** Database and Microsoft 365 access authenticate as the person running the app — their Windows session for on-prem servers, an Entra browser sign-in for cloud services. No service accounts, no passwords in connection strings, no secrets in files.

**IT supports exactly one stack.** Every job — HTTP, database, Excel, Graph, config, retries — has one approved library. This keeps every citizen app reviewable, predictable, and supportable by people who didn't write it.

---

## What This Pattern Is

The SharePoint App Pattern serves browser-based team tools; the Claude Artifacts pattern serves prototypes and one-off visuals. The Packaged Python pattern fills the third niche: **work that belongs on a local machine** — crunching files, moving data between systems, producing reports, automating a sequence a person currently does by hand.

It is a **citizen developer** tier. The person building the app may be technical; the person running it is not. Every design choice — single file, one launcher, zero install, one approved library per job — exists to keep the app simple enough to hand to a colleague and supportable by IT.

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

Because the metadata travels inside the file, the app cannot drift from its requirements — script and environment are one artifact.

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

No service accounts, no stored passwords anywhere in this pattern. Every external system authenticates as the person running the app:

- **SQL Server / Azure SQL** — on Entra-enabled servers, `Authentication=ActiveDirectoryInteractive` opens a browser sign-in through the normal Conditional Access flow; on on-prem domain servers (e.g. <your-sql-server-hostname>), `Trusted_Connection=yes` uses the Windows session directly.
- **Microsoft Graph and SharePoint REST** — `InteractiveBrowserCredential` with a persistent token cache; every app signs in through the shared, IT-owned **Contoso EUDA Applications** registration (see The Shared App Registration below).
- **The app inherits the user's permissions.** If the user can't read a table or site, neither can the app — a citizen app can never escalate anyone's access.

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

- **Data the app itself creates and owns** (state, results, shared team records) — **SharePoint Lists are the preferred store**, following the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.md). A SQL Server database is **not** the preferred home: provisioning tables and permissions requires DBA involvement, while any user at your organization can create a SharePoint site and lists self-service. See SharePoint Lists for App Data below.
- Reading or writing **existing SQL Server / Azure SQL data** — connect with the user's identity via `mssql-python`, using the user's existing database permissions. Use SQL Server to reach data that already lives there, not to store new app data.
- Reading **DB2** — never directly. Reach DB2 tables through the IT-managed SQL Server linked server, queried as SQL Server objects (or via `OPENQUERY` for pass-through).
- Reading or writing **M365 content** (mail, SharePoint, profiles) — Microsoft Graph through `msgraph-sdk`.
- Local scratch data — `sqlite3` + SQLAlchemy, stored under `%LOCALAPPDATA%\<appname>\`.

### SharePoint Lists for App Data

To persist the app's own data, use SharePoint Lists — columns are fields, items are rows, the REST API gives full OData querying, and lists auto-provision on first use. Everything the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.md) says about list design applies. From Python, call the list REST API with `httpx` and a Bearer token from the same Entra sign-in used for Graph:

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

Because requests authenticate with a Bearer token rather than browser cookies, the form digest is not required for writes. Reads and writes run as the user — if the user can't write to the list, neither can the app. The [Worker Pool Pattern](WORKER_POOL_PATTERN.md) is the reference implementation of this access path, including etag-conditioned writes and 429/503 backoff.

### The Shared App Registration

Interactive Entra sign-in (Graph, SharePoint REST) requires an app registration. IT has already created one, shared by all packaged Python apps — use it, never create your own:

| | |
|---|---|
| Display name | Contoso EUDA Applications |
| Client ID | `<your-entra-client-id>` |
| Tenant ID | `<your-tenant-id>` |
| Object ID | `<your-entra-object-id>` |
| Redirect URI | `http://localhost` |

**The common scopes are already consented — a typical app needs nothing from IT.** As of 2026-07-08 the registration is provisioned for the SharePoint list read/write path (verified against the live site) and common Microsoft Graph reads (profile, mail, calendar, presence). Build on those and there is no IT step.

**Releases never touch this registration.** The registration is tenant-side state keyed by the client ID; distributing a new `app.py` changes nothing in Entra, so shipping a release does not re-trigger any enterprise app registration process. The only event that involves IT is requesting a **delegated scope that has not yet been admin-consented** — a one-time grant per new scope (handled quickly), not per release. Keep the app on already-consented scopes and releases are entirely self-service.

### SQL Server Access

The `mssql-python` driver (Microsoft's official Python driver) ships its own binaries — no OLE DB or ODBC prerequisite on the machine. Use its DB-API interface directly, with the authentication that matches the server:

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

SQLAlchemy's `mssql+mssqlpython` dialect ships in **SQLAlchemy 2.1, which is still in beta** (as of June 2026). Until 2.1 is stable, query SQL Server through `mssql-python` directly as shown above; `sqlalchemy` remains the approved tool for local SQLite data.

SQL safety rules are absolute: use parameterized queries (`?` placeholders) — never build SQL with f-strings, `%` formatting, or concatenation. Never request elevated database roles; the app runs with whatever access the user already has.

### Streamlit Apps Bootstrap Themselves

`uv run streamlit run app.py` does **not** work with this pattern: when the run target is the `streamlit` command instead of the script, uv never reads the script's PEP 723 metadata, so no dependencies get installed. Instead, the script detects whether it is running under the Streamlit runtime and re-launches itself if not:

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
        # The file watcher exists to hot-reload the source while a developer
        # is editing it. A released app.py never changes while an operator is
        # running it, so the watcher has nothing to watch - and leaving it on
        # prints an "install the Watchdog module" nag at the end user.
        os.environ.setdefault("STREAMLIT_SERVER_FILE_WATCHER_TYPE", "none")

        # Newer Streamlit shows an in-app "Help agents write better apps /
        # Install the official Streamlit skills" dialog on any machine with an
        # AI coding agent installed. There is no config option for it - the
        # only supported switch is the marker file its own "Don't show again"
        # button writes, so write it. Best effort: never block startup.
        try:
            from streamlit.web import skills as _skills
            _skills.write_nudge_dismissed_marker()
        except Exception:
            try:
                marker = Path.home() / ".streamlit" / ".skills_nudge_dismissed"
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.touch(exist_ok=True)
            except OSError:
                pass

        print_banner()   # defined below; says how to stop the app

        from streamlit.web import cli as stcli
        sys.argv = ["streamlit", "run", sys.argv[0], "--server.address", "localhost"]
        sys.exit(stcli.main())
```

This keeps the launcher identical for both shapes — the canonical `launch.cmd` always ends in `uv run app.py`. The first-run hygiene block also gives end users a clean experience: no Streamlit email prompt, no usage telemetry, no Deploy button (which advertises Streamlit's external hosting service — not approved for company tools), no Watchdog nag, and no skills dialog. The server binds to localhost only; the user's Windows session is the authentication, so never build an in-app login.

Two of those deserve their reasoning, because the obvious fix for each is the wrong one.

**The file watcher goes off; `watchdog` does not go in.** Left on, every Pattern C app greets the user with `For better performance, install the Watchdog module:` followed by `xcode-select --install` and `pip install watchdog`. An end user reads that as "this app is missing something" and calls the Help Desk — and on a Mac it is an instruction to install the Xcode command line tools, which a citizen-tier app has no business suggesting to anyone. The tempting silencer is adding `watchdog` to the PEP 723 dependencies. Don't: the watcher exists to hot-reload the source file while a developer edits it, and a released `app.py` never changes while an operator is running it, so the watcher has nothing to watch. Adding the dependency would ship a package with native components to every operator's machine to service a developer feature that cannot fire in production. Turning the watcher off is smaller, more correct, and drops a polling thread as a side effect.

**The skills nudge is dismissed by writing its marker file.** Newer Streamlit builds show a dialog *inside the running app* — "Help agents write better apps / Install the official Streamlit skills," with **Install** and **Don't show again**. An operator opening an internal tool should not be offered a developer SDK, and it fires on any machine with an AI coding agent installed, so builders and anyone testing on a workstation hit it too. There is no config option: nothing in Streamlit's `config.py` matches `skill` or `nudge`. The only supported switch is the marker file that the dialog's own **Don't show again** button writes, so the app writes it at startup. The `write_nudge_dismissed_marker()` call is not documented public API and could move, which is why the fallback touches the marker path directly — the location is the stable part — and why both arms are wrapped so a failure can never block startup. Like the `credentials.toml` pre-seed it sits next to, this writes to the user's Streamlit directory and so applies to their whole Streamlit install, not just this app.

The terminal prints its own version of the skills recommendation, and that one is **not** gated on the marker — `web/bootstrap.py` checks only `server.headless`, `logger.hideWelcomeMessage`, and `are_skills_installed()`. Leave it. The only switch that would silence it is `logger.hideWelcomeMessage`, which also suppresses the `URL: http://localhost:8501` line; see the banner section below for why the app cannot reliably reprint that.

### The Launcher Says How to Stop the App

A Pattern C app keeps running after the browser tab is closed, and nothing in Streamlit's output says so. Print a banner before the runtime starts:

```
==================================================================
  CLAIMS RECONCILIATION   v1.2.0
==================================================================

  Starting up - this opens in your browser in a few seconds.

   TO STOP THE APP   press Ctrl-C here, or close this window.

  Closing the browser tab alone does NOT stop it.

==================================================================
```

Two details in the implementation are worth copying rather than rediscovering.

**Colour, but detect support first.** ANSI escapes make the stop instruction genuinely hard to miss, and a console that does not understand them prints the escape sequences at the operator, which is worse than no colour at all. Gate on `NO_COLOR` / `FORCE_COLOR`, then `sys.stdout.isatty()`, then — on Windows, where console virtual-terminal processing is off by default — a `SetConsoleMode(..., ENABLE_VIRTUAL_TERMINAL_PROCESSING)` call through `ctypes`, falling back to plain text if any of it fails. All stdlib: no `colorama`, and no `rich` (which this stack scopes to Pattern B anyway).

**ASCII only.** `cmd.exe` runs under a legacy code page, so box drawing characters come out as mojibake. `=` and `|` render identically everywhere.

The canonical `colour_supported()` and `print_banner()` implementations are in [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md).

**Do not suppress Streamlit's own startup output to make room for the banner.** The tempting next step is `logger.hideWelcomeMessage`, leaving the banner as the only thing on screen. It also suppresses the `URL: http://localhost:8501` line, and the app cannot reliably reprint that itself: `streamlit.config.get_option("server.port")` read before launch returns the built-in default and ignores both `STREAMLIT_SERVER_PORT` and `config.toml`, because the overlay happens later in `bootstrap.load_config_options`. Pinning the port in `sys.argv` to make the value knowable would break a real case — Streamlit already picks the next free port on its own, so a second instance comes up on 8502 unprompted where a pinned port would simply fail. The banner goes *before* Streamlit's output and Streamlit keeps printing the address; its handful of lines after the banner is a fair price for an accurate URL.

### Security Rules (Fixed)

- **No hardcoded secrets** — no passwords, API keys, or tokens in code or config. If a secret is unavoidable, store it with `keyring` (Windows Credential Manager).
- **No shell interpolation** — `subprocess` only in list form, never `shell=True`.
- **No runtime code download or execution** — nothing fetched gets `exec()`ed; no `pip install` calls from inside the app.
- **Writes stay in user space** — logs and temp files under `%LOCALAPPDATA%\<appname>\`, never system locations.
- **No regulated data in local files** — PHI, payment card data, and export-controlled material are out of scope for this tier; escalate to IT. **Ordinary personal data is fine**: names, email addresses, employee IDs, org structure, and business records appear in nearly every app here. Treat them as Internal — keep them under `%LOCALAPPDATA%`, don't mail the files around — and build the app.

---

## Project Layout

```
<app-name>/
  app.py        # the only Python file
  launch.cmd    # the canonical launcher — copy verbatim, never edit
  README.md     # what it does, who owns it, what data it touches
  HOW-TO-RUN.md # how to start and stop it, for the person running it
```

No `src/`, no `tests/`, no module split — unless the script exceeds ~500 lines with a clear reason. The `README.md` must name the app, its owner (name + email), its purpose, every data source it touches (databases, SharePoint sites, Graph scopes), and the date last reviewed. This is what makes the app supportable after its author changes roles.

### HOW-TO-RUN.md

`README.md` is written for the owner and the reviewer. None of it — data sources, Graph scopes, last-reviewed date — helps the non-technical colleague who was sent a folder and needs to open it. That is a different document, and every app ships one.

One page covers it:

- Double-click `launch.cmd` on Windows, and expect the first run to take a minute or two because it installs uv and downloads Python. Mention the SmartScreen prompt if the app is shared as a download.
- `brew install uv` once, then `uv run app.py`, on a Mac — `launch.cmd` is Windows-only.
- How to stop it: Ctrl-C or close the terminal window, and that closing the browser tab does not.
- Anything the user needs in hand before starting — a key from Keeper, a file to point at, a VPN connection.
- A short table of the errors they are most likely to hit and what each one means.

### The Canonical Launcher

`launch.cmd` is the same file in every app — copy it verbatim, never modify it. It finds uv on the machine, installs it if missing (winget first, the official installer as fallback — both user-space, no admin), then runs the app:

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

Why it works this way: a freshly installed uv is not on the *current* session's PATH, so the launcher calls it by its known install location; winget comes first because it installs a Microsoft-validated, signed package; both paths are user-space. Because every app ships the identical file, reviewing a launcher means diffing it against this canonical text — any difference is a defect.

---

## Distributing Your Application

- There are **no prerequisites** for the recipient — not even uv. The canonical `launch.cmd` installs uv automatically on first run (user-space, no admin) before running the app.
- Share the app folder however files normally move — SharePoint, Teams, a network share.
- The recipient double-clicks `launch.cmd`. First run: uv is installed if missing, the environment is provisioned, and a browser window may open for sign-in. Every run after that is instant and silent.
- Updates are just a new copy of `app.py` — because dependencies live inside the file, there is nothing else to synchronize.

### Team Distribution: a SharePoint Site as the Release Channel

Ad-hoc copying works for one colleague; for a *team* it drifts — nobody knows which copy is current. Use a SharePoint site as the single distribution point:

- **Site creation is open at your organization** — any user can create a SharePoint site, no ticket required. From the SharePoint home page ([contoso.sharepoint.com/_layouts/15/sharepoint.aspx](https://contoso.sharepoint.com/_layouts/15/sharepoint.aspx)) → **+ Create site**, pick a **Communication site** with the **Blank** template — not a Team site. A communication site is built for broadcasting to a broad audience (a few publish, many consume), which is the shape of a release channel; a Team site spins up an M365 group, shared mailbox, and Teams membership you don't need. Put the release folder (`app.py`, `launch.cmd`, `README.md`, `HOW-TO-RUN.md`) in a document library. (Reuse the team's existing site if one already fits.)
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
- **Publishing a release is uploading files** — a new `app.py` plus an updated `version.json`. This never touches Entra (see The Shared App Registration), so releases are entirely self-service.
- **This pairs with the [Worker Pool Pattern](WORKER_POOL_PATTERN.md)**: the same SharePoint site that hosts the pool's coordination lists and status page can host the worker's distributable and `version.json`, and the worker's dashboard can surface "a newer version is available" so the whole pool converges on the current release.

---

## Out of Scope — Stop and Escalate

If a requirement includes any of these, the app needs IT-supported hosting, not the citizen tier:

- Scheduled or unattended execution (Task Scheduler, services, cron-style runs)
- Listening sockets, webhooks, or any inbound network exposure
- Multi-user concurrent writes beyond what SharePoint Lists or SQL handle natively
- Data classified above Internal — PHI, payment data, any regulated data
- Distribution outside your organization
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
| Layout | `app.py` + `launch.cmd` + `README.md` + `HOW-TO-RUN.md` — nothing else |
| Anything unattended, networked, or regulated | Stop and escalate to IT |
