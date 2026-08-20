# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "streamlit",
#   "pandas",
#   "openpyxl",
# ]
# ///
"""Data Explorer — Packaged Python sample (Pattern C — Streamlit).

An interactive dashboard over a tabular dataset: upload a CSV or Excel
file (or generate sample data), filter it, see metrics and charts, and
download the filtered rows. Everything runs at localhost — nothing leaves
the machine.

Demonstrates the Packaged Python pattern:
- Self-bootstrapping launcher: launch.cmd is exactly `uv run app.py`; the
  script re-launches itself under the Streamlit runtime, bound to localhost
- Ephemeral state in st.session_state — no files written to the app folder
- Approved stack only: streamlit, pandas, openpyxl + stdlib
- Logs under %LOCALAPPDATA%\\data-explorer\\
- No in-app login: the user's Windows session is the authentication
"""
from __future__ import annotations

import logging
import os
import random
import sys
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import streamlit as st

APP_NAME = "data-explorer"


def setup_logging() -> logging.Logger:
    log_dir = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / APP_NAME
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=log_dir / "run.log",
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    return logging.getLogger(APP_NAME)


CATEGORIES = {
    "Imaging": ["X-Ray Tube Housing", "Collimator Assembly", "Detector Panel", "Image Intensifier"],
    "Biomed": ["SpO2 Sensor", "ECG Lead Set", "NIBP Cuff Adult", "Monitor Battery Pack"],
    "Lab": ["Centrifuge Rotor", "Reagent Pump", "Sample Probe"],
    "Infusion": ["Pump Module", "Door Assembly", "Keypad Overlay"],
}
STATUSES = ["Open", "Shipped", "Delivered", "Backordered"]


def make_sample_data() -> pd.DataFrame:
    rng = random.Random(42)
    today = date.today()
    rows = []
    for i in range(300):
        category = rng.choice(list(CATEGORIES))
        qty = rng.randint(1, 6)
        price = round(rng.uniform(40, 2500), 2)
        rows.append({
            "order_id": f"SO-{310500 + i}",
            "order_date": today - timedelta(days=rng.randint(0, 179)),
            "category": category,
            "part_description": rng.choice(CATEGORIES[category]),
            "quantity": qty,
            "unit_price": price,
            "line_total": round(qty * price, 2),
            "status": rng.choice(STATUSES),
        })
    return pd.DataFrame(rows).sort_values("order_date").reset_index(drop=True)


def load_uploaded(file) -> pd.DataFrame:
    if file.name.lower().endswith(".csv"):
        return pd.read_csv(file)
    return pd.read_excel(file)


def text_columns(df: pd.DataFrame) -> list[str]:
    # dtype == object covers pandas 2.x strings (and mixed columns);
    # is_string_dtype covers the Arrow-backed str dtype that is the
    # default for strings from pandas 3.0 on
    return [
        c for c in df.columns
        if df[c].dtype == object or pd.api.types.is_string_dtype(df[c])
    ]


def apply_filters(df: pd.DataFrame) -> pd.DataFrame:
    filtered = df
    text_cols = text_columns(df)

    st.sidebar.header("Filters")
    for col in text_cols:
        if 1 < df[col].nunique() <= 20:
            options = sorted(df[col].dropna().unique().tolist())
            chosen = st.sidebar.multiselect(col, options, default=options)
            filtered = filtered[filtered[col].isin(chosen)]

    search = st.sidebar.text_input("Search (any text column)")
    if search and text_cols:
        mask = pd.Series(False, index=filtered.index)
        for col in text_cols:
            mask |= filtered[col].astype(str).str.contains(search, case=False, na=False)
        filtered = filtered[mask]
    return filtered


def main() -> None:
    log = setup_logging()
    st.set_page_config(page_title="Data Explorer", layout="wide")
    st.title("Data Explorer")
    st.caption(
        "Packaged Python sample — Pattern C (Streamlit). "
        "Runs at localhost only; nothing leaves your machine."
    )

    with st.sidebar:
        st.header("Data")
        uploaded = st.file_uploader("Upload a CSV or Excel file", type=["csv", "xlsx"])
        if uploaded is not None:
            try:
                st.session_state["df"] = load_uploaded(uploaded)
                st.session_state["source"] = uploaded.name
                log.info("Loaded uploaded file: %s", uploaded.name)
            except Exception as exc:
                st.error(f"Could not read file: {exc}")
                log.exception("Failed to read uploaded file")
        if st.button("Load sample data"):
            st.session_state["df"] = make_sample_data()
            st.session_state["source"] = "sample data (generated locally)"
            log.info("Generated sample dataset")

    if "df" not in st.session_state:
        st.info(
            "Upload a CSV or Excel file in the sidebar, or click "
            "**Load sample data** to explore a generated tabular dataset."
        )
        return

    df = st.session_state["df"]
    filtered = apply_filters(df)
    st.caption(f"Source: {st.session_state['source']} — showing {len(filtered):,} of {len(df):,} rows")

    c1, c2, c3 = st.columns(3)
    c1.metric("Rows", f"{len(filtered):,}")
    if "line_total" in filtered.columns:
        c2.metric("Total value", f"${filtered['line_total'].sum():,.0f}")
    if "part_description" in filtered.columns:
        c3.metric("Distinct parts", f"{filtered['part_description'].nunique():,}")

    if not filtered.empty:
        chart1, chart2 = st.columns(2)
        if "category" in filtered.columns:
            with chart1:
                st.subheader("Orders by category")
                st.bar_chart(filtered["category"].value_counts())
        if {"order_date", "line_total"} <= set(filtered.columns):
            with chart2:
                st.subheader("Value by month")
                monthly = (
                    filtered.assign(
                        month=pd.to_datetime(filtered["order_date"]).dt.to_period("M").dt.to_timestamp()
                    )
                    .groupby("month")["line_total"]
                    .sum()
                )
                st.line_chart(monthly)

    st.subheader("Rows")
    st.dataframe(filtered, hide_index=True)
    st.download_button(
        "Download filtered rows (CSV)",
        filtered.to_csv(index=False).encode("utf-8"),
        file_name="filtered_rows.csv",
        mime="text/csv",
    )


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
    print("  " + paint("DATA EXPLORER", "1", "96"))
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
