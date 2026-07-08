# 0001. Publish a de-branded public version of the internal EUDA platform

- Status: accepted
- Date: 2026-06-23

## Context

A private internal platform holds reusable development patterns, AI starter prompts, sample apps, and deploy tooling that help citizen developers build approved internal tools inside M365 instead of using external AI app builders. The patterns and samples are broadly useful and worth sharing publicly, but the source is saturated with organization-specific identifiers (tenant URLs, an Entra client-id, internal SQL hostnames, owner emails, brand names) and two business artifacts containing real schema and business logic.

## Decision

Create a **separate public repository** (`m365-citizen-dev-kit`) that is the anonymized, de-branded version of the upstream — rather than open-sourcing the upstream in place or rewriting its history. The upstream stays private. Content is ported forward (not git-merged) so no internal history leaks. Anonymization uses the **Contoso** convention (`contoso.sharepoint.com`, `Contoso`, `<placeholder>`). License: MIT.

## Consequences

- Clean public history with zero internal commits; the upstream remains the working source.
- A port + de-brand step is required for every piece of content (see [anonymization-plan.md](../anonymization-plan.md)); future upstream changes must be ported deliberately, not synced.
- Two internal business artifacts (a claims-tool migration prompt and a development chat transcript) are **excluded**; a fully fictional migration example replaces them.
- The repo follows an internal repository-documentation standard but does **not** link to its private source; the operative conventions are inlined in `AGENTS.md` so the public repo has no private dependency.

## Options considered
- **Open-source the upstream in place** — rejected: history and live identifiers would leak.
- **`git filter-repo` to scrub history** — rejected: brittle, and the brand/URLs are woven into prose, not isolated to a few blobs; a clean hand-port is safer and produces better public docs.
