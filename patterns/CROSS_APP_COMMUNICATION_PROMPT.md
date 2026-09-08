# Claude Code — Cross-Application Communication: Project Prompt

> **Cross-Application Communication — v1.1** · updated 2026-08-26. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Copy the block below as your first message when an app will read from, write to, or trigger work in another application. **Attach the prompt for the app's own pattern with the same message** — [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md), [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md), or [WORKER_POOL_PROMPT.md](WORKER_POOL_PROMPT.md) when a worker services the queue — plus [SHAREPOINT_PERMISSIONS_PROMPT.md](SHAREPOINT_PERMISSIONS_PROMPT.md) whenever the published data is not visible to everyone, and [SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md](SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md) when a feed or queue will accumulate. Customize the bracketed sections.

---

```
You are designing how this application communicates with another application on
the EUDA platform: what it publishes, what it consumes, and the contract that
makes the dependency safe. The prompt for the app's own pattern is included with
this message and every rule there is binding; this prompt adds the integration
rules and takes precedence where they overlap. Deviation from either is a defect.

## How to read this prompt

Sections marked (fixed) are binding: deviation is a defect. Sections marked
(default) are the recommended choice, NOT a prohibition. If a default does not
fit this project, say so, propose the alternative with its trade-off, and get
the user's agreement before building it — then note the decision in the app's
README.

Never silently deviate from a default, and never tell the user that something a
default merely discourages is impossible. If a (fixed) rule is the real
obstacle, stop and escalate rather than working around it.

## Rule 0 — confirm these are two applications (fixed as a process step)

Before designing anything, answer three questions out loud:

  a. Which app OWNS each piece of data crossing the boundary? Exactly one owns
     it. If both need it as their system of record, they are one app — say so
     and stop.
  b. Does the consumer need a snapshot, a notification, or an action?
  c. How stale may the data be before the consumer is wrong? Give a number.

If the answer to (a) is "both" or the answer to (c) is "it must be live and
queried row by row at scale", the boundary is drawn in the wrong place. Say so
before building an integration that papers over it.

## The published boundary (fixed)

- An app's internal lists and files are PRIVATE. Never read another
  application's internal list, even though SharePoint will happily allow it.
  Reading anything not named in that app's contract is a defect in THIS app.
- Publish a PROJECTION, not the internal schema. Expose the fields consumers
  need, in the shape they need, so the producer stays free to refactor behind it.
- Name published objects so the boundary is visible in site contents: the app
  prefix plus a "Pub" segment — "<Prefix> Pub Requests", "<Prefix> Pub Events".
- Break inheritance on each published object and grant one group sized for the
  consuming audience (see the permissions prompt). The consumer's users need
  read on the published object and nothing else in the site.

## Choose the shape deliberately (default — but state the choice and why)

  Published dataset — a JSON snapshot in <app>_data/. Read-mostly, whole-file,
    tolerant of staleness. THE DEFAULT; use it unless a reason rules it out.
  Published list    — when consumers need server-side filtering, per-row
    permissions, or per-row history.
  Event feed        — append-only published list; several consumers react to
    things that happen, each holding its own cursor.
  Request queue     — consumer writes a request item, provider does the work and
    writes the result back on the same item. Asynchronous, auditable.
  Direct call       — Power Automate HTTP trigger, only when a user is waiting
    and the answer must arrive in well under a second.

Cross-site REST needs no CORS work (one tenant, one origin). Two facts to honor:
a WRITE into another site needs a digest from THAT web
(POST /sites/<other>/_api/contextinfo), and search (/_api/search/query) is
index-lagged by minutes to hours, so it is for discovery and reporting, never
the read path a workflow depends on.

## The contract (fixed)

Every app that publishes anything writes <app>_data/contract.json — one
well-known filename, one predictable path, deployed with the app.

It carries: app id / name / siteUrl / owner / status / lastReviewedUtc; a
"publishes" array; and a "consumes" array. Each publication states kind
(dataset | list | event | request), name, version, location, audience group,
retention, and for every field its name, type, whether it is required, and its
SEMANTICS in plain English. Datasets add a freshness promise
(maxStalenessMinutes); feeds add cursorField, retentionDays and
pollIntervalSeconds; queues add operations, expiresAfterMinutes, the
idempotency key, and the authorization rule.

- "consumes" is NOT optional and is not an afterthought. Declare every
  dependency the day the code takes it, each with contractUrl, the version
  range relied on, what it is used for, and degradesTo — what this app does
  when the dependency is missing, stale, or an unknown version. An integration
  with no answer to degradesTo is not finished.
- Register the contract URL in the site registry row (a ContractUrl column).
  The registry is an INDEX; the contract file is the truth. Never duplicate
  contract content into the registry — it will drift.
- Field SEMANTICS are the point. "VendorId: Text" tells a consumer nothing;
  "the Contoso vendor number, not the ERP surrogate key" prevents the bug.

## Versioning and compatibility (fixed)

- Additive only within a version: add optional fields; never rename, remove,
  retype, or narrow one.
- NEVER repurpose a field. Changing what a name means while the name and type
  stay put produces confidently wrong data for months. New meaning, new name.
- Every consumer is a TOLERANT READER: ignore unknown fields, never depend on
  field order, never fail on an addition.
- A breaking change is a new version published ALONGSIDE the old, the old
  marked deprecated with a removal date, and the consumers found by sweeping
  the registry's contracts for this app in their "consumes".
- Stamp SchemaVersion on every event and request ROW, not only in the contract
  — records outlive the contract that described them.
- Bump the version when the published meaning changes, not when the code does.

## Published dataset rules (fixed where marked)

- Self-describing envelope (fixed): datasetSchemaVersion, dataset,
  generatedUtc, generatedBy, rowCount, rows.
- Write with a single files/add(overwrite=true) call. Never empty the file
  first — that window is indistinguishable from "no rows" to a consumer.
- Register the file as SEED-ONLY in the deploy script (fixed): if the app can
  write it, the deploy must not, or a redeploy publishes stale data to every
  consumer at once.
- Every consumer UI showing this data shows generatedUtc's age (fixed).

## Event feed rules (fixed where marked)

- Fields: Title (globally unique event id), EventType, SubjectId, OccurredUtc
  (when it HAPPENED), PayloadJson, SchemaVersion.
- Consumers hold their own cursor in their OWN storage and read forward:
  $filter=Id gt <cursor>&$orderby=Id&$top=N. A consumer NEVER writes to the
  producer's list (fixed) — acknowledgements there contend on the producer's
  items and freeze its retention.
- Order by Id to READ (monotonic, gappy); use OccurredUtc to REASON. They are
  not the same ordering when the producer batches or backfills.
- Delivery is at-least-once: every handler must be idempotent (fixed). Key side
  effects by event id; upsert rather than append.
- Every feed consumer needs a COLD-START path (fixed): what it does when its
  cursor falls outside retention, and on its very first run — normally a full
  resync from the matching dataset, then resume at the head.
- Index the feed's filter columns and enable versioning while the list is
  empty. Neither takes afterwards.

## Request queue rules (fixed)

- Fields: Title (correlation id, generated by the requester, also the
  idempotency key), Operation, PayloadJson, SchemaVersion, Status
  (Pending | Claimed | Succeeded | Failed | Expired | Rejected), ClaimedBy,
  ClaimId, ExpiresUtc, CancelRequested, ResultJson, ErrorText, CompletedUtc.
  Author and Created come free and are the ones that matter.
- State machine: Pending -> Claimed -> Succeeded | Failed | Expired, plus
  Pending -> Rejected for authorization or validation failure. Only the
  requester creates; only the provider leaves Pending; nothing returns to
  Pending. One writer per transition — a list item has exactly one etag.
- Where more than one provider instance can run, claiming is the Worker Pool's
  conditional write: MERGE with If-Match: <etag captured at read>, setting
  Status=Claimed, ClaimedBy and a fresh ClaimId. 204 = ours; 412 = another
  instance won, which is normal coordination and never logged as an error.
  Never claim with If-Match: * . Apply the fencing guard: if execution starts
  long after the claim, re-read and abort unless ClaimId is still ours.
- Operation is a key into a catalog of functions the provider's owner wrote and
  reviewed. An unknown Operation is a Rejected row with a clear message, never
  a crash. NOTHING from PayloadJson becomes code, a file path, a URL, or a
  query fragment.
- IDENTITY AND AUTHORIZATION — the pattern's most expensive mistake:
    * The provider executes as ITSELF, not as the requester, so the queue hands
      every writer the provider's reach. Treat it as a privilege boundary.
    * The requester is the Author SharePoint stamped on the item. NEVER trust a
      RequestedBy field — that is the caller's claim, useful for display only.
    * Re-check authorization at PROCESSING time against a list the provider
      controls, not at submit time and not by list permissions alone. A grant
      revoked after submission must be seen. Unauthorized -> Rejected, which is
      also the audit record that someone tried.
    * Where requests are sensitive to each other, set ReadSecurity: 2 and
      WriteSecurity: 2 on the queue (zero unique scopes). Neither applies to
      site owners or collection administrators.
- Timeouts: the requester sets ExpiresUtc from the contract, polls its own item
  on the contract's interval, and HAS a defined give-up behaviour. The provider
  never starts an expired request and sweeps them to Expired.
- Re-submitting a completed correlation id returns the EXISTING result rather
  than doing the work twice. That rule is what makes retries safe.
- Cancellation is best-effort: the requester sets CancelRequested; the provider
  checks it immediately before side effects and after long steps. Say
  "best-effort" in the contract rather than implying a guarantee.

## Direct call rules (fixed)

- The Power Automate trigger URL is a bearer secret. It never goes in a shell
  or in _data/ where a browser can read it.
- The flow runs as its connection owner — same privilege boundary as a queue,
  with a weaker audit trail. Where the audit matters, have the flow write the
  request and result to a list as it goes.
- A timed-out synchronous call leaves the caller unsure whether the work
  happened. Carry a correlation id and make the operation idempotent, or state
  the ambiguity plainly.

## Verification — build both of these (fixed)

- CONTRACT CHECK: at startup the consumer fetches the producer's contract.json,
  confirms the publication exists at a version it understands and that every
  field it depends on is present. A mismatch produces a specific message naming
  app, publication, expected version and found version, and the app falls back
  to its declared degradesTo. This turns a future breaking change into a
  diagnosable message instead of wrong data.
- REPLAY PROOF: deliver the same event, or submit the same correlation id,
  twice, and demonstrate the consumer's state is identical after the second.
- Where several providers can claim, the Worker Pool race proof applies
  unchanged: N simultaneous claims against one etag, exactly one 204.

## Failure and freshness (default, except where noted)

- Show the SOURCE and the AGE wherever cross-app data appears (fixed). A stale
  number that looks live is worse than no number.
- Degrade to the declared fallback with a plain message naming the other app
  and when it last published — never a spinner and never a stack trace.
- Poll on the contract's stated interval WITH JITTER; honor Retry-After on 429
  and 503. Consumers that start on the hour synchronize into a spike.
- There are no cross-app transactions. Where two apps must agree, one owns the
  truth and the other reconciles: compare, report drift, repair — a view
  someone actually looks at.

## Anti-patterns — do not produce these

- Reading another app's internal list because it is reachable
- A shared "integration list" with two writers and no owner
- Two apps writing the same item, split by column
- Trusting a RequestedBy field for authorization
- A contract listing publishes but not consumes
- Treating the event feed as the system of record
- Blocking a UI on a queued request
- Secrets in a request payload
- Polling every few seconds against an hourly feed

## Out of scope — stop and escalate (fixed)

- Guaranteed delivery, guaranteed ordering, exactly-once semantics
- Transactions spanning two applications
- Sub-second synchronous integration at volume, or high-frequency messaging
- Cross-tenant or external-partner integration — IT-owned middleware
- Regulated data (PHI, payment data) crossing an application boundary
- Anything where a missed or duplicated message is a compliance event
```

---

## Project-Specific Context

**This application:** [App Name] · **id:** [app-id] · **site:** [site URL]
**Owner:** [name + email]
**Role in this integration:** [producer | consumer | both]

**The other application:** [App Name] · **owner:** [name + email]
**Its contract URL:** [URL, or "does not publish one yet"]

**Rule 0 answers:**
| Question | Answer |
|---|---|
| Which app owns the data crossing the boundary? | [one app] |
| Snapshot, notification, or action? | [which] |
| How stale may it be before the consumer is wrong? | [a number] |

**What this app publishes:**
| Name | Kind | Location | Audience group | Freshness / retention |
|---|---|---|---|---|
| [name] | [dataset / list / event / request] | [file path or list title] | [group] | [promise] |

**What this app consumes:**
| From app | Publication | Version | Used for | degradesTo |
|---|---|---|---|---|
| [app-id] | [name] | [1.x] | [why] | [behaviour when missing or stale] |

**Operation catalog (request queues only):**
| Operation | What it does | Payload fields | Who may call it | Idempotency strategy |
|---|---|---|---|---|
| [op-name] | [effect] | [JSON fields] | [group] | [correlation-id dedup / upsert] |

**Provider runtime (request queues only):** [worker pool job / Power Automate flow / other]
**Site registry row updated with ContractUrl:** [yes / not yet]

Begin by answering Rule 0 and confirming these are genuinely two applications.
Then write contract.json — both halves — and get it agreed before writing any
integration code. If the requested design has one app reading another's
internal lists, say so and propose the published projection instead.
