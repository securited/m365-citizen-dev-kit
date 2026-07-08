@echo off
rem Legacy launcher for the OLD Order Status Report — the "before" state.
rem Anti-pattern: installs packages at runtime, then runs the script directly.
rem The migration replaces this with the canonical launch.cmd (uv run app.py).
pip install some-legacy-db-driver
python app.py
pause
