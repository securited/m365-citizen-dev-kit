# Data Explorer

**App name:** Data Explorer
**Owner:** EUDA App Platform team — `<owner-email>` *(replace when you copy this sample)*
**Pattern:** Packaged Python — Pattern C (Streamlit)
**Date last reviewed:** 2026-06-11

## Purpose

Reference sample for the Packaged Python pattern's Streamlit shape. An
interactive dashboard over a tabular dataset: upload a CSV or Excel file
(or generate sample data locally), filter by any low-cardinality text column,
search across text columns, view metrics and charts, and download the
filtered rows as CSV. Everything runs in the user's browser at localhost —
nothing leaves the machine.

## How to run

Double-click `launch.cmd` — it installs uv automatically if missing
(one-time, no admin needed), then runs the app. Or run `uv run app.py` from a
terminal. The script bootstraps itself under the Streamlit runtime and opens
a browser tab at localhost. There is nothing else to install: dependencies
are declared in the PEP 723 block at the top of `app.py` and resolved
automatically.

## Data sources touched

- **SQL databases:** none
- **SharePoint sites:** none
- **Graph scopes:** none
- **Local files:** reads only files the user explicitly uploads; writes logs
  to `%LOCALAPPDATA%\data-explorer\run.log`

## What it demonstrates

- The self-bootstrapping Streamlit launcher: `launch.cmd` is exactly
  `uv run app.py`, so PEP 723 metadata is honored for both app shapes
- Server bound to localhost only — never `0.0.0.0`
- No in-app login: the user's Windows session is the authentication
- Ephemeral state in `st.session_state`; no persistent files in the app folder
- Approved stack only: `streamlit`, `pandas`, `openpyxl`, plus stdlib
  `logging`/`pathlib`/`datetime`/`random`
