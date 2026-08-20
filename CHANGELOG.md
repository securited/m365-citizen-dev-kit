# Changelog

All notable changes to this repository are documented here. Newest first.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Initial repository scaffold brought into compliance with the Repository
  Documentation & AI Context Standard: canonical `AGENTS.md`, `CLAUDE.md`
  import, `README.md`, `LICENSE` (MIT), `SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `CODEOWNERS`, and the `docs/` + `docs/decisions/` layer.
- `docs/anonymization-plan.md` — notes on how the kit was de-branded for
  publication (the Contoso convention, what was excluded vs. ported, the
  pre-publish scan, and contributor rules).
- `patterns/` — four development patterns (Claude Artifacts, SharePoint App,
  Packaged Python, Worker Pool): guide, starter prompt, and published `.aspx`
  each, plus the Development Patterns hub and its `versions.json`/`samples.json`.
- `samples/` — SharePoint `.aspx` demos (hello-world, guestbook, exec-summary,
  diagnostics, worker-status) with `_data/` companions; single-file Python apps
  (csv-merge-report, data-explorer, sql-connection-test, sql-schema-explorer,
  euda-worker); and a fully fictional `migrate-existing-app` worked example.
- `deploy/Deploy-SampleLibrary.ps1` — PnP.PowerShell sync of `patterns/` +
  `samples/` to a SharePoint library; no built-in Entra app id (supply your own).
- `.claude/` local preview (`serve.ps1`) and run configs (`launch.json`);
  `docs/adoption-notice.md` and `docs/script-enablement-self-service.md`.

### Added
- Two **supporting patterns** (de-branded), applied alongside a core pattern:
  **SharePoint Permissions & Auditing 1.1** — site/list/folder/file permissions
  as the app's authorization layer, plus a no-code audit trail; and
  **Storage Shape & Lifecycle 1.1** — object counts, the mechanism that can
  carry them, and archiving as data ages.
- `hello-world` rebuilt on the platform/manifest architecture: a boot-only
  `.aspx` shell (~6.8 KB) loading `platform.js` + `app.js`, with feature modules
  (`dashboard.js`, `messages.js`, `metrics.js`) listed in
  `hello-world_data/manifest.json` and loaded at runtime — adding a module never
  redeploys the shell.

### Changed
- Pattern updates (de-branded): **SharePoint App 1.1 → 1.7** (SPA-redirect Graph
  procedure, shell content rule + runtime module loading, seed-only config,
  inferred enablement, manifest pre-flight, one-site-per-app siting),
  **Packaged Python 1.3 → 1.6** (quieter Pattern C startup, stop-the-app banner,
  HOW-TO-RUN guidance), **Worker Pool 1.2 → 1.4**, **Claude Artifacts 1.0 → 1.2**.
- All six guides now label rules **Fixed** (deviation breaks the platform, its
  security model, or its audit trail) vs **Default** (the right answer absent a
  specific reason), with a protocol for departing from a default.
- Earlier: **Packaged Python 1.2 → 1.3** (de-branded): shared app registration confirmed
  consented for the SharePoint list path (a typical app needs nothing from IT);
  recommends a blank Communication site as the team release channel.
- **Worker Pool 1.1 → 1.2** (de-branded): registration-consent verification
  recorded; aligned with Packaged Python 1.3.
- Earlier: **SharePoint App 1.0 → 1.1** (correctness fixes; MSAL-browser Graph
  guidance), **Packaged Python → 1.2** (SharePoint-first storage, shared Entra
  app registration, `version.json` release channel), **Worker Pool → 1.1**.
  Claude Artifacts stays 1.0 (pattern-page version-display fix only).
- The `euda-worker` sample now signs in through the shared app registration via
  `EUDA_WORKER_CLIENT_ID` / `EUDA_WORKER_TENANT_ID` (placeholders in this repo).
