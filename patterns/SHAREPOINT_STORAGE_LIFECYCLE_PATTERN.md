# Storage Shape and Lifecycle

> **Storage Shape & Lifecycle — v1.1** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A supporting pattern for apps that will grow: **how many objects the storage layer creates, which mechanism can carry them, and what happens to data when it gets old.**

> **Designing a data model that will grow?** See [SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md](SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md) for a prompt you can give Claude. Attach it **together with** the prompt for the app's own pattern.

---

## Executive Summary

The [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx) pattern answers *who can see what*. This one answers *how many, and how long* — and they are the same design conversation held at two different scales.

A data model that is obviously correct at twenty units can be unworkable at two thousand. A list that is healthy in year one is unusable in year four, not because SharePoint ran out of room, but because thresholds, view performance, and permission operations all degrade with volume. Both failure modes are nearly free to prevent while the lists are empty and expensive to fix once they are not.

Three rules carry the guide:

- **Shape follows count and lifetime.** The permissible unit tells you what must be *separable*. The projected count and the data's lifetime tell you which mechanism can actually carry it. Lists buy querying, safe concurrent writes, and per-row audit; files buy cheapness and effectively unlimited count. A design that would provision hundreds of lists is usually a folder of files in disguise.
- **Provisioning and observation are app features, not chores.** Stand the app up with a setup page and watch it with an admin page — built, reviewed, and deployed like any other part of it. A procedure someone follows by hand is a design nobody can reproduce or verify.
- **Data has a lifetime, and you decide it while the list is empty.** Hot list → cold archive → gone. Deciding this at three years means a migration; deciding it on day one means a column and a scheduled job.

---

## When This Pattern Applies

| Pattern | How it applies |
|---|---|
| [SharePoint App](SHAREPOINT_APP_PATTERN.aspx) | Directly. Its lists, libraries, folders, and `_data/` files are the objects being counted and aged. |
| [Worker Pool](WORKER_POOL_PATTERN.aspx) | The archiver, the rehydrator, and the orphan sweep are all worker jobs — idempotent, scheduled, logged. |
| [Packaged Python](PACKAGED_PYTHON_PATTERN.aspx) | Same storage decisions when a local app reads or writes SharePoint. |
| [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx) | Tightly coupled: scope budgets, group accumulation, and archive ACLs are all shared concerns. Read that guide first. |

Reach for this guide when the app will create more than a handful of objects, or when its data accumulates rather than turning over.

---

## 1. Shape Follows Count and Lifetime (Default — this is the judgement call)

Two questions decide the mechanism, and both must be answered before the first list exists:

> **How many units will there be at three years' growth?**
> **Does a unit's content need server-side querying, safe concurrent writes, or per-row history?**

The first question is about ceilings. The second is about what a list actually buys you — because if the answer is no, a list is an expensive way to store a file.

### The decision table

| Units at 3 years | Content needs querying, concurrent writes, or per-row history | Mechanism |
|---|---|---|
| 1–20 | Yes | One list per unit |
| 20–200 | Yes | One list per unit — against a hard ceiling of **2,000 lists and libraries per site collection** |
| 200+ | Yes | **One folder per unit inside one shared list or library.** Rows are items in the shared list; the folder carries the ACL |
| Any count | No — read whole, written rarely, one writer at a time | **One JSON file per unit** |
| Any count | Both — a queryable summary plus private detail | **Index list + payload file per unit** (below) |

### Lists buy three things; files are cheaper at everything else

| | List | JSON file |
|---|---|---|
| Cost to create one | Schema, fields, indexes, versioning, views — a real provisioning operation | One write |
| Ceiling | 2,000 lists and libraries per site collection | Library file limits only (30 million) |
| Query | Server-side OData: filter, sort, page, expand | None — load the whole file, filter client-side |
| Concurrent writes | Safe, via etag conditional writes | **Unsafe.** Last write wins, no transaction, no warning |
| Audit granularity | Per row: `Author`, `Editor`, and version history | Per file only |
| Cost of a per-unit ACL | One scope | One scope |
| Comfortable size | Unbounded rows | Keep under ~1 MB and a few hundred records |

**Concurrency usually decides it.** If two people can edit the same unit at the same time, it is a list — files have no transaction safety and will silently lose one person's work. If a unit has exactly one writer, or is written only by a job, a file is fine and far cheaper.

### "Hundreds of lists" is a folder of files in disguise

The symptoms are consistent, and worth checking for by name:

- Every list has the same schema, created from the same template
- Each holds a few dozen rows, not thousands
- Nobody queries *across* them; the app always knows which one it wants
- Provisioning a list is part of unit creation, so unit creation is slow and can half-fail
- The list count is heading toward a ceiling you have to think about

That design wants to be one folder per unit, or one file per unit. Both give the same per-unit ACL for the same one scope, with none of the schema overhead and no ceiling worth worrying about.

### The hybrid: index list plus payload file

The strongest shape for most large-N apps, because it separates the two jobs that were fighting each other:

```
Units/                              (library)
  index                             → "Unit Index" list, one row per unit
                                       id, title, status, owner, opened, closed
  1042-Project-Halyard/             (folder — ACL: "Deal 1042 Team")
    unit.json                       → the payload: everything sensitive
    archive/2026-Q1.json
```

One shared **index list** carries only non-sensitive metadata — one row per unit. One **payload file per unit** carries the detail and holds the ACL.

What that buys:

- **Cross-unit querying, dashboards, counts, and sorting** come from the index, cheaply and server-side
- **Per-unit access control** comes from the payload file's ACL — one scope per unit, not one per row
- **A clean answer to "absence is ambiguous"** (see the Permissions guide): the index can show that a unit *exists* — its title and status — to people who may not open it. Or the index row itself can be trimmed when even existence is sensitive. You now have both options; a single mechanism gives you one.

**The one rule that makes it safe: nothing sensitive goes in the index.** The index is the low-security surface by design. If a field cannot be shown to everyone who can read the index, it belongs in the payload. Treat that as a review item, because index columns are exactly what gets added casually later.

### When the count exceeds every mechanism

If the projected unit count is uncomfortable even as files, the unit is probably too fine or the app boundary is wrong. Coarsen the unit, or split the app across sites (see the [SharePoint App Pattern's siting guidance](SHAREPOINT_APP_PATTERN.aspx)). Do not solve it by giving up per-unit separation — that is the one property you cannot add back later.

---

## 2. Controlling Sprawl

Sprawl is what happens when creating an object is cheap, nothing counts them, and nothing ever removes one.

- **Write down the unit-count budget** — today, at one year, at three — next to the ceiling of the mechanism you chose. Then put the live count on the admin page against that budget. A number nobody displays is a number nobody watches, and every ceiling in this guide is one an app crosses silently.
- **Never provision speculatively.** Create a unit's objects on first use, not for every value in a lookup table "so they're ready." Speculative provisioning burns lists, scopes, and groups on units that never get used, and it makes the orphan sweep meaningless — everything looks empty because most of it is.
- **Name so it sorts.** `2026-Q1`, `1042-Project-Halyard`, `EMEA-Pipeline`. Zero-pad numbers so `0042` sorts before `1042`. A convention that sorts stays legible at a thousand units; one that doesn't turns Site Contents into a junk drawer within a year.
- **Groups sprawl too.** One group per unit is the right permission design, and it accumulates against **10,000 SharePoint groups per site collection** (and 5,000 groups per user). When a unit closes, decide explicitly: keep the group so its members can still read the archive, or remove it. Leaving it undecided is how you reach the ceiling.
- **Run an orphan sweep on a schedule** — a [worker job](WORKER_POOL_PATTERN.aspx) that reports and never auto-fixes. What it should look for:

| Finding | Means |
|---|---|
| A unit whose ACL names no group | Provisioning half-failed, or someone edited it by hand |
| A group with no unit | The unit was deleted and the group was not |
| A role assignment naming a deleted principal | Offboarding left a stale grant |
| An archive file with no manifest row | The archiver crashed between the two writes |
| A manifest row with no file | Worse — investigate before anything else |
| A list provisioned by an older schema version | The setup page needs re-running here |
| A unit created and never written to | Speculative provisioning, or an abandoned workflow |

  Auto-fixing any of these is how a sweep deletes something that mattered. Report, and let an owner act.

- **Decommission individual units, not just the app.** What happens to a closed deal's folder, its group, and its archives? Archived and deleted, or kept forever? Decide once, at design time, and encode it — otherwise the answer is always "keep it," forever, by default.

---

## 3. Hot and Cold: The Archive Contract

### Why archive at all

Not to save disk. The reasons are operational, and each one arrives without warning:

- The **5,000-item view threshold** starts failing unindexed queries and views
- Past **100,000 items** in a list, library, or folder, you can no longer break or restore permission inheritance on that container
- **Version history multiplies storage silently** — the 50,000-major-version ceiling is a limit, not a plan
- Query cost and index maintenance grow with the list, for every user, forever
- And the human one: a list that is 95% dead rows makes every view, filter, and query more complicated than the problem actually is

### The three tiers

- **Hot** — a list. Queryable, writable, per-row audit, ACL'd. Holds the working set and nothing else.
- **Cold** — immutable JSON files in an archive folder. Read-only *by construction*: the app never writes them, and the folder grants Read to the app's readers with Contribute only to whoever runs the archiver.
- **Gone** — deleted per the retention decision, or moved out of SharePoint entirely.

### The archive file is self-describing

Someone opening this file in five years must not need the app to make sense of it:

```json
{
  "archiveSchemaVersion": 1,
  "sourceList": "Deal Activity",
  "sourceSiteUrl": "https://contoso.sharepoint.com/sites/euda-deals",
  "unit": "1042-Project-Halyard",
  "period": "2026-Q1",
  "rowCount": 1843,
  "checksum": "sha256:9f2c...",
  "generatedUtc": "2026-08-20T14:02:11Z",
  "generatedBy": "j.okafor@contoso.com",
  "columns": [
    { "name": "Title",       "type": "Text" },
    { "name": "ActivityUtc", "type": "DateTime" },
    { "name": "Amount",      "type": "Number" }
  ],
  "rows": [
    {
      "Id": 8812, "Title": "Diligence call", "ActivityUtc": "2026-02-03T15:00:00Z",
      "Amount": 0,
      "Author": "r.singh@contoso.com",  "Created":  "2026-02-03T15:04:22Z",
      "Editor": "j.okafor@contoso.com", "Modified": "2026-02-11T09:12:40Z"
    }
  ]
}
```

Four rules govern it:

- **Capture the audit columns.** `Author`, `Created`, `Editor`, and `Modified` must be *inside the file*. The moment the source rows are deleted, this file is the only surviving record of who did what — and rehydrated rows will carry a different trail entirely (§4). An archiver that drops these destroys history permanently, silently, and irreversibly. It is the single most expensive mistake in this guide.
- **Immutable once written.** Never rewrite an archive file. A correction is a *new* file that supersedes the old one in the manifest, with the old one retained. A rewritable archive is indistinguishable from a tampered one, which costs you the audit value you were archiving to keep.
- **Archive a nameable whole** — a period (`2026-Q1`) or a closed unit. Never an arbitrary slice, because "which rows are in which file?" has to have a one-word answer.
- **Inherit the unit's ACL; don't invent a group.** Whoever could see the deal can see the deal's archive. Put archive files inside the unit's folder, or in an archive folder granted to the same group.

### The manifest

An `Archives` list is what the app reads to know what exists, without enumerating files:

| Field | Purpose |
|---|---|
| `Title` | Archive file name |
| `Unit` | Which unit it belongs to |
| `Period` | Period label |
| `RowCount` | Rows in the file |
| `Checksum` | Integrity check |
| `FileUrl` | Server-relative URL |
| `ArchivedUtc` / `ArchivedBy` | Provenance |
| `State` | `Archived` · `Superseded` · `Rehydrated` |

Because it is a list, the manifest is security-trimmed like everything else — "which archives may I load?" is answered by SharePoint, not by the app.

### Verify, then delete — never delete, then write (Fixed)

This is the rule that makes archiving safe to automate:

```javascript
function archivePeriod(list, unit, period) {
  return readAllRows(list, unit, period)                      // 1. page the source out
    .then(function (rows) {
      var doc = buildEnvelope(list, unit, period, rows);      // 2. build the envelope
      return writeArchiveFile(doc)                            // 3. write the file
        .then(function () { return readArchiveFile(doc.fileName); })
        .then(function (readBack) {                           // 4. verify a FRESH read
          if (readBack.rowCount !== rows.length) throw new Error('row count mismatch');
          if (readBack.checksum  !== doc.checksum) throw new Error('checksum mismatch');
          return addManifestRow(doc);                         // 5. manifest before delete
        })
        .then(function () { return deleteRows(list, rows); }); // 6. only now
    });
}
```

Every step's position matters. The file exists before the manifest row; the manifest row exists before the delete; and verification reads the file back from SharePoint rather than trusting the object still in memory. A crash anywhere leaves either untouched source data, or a complete archive *plus* the source data — both recoverable, neither lossy. Deleted rows land in the recycle bin, which is the second net (and counts against site storage while it holds them).

**This is a [Worker Pool](WORKER_POOL_PATTERN.aspx) job**, so at-least-once execution applies: key the job by `unit + period`, check the manifest before doing anything, and treat "already archived" as success rather than an error.

### Archive-aware reads

The app has to know how to load cold content, and must never let anyone edit it.

- **Hot by default.** The working set is the common case; don't pay for archives on every page load.
- **Opt in explicitly**, with an "include archived" control that says what it costs — whole files, slower, no server-side filtering.
- **Read-only by construction.** No edit affordances at all on archived records, not disabled ones. Mark each visibly with its period.
- **Merge for display only.** Never write a merged set back into the hot list — that is how archived rows get resurrected as duplicates.

```javascript
function loadUnit(unit, opts) {
  var hot = queryHot(unit).then(function (rows) { return tag(rows, false); });
  if (!opts.includeArchived) return hot;

  return Promise.all([hot, listManifest(unit)])        // manifest is security-trimmed
    .then(function (res) {
      var hotRows = res[0];
      var loadable = res[1].filter(function (m) { return m.State === 'Archived'; });
      return Promise.all(loadable.map(loadArchiveFile))
        .then(function (files) {
          return files.reduce(function (all, f) {
            return all.concat(tag(f.rows, true));      // tagged archived -> rendered read-only
          }, hotRows);
        });
    });
}
```

Note the `State === 'Archived'` filter: rows that have been rehydrated are back in the hot list, and loading their archive file too would show every one of them twice.

---

## 4. Dehydration and Rehydration

Archiving is one-way until someone needs the old data back — a deal reopens, an audit lands, a dispute surfaces. Design the return trip before you need it, because the constraints are surprising.

- **Dehydrate**: hot → cold. Triggered by age, by status (closed, resolved, shipped), or by an owner action. Always a whole unit or period.
- **Rehydrate**: cold → hot. Also always a whole unit or period.

### The rules

- **Rehydration copies; it never moves.** The archive file stays exactly where it is; the manifest row flips to `Rehydrated` so archive-aware reads stop loading it. If rehydration *moved* the file, a crash mid-restore would lose the data outright.
- **Whole units only.** Partial rehydration makes "where does this row live right now?" unanswerable, and guarantees a double-count somewhere.
- **Cap it.** Rehydrating a large archive can push a list straight past the view threshold. Check the projected resulting count first and refuse with a clear message rather than half-restoring.
- **Idempotent and resumable**, like the archiver: check the manifest state first, and treat "already rehydrated" as success.
- **Re-dehydration must reconcile.** Once someone edits a rehydrated row, the original archive file is stale. Write a *new* archive file, set the old manifest row to `Superseded`, and keep both. Never overwrite the original.

### The audit trap (Fixed)

This is the part that is easy to get wrong and impossible to fix afterwards.

Rehydrated rows are **new list items**. SharePoint stamps `Author` and `Editor` with whoever ran the rehydration, and `Created` / `Modified` with the moment they did it. That is completely honest — those columns record who put these rows here — and it is *not* the original history.

So:

- **Provision `OriginalId`, `OriginalAuthor`, `OriginalCreated`, `OriginalEditor`, `OriginalModified` in the setup page from day one**, not the day you first need to restore something. Columns added later are empty for everything that came before.
- **Display the original values as the record's history**, and the system columns as "restored by X on Y." Showing the system columns as the record's provenance is actively misleading.
- **Per-row version history does not survive the round trip.** If the intermediate states of a unit matter — approvals, status transitions, edits under dispute — either archive the versions too (which bulks the file considerably) or do not dehydrate that unit at all.

### What survives the round trip

| | Survives | Notes |
|---|---|---|
| Field values | Yes | Everything the archiver captured, and only that |
| Original author, editor, dates | Only as data | Requires the `Original*` columns provisioned up front |
| System `Author` / `Editor` | No | Become the person who ran the rehydration |
| Per-row version history | No | Gone unless the archiver captured versions explicitly |
| Attachments | Only if copied | The archiver must copy the files as well as the rows |
| Item IDs | No | New IDs are assigned; keep `OriginalId` |
| Per-row unique permissions | No | Re-provision from the unit's group |

Put this table in front of whoever is asking for archiving. "We can always get it back" is true for field values and false for almost everything else, and that is a decision for the data's owner rather than its developer.

---

## 5. Standing It Up: Setup Is a Page, Not a Procedure

**Have Claude build a one-time setup page. Do not click through the SharePoint UI.**

Provisioning by hand feels faster exactly once. What it costs afterwards: nobody can reproduce it, nobody can verify it, nobody can review it before it happens, and the only record is a document that started going stale the moment it was written. A setup page is executable documentation — the design and the record of it become the same artifact.

The payoff shows up in places you didn't plan for: standing up a test site is a click, recovering from someone deleting a column is a click, and provisioning the app's second business unit is a click.

**What a setup page has to do:**

- **Be idempotent.** Create the list on 404; treat the field-exists error `-2130575306` as success; never blindly recreate something already there. "One-time" means once *per site*, not once ever.
- **Preview before it applies.** Show what exists and what it is about to create or change, and require a button press. A setup page that acts on load is a page nobody dares open twice.
- **Run in the right order.** List → fields → indexes → versioning and version limits → permissions → seed data. Indexes and versioning must be set while the list is still empty; a setup page that gets this order wrong produces a site that looks provisioned and has no audit history.
- **Provision the lifecycle machinery too** — the `Archives` manifest list, the archive folder and its ACL, and the `Original*` provenance columns. Every one of these is nearly free at setup and impossible to backfill.
- **Provision permissions, not just schema** — the unit's group and ACL, including the read-back described in the [Permissions guide](SHAREPOINT_PERMISSIONS_PATTERN.aspx). Setup that creates lists but leaves permissions to be clicked in later has solved the easy half.
- **Gate on permission with a plain-English message.** Check `effectivebasepermissions` for `ManageLists` and `ManagePermissions` up front and say "you need to be a site owner to run this — ask one to open this page once," rather than failing halfway through with a 403 and a half-built site.
- **Verify itself.** After applying, re-read live state and display it item by item — every list, field, index, versioning setting, and role assignment, pass or fail. The last screen should be the report you would otherwise go and check by hand.
- **Stamp a schema version.** Write the version it provisioned into the app's config so a later release can detect a site built by an older setup page and offer to bring it forward. Without this, "which sites have the new column?" is a manual audit across every site.
- **Stay after go-live.** Do not delete the setup page. It is the repair tool, the clone-to-a-new-site tool, and the fastest honest answer to "is this site configured correctly?"

Setup runs as the person who clicks it, so an owner with list-creation and permission-management rights should run it once before anyone else is invited in.

---

## 6. Watching It: Administrative Pages

Build one. An app that gives its owners no view of its own state pushes them into Site Settings and the admin center to answer questions the app could answer better — and the numbers that matter most here are exactly the ones nobody thinks to check until something has already broken.

| Panel | Answers | Why it matters |
|---|---|---|
| Provisioning state | Are all lists, fields, indexes, and versioning settings as the setup page intended? | Drift from manual edits shows up here first |
| Unit count vs budget | How many units exist, against the projected budget and the mechanism's ceiling? | The sprawl number nobody watches |
| Scope budget | Unique permission scopes per list, against the 5,000 recommendation | Permission operations start failing near it |
| Threshold headroom | Hot row counts against the 5,000-item view threshold and the 100,000-item inheritance wall | Both change what the app is allowed to do, silently |
| Storage and growth | Site quota used, item counts, largest files, version-history storage | Versioning is the usual surprise; recycle-bin contents count too |
| Archive inventory | Archives per unit, oldest and newest period, total archived rows, anything `Superseded` or `Rehydrated` | Tells you whether the archiver is actually running |
| Orphan sweep | Latest sweep findings, unactioned | Turns a silent report into a visible one |
| Access report | Each unit, its group, member count, and drift between live ACLs and the grants list | The audit answer the Permissions guide says you have to build |
| Configuration in effect | Current values from the seed-only config file, and who last wrote it | Deployed config is live state, not repo state |
| Provenance | App version, last deploy, schema version, named owners, last-reviewed date | Staleness you can see |

**Rules for admin pages:**

- **Derived, never authoritative.** An admin page displays state that lives somewhere else. The moment it keeps its own copy of who-can-see-what or what-was-archived, you have built a two-sources-of-truth problem and given it a friendly UI.
- **Gate and degrade.** Check `effectivebasepermissions` and show non-owners a clear "this page is for the app's owners," not a cascade of 403s. Hiding it is a courtesy — the server is what enforces.
- **Be honest about the viewer's lens.** A permissions or archive report shows what *this viewer* may enumerate. Say so on the page, or an owner-only view gets quietly misread as the whole picture.
- **Preview and confirm destructive actions.** Anything that archives, rehydrates, grants, revokes, deletes, or bulk-edits gets a dry run showing exactly what will change, plus a deliberate confirm. Log what it did.
- **Don't rebuild tenant tooling.** If the real answer lives in the Microsoft 365 admin center or Purview, link to it. An approximation of a compliance report is worse than a link to the real one.

---

## 7. Retention, Ownership, and Decommission

- **Decide retention while the lists are empty.** How long is hot, how long stays archived, what is deleted and when. Writing it down costs a paragraph on day one and a migration on day one thousand.
- **Two named owners, minimum**, reviewed when people change roles. A single owner is an outage, an offboarding incident, and an orphaned site waiting to happen.
- **Offboarding is a storage event as well as a permissions one.** When someone leaves: were they the only owner of anything, and does anything they alone wrote need rehousing?
- **Put the last-reviewed date on the admin page**, not just in the README. A date owners see every time they open the app is a date that gets updated.
- **Write down how the app is retired** — who signs off, what happens to the archives, whether the site is deleted or locked read-only. One site per app makes execution trivial; the decision still needs an owner.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Instead |
|---|---|---|
| A list per unit at hundreds of units | Provisioning cost per unit, a 2,000-list ceiling, and no cross-unit query anyway | Folder or file per unit |
| A JSON file per unit with concurrent writers | Files have no transaction safety; one person's edit vanishes with no error | A list, or a single-writer job |
| Sensitive fields in the shared index list | The index is the low-security surface by design | Metadata in the index, detail in the ACL'd payload |
| Provisioning units speculatively | Burns lists, scopes, and groups on units nobody uses, and makes orphan sweeps meaningless | Create on first use |
| Deleting source rows before verifying the archive | A failed write plus a completed delete is unrecoverable data loss | Write, re-read, verify, manifest, then delete |
| An archiver that drops `Author` / `Created` | Once the rows are gone, the file is the only record — and it no longer has one | Capture audit columns in the envelope |
| Rewriting an archive file to correct it | A mutable archive is indistinguishable from a tampered one | New file, supersede the old in the manifest, keep both |
| Rehydrating and presenting system `Author` as the record's history | It names the restorer, not the author | `Original*` columns, provisioned up front |
| Editing archived records in place | Cold storage is read-only by construction; an editable archive is just a slow list | Rehydrate the whole unit first |
| An orphan sweep that auto-fixes | Sooner or later it deletes something that mattered | Report; let an owner act |
| Provisioning by clicking through Site Settings | Unreproducible and unverifiable; the only record is a document that goes stale | A re-runnable setup page |
| Deciding retention once the list is large | Moving or trimming a big list is expensive and permission-sensitive | Decide while it is empty |

---

## Design Checklist

1. **Project the unit count** at today, one year, and three years. Write the number down.
2. **Answer the content question**: does a unit's content need server-side querying, safe concurrent writes, or per-row history? If no to all three, it is a file.
3. **Pick the mechanism** from the decision table, and record the ceiling you are budgeting against.
4. **Decide whether you need the hybrid** — a queryable index plus an ACL'd payload — and if so, write down what may never appear in the index.
5. **Decide the data's lifetime**: what makes a row cold, how long archives are kept, and what is finally deleted.
6. **Design the archive envelope**, including the audit columns, and the `Archives` manifest schema.
7. **Decide whether rehydration is required at all.** If it is, provision the `Original*` columns now and get the owner's acknowledgement of what does not survive the round trip.
8. **Write the setup page before provisioning anything by hand** — idempotent, previewed, correctly ordered, lifecycle-aware, permission-gated, self-verifying, schema-stamped, and kept.
9. **Write the admin page** with the unit count, scope budget, threshold headroom, and archive inventory on it.
10. **Schedule the archiver and the orphan sweep** as idempotent worker jobs, and put their last-run times on the admin page.
11. **Name the two owners, the review cadence, and the retirement plan.**

---

## What This Pattern Is Good For

- Apps whose object count grows with usage — one per deal, case, client, vendor, region, or person
- Anything that accumulates time-series or activity data that will eventually be mostly historical
- Deciding between a list and a file when both would work today and only one works in three years
- Making "we can always get it back" a true statement instead of an assumption

## What It Is Not Good For — Escalate Instead

- **Data that must be provably retained or provably destroyed.** Retention labels, legal hold, and defensible disposal are Microsoft Purview capabilities and IT-owned; a JSON file in a library is an operational archive, not a compliance one.
- **Regulated data** (PHI, payment data, export-controlled). Same boundary as every other pattern.
- **Datasets that outgrow SharePoint as a store** — tens of millions of rows, sub-second analytical queries, or anything wanting a warehouse. Archive *out* to the platform that fits, and keep SharePoint as the app surface.
- **Real-time or transactional workloads.** Neither lists nor files give you transactions across objects.

---

## Quick Reference

| Need | Use |
|---|---|
| Choose list vs file | Does the unit's content need querying, concurrent writes, or per-row history? If no to all three, file |
| Hundreds of units | Folder per unit in one library, or file per unit — never a list per unit |
| Cross-unit dashboard plus per-unit privacy | Index list (non-sensitive metadata) + ACL'd payload file per unit |
| Keep a growing list usable | Archive cold periods out; keep the hot list to the working set |
| Write an archive safely | Write file → re-read → verify count and checksum → manifest row → delete source |
| Know what archives exist | The `Archives` manifest list — security-trimmed, so it answers per user |
| Load archived content | Opt-in, whole-file, tagged read-only, filtered to `State === 'Archived'` |
| Bring old data back | Rehydrate a whole unit; the file stays, the manifest row flips to `Rehydrated` |
| Preserve history across a round trip | `Original*` columns provisioned at setup — system `Author` becomes the restorer |
| Correct an archive | New file, old row `Superseded`, both retained — never rewrite |
| Stand up a site | A re-runnable, self-verifying setup page — never the SharePoint UI |
| Catch drift and orphans | Scheduled sweep that reports; an owner acts |
| Watch the silent ceilings | Admin page: unit count, unique scopes vs 5,000, rows vs 5,000 and 100,000, version storage |
