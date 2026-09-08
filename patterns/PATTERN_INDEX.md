# Pattern Index — Read This First

> **Pattern Index — v1.0** · updated 2026-09-03. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A routing guide for an AI assistant pointed at this repository. The seven pattern guides and their seven project prompts total about **353 KB** — far more than you should read, and more than you can hold usefully. This page tells you which two or three documents your task actually needs, what is inside each one, and which parts you cannot safely skip.

> **This index is a map, not a substitute.** It tells you what a guide contains so you can decide to open it. It does not contain the rules themselves, and answering from this page alone will produce plausible, confidently wrong guidance.

---

## The Failure This Page Exists to Prevent

The observed behaviour is reasonable and wrong: an assistant opens the pattern folder, reads the first two or three guides in whatever order the directory listing produced, finds enough to start building, and never opens the rest. What gets missed is never the app-shape guide — it is the **cross-cutting supporting patterns**, because nothing in a build request announces that they apply.

That matters more than ordinary incompleteness, because the three supporting patterns constrain the **data model**, and the data model is the one thing you cannot change later:

- Permission granularity cannot be retrofitted without a data migration — the permissible unit has to be a securable object from the first row.
- Archive provenance columns and the Archives manifest cannot be backfilled — they must exist before the first archive runs.
- A published contract has to be agreed before an integration is coded, because the consumer is already depending on whatever you shipped.

Work through the four steps below before you write any code.

---

## Step 1 — Pick Exactly One App Shape

Every app is one of four shapes. Read that shape's guide and its prompt; ignore the other three.

| If the user wants… | Pattern | Read |
|---|---|---|
| A form, dashboard, tracker, or anything several people open in a browser and share data through | **SharePoint App** | `SHAREPOINT_APP_PATTERN.md` + `SHAREPOINT_APP_PROMPT.md` |
| A throwaway prototype, a visual to discuss, or a one-off tool with no persistence | **Claude Artifacts** | `CLAUDE_ARTIFACTS_PATTERN.md` + `CLAUDE_ARTIFACTS_PROMPT.md` |
| To crunch files, generate reports, run ETL, or query a database from their own machine | **Packaged Python** | `PACKAGED_PYTHON_PATTERN.md` + `PACKAGED_PYTHON_PROMPT.md` |
| Scheduled or background work with no server and no service account | **Worker Pool** | `WORKER_POOL_PATTERN.md` + `PACKAGED_PYTHON_PROMPT.md` + `WORKER_POOL_PROMPT.md` |

Worker Pool is a composition, not a standalone shape — it is a Packaged Python app coordinated through SharePoint lists, and every rule in both parent patterns still applies.

If the request fits none of these — a guaranteed schedule, sub-minute latency, exactly-once execution, regulated data, or anything needing a hosted server — **stop and escalate**. Each guide carries its own "What It Is Not Good For" section naming the boundary.

---

## Step 2 — Check the Cross-Cutting Triggers

**This is the step that gets skipped.** Read the trigger column against the app you are about to build. If any line is true, that supporting pattern is not optional and it has to be applied *before* the lists are designed.

| If this is true of the app… | Also read | What is too late to fix afterwards |
|---|---|---|
| Not everyone who can open the app should see everything in it | `SHAREPOINT_PERMISSIONS_PATTERN.md` + `SHAREPOINT_PERMISSIONS_PROMPT.md` | Permission granularity. The permissible unit must be its own securable object from day one; changing it later is a data migration |
| It creates many objects, or accumulates data that will still be there in three years | `SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.md` + `SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md` | Storage mechanism and archive provenance. `Original*` columns and the Archives manifest cannot be backfilled |
| It reads from, writes to, or triggers work in **another** app | `CROSS_APP_COMMUNICATION_PATTERN.md` + `CROSS_APP_COMMUNICATION_PROMPT.md` | The published boundary. Once a consumer depends on a surface, changing it is a breaking change, not an edit |
| It needs an audit trail of who changed what | `SHAREPOINT_PERMISSIONS_PATTERN.md` | The audit trail only exists because every write happens as the acting user. A service account erases it retroactively |

Two or three of these are commonly true at once. They compose — apply all that trigger.

Attach the supporting prompt **together with** the app's own prompt in the same message. A supporting prompt does not replace the app-shape prompt; it constrains the data model that prompt produces.

---

## Step 3 — Read the Prompt, Not Only the Guide

Each pattern ships two files, and they are not two views of the same content.

| File | What it is | Use it for |
|---|---|---|
| `<PATTERN>_PATTERN.md` | The guide — explains the mechanism, the trade-offs, and the reasoning behind each rule | Understanding *why*, and deciding between options |
| `<PATTERN>_PROMPT.md` | A binding prompt block to be pasted as the first message of a build | The rules themselves, in the form they are meant to be applied |

When you are building rather than explaining, the prompt block is the authoritative constraint set. The guide tells you which judgement calls are yours to make.

---

## Step 4 — Respect the Fixed/Default Distinction

Every rule in every guide is classified. Getting this wrong in either direction is the most common failure in this corpus.

- **Fixed** — deviation breaks the platform, its security model, its audit trail, a protocol guarantee, or supportability. Also covers Microsoft's own service limits. If a Fixed rule blocks the task, stop and escalate rather than engineering around it.
- **Default** — the recommended choice absent a specific reason. Departing is legitimate: name it, say what makes this case different and what you give up, get the user's agreement, and record it in the app's README.

Two misreadings have been observed in real use, and both are worth guarding against explicitly:

- **Do not harden an illustrative figure into a hard limit.** The shell's "roughly 15 KB" became an invented maximum in practice. There is no size limit on the shell; the test is behavioural — no feature code, no application state.
- **"Sensitive data" is not one category.** Secrets, confidential business data, and regulated data have three different answers. The platform can absolutely store confidential data — that is what the permissions pattern is for. Only secrets are barred from files a browser can read.

---

## What Is In Each Document

### SharePoint App Pattern

`SHAREPOINT_APP_PATTERN.md` — 794 lines, 53 KB · prompt 622 lines, 33 KB

The platform's centrepiece: browser applications served from SharePoint itself, with no server and no separate hosting. A boot-only `.aspx` shell in a dedicated document library loads its CSS, HTML, and JavaScript from a companion `_data/` folder at runtime.

**Only this document settles:**

- The shell + `_data/` split, and the two reasons for it — SharePoint's content scanner, and the permission asymmetry between updating an `.aspx` and updating a data file
- Custom-script enablement: the 24-hour window, that it is now self-service with no admin rights, and that the uploader separately needs Design or Full Control at upload time
- Why re-uploading an unchanged `.aspx` outside the window silently breaks the app
- Zero-code authentication, and that `_spPageContextInfo` is undefined in document-library ASPX so identity comes from `/_api/web/currentUser`
- The form digest requirement on every write, fetched from `/_api/contextinfo`
- Runtime module loading through `manifest.json`, so new features never require a shell redeploy
- Where external API data comes from — Power Automate's HTTP action is a **premium** connector, which makes Packaged Python the workhorse ingestion route
- Deploy-script mechanics: upload order, dedicated libraries, and seed-only files

**Jump to:** *Requirements* for anything deployment-related · *Core Concepts* for the shell model and lists-as-database · *Query Design for Large Lists* past 5,000 items · *Getting External API Data Into SharePoint* for third-party data · *Quick Reference* for a one-screen recap.

### Claude Artifacts Pattern

`CLAUDE_ARTIFACTS_PATTERN.md` — 206 lines, 9 KB · prompt 83 lines, 6 KB

The smallest guide, and the right first stop for prototypes. Artifacts are a rapid prototyping and communication tool, explicitly not a deployed application.

**Only this document settles:**

- The six artifact types and when each is the right one
- Prompt patterns for embedding data, controlling style, and requesting variants
- Conventions that keep an artifact portable enough to hand off later
- The hard limitations — no SharePoint REST access, no persistence between conversations, no file system, CDN dependencies, iframe sandboxing
- A seven-step handoff sequence for turning an artifact into a SharePoint App

**Read it when** the user is exploring, or when a request is really a prototype wearing a production costume. Skip it once real shared data is involved.

### Packaged Python Pattern

`PACKAGED_PYTHON_PATTERN.md` — 436 lines, 33 KB · prompt 582 lines, 31 KB

Local-machine automation. One Python file with a PEP 723 inline header, run through `uv` or a double-click launcher, with nothing for the recipient to install.

**Only this document settles:**

- The single-file, zero-install mechanism and the canonical `launch.cmd` copied verbatim
- The two app shapes — Pattern B (script, runs to completion) and Pattern C (Streamlit UI at localhost)
- That identity is the running user, so there are no service accounts and no secrets in files
- The one-approved-library-per-job list
- SQL Server access, and the shared Entra app registration
- Streamlit self-bootstrapping, and why the launcher must say how to stop the app
- The four-file app folder: `app.py`, `launch.cmd`, `README.md`, `HOW-TO-RUN.md`
- Team distribution through a SharePoint site as a release channel, with staged self-update applied by the launcher (new in v2.0)

**Jump to:** *Two App Shapes* to choose B or C · *Start With the Data Path* before designing anything · *Out of Scope — Stop and Escalate* to check the request is in bounds.

### Worker Pool Pattern

`WORKER_POOL_PATTERN.md` — 162 lines, 14 KB · prompt 149 lines, 8 KB

Scheduled and background work with no server, no service account, and no premium licence: a Packaged Python worker on each participant's machine, coordinated through SharePoint lists.

**Only this document settles:**

- The coordination lists — Schedules as data, JobRuns as the audit log
- That claiming a due run is an atomic etag compare-and-set (MERGE + `If-Match`), so exactly one worker gets a 204 and the rest get 412. It is a conditional write, never a lock
- At-least-once execution, which makes idempotency a **Fixed** requirement on every job
- The fencing guard, and that liveness is community-powered — someone must have the app open
- Etiquette toward SharePoint so a pool does not hammer the tenant
- The race proof: the verification every implementation must ship
- A decision table separating this pattern from a Power Automate scheduled flow and from Pattern B plus Task Scheduler

**Read it when** the words "scheduled", "nightly", "in the background", or "automatically" appear. Check its decision table first — a connector-shaped, fully tenant-side job should be a Power Automate flow instead, and this guide says so.

### SharePoint Permissions & Auditing

`SHAREPOINT_PERMISSIONS_PATTERN.md` — 633 lines, 49 KB · prompt 312 lines, 18 KB

Cross-cutting, not an app shape. SharePoint's own ACLs are the authorization layer; the work is shaping storage so they land where they are needed.

**Only this document settles:**

- The permissible unit — the smallest thing two people might need different access to — and that naming it comes *before* the data model
- The securable ladder, with Microsoft's hard numbers: 5,000 unique scopes per list recommended (50,000 supported), 2,000 lists per site collection, and the 100,000-item cliff past which inheritance can no longer be broken or restored
- That security trimming replaces query filters (**Fixed**) — you do not filter by user, you let the ACL do it
- Groups as the join table, one group per unit as the sole ACL entry
- That site owners are automatically the app's administrators, derived from `effectivebasepermissions` and never stored as a role list
- Why the site is the security perimeter, making one-site-per-app a day-one decision rather than a setting
- Seven concrete design shapes (A–G), from folder-per-unit to ACL-as-graph to segregation of duties
- What SharePoint records for free — Author/Editor, versioning, recycle bin, role assignments — and that this audit trail only works because every write happens as the acting user

**Jump to:** *The Permissible Unit* first, always · *Design Shapes* to match your case to a worked example · *Gotchas That Bite* and *Anti-Patterns* before finalising · *Design Checklist* to verify.

### Storage Shape & Lifecycle

`SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.md` — 441 lines, 33 KB · prompt 254 lines, 14 KB

Cross-cutting, not an app shape. Answers how many objects the storage layer creates, which mechanism can carry them, and what happens to data when it gets old.

**Only this document settles:**

- The two questions that pick the mechanism: unit count at three years, and whether a unit needs server-side querying, safe concurrent writes, or per-row history
- What lists buy you (exactly three things) and why files are cheaper at everything else
- That a design provisioning hundreds of lists is a folder of files in disguise
- The hybrid: an index list plus payload files
- Hot/cold tiering with an immutable, self-describing archive envelope and a security-trimmed Archives manifest
- Verify, then delete — never delete, then write (**Fixed**). Write the file, re-read it, verify row count and checksum, write the manifest row, and only then delete the source rows
- Dehydration and rehydration, and the audit trap: rehydrated rows are new items, so SharePoint stamps whoever ran the restore. Version history, item IDs, unique permissions, and attachments do not survive
- Setup as a re-runnable page rather than a written procedure

**Jump to:** *Shape Follows Count and Lifetime* and its decision table before choosing lists or files · *The Archive Contract* when data ages out · *Design Checklist* to verify.

### Cross-Application Communication

`CROSS_APP_COMMUNICATION_PATTERN.md` — 458 lines, 36 KB · prompt 284 lines, 16 KB

Cross-cutting, not an app shape. Answers the cost that one-site-per-app creates and leaves open: how apps reach each other without reaching into each other.

**Only this document settles:**

- The published boundary (**Fixed**): an app's lists are private, and another app reads only what has been deliberately published
- `contract.json` at a well-known path — an API schema carrying each publication's fields, types, plain-English semantics, freshness promise, audience, retention, and version
- The `consumes` array, which turns "who breaks if I change this?" into a registry sweep instead of a mass email
- Four shapes: published dataset (the default), published list, append-only event feed with consumer-held cursors, and request queue
- The request-queue state machine — Pending, Claimed, Succeeded, Failed, Expired, Rejected — with one writer per transition, the response written back on the same item, and a correlation id as the idempotency key
- That claiming a request is the Worker Pool's etag CAS, unchanged
- Additive-only compatibility with tolerant readers; a breaking change is a new version published alongside the old
- The two verifications every implementation ships: a startup contract check and a replay proof

**Jump to:** *The Published Boundary* first · *The Communication Contract* to author `contract.json` · *Shape A–D* to pick the mechanism · *Design Checklist* to verify.

---

## Symptom → Document

When something is already broken, or a specific question has come up, go straight here.

| Symptom or question | Document | Section |
|---|---|---|
| The `.aspx` downloads instead of running | SharePoint App | Requirements |
| `_spPageContextInfo` is undefined | SharePoint App | Authentication Is Free |
| A write returns 403 | SharePoint App | Write Operations and the Form Digest |
| Queries slow or failing past 5,000 items | SharePoint App | Query Design for Large Lists |
| A change would require redeploying the shell | SharePoint App | Adding Modules Without Redeploying the Shell |
| The app needs a credentialed external API | SharePoint App | Getting External API Data Into SharePoint |
| Users must not see each other's rows | Permissions | The Permissible Unit; Security Trimming |
| The app needs an admin role | Permissions | Site Owners Are Automatically Application Administrators |
| Who changed this record, and when? | Permissions | What SharePoint Records for Free |
| The design would create hundreds of lists | Storage Lifecycle | "Hundreds of Lists" Is a Folder of Files in Disguise |
| Data must be retained but the list is growing | Storage Lifecycle | Hot and Cold: The Archive Contract |
| Restored rows show the wrong author | Storage Lifecycle | The Audit Trap |
| The app needs data another app owns | Cross-App | The Published Boundary |
| The app must trigger work in another app | Cross-App | Shape C — The Request Queue |
| It has to run nightly / on a schedule | Worker Pool | When to Choose This Pattern |
| Two workers might run the same job | Worker Pool | Claiming Is a Conditional Write, Not a Lock |
| It has to query SQL Server | Packaged Python | SQL Server Access |
| The user just wants to see the idea | Claude Artifacts | Executive Summary |

---

## Beyond the Patterns

| Path | What it holds |
|---|---|
| `AGENTS.md` | Canonical AI context — folder map, commands, and the required conventions. Useful as a structured cross-check against this page |
| `deploy/examples/Deploy-MyApp.Example.ps1` | The script to copy for a new app's deployment. Minimal by design |
| `deploy/Deploy-SampleLibrary.ps1` | This repo's own deploy script. It publishes the pattern library only — do not point it at an app |
| `docs/RELEASING.md` | The dual-bump rule. Editing any pattern means updating both files of the pair *and* `versions.json` |
| `docs/script-enablement-self-service.md` | How self-service custom-script enablement works, and its security model |
| `patterns/DEVELOPMENT_PATTERNS_data/versions.json` | Authoritative version and changelog for every pattern |
| `samples/hello-world_data/`, `samples/guestbook.aspx`, `samples/euda-worker/` | Working reference implementations. Copy a sample folder rather than starting from an empty file |
| `docs/adoption-notice.md` | Why the platform exists and which external tools it replaces |

**Do not modify:** `samples/euda-worker_data/latest.json` is a first-run seed — the deployed copy is live runtime data — and `samples/exec-summary.aspx` contains inlined minified Chart.js; reformatting it will break the page.

---

## Rules for Reading This Corpus

- **Do not answer from general SharePoint knowledge.** These guides exist because the platform's constraints are specific and frequently counter-intuitive. Open the guide.
- **Do not treat this index as the source.** It names what a document settles; it does not settle anything itself.
- **Check the version before quoting a rule.** Every `.md` here is a point-in-time copy. The hub holds the authoritative version.
- **When editing a pattern, follow `docs/RELEASING.md`.** Both files of the pair, plus a `versions.json` entry, move together.
- **Keep `.md` and `.aspx` in sync.** Each pattern's published page renders its `.md` at runtime, so guide content lives in exactly one place — but the page's own boot code does not.
- **Mind the renderer's limits when editing any `.md` here.** The hub's markdown renderer only recognises a table when the line starts at column 0, only recognises list items at column 0, and handles blockquotes one line at a time. Indenting a table for tidiness makes readers see raw pipe characters.

---

## Every File at a Glance

| File | Lines | Purpose |
|---|---|---|
| `PATTERN_INDEX.md` | — | This page |
| `SHAREPOINT_APP_PATTERN.md` | 794 | Browser apps on SharePoint — the platform centrepiece |
| `SHAREPOINT_APP_PROMPT.md` | 622 | Binding prompt for a new SharePoint app |
| `SHAREPOINT_PERMISSIONS_PATTERN.md` | 633 | Authorization and audit; shapes the data model |
| `SHAREPOINT_PERMISSIONS_PROMPT.md` | 312 | Binding prompt; attach with the app's own |
| `CROSS_APP_COMMUNICATION_PATTERN.md` | 458 | Published contracts between apps |
| `CROSS_APP_COMMUNICATION_PROMPT.md` | 284 | Binding prompt; attach with the app's own |
| `SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.md` | 441 | Sizing, sprawl, archiving, retention |
| `SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md` | 254 | Binding prompt; attach with the app's own |
| `PACKAGED_PYTHON_PATTERN.md` | 436 | Single-file local Python apps |
| `PACKAGED_PYTHON_PROMPT.md` | 582 | Binding prompt for a new Packaged Python app |
| `WORKER_POOL_PATTERN.md` | 162 | Scheduled work with no server |
| `WORKER_POOL_PROMPT.md` | 149 | Binding prompt; attach with Packaged Python's |
| `CLAUDE_ARTIFACTS_PATTERN.md` | 206 | Prototypes and handoff to production |
| `CLAUDE_ARTIFACTS_PROMPT.md` | 83 | Binding prompt for a portable artifact |

On the live site each guide is the matching `.aspx` page — `SHAREPOINT_APP_PATTERN.aspx` and so on. In this repository, read the `.md`.
