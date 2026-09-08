# Contributing

Thanks for your interest. This kit is meant to be copied and adapted — most "contributions" are improvements to the patterns, prompts, and sample apps.

## Ground rules

1. **Never commit organization-specific data.** This is a public repo. No real tenant URLs, internal hostnames, owner names/emails, Entra client-ids, or business data. Use the placeholders from [docs/anonymization-plan.md](docs/anonymization-plan.md) (`contoso.sharepoint.com`, `Contoso`, `<your-pnp-client-id>`, etc.).
2. **No secrets.** Apps authenticate as the running user. Don't add passwords, keys, or tokens to any file.
3. **Keep `AGENTS.md` current.** If you change a command, convention, folder, or generated file, update [`AGENTS.md`](AGENTS.md) in the same change. It is the canonical AI context; pointer files (`CLAUDE.md`) must not carry unique content.

## Workflow

1. Branch from `main`.
2. Make your change. For a pattern change, follow the dual-bump rule (update `versions.json` *and* the matching `*_PATTERN.md` / `*_PROMPT.md` version headers).
3. Run the anonymization scan — `pwsh -NoProfile -File deploy/Test-Anonymization.ps1` — and make sure it exits 0. See [the anonymization plan](docs/anonymization-plan.md) for what it checks.
4. Open a PR. Significant structural or publication decisions get an ADR under [`docs/decisions/`](docs/decisions/).

## Conventions

See [`AGENTS.md`](AGENTS.md) for the folder map, per-pattern file layout, and required conventions.
