# Security Policy

## Reporting a vulnerability

If you find a security issue in this repository — including **any leaked organization-specific data** (a real tenant URL, internal hostname, owner email, Entra client-id, or business data that should have been anonymized) — please report it privately rather than opening a public issue.

- Open a [GitHub private vulnerability report](https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) on this repo, **or** email the maintainer listed in `CODEOWNERS`.
- Include the file, line, and what you believe is exposed.

**Response SLA:** we aim to acknowledge a report within **3 business days** and to remove or remediate confirmed leaks within **5 business days** (including history rewrite if needed).

## Scope notes

- This is a public, de-branded kit. Apps in it authenticate as the **running user** (Windows session or Entra browser sign-in) — there are no service accounts, connection-string passwords, or embedded secrets by design.
- Do not commit secrets to any file. These files are loaded into AI context and synced to model providers.
