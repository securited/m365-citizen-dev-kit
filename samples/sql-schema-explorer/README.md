# SQL Schema Explorer

**App name:** SQL Schema Explorer
**Owner:** EUDA App Platform team — `<owner-email>` *(replace when you copy this sample)*
**Pattern:** Packaged Python — Pattern C (Streamlit)
**Date last reviewed:** 2026-06-11

## Purpose

Read-only interactive explorer for a SQL Server database. Browse schemas and
their tables or views, inspect column definitions (name, type, length,
nullability), preview the top 200 rows of any object you have SELECT on, and
download the preview as CSV. Useful for verifying what your account can see
on a server before building a reporting app against it.

## How to run

Double-click `launch.cmd` — it installs uv automatically if missing
(one-time, no admin needed), then runs the app. Or run `uv run app.py` from a
terminal. The app opens in your browser at localhost. Enter the server and
database in the sidebar (defaults: `<your-sql-server-hostname>` / master)
and click **Connect / refresh**.

## Data sources touched

- **SQL databases:** the server entered in the sidebar (default
  `<your-sql-server-hostname>` / master) — reads system catalogs (`sys.schemas`,
  `sys.tables`, `sys.views`, `INFORMATION_SCHEMA.COLUMNS`,
  `sys.dm_db_partition_stats` when permitted) and `SELECT TOP 200` on objects
  the user chooses. No writes of any kind.
- **SharePoint sites:** none
- **Graph scopes:** none
- **Local files:** writes logs to `%LOCALAPPDATA%\sql-schema-explorer\run.log`;
  CSV downloads go wherever the browser saves them

## What it demonstrates

- `mssql-python` with the user's own identity — Windows integrated
  (`Trusted_Connection=yes`) by default, Entra
  (`Authentication=ActiveDirectoryInteractive`) selectable
- Parameterized metadata queries; identifiers are taken only from catalog
  query results (never free text) and bracket-escaped
- `st.cache_data` (5-minute TTL) over short-lived per-query connections
- Graceful degradation: row counts skipped without VIEW DATABASE STATE;
  per-object permission errors shown inline
- The self-bootstrapping Streamlit launcher (`launch.cmd` = `uv run app.py`)
