# Claude Code — Claude Artifacts Pattern: Project Prompt

> **Claude Artifacts Pattern — v1.0** · updated 2026-05-21. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

Copy and paste the block below as your first message when starting a new Claude artifact. Customize the bracketed sections for your specific project.

---

```
You are building a self-contained Claude artifact — a single rendered preview that runs in a sandboxed iframe alongside the conversation. An artifact is a rapid prototyping and communication tool, not a deployed application. Follow all conventions below exactly — they keep the artifact portable and make it hand off cleanly to a production pattern later.

---

## Artifact Type

Pick the simplest type that fits the goal and state it explicitly:
- **HTML** — a self-contained interactive page. The default for tools, dashboards, forms, and mockups.
- **React** — component-driven, state-heavy UI (multi-step forms, tabs, filtered lists). React 18 with hooks. You may use shadcn/ui and Tailwind. Do **not** write `import` statements for external packages — the runtime provides React and common UI libraries automatically.
- **SVG** — diagrams, icons, and simple visualizations.
- **Mermaid** — flowcharts, sequence diagrams, entity-relationship models, architecture overviews.

---

## Self-Contained Constraints (hard requirements)

- **No backend and no authenticated APIs.** The artifact runs in a sandbox with no access to SharePoint, `_spPageContextInfo`, the file system, or any logged-in session.
- **All data is embedded inline** or fetched from a fully public URL. For prototypes, embed realistic sample data directly in the code rather than calling out to a service.
- **No build step and no npm.** External libraries load from a public CDN only (e.g. Tailwind, Chart.js, D3). If the target environment may block CDNs, inline the dependency instead.
- **No persistence.** State resets on reload and does not carry between conversations. Do not assume local storage or a database.

---

## Portability Conventions (so it survives handoff)

- **Theme with CSS variables.** Define color and spacing tokens as `--name` at `:root` so the look can be rethemed or extracted into a stylesheet without hunting through the markup.
- **Separate data, logic, and markup.** Put data in a clearly labeled block at the top of the script, rendering functions in the middle, and initialization at the bottom. This mirrors the production Shell + Data pattern and makes extraction straightforward.
- **Name elements by purpose, not appearance** — `id="user-greeting"`, never `id="blue-text-top"`. IDs survive refactoring; visual descriptions do not.
- **No inline event handlers in HTML attributes.** Wire events with `addEventListener` in script. This keeps markup clean and avoids issues in environments with strict content scanning.
- **Mark every hardcoded value** with a comment naming where real data would come from:
  ```javascript
  // TODO: replace with /_api/web/currentUser?$select=Title
  var userName = 'Sample User';
  ```

---

## Styling

Tailwind utility classes are the fastest path to a polished result. If this artifact is likely to become a SharePoint application, match the platform design tokens so the handoff keeps its look: Segoe UI font, #0078d4 blue, #f3f2f1 background, white surface cards, 1px #e1dfdd borders, 14px base font size.

---

## Handoff Readiness

Assume this artifact may later become a real application under another pattern (most often the SharePoint App Pattern). Keep the data model explicit and the markup and styles cleanly separable so that, on handoff, each hardcoded entity can become a SharePoint list or a JSON file, the HTML can move into `content.html`, and the CSS can move into `styles.css` with minimal rework.

---

## Project-Specific Context

**Artifact purpose:** [what it does / who uses it]
**Artifact type:** [HTML | React | SVG | Mermaid]
**Sample data:** [describe or paste the data to embed]
**Views/sections:** [list the screens or tabs, if there is more than one]
**Target production pattern (if any):** [SharePoint App Pattern | static page | none — prototype only]
**Styling:** [SharePoint design tokens | custom — describe]

Begin by confirming the artifact type and the shape of the sample data, then produce the artifact as a single self-contained block.
```
