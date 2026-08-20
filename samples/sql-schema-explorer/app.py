# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "streamlit",
#   "pandas",
#   "mssql-python",
# ]
# ///
"""SQL Schema Explorer — Packaged Python sample (Pattern C — Streamlit).

Interactive, read-only explorer for a SQL Server database: browse schemas,
tables, and views; inspect column definitions; preview sample rows; and
download a preview as CSV. Connects as the signed-in user — no service
accounts, no stored passwords.

Demonstrates the Packaged Python pattern:
- mssql-python with Windows integrated auth (Entra interactive optional)
- All metadata queries parameterized; identifiers only ever come from
  sys.tables/sys.views results, never from free text
- st.cache_data for query results, fresh short-lived connection per query
- Self-bootstrapping launcher: launch.cmd is exactly `uv run app.py`
- Logs under %LOCALAPPDATA%\\sql-schema-explorer\\
"""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

import pandas as pd
import streamlit as st

APP_NAME = "sql-schema-explorer"
DEFAULT_SERVER = "<your-sql-server-hostname>"
DEFAULT_DATABASE = "master"
SAMPLE_ROWS = 200


def setup_logging() -> logging.Logger:
    log_dir = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / APP_NAME
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=log_dir / "run.log",
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    return logging.getLogger(APP_NAME)


def conn_str(server: str, database: str, auth: str) -> str:
    parts = [f"Server={server}", f"Database={database}", "Encrypt=yes", "TrustServerCertificate=yes"]
    if auth == "interactive":
        parts.append("Authentication=ActiveDirectoryInteractive")
    else:
        parts.append("Trusted_Connection=yes")
    return ";".join(parts)


@st.cache_data(ttl=300, show_spinner=False)
def q(server: str, database: str, auth: str, sql: str, params: tuple = ()) -> pd.DataFrame:
    from mssql_python import connect
    conn = connect(conn_str(server, database, auth))
    try:
        cur = conn.cursor()
        cur.execute(sql, list(params))
        cols = [d[0] for d in cur.description]
        return pd.DataFrame([tuple(r) for r in cur.fetchall()], columns=cols)
    finally:
        conn.close()


def bracket(identifier: str) -> str:
    # identifiers come only from sys.tables/sys.views results, but escape anyway
    return "[" + identifier.replace("]", "]]") + "]"


def main() -> None:
    log = setup_logging()
    st.set_page_config(page_title="SQL Schema Explorer", layout="wide")
    st.title("SQL Schema Explorer")
    st.caption(
        "Packaged Python sample — Pattern C (Streamlit). Read-only; connects as you; "
        "runs at localhost only."
    )

    with st.sidebar:
        st.header("Connection")
        server = st.text_input("Server", value=DEFAULT_SERVER)
        database = st.text_input("Database", value=DEFAULT_DATABASE)
        auth = st.selectbox("Authentication", ["windows", "interactive"],
                            help="windows = your signed-in session; interactive = Entra browser sign-in")
        if st.button("Connect / refresh"):
            st.cache_data.clear()
            st.session_state["cfg"] = (server, database, auth)
            log.info("Connect requested: %s/%s (%s)", server, database, auth)

    if "cfg" not in st.session_state:
        st.info("Enter the server and database in the sidebar, then click **Connect / refresh**.")
        return

    server, database, auth = st.session_state["cfg"]

    try:
        who = q(server, database, auth,
                "SELECT @@SERVERNAME AS server_name, DB_NAME() AS db, SUSER_SNAME() AS login_name, "
                "CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50)) AS version")
    except Exception as exc:
        st.error(f"Connection failed: {exc}")
        log.exception("Connection failed")
        return

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Server", who.at[0, "server_name"])
    c2.metric("Database", who.at[0, "db"])
    c3.metric("Signed in as", str(who.at[0, "login_name"]).split("\\")[-1])
    c4.metric("SQL Server", who.at[0, "version"])

    kind = st.radio("Object type", ["Tables", "Views"], horizontal=True)
    catalog = "sys.tables" if kind == "Tables" else "sys.views"

    schemas = q(server, database, auth,
                f"SELECT s.name AS schema_name, COUNT(o.object_id) AS objects "
                f"FROM sys.schemas s JOIN {catalog} o ON o.schema_id = s.schema_id "
                f"GROUP BY s.name ORDER BY s.name")
    if schemas.empty:
        st.warning(f"No {kind.lower()} visible to your account in this database.")
        return

    left, right = st.columns([1, 2])

    with left:
        labels = [f"{r.schema_name} ({r.objects})" for r in schemas.itertuples()]
        chosen = st.selectbox("Schema", labels)
        schema = schemas.at[labels.index(chosen), "schema_name"]

        objects = q(server, database, auth,
                    f"SELECT o.name AS object_name FROM {catalog} o "
                    f"WHERE o.schema_id = SCHEMA_ID(?) ORDER BY o.name", (schema,))
        if kind == "Tables":
            try:
                counts = q(server, database, auth,
                           "SELECT t.name AS object_name, SUM(ps.row_count) AS row_count "
                           "FROM sys.tables t "
                           "JOIN sys.dm_db_partition_stats ps ON ps.object_id = t.object_id "
                           "AND ps.index_id IN (0, 1) "
                           "WHERE t.schema_id = SCHEMA_ID(?) GROUP BY t.name", (schema,))
                objects = objects.merge(counts, on="object_name", how="left")
            except Exception:
                pass  # row counts need VIEW DATABASE STATE; list works without them

        search = st.text_input("Filter by name")
        if search:
            objects = objects[objects["object_name"].str.contains(search, case=False, na=False)]

        st.caption(f"{len(objects)} {kind.lower()} in {schema}")
        st.dataframe(objects, hide_index=True, height=420)
        names = objects["object_name"].tolist()
        target = st.selectbox(f"Inspect {kind.lower()[:-1]}", names) if names else None

    with right:
        if not target:
            st.info("Select an object on the left.")
            return
        st.subheader(f"{schema}.{target}")

        cols_meta = q(server, database, auth,
                      "SELECT ORDINAL_POSITION AS pos, COLUMN_NAME AS name, DATA_TYPE AS type, "
                      "CHARACTER_MAXIMUM_LENGTH AS max_len, IS_NULLABLE AS nullable "
                      "FROM INFORMATION_SCHEMA.COLUMNS "
                      "WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION",
                      (schema, target))
        st.markdown(f"**Columns ({len(cols_meta)})**")
        st.dataframe(cols_meta, hide_index=True, height=240)

        st.markdown(f"**Sample rows (top {SAMPLE_ROWS})**")
        try:
            sample = q(server, database, auth,
                       f"SELECT TOP {SAMPLE_ROWS} * FROM {bracket(schema)}.{bracket(target)}")
            st.dataframe(sample, hide_index=True, height=320)
            st.download_button(
                "Download sample (CSV)",
                sample.to_csv(index=False).encode("utf-8"),
                file_name=f"{schema}.{target}.sample.csv",
                mime="text/csv",
            )
            log.info("Previewed %s.%s (%d rows)", schema, target, len(sample))
        except Exception as exc:
            st.warning(f"Could not read rows (likely no SELECT permission): {exc}")


def colour_supported() -> bool:
    """Can we write ANSI colour to this terminal without leaving garbage?

    Honours the NO_COLOR / FORCE_COLOR conventions. On Windows, console
    virtual-terminal processing is off by default and has to be switched on,
    which is what the ctypes call does - if that fails we fall back to plain
    text rather than printing escape sequences at the operator.
    """
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

    Deliberately ASCII only - cmd.exe runs under a legacy code page where box
    drawing characters come out as mojibake.
    """
    use_colour = colour_supported()

    def paint(text: str, *codes: str) -> str:
        if not use_colour or not codes:
            return text
        return "\033[" + ";".join(codes) + "m" + text + "\033[0m"

    rule = paint("=" * 66, "36")
    print()
    print(rule)
    print("  " + paint("SQL SCHEMA EXPLORER", "1", "96"))
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

        print_banner()

        from streamlit.web import cli as stcli
        sys.argv = ["streamlit", "run", sys.argv[0], "--server.address", "localhost"]
        sys.exit(stcli.main())
