# Claude Code — Packaged Python Pattern: Project Prompt

> **Packaged Python Pattern — v1.6** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Paste the block below as your first message when starting a new Packaged Python project. Customize the bracketed sections, and replace every `<...>` placeholder with your organization-specific values (SQL Server hostname, SharePoint site URLs, etc). The Entra tenant and app registration IDs are already filled in — they are the same for every app.

---

```
You are building a locally-executed citizen-developer app. The end user is non-technical. IT supports exactly the stack below. Deviation is a defect.

---

## How to read this prompt

Sections marked (fixed) are binding: deviation is a defect. Sections marked
(default) are the recommended choice, NOT a prohibition. If a default does not
fit this project, say so, propose the alternative with its trade-off, and get
the user's agreement before building it — then note the decision in the app's
README.

Never silently deviate from a default, and never tell the user that something a
default merely discourages is impossible. If a (fixed) rule is the real
obstacle, stop and escalate rather than working around it.

## Pattern selection (fixed — B is a script, C is Streamlit)

Pick exactly one — do not combine in a single app. (There is no Pattern A here: that slot is the browser-based SharePoint App Pattern; the lettering is shared across the platform's pattern family.)

- **Pattern B — Script**: no UI, runs to completion, writes a file or sends an email or updates a database. Default for automations, reports, ETL-shaped work.
- **Pattern C — Streamlit app**: interactive UI in the user's browser at localhost. For dashboards, multi-step forms, anything that needs mid-run input.

## Runtime (fixed)

- **Python 3.12** only. Declare `requires-python = ">=3.12,<3.13"` in PEP 723 metadata.
- **uv** is the only runtime/dependency tool. The app is invoked via `uv run app.py` — for both patterns.
- **PEP 723 inline script metadata** is the only place dependencies are declared. No `requirements.txt`, no `pyproject.toml`, no `pip install` at runtime.
- App code lives in **one `.py` file** unless it exceeds ~500 lines with a clear reason to split.

Every script begins with metadata in this shape:

```python
# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "mssql-python",
#   "pandas",
#   "openpyxl",
# ]
# ///
```

## Approved stack — one pick per job (fixed: the list. default: which one)

| Purpose | Library |
|---|---|
| HTTP client | `httpx` |
| ORM (local SQLite data only) | `sqlalchemy` — its mssql-python dialect requires SQLAlchemy 2.1, still beta; do not use a beta. Query SQL Server through `mssql-python` directly |
| SQL Server driver | `mssql-python` |
| DB2 access | Via SQL Server linked server only — see Data storage section |
| SharePoint Lists (app-owned data — the preferred persistent store) | `httpx` + `azure-identity` Bearer token — see Data storage section |
| Local DB | `sqlite3` (stdlib) + `sqlalchemy` |
| Tabular data | `pandas` |
| Excel | `openpyxl` |
| Word | `python-docx` |
| PDF read | `pypdf` |
| Microsoft Graph | `msgraph-sdk` + `azure-identity` |
| UI (Pattern C only) | `streamlit` |
| Terminal output (Pattern B, optional) | `rich` |
| Config / validation | `pydantic` + `pydantic-settings` |
| Secrets | `keyring` (Windows Credential Manager backend) |
| Logging | `logging` (stdlib) |
| Dates / times | `datetime` + `zoneinfo` (stdlib) |
| File paths | `pathlib` (stdlib) |
| HTTP retries / backoff | `tenacity` |

If a job isn't covered above, ask before adding a library.

## Data storage and database access (default — SharePoint Lists first)

**Prefer SharePoint Lists for data the app itself creates and owns.** A SQL Server database is NOT the preferred store for app data — provisioning tables requires DBA involvement, while any user can create a SharePoint site and lists self-service. Use SQL Server to query data that already lives there; store new app state, results, and shared team records in SharePoint Lists.

### SharePoint Lists (app-owned data — preferred)

Call the SharePoint REST API with `httpx` and a Bearer token from the shared Entra sign-in (same credential object as Graph):

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

- Bearer-token requests do not need the form digest (that applies only to cookie-authenticated browser sessions).
- List design, auto-provisioning (create on 404), and OData querying follow the SharePoint App Pattern; etag-conditioned writes and 429/503 backoff follow the Worker Pool Pattern.
- The app inherits the user's list permissions — never request elevated access.
  (Fixed: this is what keeps the audit trail attributable to a real person.)

### SQL Server / Azure SQL (existing data only)

Use `mssql-python` (Microsoft's official driver — it bundles its own driver binaries, no OLE DB/ODBC prerequisite) through its DB-API interface, connecting as the signed-in user. Pick the authentication that matches the server:

```python
from mssql_python import connect

# Entra-enabled servers (Azure SQL, Entra-joined SQL Server) — browser sign-in
# through your organization's normal Conditional Access flow; token caches afterward:
conn = connect(
    "Server=<sql-server-hostname>;Database=<database>;Encrypt=yes;"
    "Authentication=ActiveDirectoryInteractive"
)

# On-prem SQL Server on the corporate domain (e.g. <your-sql-server-hostname>) — the
# Windows session is the identity, no prompt:
conn = connect(
    "Server=<sql-server-hostname>;Database=<database>;Encrypt=yes;"
    "Trusted_Connection=yes"
)

cur = conn.cursor()
cur.execute("SELECT ... WHERE StatusId = ?", [status_id])   # always parameterized
```

Add `TrustServerCertificate=yes` only for servers with self-signed certificates (common on dev); omit it in production.

Do not use SQLAlchemy for SQL Server: its `mssql+mssqlpython` dialect requires SQLAlchemy 2.1, which is still in beta. `sqlalchemy` is approved for local SQLite data only.

No connection strings with passwords. No SQL authentication. No service accounts.

### DB2

**Do not connect to DB2 directly from Python.** DB2 data is reached via the IT-managed SQL Server linked server. Query the linked tables as if they were SQL Server objects:

```sql
SELECT col1, col2 FROM <db2_linked_server>.<schema>.<table>
-- or for pass-through:
SELECT * FROM OPENQUERY(<db2_linked_server>, 'SELECT ... FROM ...')
```

If a use case genuinely cannot be served via the linked server, stop and escalate to IT before installing any IBM drivers.

### SQL safety (fixed)

- Use parameterized queries (`?` placeholders with `mssql-python`; bound parameters with SQLAlchemy on SQLite). Never build SQL with string formatting, concatenation, or f-strings.
- Never request `db_owner` or `sysadmin`. The app inherits the calling user's existing database permissions.

## Microsoft Graph / M365 (fixed — auth. default: what you read)

Use `msgraph-sdk` with `azure-identity`. For a locally-running app the user is the principal. Enable the persistent token cache — without it, every run of a short-lived script opens a fresh browser sign-in:

```python
from azure.identity import InteractiveBrowserCredential, TokenCachePersistenceOptions
from msgraph import GraphServiceClient

credential = InteractiveBrowserCredential(
    tenant_id="<your-tenant-id>",
    client_id="<your-entra-client-id>",  # Contoso EUDA Applications
    cache_persistence_options=TokenCachePersistenceOptions(name="<appname>"),
)
client = GraphServiceClient(credentials=credential, scopes=["<scope>"])
```

On Windows the persistent cache is encrypted with DPAPI under the user's profile — no secrets are written in plain text.

All packaged Python apps share one IT-owned app registration — **Contoso EUDA Applications** (client ID `<your-entra-client-id>`, tenant ID `<your-tenant-id>`, redirect URI `http://localhost` already configured). Never create a new app registration from this project. It is already consented for the SharePoint list read/write path and common Graph reads (profile, mail, calendar, presence), so a typical app needs nothing from IT. Releases of the app never touch this registration — distributing a new `app.py` changes nothing in Entra. The only event that involves IT is requesting a delegated scope that has not yet been admin-consented (a one-time grant per scope, handled quickly). Prefer scopes that are already consented.

## Pattern C (Streamlit) specifics (fixed: bootstrap + localhost binding. default: the UI)

- The launcher is still the canonical `launch.cmd` (which ends in `uv run app.py`). Do **not** launch with `uv run streamlit run app.py` — when the run target is the `streamlit` command rather than the script, uv never reads the script's PEP 723 metadata and no dependencies get installed. Instead, the script re-launches itself under the Streamlit runtime:

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

- The first-run hygiene block above is part of the canonical bootstrap — include it verbatim. Streamlit's email prompt, usage telemetry, Deploy button (its external hosting service), Watchdog nag, and skills dialog are never shown to users at your organization.
- **Do not add `watchdog` to the PEP 723 dependency list** to silence the "install the Watchdog module" message. That message also tells macOS users to run `xcode-select --install`, which a citizen-tier app has no business suggesting. Watchdog would put a package with native components on every operator's machine to service a developer feature that cannot fire in production. Turning the watcher off is smaller, more correct, and drops a polling thread.
- **Do not set `logger.hideWelcomeMessage`** to tidy up the terminal. It also suppresses Streamlit's `URL: http://localhost:8501` line, and the app cannot reliably reprint that: `streamlit.config.get_option("server.port")` read before launch returns the built-in default and ignores both `STREAMLIT_SERVER_PORT` and `config.toml`, because the overlay happens later in `bootstrap.load_config_options`. Pinning the port in `sys.argv` to make it knowable would break Streamlit's own fallback to the next free port when one instance is already running. Print the banner *before* the runtime starts and let Streamlit print the address.
- Server binds to localhost only. Never set `--server.address 0.0.0.0`.
- Authentication is the user's Windows session — do not build an in-app login.
- Ephemeral state goes in `st.session_state`. Persistent state goes to SharePoint Lists (preferred) or an existing SQL Server database — never to files in the app folder.

### The stop-the-app banner

A Pattern C app keeps running after the browser tab is closed, and nothing in Streamlit's output says so. Print this before the runtime starts — copy both functions verbatim:

```python
def colour_supported() -> bool:
    """Can we write ANSI colour to this terminal without leaving garbage?"""
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    if not sys.stdout.isatty():
        return False
    if os.name != "nt":
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            return False
        # ENABLE_VIRTUAL_TERMINAL_PROCESSING
        return bool(kernel32.SetConsoleMode(handle, mode.value | 0x0004))
    except Exception:
        return False


def print_banner() -> None:
    """Announce startup and, loudly, how to stop the app again.

    ASCII only - cmd.exe runs under a legacy code page where box drawing
    characters come out as mojibake.
    """
    use_colour = colour_supported()

    def paint(text: str, *codes: str) -> str:
        if not use_colour or not codes:
            return text
        return "\033[" + ";".join(codes) + "m" + text + "\033[0m"

    rule = paint("=" * 66, "36")
    print()
    print(rule)
    print("  " + paint(f"<APP NAME IN CAPS>   v{__version__}", "1", "96"))
    print(rule)
    print()
    print("  Starting up - this opens in your browser in a few seconds.")
    print()
    print("  " + paint(" TO STOP THE APP ", "1", "30", "103")
          + "  press " + paint("Ctrl-C", "1", "93") + " here, or close this window.")
    print()
    print("  Closing the browser tab alone does "
          + paint("NOT", "1", "91") + " stop it.")
    print()
    print(rule)
    print()
```

Two details are not optional. **Detect colour support first** — a console that does not understand ANSI escapes prints them at the operator, which is worse than no colour; `NO_COLOR`/`FORCE_COLOR`, `isatty()`, and the Windows virtual-terminal call cover it, all stdlib (no `colorama`, no `rich`). **ASCII only in the banner** — `cmd.exe` runs under a legacy code page, so `=` and `|` render everywhere and box-drawing characters do not.

## Security rules (fixed)

- **No hardcoded secrets.** No passwords in connection strings, no API keys, no tokens. Use `keyring` if a secret is unavoidable.
- **No `subprocess.run(..., shell=True)`.** Use the list form `["cmd", "arg1", "arg2"]` with no shell interpolation.
- **No runtime code download or execution.** No `urllib`/`httpx` fetches that get `exec()`ed. No `pip install` calls.
- **No writing to system locations.** Logs and temp files go under `%LOCALAPPDATA%\<appname>\`.
- **No raw SQL from user input.** Parameterize everything.
- **No REGULATED data written to local files** — PHI, payment card data, export-controlled material. If the app handles those, escalate; this tier does not cover it.
- Ordinary personal and confidential business data (names, emails, employee IDs, salaries, order history) is IN SCOPE and expected. Never tell the user this platform cannot store it — keep it under `%LOCALAPPDATA%` and carry on.

## Prohibited libraries (fixed)

These will fail review:

- `requests`, `urllib3` — use `httpx`
- `pyodbc` — use `mssql-python`
- `ibm_db`, `ibm_db_sa` — use the SQL Server linked server
- `flask`, `fastapi`, `django`, `bottle`, `tornado`, `aiohttp` — hosted-app frameworks, not citizen tier
- `tkinter`, `PyQt5`, `PyQt6`, `PySide6`, `wxPython`, `kivy`, `toga`, `customtkinter` — no native UI
- `selenium`, `playwright` for Office automation — use Power Automate or Office Scripts
- `pyinstaller`, `cx_freeze`, `py2exe`, `nuitka` — no executable bundling
- `loguru`, `structlog` — use stdlib `logging`
- `arrow`, `pendulum` — use stdlib `datetime` + `zoneinfo`
- `python-dotenv` (direct use) — use `pydantic-settings` + `keyring`. (`pydantic-settings` pulls it in transitively; that is fine — just never import it or ship `.env` files yourself.)

## Project layout (fixed — one app.py, launch.cmd, README, HOW-TO-RUN)

```
<app-name>/
  app.py        # the only Python file
  launch.cmd    # the canonical launcher below — copy verbatim, never edit
  README.md     # what it does, who owns it, what data it touches
  HOW-TO-RUN.md # how to start and stop it, for the person running it
```

No `src/`, `tests/`, `__init__.py`, or module split unless the script exceeds ~500 lines with a clear reason.

`launch.cmd` is identical in every app. It finds uv, installs it if missing (user-space, no admin: winget first, the official installer as fallback), then runs the app. Use exactly this text — any difference is a defect:

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

Save `launch.cmd` with CRLF line endings — `goto :label` is unreliable in LF-only batch files.

The `README.md` must include: app name, owner (name + email), brief purpose, data sources touched (which SQL databases, which SharePoint sites, which Graph scopes), and date last reviewed. It is an owner-and-reviewer document; none of it helps the colleague who was sent a folder.

`HOW-TO-RUN.md` is that colleague's page, and every app ships one. Keep it to a single page: double-click `launch.cmd` on Windows and expect the first run to be slow (it installs uv and downloads Python); `brew install uv` then `uv run app.py` on a Mac, since `launch.cmd` is Windows-only; how to stop the app, including that closing the browser tab does not; anything the user must have in hand before starting (a key from Keeper, a file to point at); and a short table of the errors they are most likely to hit and what each means.

## Distribution and versioning (default)

For an app distributed to a team, the release channel is a SharePoint site (site creation is open at your organization — any user can create one, no ticket):

- The release folder (`app.py`, `launch.cmd`, `README.md`, `HOW-TO-RUN.md`) lives in a document library, alongside a `version.json` (`{"version": ..., "released": ..., "notes": ..., "url": ...}`).
- `app.py` declares a `__version__` constant. At startup it fetches `version.json` (one `httpx` GET with the SharePoint Bearer token) and, if a newer release exists, tells the user and points at the download URL. The check must be **non-blocking** — if the site is unreachable, log it and run anyway. Never auto-download or auto-execute the new version.
- Publishing a release = uploading a new `app.py` and updating `version.json`. Releases never touch Entra (the shared app registration is untouched), so they are entirely self-service.
- For worker pool apps, host `version.json` on the same site as the coordination lists and surface "a newer version is available" on the dashboard.

## Out of scope for this tier — stop and escalate (fixed)

If the requirement includes any of these, this app needs IT-supported hosting, not the citizen tier:

- Scheduled or unattended execution (Task Scheduler, services, cron-style runs)
- Listening sockets, webhooks, or any inbound network exposure
- Multi-user concurrent writes beyond what SharePoint Lists or SQL handle natively
- Data classified above Internal — PHI, payment data, any regulated data
- Distribution outside your organization
- Modifying Active Directory, Entra ID, or Intune state

## When in doubt

Default to the simplest pattern (Pattern B, no UI) and the smallest dependency set. Ask the user before adding any library not listed in the Approved Stack table.

---

## Project-Specific Context

**Application name:** [App Name]
**Pattern:** [B — Script | C — Streamlit]
**Owner:** [name + email]
**Purpose:** [one paragraph]

**Data sources:**
| Source | Details |
|---|---|
| [SQL Server database / SharePoint site / Graph scope] | [what is read or written] |

**Inputs:** [files, prompts, parameters the user supplies]
**Outputs:** [files written, emails sent, rows updated]

Begin by confirming the pattern choice and the data sources, then write the PEP 723 metadata block and scaffold app.py before filling in application logic.
```
