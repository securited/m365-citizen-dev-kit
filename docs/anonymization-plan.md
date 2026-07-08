# De-branding & Publication Notes

This kit is the public, de-branded version of a private internal platform. This
document records **how** the content was de-branded for public release and the
rules that keep it clean — without reproducing any of the source's
organization-specific identifiers (that would defeat the purpose).

> The full migration runbook — including the literal source identifiers, the
> exact substitution table, and the executable pre-publish scan — is kept
> **private by the maintainer** (outside this repo). This published note is the
> method and the contributor-facing rules only.

---

## 1. Principles

1. **Reusable platform content ships; business artifacts don't.** The patterns, prompts, sample apps, and deploy tooling are the product. App-specific data (internal reports, development transcripts) is not.
2. **De-brand in prose, not just in config.** Brand and tenant references were woven through guide text, so every ported file was read and de-branded, not just grep-replaced.
3. **No embedded secrets.** The reusable content carries no passwords, keys, or tokens by design — apps authenticate as the running user. The de-branding surface was *identifiers*: brand name, tenant URLs, an Entra client-id, internal hostnames, owner emails, and local machine paths.
4. **The scan is a gate, not a step.** A pre-publish scan for organization markers must come back clean before anything is pushed to a public remote.

## 2. Naming convention

Anonymized identifiers use the **Contoso** convention (Microsoft's standard sample identifiers), so the docs read naturally to an M365 audience:

| Category | Public placeholder |
|---|---|
| Organization / brand | `Contoso`, or "your organization" / "your company" |
| SharePoint tenant | `contoso.sharepoint.com` |
| SharePoint admin center | `contoso-admin.sharepoint.com` |
| Entra app registration name | `Contoso EUDA Applications` |
| Entra client-id | `<your-entra-client-id>` (shared app registration); `<your-pnp-client-id>` for the deploy script (via `PNP_CLIENT_ID`, no built-in default) |
| Entra tenant-id / object-id | `<your-tenant-id>` / `<your-entra-object-id>` |
| Owner / author | `<owner-name>`, `<owner@example.com>` |
| On-prem SQL Server host / database | `<your-sql-server-hostname>` / `<database>`, or the fictional `sqldev.contoso.com` / `OrdersDW` in the example |
| Local absolute paths | relative paths, or paths under this repo |
| Branded design-system labels | "sample design system" (CSS values kept, brand labels renamed) |

## 3. What was excluded vs. ported

- **Excluded entirely** — two internal business artifacts (an app-specific data-migration prompt and a development chat transcript). They contained a live internal SQL hostname, real schema/column names, and real business records — none of it reusable. They were never copied into this repo.
- **Replaced** — those artifacts' teaching value (how to migrate a working app onto the Packaged Python pattern) is preserved by a **fully fictional** worked example, [`samples/migrate-existing-app/`](../samples/migrate-existing-app/MIGRATION_PROMPT.md), built on an invented Contoso "Order Status Report" / `OrdersDW` scenario with generic tables and an `ActiveFlag` column — zero real schema.
- **Ported + de-branded** — the four development patterns (guides, starter prompts, published `.aspx`), the Development Patterns hub and its data, the SharePoint `.aspx` sample apps and Python sample apps, the PnP deploy script, and the local-dev tooling. A few samples had real internal identifiers (a warehouse host, a database name, internal schema/view names, an Entra client-id) baked into code — these were genericized during the port.

## 4. Structure

The upstream kept everything flat in one deploy folder. Here it's split into intent-named top-level folders:

- `patterns/` — all pattern files share one folder (each `.aspx` shell fetches its `*_PATTERN.md` and the `DEVELOPMENT_PATTERNS_data/` folder relative to its own library location, so they must stay co-located).
- `samples/` — each sample `.aspx` keeps its `_data/` companion beside it; Python apps each in their own folder.
- `deploy/Deploy-SampleLibrary.ps1` syncs `patterns/` + `samples/` into a SharePoint document library, preserving structure.

## 5. The pre-publish scan (gate)

Before any push to a public remote, scan the whole tree for organization markers:
the brand name, the tenant host and admin host, the Entra client-id, internal
SQL hostnames, internal database/schema/view names, and owner emails. The
**exact literal token list lives in the maintainer's private runbook**, not in
this public file. The scan must return zero hits (excluding the running user's
own public GitHub handle in `CODEOWNERS`). Also confirm no OS noise
(`.DS_Store`), no local settings (`.claude/settings.local.json`), and no
`.private/` content is staged.

## 6. Contributor rules

These are enforced going forward (see [`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`SECURITY.md`](../SECURITY.md)):

- Never commit a real tenant URL, internal hostname, owner email, Entra client-id, or business data. Use the Contoso placeholders above.
- No secrets in any file — apps authenticate as the running user.
- If you spot a leaked identifier, report it per `SECURITY.md` rather than opening a public issue.

## 7. Open item

- **Public remote** — created at publication time. Run the pre-publish scan immediately before the first push.
