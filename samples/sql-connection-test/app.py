# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "mssql-python",
#   "rich",
# ]
# ///
"""SQL Connection Test — Packaged Python sample (Pattern B — Script).

Diagnostic tool that proves connectivity to a SQL Server from this machine
as the signed-in user, then reports what the connection can see. The SQL
counterpart to the SharePoint pattern's sp-test.aspx page.

Checks, in order:
  1. TCP reachability of the server on port 1433
  2. Login (Windows integrated by default; --auth interactive for Entra)
  3. Server identity: @@SERVERNAME, version, login name, STRING_AGG support
  4. Databases visible to this login
  5. Schemas and table counts in the target database
  6. Session temp-table round trip (#t) across separate statements
  7. Target-app readiness: presence of expected schemas and views, if any

Usage:
  uv run app.py
  uv run app.py --server myserver --database MyDatabase
  uv run app.py --auth interactive        (Entra browser sign-in)
"""
from __future__ import annotations

import argparse
import logging
import os
import socket
import sys
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

APP_NAME = "sql-connection-test"
DEFAULT_SERVER = "<your-sql-server-hostname>"

# Replace with the schema and view names your target app expects to find.
# These are checked in step 7 to confirm the database has the right structure.
TARGET_SCHEMAS = ["dbo", "reporting"]
TARGET_VIEWS: list[str] = []  # e.g. ["reporting.vw_Orders", "reporting.vw_Customers"]

console = Console()
results: list[tuple[str, str, str]] = []  # (step, PASS/FAIL/INFO, detail)


def setup_logging() -> logging.Logger:
    log_dir = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / APP_NAME
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=log_dir / "run.log",
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    return logging.getLogger(APP_NAME)


def record(step: str, ok: bool | None, detail: str) -> None:
    status = "INFO" if ok is None else ("PASS" if ok else "FAIL")
    results.append((step, status, detail))
    style = {"PASS": "green", "FAIL": "red", "INFO": "cyan"}[status]
    console.print(f"[{style}]{status}[/{style}]  {step} — {detail}")


def check_tcp(server: str, port: int = 1433) -> bool:
    try:
        with socket.create_connection((server, port), timeout=8):
            record("TCP reachability", True, f"{server}:{port} accepts connections")
            return True
    except OSError as exc:
        record("TCP reachability", False, f"{server}:{port} — {exc}")
        return False


def build_conn_str(server: str, database: str, auth: str, trust_cert: bool) -> str:
    parts = [f"Server={server}", f"Database={database}", "Encrypt=yes"]
    if trust_cert:
        parts.append("TrustServerCertificate=yes")
    if auth == "interactive":
        parts.append("Authentication=ActiveDirectoryInteractive")
    else:
        parts.append("Trusted_Connection=yes")
    return ";".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description="SQL Server connection test")
    parser.add_argument("--server", default=DEFAULT_SERVER)
    parser.add_argument("--database", default="master")
    parser.add_argument("--auth", choices=["windows", "interactive"], default="windows",
                        help="windows = Trusted_Connection (default); interactive = Entra browser sign-in")
    parser.add_argument("--no-trust-cert", action="store_true",
                        help="require a CA-signed server certificate")
    args = parser.parse_args()

    log = setup_logging()
    log.info("Test started: server=%s database=%s auth=%s", args.server, args.database, args.auth)
    console.print(Panel.fit(
        f"[bold]SQL Connection Test[/bold]\n{args.server} / {args.database} / {args.auth} auth"
    ))

    if not check_tcp(args.server):
        return finish(log)

    conn_str = build_conn_str(args.server, args.database, args.auth, not args.no_trust_cert)
    try:
        from mssql_python import connect
        conn = connect(conn_str)
        record("Login", True, f"connected with {args.auth} auth")
    except Exception as exc:
        record("Login", False, str(exc).splitlines()[0][:200])
        return finish(log)

    cur = conn.cursor()

    try:
        cur.execute(
            "SELECT @@SERVERNAME, SUSER_SNAME(), DB_NAME(), "
            "CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50)), "
            "CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)"
        )
        srv, login, db, ver, major = cur.fetchone()
        record("Server identity", True, f"server={srv}  login={login}  db={db}  version={ver}")
        record("STRING_AGG support (SQL 2017+)", major >= 14, f"major version {major}")
    except Exception as exc:
        record("Server identity", False, str(exc)[:200])

    try:
        cur.execute("SELECT name FROM sys.databases ORDER BY name")
        dbs = [r[0] for r in cur.fetchall()]
        bi_dbs = [d for d in dbs if "bi" in d.lower() or "prod" in d.lower()]
        record("Visible databases", True, f"{len(dbs)} visible: {', '.join(dbs[:15])}"
               + (" …" if len(dbs) > 15 else ""))
        if bi_dbs:
            record("BI database candidates", None, ", ".join(bi_dbs))
    except Exception as exc:
        record("Visible databases", False, str(exc)[:200])

    try:
        cur.execute(
            "SELECT s.name, COUNT(t.object_id) FROM sys.schemas s "
            "LEFT JOIN sys.tables t ON t.schema_id = s.schema_id "
            "WHERE s.schema_id < 16384 AND s.name NOT IN ('guest','INFORMATION_SCHEMA','sys') "
            "GROUP BY s.name HAVING COUNT(t.object_id) > 0 ORDER BY s.name"
        )
        rows = cur.fetchall()
        if rows:
            detail = ", ".join(f"{name} ({n} tables)" for name, n in rows[:12])
            record("Schemas with visible tables", True, detail + (" …" if len(rows) > 12 else ""))
        else:
            record("Schemas with visible tables", None,
                   "none — login works but has no table permissions in this database")
    except Exception as exc:
        record("Schemas with visible tables", False, str(exc)[:200])

    try:
        cur.execute("SELECT 1 AS n INTO #t; INSERT INTO #t VALUES (2);")
        cur.execute("SELECT SUM(n) FROM #t")
        total = cur.fetchone()[0]
        record("Temp-table round trip", total == 3,
               f"#t persisted across statements on one connection (sum={total})")
    except Exception as exc:
        record("Temp-table round trip", False, str(exc)[:200])

    try:
        cur.execute("SELECT name FROM sys.schemas WHERE name IN ({})".format(
            ",".join("?" * len(TARGET_SCHEMAS))), TARGET_SCHEMAS)
        found = {r[0] for r in cur.fetchall()}
        missing = [s for s in TARGET_SCHEMAS if s not in found]
        if found:
            views = []
            for v in TARGET_VIEWS:
                cur.execute("SELECT OBJECT_ID(?)", [v])
                views.append(f"{v}: {'yes' if cur.fetchone()[0] else 'NO'}")
            view_txt = " | " + ", ".join(views) if views else ""
            record("Target-app readiness", not missing,
                   f"schemas found: {', '.join(sorted(found))}"
                   + (f" | missing: {', '.join(missing)}" if missing else "")
                   + view_txt)
        else:
            record("Target-app readiness", None,
                   "none of the expected schemas found — rerun with --database <target database>")
    except Exception as exc:
        record("Target-app readiness", False, str(exc)[:200])

    conn.close()
    return finish(log)


def finish(log: logging.Logger) -> int:
    table = Table(title="Connection Test Summary")
    table.add_column("Check")
    table.add_column("Status")
    table.add_column("Detail", overflow="fold")
    for step, status, detail in results:
        style = {"PASS": "green", "FAIL": "red", "INFO": "cyan"}[status]
        table.add_row(step, f"[{style}]{status}[/{style}]", detail)
    console.print(table)

    failed = any(s == "FAIL" for _, s, _ in results)
    log.info("Test finished: %s", "FAIL" if failed else "PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        logging.getLogger(APP_NAME).exception("Unhandled error")
        console.print(f"[red]Unexpected error: {exc}[/red]")
        sys.exit(1)
