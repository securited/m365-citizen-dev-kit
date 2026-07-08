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

### Changed
- **Packaged Python 1.2 → 1.3** (de-branded): shared app registration confirmed
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
