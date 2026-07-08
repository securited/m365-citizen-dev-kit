# SQL Connection Test

**App name:** SQL Connection Test
**Owner:** EUDA App Platform team — `<owner-email>` *(replace when you copy this sample)*
**Pattern:** Packaged Python — Pattern B (Script)
**Date last reviewed:** 2026-06-11

## Purpose

Diagnostic tool that proves SQL Server connectivity from this machine as the
signed-in user — the SQL counterpart to the SharePoint pattern's
`sp-test.aspx`. Runs seven checks and prints a pass/fail summary: TCP
reachability, login, server identity and version (STRING_AGG support),
visible databases, schemas with table permissions, a session temp-table
round trip, and target-app schema readiness.

## How to run

Double-click `launch.cmd` — it installs uv automatically if missing
(one-time, no admin needed), then runs the test. Or from a terminal:

- `uv run app.py` — defaults: `<your-sql-server-hostname>`, master,
  Windows integrated auth
- `uv run app.py --server <host> --database <db>` — other targets
- `uv run app.py --auth interactive` — Entra browser sign-in instead of
  Windows auth
- `uv run app.py --no-trust-cert` — require a CA-signed server certificate

Exit code 0 = all checks passed; 1 = at least one failure (suitable for
sharing the on-screen summary with the database team).

## Data sources touched

- **SQL databases:** connects to the server given via `--server`
  (default `<your-sql-server-hostname>`); reads only system catalog views
  (`sys.databases`, `sys.schemas`, `sys.tables`) and creates one session temp table
- **SharePoint sites:** none
- **Graph scopes:** none
- **Local files:** writes logs to `%LOCALAPPDATA%\sql-connection-test\run.log`

## What it demonstrates

- `mssql-python` connecting with the user's own identity — Windows
  integrated (`Trusted_Connection=yes`) or Entra
  (`Authentication=ActiveDirectoryInteractive`) — no service accounts,
  no stored passwords
- Session-scoped temp tables persisting across statements on one
  connection (the technique multi-step reporting queries depend on)
- Parameterized queries only — no string-built SQL
- Pattern B shape: runs to completion with clear terminal output and a
  meaningful exit code
