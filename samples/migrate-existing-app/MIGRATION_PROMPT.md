# Order Status Report — Migration Prompt

> **Who/how to use this.** You are migrating an existing, hand-rolled internal
> tool onto the kit's **Packaged Python pattern (Pattern C — Streamlit)**. This
> is the worked example that ships with the kit; the scenario and all data are
> fictional (Contoso / `OrdersDW`). Use it as a template for migrating a real
> tool of your own.
>
> Start a fresh Claude Code (or other approved AI) session and attach **both**
> of these files to your first message:
>
> 1. **this file** (`MIGRATION_PROMPT.md`) — the migration-specific instructions, and
> 2. **`PACKAGED_PYTHON_PROMPT.md`** — the canonical pattern prompt, which lives
>    in the repo's [`patterns/`](../../patterns/PACKAGED_PYTHON_PROMPT.md) folder.
>
> The pattern prompt defines the approved stack, the launcher, and the security
> rules. This file describes what to keep, replace, and drop when porting the
> legacy app. When the two conflict, the pattern prompt wins — it is the
> standard; this file is just the migration brief.
>
> A tiny illustrative "before" stub lives in [`legacy/`](legacy/) so the
> migration is concrete. It is intentionally written with the anti-patterns this
> migration removes. It is **not** a runnable production app — do not copy from it.

---

```
You are migrating an existing internal tool onto the Packaged Python pattern
(Pattern C — Streamlit). Follow the attached PACKAGED_PYTHON_PROMPT.md for the
stack, launcher, and security rules. This brief tells you what to preserve and
what to change.

## The existing application

"Order Status Report" is a hand-rolled desktop reporting tool. Today it is:

- A single Python script that starts a local web server with the stdlib
  `http.server` (HTTPServer + a custom BaseHTTPRequestHandler).
- The handler builds an HTML page by hand (string concatenation) and serves it.
- It queries Contoso's "OrdersDW" SQL Server warehouse for orders and their
  status, joins to customers, and filters out inactive rows.
- The SQL is assembled with Python f-strings from the user's filter inputs.
- Results are written to a local SQLite file ("cache.db") that the script reads
  on the next launch to avoid re-querying.
- It is launched by a .bat file that runs `pip install` and then `python app.py`.

The reporting logic is correct and in active use. The delivery mechanism (the
hand-built HTTP server, the hand-built HTML, the f-string SQL, the SQLite file
cache, the .bat launcher) is what we are replacing.

## The target

One folder in the Packaged Python Pattern C layout:

    migrate-existing-app/        (your real app would get its own folder name)
      app.py        # the only Python file — Streamlit UI + the SQL
      launch.cmd    # the canonical launcher, copied verbatim, never edited
      README.md     # owner, pattern, purpose, data sources, last-reviewed date

PEP 723 inline dependencies — declare exactly these (and nothing else without
asking):

    # /// script
    # requires-python = ">=3.12,<3.13"
    # dependencies = [
    #   "streamlit",
    #   "pandas",
    #   "openpyxl",
    #   "mssql-python",
    # ]
    # ///

`openpyxl` is included so the report can offer an Excel download; `pandas`
holds the result set; `mssql-python` is the only SQL Server driver; `streamlit`
is the UI. Do not add `pyodbc`, `requests`, `flask`/`fastapi`, or any of the
prohibited libraries in the pattern prompt.

## What to preserve exactly

These carry the business meaning. Do not "clean them up" — port them faithfully.

- **Single-connection, sequential SQL for any temp tables.** If the report
  creates a `#temp` table and then selects from it, those statements must run on
  the *same* connection, in order, on one cursor. A temp table created on one
  connection is invisible to another. Open one connection, run the create, run
  the populate, run the select, then close — do not parallelize and do not open
  a second connection mid-report.
- **The ActiveFlag filter.** Every base query against `Orders`, `OrderItems`,
  and `Customers` must keep `WHERE ActiveFlag = 1` (1 = active). Dropping it
  silently pulls inactive/retired rows back into the report — a correctness bug,
  not a style choice.
- **Column order.** The columns in the output table, and their order, must match
  the legacy report exactly. Downstream users have spreadsheets keyed to column
  position. Preserve the existing SELECT list order verbatim.

## What to replace

- **ADODB / hand-rolled HTTP server → Streamlit.** Delete the `http.server`
  request handler and the hand-built HTML. Render the report with Streamlit
  widgets (`st.dataframe`, `st.download_button`, sidebar filters). The Streamlit
  app binds to localhost and re-launches itself under the Streamlit runtime as
  shown in the pattern prompt — `launch.cmd` stays `uv run app.py`.
- **f-string SQL → parameterized queries.** Every place the legacy code
  interpolated a filter value into the SQL string becomes a `?` placeholder with
  the value passed in a `params` list to `cursor.execute(sql, params)`. No
  f-strings, no `.format()`, no string concatenation for SQL — ever.
- **SQLite file cache → `st.session_state`.** Remove `cache.db` and all the
  SQLite read/write code. Hold the last result set in `st.session_state` (or
  `st.cache_data` on the query function). Ephemeral state lives in memory, not
  in a file in the app folder.
- **The .bat launcher → the canonical `launch.cmd`.** Delete the old
  `Run-Order-Status-Report.bat` (with its `pip install`). Copy the canonical
  `launch.cmd` from the pattern prompt **verbatim** — same bytes, CRLF line
  endings, no edits. uv resolves dependencies from the PEP 723 block; there is
  no `pip install` step.

## What to drop

- **The hand-built HTML and the HTTPServer machinery.** No `BaseHTTPRequestHandler`,
  no manual `<html>...</html>` string building, no `serve_forever()`. Streamlit
  owns the UI.
- **The SQLite schema/cache code.** No `CREATE TABLE cache(...)`, no
  `sqlite3.connect("cache.db")`, no file-based result persistence. It is gone,
  not ported.

## Environment facts

- **Dev warehouse:** Server `sqldev.contoso.com`, Database `OrdersDW`.
- **Auth:** Windows integrated — `Trusted_Connection=yes`. The app connects as
  the signed-in user; no service account, no password in the connection string.
- **Encryption (dev):** `Encrypt=yes;TrustServerCertificate=yes`. The
  `TrustServerCertificate=yes` is **for the dev server only** (self-signed
  certificate). Remove it for production.
- **Production warehouse:** `<confirm with IT>` — do not guess the production
  server name or database. Leave it as a clearly-marked placeholder and confirm
  the real value (and whether `TrustServerCertificate` is still needed) with IT
  before pointing the app at production.

Example dev connection string:

    Server=sqldev.contoso.com;Database=OrdersDW;Encrypt=yes;
    TrustServerCertificate=yes;Trusted_Connection=yes

## Acceptance checklist

- [ ] Folder has exactly `app.py`, `launch.cmd`, `README.md` (no `src/`, no `tests/`).
- [ ] PEP 723 block declares only: streamlit, pandas, openpyxl, mssql-python;
      `requires-python = ">=3.12,<3.13"`.
- [ ] `launch.cmd` is the canonical launcher, byte-for-byte, CRLF, unedited.
- [ ] No `http.server` / `BaseHTTPRequestHandler`; UI is Streamlit, bound to localhost.
- [ ] No `sqlite3` and no `cache.db`; last result set held in `st.session_state`.
- [ ] Every SQL statement is parameterized (`?` + params list). Zero f-string/
      `.format()`/concatenation SQL.
- [ ] Any temp-table report runs create → populate → select on one connection,
      one cursor, in order.
- [ ] `WHERE ActiveFlag = 1` present on every base-table query.
- [ ] Output column order matches the legacy report exactly.
- [ ] Connection uses `Trusted_Connection=yes`; no passwords; `TrustServerCertificate=yes`
      flagged as dev-only.
- [ ] Production server/database left as `<confirm with IT>`, not invented.
- [ ] `README.md` lists owner (name + email), pattern, purpose, data sources, last-reviewed date.
- [ ] Runs with `uv run app.py`; opens in the browser at localhost.
```

---

## Project-Specific Context

Fill these in for your own migration (the values below are placeholders for this
fictional example):

**Application name:** Order Status Report
**Pattern:** C — Streamlit
**Owner:** `<owner-name>` / `<owner@example.com>`
**Purpose:** `<one paragraph — what the report shows and who relies on it>`

**Data sources:**

| Source | Details |
|---|---|
| SQL Server `OrdersDW` on `sqldev.contoso.com` (dev) | Reads `Orders`, `OrderItems`, `Customers`; filters `ActiveFlag = 1`; no writes |
| Production warehouse | `<confirm with IT>` — server/database not yet confirmed |

**Inputs:** `<the filters the user picks — e.g. status, date range, customer>`
**Outputs:** on-screen table + Excel/CSV download (no rows written back)
