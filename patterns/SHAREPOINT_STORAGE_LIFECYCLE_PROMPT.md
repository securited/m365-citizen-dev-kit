# Claude Code — Storage Shape & Lifecycle: Project Prompt

> **Storage Shape & Lifecycle — v1.1** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Copy the block below as your first message when an app will create many objects or accumulate data over time. **Attach the prompt for the app's own pattern with the same message** — [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md), [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md), or [WORKER_POOL_PROMPT.md](WORKER_POOL_PROMPT.md) for the archiver job — and [SHAREPOINT_PERMISSIONS_PROMPT.md](SHAREPOINT_PERMISSIONS_PROMPT.md) whenever access control is also in play. Customize the bracketed sections.

---

```
You are designing the storage shape and data lifecycle of an application whose
data lives in SharePoint: how many objects it creates, which mechanism can
carry them, and what happens to the data when it gets old. The prompt for the
app's own pattern is included with this message and every rule there is
binding; this prompt adds the sizing and lifecycle rules and takes precedence
where they overlap. Deviation from either is a defect.

## How to read this prompt

Sections marked (fixed) are binding: deviation is a defect. Sections marked
(default) are the recommended choice, NOT a prohibition. If a default does not
fit this project, say so, propose the alternative with its trade-off, and get
the user's agreement before building it — then note the decision in the app's
README.

Never silently deviate from a default, and never tell the user that something a
default merely discourages is impossible. If a (fixed) rule is the real
obstacle, stop and escalate rather than working around it.

## Rule 0 — project the count before choosing a mechanism (fixed as a process step)

Before proposing lists, columns, or files, state two numbers and one answer:

  a. How many units will exist today, at one year, and at three years?
  b. Does a unit's CONTENT need server-side querying, safe concurrent writes,
     or per-row history?

Confirm both with the user before designing anything. Then state the mechanism
you are choosing, and the ceiling you are budgeting against.

## Mechanism selection (default — this is the judgement call)

  1-20 units, content needs a list        -> one list per unit
  20-200 units, content needs a list      -> one list per unit; ceiling is
                                             2,000 lists and libraries per
                                             site collection
  200+ units, content needs a list        -> ONE folder per unit inside ONE
                                             shared list or library; rows are
                                             items in the shared list and the
                                             folder carries the ACL
  Any count, content read whole, written
  rarely, one writer at a time            -> one JSON file per unit
  Any count, needs both a queryable
  summary and private detail              -> index list + payload file (below)

Do not silently land on a design that provisions hundreds of lists. If the
count and the content answer point there, stop and say so: folders or files
give the same per-unit ACL for the same one scope, without the schema overhead
or the ceiling. There are real exceptions — a list carries per-row versioning
and safe concurrent writes that a file cannot, so a few hundred genuinely
concurrent, individually-audited units may justify it. Make that case out loud,
with the ceiling arithmetic, rather than defaulting into it.

Concurrency is usually the deciding factor: files have NO transaction safety,
so if two people can edit the same unit at once it must be a list. Keep any
JSON payload file under about 1 MB and a few hundred records.

## The hybrid (default — but "nothing sensitive in the index" is fixed)

When the app needs cross-unit dashboards AND per-unit privacy: one shared index
list with one row per unit carrying only NON-SENSITIVE metadata (id, title,
status, owner, dates), plus one ACL'd payload file per unit carrying the
detail. Cross-unit querying comes from the index; access control comes from the
file.

Hard rule: nothing sensitive goes in the index. If a field cannot be shown to
everyone who can read the index, it belongs in the payload. Call this out
explicitly whenever you add an index column.

## Sprawl control (default — except that the orphan sweep never auto-fixes)

- Never provision speculatively. Create a unit's objects on FIRST USE, not for
  every value in a lookup table.
- Name so it sorts: 2026-Q1, 1042-Project-Halyard. Zero-pad numbers.
- Groups accumulate too (10,000 SharePoint groups per site collection, 5,000
  groups per user). When a unit closes, state whether its group is kept for
  archive read access or removed.
- Propose a scheduled orphan sweep that REPORTS and never auto-fixes: units
  with no group, groups with no unit, role assignments naming deleted
  principals, archive files with no manifest row, manifest rows with no file,
  lists on an older schema version, units never written to.
- Put the live unit count on the admin page against the projected budget.

## Archiving (fixed: verify-then-delete, audit columns, immutability. default: granularity)

Three tiers: HOT (a list, the working set only), COLD (immutable JSON files in
an archive folder the app never writes), GONE (deleted per retention).

The archive file is SELF-DESCRIBING — a reader must not need the app:
archiveSchemaVersion, sourceList, sourceSiteUrl, unit, period, rowCount,
checksum, generatedUtc, generatedBy, columns[], rows[].

- CAPTURE THE AUDIT COLUMNS. Author, Created, Editor, and Modified must be
  inside the file. Once source rows are deleted this file is the only surviving
  record of who did what, and rehydrated rows carry a different trail. An
  archiver that drops these destroys history permanently and silently. This is
  the most expensive mistake available here — never ship an archiver without
  them.
- IMMUTABLE once written. A correction is a NEW file that supersedes the old
  one in the manifest; the old one is retained. Never rewrite an archive.
- Archive a NAMEABLE WHOLE — a period or a closed unit, never an arbitrary
  slice.
- Archive files INHERIT THE UNIT'S ACL. Never invent a new group for them.

Maintain an "Archives" manifest list: Title (file name), Unit, Period,
RowCount, Checksum, FileUrl, ArchivedUtc, ArchivedBy, State (Archived |
Superseded | Rehydrated). It is security-trimmed, so it answers "which archives
may I load?" per user.

VERIFY, THEN DELETE — never delete, then write. Fixed order:
  read source (paged) -> build envelope -> write file -> RE-READ the file from
  SharePoint -> verify row count and checksum -> write the manifest row ->
  only then delete the source rows.
A crash at any point must leave either untouched source data or a complete
archive plus the source data. Deleted rows go to the recycle bin as a second
net. The archiver is a Worker Pool job: idempotent, keyed by unit + period,
"already archived" is success and not an error.

## Archive-aware reads (default — except that archived records stay read-only)

- Hot by default; never load archives on every page load.
- "Include archived" is an explicit opt-in that says what it costs.
- Archived records render READ-ONLY BY CONSTRUCTION — no edit affordances at
  all, not disabled ones — and are visibly marked with their period.
- Filter the manifest to State === 'Archived' when loading, or rehydrated rows
  appear twice.
- Merge for display only. Never write a merged set back to the hot list.

## Rehydration (fixed: the provenance columns and the audit disclosure. default: the rest)

- Copies, never moves. The archive file stays; the manifest row flips to
  Rehydrated.
- Whole units or periods only. Never individual rows.
- Cap it: check the projected resulting row count against the 5,000-item view
  threshold first and refuse with a clear message rather than half-restoring.
- Idempotent: check manifest state first, "already rehydrated" is success.
- Re-dehydrating an edited rehydrated unit writes a NEW archive file and marks
  the old row Superseded.

THE AUDIT TRAP — do not get this wrong. Rehydrated rows are NEW list items, so
SharePoint stamps Author/Editor with whoever ran the rehydration and
Created/Modified with the moment they did. Therefore:
  - Provision OriginalId, OriginalAuthor, OriginalCreated, OriginalEditor and
    OriginalModified IN THE SETUP PAGE from day one. Columns added later are
    empty for everything that came before.
  - Display the Original* values as the record's history and the system columns
    as "restored by X on Y". Presenting system Author as the record's author is
    actively misleading.
  - Per-row version history does NOT survive the round trip. If intermediate
    states matter, either archive the versions too or do not dehydrate that
    unit at all.

Before building rehydration, show the user what does not survive: system
Author/Editor, version history, item IDs, per-row unique permissions, and
attachments unless the archiver copies them. Get an explicit acknowledgement —
"we can always get it back" is true for field values and false for the rest.

## Setup is a page, not a procedure (default — a strong one)

Build a setup page and provision through it rather than walking the user
through Site Settings — a clicked-together site cannot be reproduced, reviewed,
or rebuilt. For a single site with two lists and no permissions work, a short
manual checklist is a defensible call; say so explicitly rather than drifting
into it. When you do build the page, these are its requirements:

  - be idempotent (create on 404, treat field-exists error -2130575306 as
    success). "One-time" means once per site, not once ever
  - preview before it applies and require a button press; never act on load
  - run in order: list -> fields -> indexes -> versioning and version limits ->
    permissions -> seed data. Indexes and versioning MUST be set while the list
    is still empty
  - provision the lifecycle machinery: the Archives manifest list, the archive
    folder and its ACL, and the Original* provenance columns. All are nearly
    free at setup and impossible to backfill
  - gate on effectivebasepermissions (manageLists, managePermissions) up front
    with a plain-English message, never a 403 halfway through
  - verify itself: re-read live state afterwards and display every list, field,
    index, versioning setting, and role assignment as pass/fail
  - stamp a schema version into the app's config
  - be KEPT after go-live as the repair and clone-to-a-test-site tool

## Administrative page (default)

Panels: provisioning state; unit count against budget and ceiling; unique
scopes per list against the 5,000 recommendation; hot row counts against the
5,000-item view threshold and the 100,000-item inheritance wall; storage and
version-history growth; archive inventory (per unit, oldest and newest period,
total archived rows, anything Superseded or Rehydrated); latest orphan-sweep
findings; last archiver run; configuration in effect and who last wrote it;
app version, schema version, owners, last-reviewed date.

Rules: every panel is DERIVED from live state and never stores its own copy;
gate on effectivebasepermissions and degrade with a clear message; state on the
page that reports show what THIS VIEWER may enumerate; give archiving,
rehydrating, deleting, and bulk-editing a dry-run preview plus a deliberate
confirm, and log what it did; link to the Microsoft 365 admin center or Purview
rather than approximating tooling that exists there.

## Out of scope — stop and escalate (fixed)

- Provable retention or provable destruction (retention labels, legal hold,
  defensible disposal) — Purview, IT-owned. A JSON file in a library is an
  operational archive, not a compliance one
- Regulated data (PHI, payment data, export-controlled)
- Datasets that outgrow SharePoint as a store — tens of millions of rows or
  analytical query workloads. Archive OUT to the right platform and keep
  SharePoint as the app surface
- Transactional workloads needing atomicity across objects

---

## Project-Specific Context

**Application name:** [App Name]
**Owner:** [name + email]
**SharePoint site:** [site URL]

**Unit:** [what one unit is — match the permissible unit if permissions apply]
**Unit count today / 1 year / 3 years:** [n / n / n]
**Unit content needs querying, concurrent writes, or per-row history?** [y/n each]
**Mechanism chosen:** [list-per-unit | folder-per-unit | file-per-unit | hybrid]
**Ceiling being budgeted against:** [which limit, and the headroom]

**If hybrid — index columns (must be non-sensitive):** [list them]

**Lifecycle:**
| Question | Answer |
|---|---|
| What makes a row or unit cold? | [age / status / owner action] |
| Archive granularity | [period label or closed unit] |
| How long are archives kept? | [duration] |
| What is finally deleted, and when? | [or "nothing"] |
| Is rehydration required? | [yes/no — if yes, acknowledge what does not survive] |

**Setup page name:** [<app>-setup.aspx]
**Admin page name:** [<app>-admin.aspx]
**Archiver:** [worker job name, schedule]
**Owners (at least two) and review cadence:** [names, cadence]

Begin by confirming the unit count projection and the content question, then
state the mechanism and its ceiling before designing any schema. If the answer
implies hundreds of lists, say so and propose folders or files instead.
```
