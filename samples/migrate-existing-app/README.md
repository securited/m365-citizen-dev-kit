# Migrate an Existing App — worked example

**Owner:** `<owner-name>` *(replace when you adapt this for a real migration)*
**Pattern:** C (Streamlit) — Packaged Python
**Date last reviewed:** 2026-06-24

## What this folder is

A **teaching example** for the Packaged Python migration workflow: taking an
existing, hand-rolled internal tool and porting it onto the kit's **Pattern C
(Streamlit)** layout. It replaces a private internal example that was excluded
from this public kit for containing real schema.

**Everything here is fictional.** The scenario is Contoso's invented
"Order Status Report", which reads a make-believe `OrdersDW` SQL Server
warehouse on `sqldev.contoso.com`. There are no real hostnames, schemas, or
business rules anywhere in this folder. The fictional schema is just three
tables (`Orders`, `OrderItems`, `Customers`) with a generic `ActiveFlag` column.

This is the kind of work a citizen developer (EUDA — End-User Developed
Application) does when moving a legacy desktop tool onto the approved stack.

## How to use it

1. Read **[`MIGRATION_PROMPT.md`](MIGRATION_PROMPT.md)** — the migration brief.
   It mirrors the structure you'd write for a real migration: the existing app,
   the target layout, what to preserve, what to replace, what to drop,
   environment facts, and an acceptance checklist.
2. Start a fresh AI session and attach **both** `MIGRATION_PROMPT.md` and the
   canonical pattern prompt
   [`../../patterns/PACKAGED_PYTHON_PROMPT.md`](../../patterns/PACKAGED_PYTHON_PROMPT.md)
   to your first message. The pattern prompt is the standard (stack, launcher,
   security rules); the migration prompt is the project-specific brief.
3. Peek at **[`legacy/`](legacy/)** to see the "before" state — a tiny stub that
   deliberately shows the anti-patterns the migration removes (hand-rolled
   `http.server`, f-string SQL, a SQLite file cache, a `pip install` .bat). It
   is illustrative only, **not** a runnable production app.

## The lessons this example teaches

These transfer to any migration, regardless of the legacy tool's specifics:

- **Parameterized SQL over f-strings** — `?` placeholders + a `params` list,
  never string interpolation.
- **Single-connection sequential SQL** for any temp tables — a `#temp` created
  on one connection is invisible to another.
- **`st.session_state` over a file cache** — ephemeral state stays in memory,
  not in a file in the app folder.
- **The canonical `launch.cmd`**, copied verbatim — uv reads PEP 723 deps; no
  runtime `pip install`.
- **Preserve business meaning** — keep the `ActiveFlag = 1` filter and the exact
  output column order even while everything around them changes.

## Reference

- Pattern prompt: [`../../patterns/PACKAGED_PYTHON_PROMPT.md`](../../patterns/PACKAGED_PYTHON_PROMPT.md)
- Pattern guide: [`../../patterns/PACKAGED_PYTHON_PATTERN.md`](../../patterns/PACKAGED_PYTHON_PATTERN.md)

## Files

| File | Purpose |
|---|---|
| `MIGRATION_PROMPT.md` | The migration brief — attach this + the pattern prompt to your first message |
| `README.md` | This file |
| `legacy/app.py` | Tiny "before" stub — intentional anti-patterns, not runnable |
| `legacy/Run-Order-Status-Report.bat` | The old launcher being replaced |

> A finished migration would add `app.py` + `launch.cmd` here (the Pattern C
> result). This example ships the brief and the "before" stub; producing the
> "after" `app.py` is the exercise.
