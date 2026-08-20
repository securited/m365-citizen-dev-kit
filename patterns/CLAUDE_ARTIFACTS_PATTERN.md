# Claude Artifacts Development Pattern

> **Claude Artifacts Pattern — v1.2** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Use Claude's artifact feature as a first-class step in your development workflow — for prototyping, communication, and handoff to production patterns.

> **Starting a new artifact?** See [CLAUDE_ARTIFACTS_PROMPT.md](CLAUDE_ARTIFACTS_PROMPT.md) for a prompt that produces a portable, handoff-ready artifact following this pattern's conventions. Copy it as your first message.

---

## Executive Summary

Claude generates self-contained, rendered previews called **artifacts** — interactive HTML pages, React components, data visualizations, and diagrams that appear alongside the conversation and update as you refine them. Artifacts are a rapid prototyping and communication tool, not a finished product.

The workflow is **describe → preview → refine → hand off**. Iterate in the conversation until the artifact has the right shape, behavior, and content, then translate it into whatever production pattern applies — a SharePoint App, a static page, a component in your codebase.

Artifacts are especially useful for:
- Exploring a UI or workflow before committing to a production implementation
- Creating a shared visual reference between technical and non-technical stakeholders
- Generating one-off tools, dashboards, or reports that don't need a full deployment
- Prototyping the data model and rendering logic before wiring up real data sources

---

## Artifact Types

### HTML

A self-contained HTML page rendered in an iframe. No build step, no dependencies beyond what is inline or loaded from a CDN. Best for:
- UI mockups and prototypes
- Single-purpose tools (calculators, converters, checklists)
- Dashboards with embedded static data
- Forms and interactive workflows

HTML artifacts can use Tailwind CSS via CDN, Chart.js, D3, or any library with a public CDN URL. Avoid libraries that require a build step or npm.

### React

A React component rendered via a lightweight in-browser runtime. Best for:
- Component-level UI design
- State-driven interfaces (multi-step forms, tabs, filtered lists)
- Anything that benefits from JSX readability

React artifacts use React 18 with hooks. You can use shadcn/ui components and Tailwind. Do not use `import` statements for external packages — the runtime provides React and common UI libraries automatically.

### SVG

A scalable vector graphic rendered directly. Best for:
- Diagrams and flowcharts
- Icons and illustrations
- Simple data visualizations where full chart libraries are overkill

### Mermaid

A diagram defined in Mermaid syntax, rendered automatically. Best for:
- Flowcharts and process diagrams
- Sequence diagrams
- Entity-relationship models
- Architecture overviews

Mermaid is the fastest way to get a diagram into a conversation — one paragraph of description yields a renderable diagram in seconds.

### Code

Syntax-highlighted source code in any language, displayed as a read-only block. Use when the artifact itself is the deliverable — a script, a query, a config file — rather than a rendered preview.

### Markdown

Formatted text rendered as documentation. Use for structured content — specs, guides, changelogs — where the rendering matters more than raw text.

---

## Prompt Patterns

### Starting an artifact

State type, purpose, and constraints upfront. Claude infers the type, but explicit direction produces better first drafts.

```
Create an HTML artifact: a single-page dashboard showing...
Create a React artifact: a multi-step form for...
Create a Mermaid diagram: the sequence of steps in...
```

### Embedding data

For prototypes with realistic content, provide sample data inline or ask Claude to generate it. Embedded-data artifacts work everywhere and require no API access.

```
Use this sample data embedded directly in the artifact — no external fetches:
[paste data or describe what to generate]
```

### Controlling style

Tailwind utility classes are the fastest path to a polished artifact. For SharePoint-like styling, reference the design tokens from the SharePoint App Pattern:

```
Style it to match SharePoint Online: Segoe UI font, #0078d4 blue, #f3f2f1 background,
white surface cards, 1px #e1dfdd borders, 14px base font size.
```

### Iterative refinement

Artifacts update in place when you follow up in the same conversation. Reference only what needs to change:

```
Move the chart to the right column.
Add a filter dropdown above the table that filters by status.
Make the header sticky and add a title.
```

### Asking for variants

```
Show me two layout options — one with a sidebar, one full-width.
Try this with a dark theme.
What would this look like as a table instead of cards?
```

---

## Design Conventions for Portable Artifacts

Artifacts that may become production applications should follow conventions that survive the handoff.

**Use CSS variables for theming.** Define color and spacing tokens as `--var-name` at `:root`, so retheming or extracting into a stylesheet is trivial.

**Keep logic and markup separated.** Put data in a clearly labeled block at the top of the script, rendering functions in the middle, and initialization at the bottom. This mirrors the Shell + Data pattern and makes extraction straightforward.

**Name elements with IDs that describe purpose, not appearance.** `id="user-greeting"`, not `id="blue-text-top"`. IDs survive refactoring; visual descriptions do not.

**Avoid inline event handlers in HTML attributes.** Wire events with `addEventListener` in script. This keeps markup clean and avoids issues in environments with strict content scanning.

**Mark hardcoded data clearly.** Add a comment where real data would come from:

```javascript
// TODO: replace with /_api/web/currentUser?$select=Title
var userName = 'Sample User';
```

---

## Limitations

**No SharePoint API access.** Artifacts run in a sandboxed iframe with no access to SharePoint REST APIs, `_spPageContextInfo`, or the current user's session. All data must be embedded or loaded from a public URL.

**No persistent state between conversations.** Each conversation starts fresh. To keep refining an artifact, stay in the same conversation or paste its code into a new one.

**No file system access.** Artifacts cannot read or write files. Data must be inline or fetched from a public API.

**CDN dependencies.** External libraries must load from a CDN. If your organization blocks CDNs or the artifact needs to work offline, inline the dependencies.

**Iframe sandboxing.** Some browser APIs (clipboard in some browsers, certain storage APIs) may behave differently inside the sandbox than in a deployed app.

---

## Handoff to Production

When an artifact is ready to become a real application, hand it off to the SharePoint App Pattern in this sequence.

**1. Extract the data model.**
Identify all hardcoded data. Each distinct entity type becomes a SharePoint list. Static lookup tables become JSON files in the `_data/` folder.

**2. Map rendering to content.html.**
Copy the artifact's HTML structure into `hello-world_data/content.html` (or your app's equivalent). Remove embedded `<style>` blocks — those move to `styles.css`.

**3. Move styles to styles.css.**
Extract the artifact's CSS into the app's `styles.css`. Convert any Tailwind utility classes to equivalent named CSS classes.

**4. Wire up data fetching.**
Replace every hardcoded data reference with a SharePoint REST API call following the patterns in the SharePoint App Pattern guide. Add loading states and error handling.

**5. Add authentication.**
Replace any placeholder user references with the `/_api/web/currentUser` identity pattern. Add Microsoft Graph calls if profile data or photos are needed.

**6. Replace navigation.**
If the artifact has multiple views, implement them with the `showView()` in-page navigation pattern. No page loads between sections.

**7. Deploy.**
Follow the SharePoint App Pattern guide — request a custom script enablement window, upload the shell and data files, test immediately.

---

## Quick Reference

| Need | Artifact type |
|---|---|
| UI mockup or prototype | HTML or React |
| Process or flow diagram | Mermaid |
| Component-level design | React |
| Data visualization | HTML (Chart.js / D3 via CDN) |
| Architecture diagram | Mermaid or SVG |
| Script, query, or config | Code |
| Spec or documentation | Markdown |
| Icon or illustration | SVG |

| Constraint | Detail |
|---|---|
| SharePoint API | Not available in artifact sandbox |
| External libraries | CDN only — no npm, no build step |
| Session persistence | None — each conversation is independent |
| Max practical complexity | ~500 lines before manageability drops |
| Styling | Tailwind CDN or inline CSS; SP design tokens recommended for consistency |
