# Notice: Building Apps with AI — Use the EUDA App Platform

*Draft for distribution via email/Teams. Replace the bracketed placeholders before sending.*

---

**Subject: Building apps with AI? Great — here's the supported way to do it**

Team,

More of you than ever are building your own tools — dashboards, trackers, report generators, small apps that make your work faster. That's exactly what we want, and we've built a platform to support it.

We've also noticed some of these tools being built on external AI app builders like **Lovable, Bolt, v0, Replit, and Base44**. We need that to stop — not because of what you're building, but because of where it runs. This notice explains the issue and, more importantly, the supported way to do exactly the same thing.

## The supported way: the EUDA App Platform

The **End-User Developed Applications (EUDA) platform** gives you the same describe-it-and-watch-it-appear experience, inside systems your organization already secures and supports:

| You want to… | Use this pattern |
|---|---|
| Prototype an idea, build a one-off tool or visualization | **Claude Artifacts** — describe it in Claude, see it running in seconds. This is the same "vibe coding" experience as Lovable, in our approved AI service |
| Build a team tool — forms, dashboards, trackers with shared data | **SharePoint App Pattern** — runs in our M365 tenant, everyone signs in automatically, data stays in SharePoint |
| Automate your own work — crunch files, generate reports, query company databases | **Packaged Python** — a single file your colleagues run with one double-click; nothing to install, connects to data as *you*, not a service account |

Each pattern comes with a ready-made Claude prompt — copy it as your first message and Claude builds within our conventions. Start here: **[Development Patterns hub — https://contoso.sharepoint.com/sites/euda-sample/Sample Sites/DEVELOPMENT_PATTERNS.aspx]**

## What we're asking you to stop using

**Any external service that hosts company tools or data outside our M365 tenant, or that you paste company data into without an approved agreement.** That includes, but is not limited to:

- **AI app builders:** Lovable, Bolt.new, v0 (Vercel), Replit, Base44, Create, Databutton, Tempo, Emergent, Builder.io, Hostinger Horizons
- **Design tools that generate hosted apps:** Figma Make, Canva Code
- **Consumer AI services:** ChatGPT, Gemini, and similar — for anything involving company data (Claude is our approved AI service)
- **No-code SaaS builders:** Bubble, Glide, Softr, Airtable apps, Retool, Zapier Interfaces

New tools in this category appear monthly — if it builds or hosts something outside your organization's systems, the rule applies even if it isn't named here. When in doubt, ask first.

## Why this matters

When a tool is built on one of these platforms:

- **Company data leaves your organization.** It lives in the vendor's database, under their terms, outside every protection we're required to maintain.
- **There's no access control.** Anyone with the link may be able to see it — there's no Entra sign-in, no permissions, no audit trail.
- **Nobody can support it.** When the builder changes roles or the vendor changes pricing, the tool dies with no migration path.
- **It may put us out of compliance** depending on the data involved — and the person building it usually has no way to know.

The EUDA patterns eliminate all four problems: your apps run in our tenant or on your own machine, sign-in is automatic, the code is reviewable, and there's a documented owner.

## Already built something on one of these platforms?

**No penalty — but come talk to us.** We've already migrated apps onto the platform and will help you do the same; in most cases your tool comes over with the same look and features, plus real sign-on and live company data it couldn't reach before. Contact **[owner name + email]** and we'll get it scheduled.

Questions about whether a specific tool or use case is OK: **[owner name + email / Teams channel]**

Thanks — keep building,

**[Sender name]**
**[Title]**
