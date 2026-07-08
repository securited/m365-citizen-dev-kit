# CSV Merge Report

**App name:** CSV Merge Report
**Owner:** EUDA App Platform team — `<owner-email>` *(replace when you copy this sample)*
**Pattern:** Packaged Python — Pattern B (Script)
**Date last reviewed:** 2026-06-11

## Purpose

Reference sample for the Packaged Python pattern. Merges every CSV file in the
`input/` folder into one formatted Excel workbook (`output/merge_report_*.xlsx`)
with a summary sheet, bold headers, frozen panes, auto-filters, and sized
columns. On first run, when `input/` is empty, it seeds three sample CSVs so
the report format is visible immediately.

## How to run

Double-click `launch.cmd` — it installs uv automatically if missing
(one-time, no admin needed), then runs the app. Or run `uv run app.py` from a
terminal. There is nothing else to install: dependencies are declared in the
PEP 723 block at the top of `app.py` and resolved automatically.

## Data sources touched

- **SQL databases:** none
- **SharePoint sites:** none
- **Graph scopes:** none
- **Local files:** reads `input/*.csv`; writes `output/*.xlsx` (both inside
  this app folder); writes logs to `%LOCALAPPDATA%\csv-merge-report\run.log`

## What it demonstrates

- PEP 723 inline script metadata as the only dependency declaration
- Approved stack only: `pandas`, `openpyxl`, `rich`, plus stdlib
  `logging`/`pathlib`/`datetime`
- Logs under `%LOCALAPPDATA%\<appname>\`, never system locations
- Single-file layout: `app.py` + `launch.cmd` + `README.md`
- Runs to completion with clear terminal output and exit codes — no UI
