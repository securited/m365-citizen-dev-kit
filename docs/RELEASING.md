# Releasing a Pattern Update

Checklist for publishing a new version of any development pattern (SharePoint App, Packaged Python, Worker Pool, Claude Artifacts). A pattern version lives in **three places that must move together** — missing one is exactly how the pattern pages ended up displaying stale versions in July 2026.

## Checklist

1. **Bump the synced version headers** — the `> **<Pattern> — vX.Y** · updated YYYY-MM-DD` line at the top of **both** files of the pair:
   - `patterns/<PATTERN>_PATTERN.md`
   - `patterns/<PATTERN>_PROMPT.md`

   The pattern guide and project prompt share one version number; a change to either bumps both.

2. **Add a changelog entry** in `patterns/DEVELOPMENT_PATTERNS_data/versions.json`:
   - Update the pattern's `"current"` field.
   - Prepend a new object to its `"versions"` array (newest first) with `version`, `date`, `summary`, and `changes`.
   - This file drives the version badge on each pattern page, the "Pattern Versions" section at the bottom, and the version chips on the Development Patterns hub. Validate it parses: `Get-Content patterns/DEVELOPMENT_PATTERNS_data/versions.json -Raw | ConvertFrom-Json`.

3. **Commit and push**, then **deploy** with `deploy/Deploy-SampleLibrary.ps1`. Two tiers:
   - **Data-only changes** (`.md` bodies, `versions.json`, anything in a `_data/` folder): deploy anytime. The script detects that no `.aspx` needs uploading and skips the tenant-admin sign-in on its own — no flag required.
   - **`.aspx` shell changes**: require the custom-script enablement window and an uploader with Design or Full Control. The script opens the window itself, self-service, as the signed-in user — `euda-sample` holds a grant, so no admin rights are needed. `-TenantAdminEnablement` falls back to `Connect-SPOService`.
   - The script also runs a **pre-flight** on every `manifest.json` (valid JSON, modules present, `FALLBACK_MODULES` in sync) and aborts rather than uploading a broken app. `-SkipPreflight` bypasses it only to recover a broken deployment.

4. **Verify on the live site**: the pattern page shows the new version badge in its header, the new entry appears under "Pattern Versions," and the hub card chip matches.

## Versioning conventions

- **Minor bump (1.x)** — guidance changes, new sections, corrections. The common case.
- **Major bump (x.0)** — a breaking change to the pattern's contract (e.g., a different canonical launcher, a changed coordination protocol). Call the migration out in the changelog summary.
- An entry that hasn't been deployed to the site yet may still be amended; once it's live on the hub, add a new version instead of rewriting history.
- Dates are the date the change ships, not the date work started.

## Related

- Sample apps under `samples/` version independently of the patterns (e.g., a `__version__` in `app.py` + `version.json` for team-distributed Packaged Python apps — see that pattern's Distributing section).
