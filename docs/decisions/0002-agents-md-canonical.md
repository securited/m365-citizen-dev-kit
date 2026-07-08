# 0002. AGENTS.md is the canonical AI context; pointer files import it

- Status: accepted
- Date: 2026-06-23

## Context

The upstream repo used a root `manifest.json` as its AI-facing index. No tool auto-loads a `manifest.json`, so it only helped when someone pointed at it. The Repository Documentation & AI Context Standard prescribes a single canonical context file at the repo root that agents auto-load.

## Decision

Adopt `AGENTS.md` at the repo root as the canonical AI context. `CLAUDE.md` is reduced to `@AGENTS.md` (plus Claude-only notes if ever needed). The upstream `manifest.json`'s non-derivable content (folder map, conventions, do-not-touch, AI guidance) is folded into `AGENTS.md`, and `manifest.json` is **not** carried into this repo — nothing here consumes it programmatically. (Pattern-data files like `versions.json`/`samples.json`, which the SharePoint hub page *does* consume at runtime, are kept when the patterns are ported.)

## Consequences
- One source of truth for AI context; pointer files cannot drift.
- The canonical file stays short (~120 lines target); depth lives in linked `docs/`.

## Options considered
- **Keep `manifest.json` as the AI index** — rejected: not auto-loaded, and it duplicated context that now lives in `AGENTS.md`.
