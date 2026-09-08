# Talking Between Applications

> **Cross-Application Communication — v1.1** · updated 2026-08-26. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A supporting pattern for apps that need each other: **how one application asks another for data or work, how a SharePoint list stands in for an API, and how an app publishes the schema that makes it safe to depend on.**

> **Connecting two apps?** See [CROSS_APP_COMMUNICATION_PROMPT.md](CROSS_APP_COMMUNICATION_PROMPT.md) for a prompt you can give Claude. Attach it **together with** the prompt for the app's own pattern.

---

## Executive Summary

The [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx) puts every app in its own site, and names the cost honestly: cross-app rollups get harder. This pattern is the answer to that cost.

The temptation is to skip the problem entirely. Every app on this platform runs in one tenant, under one origin, as an authenticated user — so App B *can* simply read App A's lists. Nothing stops it. That shortcut is the failure this pattern exists to prevent: A renames a column six months later, B breaks at 6am, and nobody on A's team has ever heard of B.

The alternative is not a server. It is a **contract**:

- **An app's lists are private by default.** It talks to other apps only through objects it has deliberately **published** — and the naming convention makes the difference visible from the site contents page.
- **Every published object is described in a contract file** at a well-known path, `<app>_data/contract.json`. It is an API schema: fields, types, semantics, freshness, retention, version, owner. Machine-readable, so a consumer can check it at startup; human-readable, so a reviewer can read it.
- **The contract declares what the app consumes, not just what it publishes.** That reverse index is what makes "who breaks if I change this?" a question with an answer.
- **Four shapes carry the traffic** — a published dataset, an event feed, a request queue, and a direct Power Automate call — and choosing between them is the main design decision.
- **A request queue is a list that behaves like an API.** Claiming a request is the same conditional write the [Worker Pool Pattern](WORKER_POOL_PATTERN.aspx) uses to claim a job: one caller gets 204, everyone else gets 412, and SharePoint referees.
- **Identity survives the hop.** The requester is the `Author` SharePoint stamped on the request item — never a field the caller filled in — and the provider re-checks authorization against it before doing the work.

The platform already runs one of these. The [self-service custom-script enablement service](https://contoso.sharepoint.com/sites/euda-sample/script-enablement/script-enablement.aspx) — live since 2026-08-25 — is a request queue between two applications: a deploy script or a page writes a queued request, a separate service picks it up, re-checks `(Author, SiteUrl)` against a grants list, acts, and stamps the result back. Everything below generalizes that.

---

## When This Pattern Applies

This is a supporting pattern, not an app shape. Read the guide for the app's own pattern first; everything there still applies. Reach for this one the moment a second app enters the picture.

| Your situation | What to do |
|---|---|
| One app, one dataset, one team | Nothing here applies yet — don't build a contract for an audience of one |
| Two apps that both need the same data as their system of record | **Stop.** They are one app, or one owns the data and the other consumes it. Decide that before splitting them |
| App B needs a read-mostly view of App A's data | Published dataset — the cheapest thing that works |
| App B needs to react to things that happen in App A | Event feed |
| App B needs App A to *do* something and report back | Request queue |
| App B needs an answer synchronously, in well under a second | Power Automate HTTP endpoint |
| App B needs to query App A row by row, live, at scale | Neither app has drawn its boundary correctly — revisit the split |
| The integration crosses tenants, or reaches a partner | Not the citizen tier — escalate to IT-owned integration |

Two apps talking is also two apps' permissions, two apps' storage growth, and two owners. [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx) governs who may see what crosses the boundary; [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx) governs what happens to the queue and the feed when they get old. Both have to be applied while the contract is being designed, not after.

---

## Core Concepts

### The Published Boundary (Fixed)

**An app's internal lists and files are private. Other applications may only read what the owning app has published.**

SharePoint will not enforce this for you. Any user with read access to a site can read every list in it over REST, and a consumer app running in that user's browser inherits exactly that reach. So the boundary is a discipline backed by three mechanics:

**Naming makes it visible.** Published objects carry a marker in the title — the platform convention is a `Pub` segment after the app prefix: `ClaimsHub Pub Requests`, `ClaimsHub Pub Events`. Anyone browsing site contents can see which lists are load-bearing for other teams and which are the app's own business. A list without the marker is not part of any contract, and reading it is a defect in the consumer.

**Permissions make it real where it matters.** A published object has a different audience from the app's internals — usually wider. Break inheritance on it and grant one group per the [permissions pattern](SHAREPOINT_PERMISSIONS_PATTERN.aspx). The consuming app's users need read on the published object and nothing else in the site.

**The contract makes it accountable.** If it is not in `contract.json`, it is not published, and the owning app is free to change it tomorrow without telling anyone. That is the whole trade: publishing buys the consumer stability and costs the producer the freedom to refactor silently.

The published object is a **projection**, not the internal table with a different name. Publish the fields other apps genuinely need, in the shape they need them, and keep the freedom to restructure everything behind it. An app that publishes its internal schema verbatim has published its refactoring plans along with it.

### Same Origin, Different Site — What Actually Works

Every site in the tenant shares one origin (`https://<tenant>.sharepoint.com`), so a page on `/sites/euda-a` can call `/sites/euda-b/_api/...` with `credentials: 'same-origin'` and no CORS configuration at all. Cross-app reads are a URL change, nothing more.

Three consequences worth knowing before you rely on it:

- **The form digest is per-web.** A write into another site needs a digest from **that** site: `POST /sites/euda-b/_api/contextinfo`. Reusing the local site's digest fails with a confusing 403. Bearer-token callers (Packaged Python, per that pattern's auth rules) skip the digest entirely.
- **Security trimming still applies, per user.** The consuming app runs as whoever opened it. If a published list is granted to a narrower group than the consumer's audience, some users get an empty result or a 403 and the app looks broken to them alone. Design the published audience deliberately, and degrade with a plain message rather than an error.
- **Search is not an integration transport.** `/_api/search/query` will roll up across sites, and it is security-trimmed, but the index lags minutes to hours and the result shape is the index's, not yours. Use it for discovery and reporting, never as the read path a workflow depends on.

### The Contract Is a File, Not a Conversation

Integration knowledge that lives in someone's head, a Teams thread, or a wiki page has a half-life of about one staff change. The contract is a file in the producer's `_data/` folder, deployed with the app, versioned with the app, and readable by the consumer at runtime.

That last property is what makes it more than documentation: **a consumer can check the contract at startup and refuse to run against a version it does not understand**, which converts a silent data corruption into a visible, specific error on the day of the change.

---

## The Communication Contract

### Where It Lives (Fixed)

Every app that publishes anything writes `contract.json` to its own data folder, at the path other apps can construct without being told:

```
https://<tenant>.sharepoint.com/sites/euda-<app>/<Library>/<app>_data/contract.json
```

One well-known filename, one predictable location. Discovery becomes mechanical: given a site URL, a consumer can fetch the contract without a conversation.

### What It Says

```json
{
  "contractSchemaVersion": 1,
  "app": {
    "id": "claims-hub",
    "name": "Claims Hub",
    "siteUrl": "https://contoso.sharepoint.com/sites/euda-claims-hub",
    "owner": "j.okafor@contoso.com",
    "status": "active",
    "lastReviewedUtc": "2026-08-26T00:00:00Z"
  },
  "publishes": [
    {
      "name": "vendor-scorecard",
      "kind": "dataset",
      "version": "2.1",
      "location": "claims-hub_data/pub-vendor-scorecard.json",
      "audience": "ClaimsHub Consumers",
      "refresh": "hourly, business hours",
      "maxStalenessMinutes": 180,
      "retention": "current snapshot only",
      "fields": [
        { "name": "VendorId",    "type": "Text",     "required": true,  "semantics": "Contoso vendor number, not the ERP surrogate key" },
        { "name": "Score",       "type": "Number",   "required": true,  "semantics": "0-100, higher is better; null means not yet scored" },
        { "name": "ScoredUtc",   "type": "DateTime", "required": true,  "semantics": "when this score was computed" }
      ]
    },
    {
      "name": "claim-events",
      "kind": "event",
      "version": "1.0",
      "location": "ClaimsHub Pub Events",
      "audience": "ClaimsHub Consumers",
      "cursorField": "Id",
      "retentionDays": 90,
      "pollIntervalSeconds": 300,
      "eventTypes": ["ClaimOpened", "ClaimClosed", "ClaimReopened"]
    },
    {
      "name": "revalue-claim",
      "kind": "request",
      "version": "1.0",
      "location": "ClaimsHub Pub Requests",
      "audience": "ClaimsHub Requesters",
      "operations": ["revalue-claim"],
      "expectedLatency": "under 15 minutes during business hours",
      "expiresAfterMinutes": 240,
      "idempotencyKey": "CorrelationId",
      "authorization": "requester must be in the ClaimsHub Requesters group; provider re-checks Author at processing time"
    }
  ],
  "consumes": [
    {
      "app": "vendor-registry",
      "name": "vendor-master",
      "version": "3.x",
      "contractUrl": "https://contoso.sharepoint.com/sites/euda-vendor-registry/Apps/vendor-registry_data/contract.json",
      "usedFor": "resolving vendor names on the scorecard",
      "degradesTo": "vendor id shown without a name"
    }
  ]
}
```

Four things earn their place in every entry, and an entry missing one is not a contract:

- **The field's meaning, not just its type.** `VendorId` is a string in any schema language; whether it is the ERP surrogate key or the vendor number is the thing that will be got wrong.
- **The freshness promise.** `maxStalenessMinutes` is the producer's commitment and the consumer's decision criterion. A consumer that cannot tolerate the stated staleness must not use the feed — and now it can tell before it is built, rather than after.
- **The audience.** Which group can read it, so a permission failure is diagnosable in one step.
- **The retention.** How far back the consumer can catch up, which decides what happens after an outage.

### `consumes` Is the Half Everyone Forgets

A contract that lists only what an app publishes tells you nothing about what breaks when you change it. The `consumes` array is the reverse index: with every app declaring its dependencies in the same field of the same file at the same well-known path, "who reads my vendor-scorecard?" is a sweep over the registry rather than an email to everyone.

Declare a dependency the day the code takes it, including `degradesTo` — what the app does when the dependency is missing, stale, or a version it doesn't understand. An app that has no answer to that question has not finished designing the integration.

### Registering It

The [site registry](SHAREPOINT_APP_PATTERN.aspx) on the hub already names each app, its site URL, its owners, and its last-reviewed date. Add one column — `ContractUrl` — rather than standing up a second registry that will drift from the first.

The registry is an **index**; the contract file is the **truth**. Nothing but the URL belongs in the registry row, because anything duplicated there will eventually disagree with the file it points at.

---

## Shape A — The Published Dataset

The default, and the right answer far more often than it feels like it should be. The producer writes a JSON snapshot to its data folder; consumers fetch it and filter client-side.

```json
{
  "datasetSchemaVersion": "2.1",
  "dataset": "vendor-scorecard",
  "generatedUtc": "2026-08-26T14:02:11Z",
  "generatedBy": "claims-hub nightly refresh",
  "rowCount": 1843,
  "rows": [
    { "VendorId": "V-10422", "Score": 87, "ScoredUtc": "2026-08-26T13:58:00Z" }
  ]
}
```

The envelope is not optional. It is the same self-describing discipline the [storage lifecycle pattern](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx) requires of archive files, and for the same reason: someone must be able to open the file cold and know what it is, when it was made, and whether it is complete.

**Rules of the shape:**

- **One overwrite, never a truncate-then-append.** `files/add(overwrite=true)` replaces the file in a single call. Anything that empties the file first has a window where consumers read nothing and cannot tell that from "no rows".
- **Register it as seed-only in the deploy script.** The moment the app writes this file at runtime, the repo copy is a first-run seed and the deployed copy is live state. A deploy that overwrites it publishes stale data to every consumer at once. The rule from the app pattern is mechanical: if the app can write it, the deploy must not.
- **`generatedUtc` is the contract.** Every consumer UI that shows this data shows its age. A number with no timestamp is a number nobody can act on.
- **Size is a behavioural test, not a limit.** A few thousand rows of narrow JSON is unremarkable; a snapshot that has to carry hundreds of thousands of rows is telling you the consumer needs a query, not a file — which means a published list, or a narrower projection.

Publish a **list** instead of a file when consumers need server-side filtering, per-row permissions, or per-row history. Publish a **file** when they need the whole thing and it is small enough to send. The trade is the same one the app pattern draws between lists and files, with one addition: a file is a single ACL and a single etag, which makes "is everyone looking at the same version?" trivially answerable.

---

## Shape B — The Event Feed

An append-only published list. The producer adds one item per business event; any number of consumers read forward independently.

| Field | Type | Purpose |
|---|---|---|
| `Title` | Text | Event id — globally unique, generated by the producer |
| `EventType` | Text | Which event this is; from the contract's enumerated list |
| `SubjectId` | Text | The business key the event is about |
| `OccurredUtc` | DateTime | When the thing happened — not when the row was written |
| `PayloadJson` | Note | Event body, conforming to the contract |
| `SchemaVersion` | Text | Version of this event's shape, stamped on the row |

**Consumers keep their own cursor.** A consumer stores the last `Id` it processed in its own list or config file and reads forward: `$filter=Id gt <cursor>&$orderby=Id&$top=200`. It never writes to the producer's list — a feed with N consumers writing acknowledgements back is N consumers contending on the producer's items, and the producer cannot prune anything without breaking one of them.

**`Id` orders the feed; `OccurredUtc` describes the world.** SharePoint's item id increases monotonically per list, which makes it a reliable read-forward cursor. It is not gap-free (deletes leave holes) and it is not the same as event time — a producer that batches or backfills will write an older `OccurredUtc` behind a newer `Id`. Order by `Id` to read; use `OccurredUtc` to reason.

**Delivery is at-least-once, so handlers must be idempotent.** A consumer that crashes after acting but before saving its cursor will reprocess. Key side effects by event id, upsert rather than append, and make replaying the last hour a non-event. This is the same contract the worker pool makes about job execution, for the same reason.

**Retention decides what an outage costs.** The contract states `retentionDays`; the producer prunes or archives past it. A consumer whose cursor falls outside that window cannot catch up from the feed — so every event-feed consumer needs a **cold-start path**: usually a full resync from the matching published dataset, then resume from the current head. Design it on day one; it is also the path a brand-new consumer takes on its first run.

**Index `Id`-adjacent filters while the list is empty.** The feed is the list most likely to pass 5,000 items, and an index added afterwards does not take.

SharePoint's own `GetChanges` change log is a tempting substitute and is not one: it reports row-level adds and updates on a list, which is the app's internal storage detail, not a published business event. Use it for an activity view inside one app. Across the boundary, publish events you chose deliberately.

---

## Shape C — The Request Queue

A published list that behaves like an API: the consumer writes a request, the provider does the work and writes the result back onto the same item. Asynchronous, auditable, and built from nothing but list items.

### The List

| Field | Type | Purpose |
|---|---|---|
| `Title` | Text | Correlation id — generated by the requester, unique, also the idempotency key |
| `Operation` | Text | Key into the provider's operation catalog |
| `PayloadJson` | Note | Request body as JSON — data, never code or paths |
| `SchemaVersion` | Text | Contract version this request was written against |
| `Status` | Text | `Pending` · `Claimed` · `Succeeded` · `Failed` · `Expired` · `Rejected` |
| `ClaimedBy` | Text | Who is executing it (display and audit) |
| `ClaimId` | Text | Unique id of the current claim — the fencing token |
| `ExpiresUtc` | DateTime | After this, the request is abandoned rather than run |
| `CancelRequested` | Boolean | Requester's cancel flag; the provider checks it before side effects |
| `ResultJson` | Note | Response body, conforming to the contract |
| `ErrorText` | Note | Plain-English failure, safe to show the requester |
| `CompletedUtc` | DateTime | When it reached a terminal state |

`Author` and `Created` come free and are the ones that matter — see authorization, below.

### The State Machine

`Pending → Claimed → Succeeded | Failed | Expired`, plus `Pending → Rejected` for a request that fails authorization or validation before any work starts.

**Only the requester creates. Only the provider moves an item out of `Pending`. Nothing returns to `Pending`.** One writer per transition is what keeps a list item — which has exactly one etag — from becoming a contended shared variable.

### Claiming Is the Worker Pool's Conditional Write (Fixed)

There may be more than one provider instance: two people with the worker app open, a Power Automate flow and a script during a migration, a retry racing a sweep. Claiming a request is the same atomic compare-and-swap the [Worker Pool Pattern](WORKER_POOL_PATTERN.aspx) uses to claim a job, and it is fixed for the same reason.

Read the `Pending` item, capturing its etag. MERGE it with `If-Match: <that etag>`, setting `Status = Claimed`, `ClaimedBy`, and a fresh `ClaimId`. SharePoint answers one caller with **204** — the request is yours — and every other caller with **412 Precondition Failed**, which is the system working, not an error. Never claim with `If-Match: *`; that defeats the entire mechanism.

The **fencing guard** applies unchanged: if execution begins suspiciously long after the claim — a laptop slept, a script was paused — re-read the item and proceed only if `ClaimId` is still yours.

### Operations Are Code, Requests Are Data (Fixed)

`Operation` is a key into a dictionary of functions the provider's owner wrote and reviewed. An unknown operation is a `Rejected` request with a clear message, never a crash and never an attempt to interpret the string as something executable. Nothing from `PayloadJson` becomes a file path, a URL, a query fragment, or code. The request queue is an entry point exposed to everyone who can write to the list, and it deserves the suspicion you would give an internet-facing endpoint.

### Authorization: the Requester's Identity, Re-Checked (Fixed)

This is the security rule that distinguishes a request queue from a shared list, and getting it wrong is the pattern's most expensive mistake.

**The provider executes as itself, not as the requester.** Whoever is running the provider — a worker-pool participant, a flow's connection owner — brings their own permissions to the work. So a request queue hands every writer the provider's reach, for the operations the provider offers. It is a privilege boundary, and it must be treated as one.

Two consequences, both binding:

- **Identity comes from `Author`, never from a field.** SharePoint stamps `Author` on the item and no client can set it. A `RequestedBy` text column is a claim by the caller, useful for display and worthless for authorization.
- **Authorization is re-checked at processing time, against a list the provider controls.** Not at submit time, not in the requester's UI, and not by trusting list permissions alone — a grant can be revoked between submission and execution, and the check must see the revocation. A request from an unauthorized author becomes a `Rejected` row, which is also the audit record that someone tried.

That is precisely how the platform's own [enablement service](https://contoso.sharepoint.com/sites/euda-sample/script-enablement/script-enablement.aspx) works: the queue is open to any authenticated user by design, because the worst a forged request achieves is a `Rejected` row.

Where request payloads are sensitive to each other, set `ReadSecurity: 2` and `WriteSecurity: 2` on the queue so requesters see only their own items — zero unique permission scopes, no per-item ACL budget. Note the standing exception: neither setting applies to site owners or collection administrators.

### Timeouts, Expiry, and the Give-Up Path

An asynchronous API needs both sides to agree on how long "waiting" lasts.

The requester sets `ExpiresUtc` from the contract's `expiresAfterMinutes`, polls its own item on the contract's stated interval, and **has a defined behaviour when the deadline passes** — show the user, fall back, or raise it for a human. A consumer that waits forever is a hang the user cannot diagnose.

The provider never starts work on an expired request; a sweep stamps `Expired` so the queue does not accumulate items nobody is waiting for. Terminal items age out per the retention in the contract, archived if they are part of the audit story.

**Re-submission is the requester's business, and the correlation id is what makes it safe.** A provider that receives a correlation id it has already completed returns the existing result instead of doing the work twice. That single rule is what lets a nervous consumer retry without inventing a distributed transaction.

### Cancellation

The requester sets `CancelRequested = Yes` on its own item. The provider checks the flag immediately before side effects begin and after any long step, and stamps a terminal state. Cancellation is best-effort by construction — an in-flight operation may complete anyway — and the contract should say so rather than implying a guarantee the queue cannot make.

---

## Shape D — The Direct Call

When a user is waiting and the answer must arrive in under a second, a queue is the wrong instrument. Use a Power Automate HTTP-triggered flow, per the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx): the consumer POSTs JSON, the flow does the work server-side, the response comes back on the same call.

It is a real synchronous API, and it carries three costs a list does not:

- **The trigger URL is a bearer secret.** Anyone holding it can invoke the flow. It must never sit in a shell or in `_data/` where a browser can read it. Keep it behind a restricted list or a server-side hop.
- **The flow runs as its connection owner.** Same privilege boundary as the request queue, with less of an audit trail — the flow's run history, not a SharePoint item with an `Author` stamp. Where the audit trail matters, have the flow write the request and result to a list as it goes.
- **There is no free retry story.** A synchronous call that times out leaves the caller genuinely unsure whether the work happened. Carry the same correlation id and make the operation idempotent, or accept the ambiguity knowingly.

Default to a queue and reach for a direct call when latency requires it — not the other way round.

---

## Versioning and Compatibility (Fixed)

A published contract is a promise. These are the rules that let a producer keep it while still changing the app.

**Additive changes only, within a version.** Add optional fields. Never rename, remove, retype, or narrow an existing one.

**Never repurpose a field.** Changing what a field *means* while its name and type stay put is worse than deleting it: deletion breaks the consumer loudly on the first read, while repurposing produces confidently wrong numbers for months. If the meaning changes, the name changes.

**Consumers are tolerant readers.** Ignore unknown fields, never assume field order, never fail on an addition. This is the property that makes additive change safe, and it has to be built in from the first version — a consumer that validates strictly turns every producer improvement into an outage.

**A breaking change is a new version published alongside the old.** Both run; the old one is marked `deprecated` in the contract with a removal date; `consumes` tells you exactly who to notify. Remove the old version after the last consumer has moved, verified by sweeping the registry rather than by assuming.

**Stamp the version on the record, not only in the contract.** `SchemaVersion` on every event and request row means a message that has been sitting in a queue across a version change can still be interpreted. Contracts describe the present; records outlive it.

**Bump the version when the meaning changes, not when the code does.** An internal refactor that leaves the published projection identical is not a contract change, and versioning it trains consumers to ignore versions.

---

## Verifying an Implementation

The worker pool proves its guarantee with a race proof. This pattern has two equivalents, and an implementation that ships neither has not demonstrated it works.

**The contract check.** At startup, the consumer fetches the producer's `contract.json`, confirms the named publication exists at a version it understands, and confirms every field it depends on is present. A mismatch produces a specific, plain-English message naming the app, the publication, the expected version, and the found version — and the app falls back to its declared `degradesTo` behaviour. This turns a future breaking change into a diagnosable message on the day it happens instead of wrong data indefinitely.

**The replay proof.** Deliver the same event, or submit the same correlation id, twice — and show that the consumer's state after the second delivery is identical to after the first. At-least-once delivery makes duplicates a certainty, not a hazard; this proof is the difference between believing the handlers are idempotent and knowing it.

Where more than one provider instance can run, the worker pool's race proof applies unchanged to the request queue: N simultaneous claims against one etag, exactly one 204.

---

## Failure, Freshness, and Honesty

Cross-app data is stale data. That is not a defect to be hidden; it is a property to be displayed.

- **Show the age and the source.** Any UI presenting another app's data shows where it came from and how old it is. A stale number that looks live is worse than no number.
- **Degrade to a stated fallback, never to a blank screen.** The `degradesTo` line in the contract is a design commitment, and the consumer implements it.
- **A dependency's outage must not look like your bug.** "Vendor Registry has not published since 09:14" is actionable; a spinner is not.
- **Poll on the contract's interval, with jitter.** Cross-app polling multiplies request volume across every consumer, and consumers that start on the hour synchronize into a spike. Honour `Retry-After` on 429 and 503, and back off.
- **Reconcile rather than transact.** There are no cross-app transactions here. Where two apps must agree, one of them owns the truth and the other periodically compares, reports the drift, and repairs — a reconciliation view someone actually looks at, not an assumption of consistency.

---

## Operating It

**One owner per published object, named in the contract.** Publication is a support commitment: a consumer that breaks needs a person to call.

**Review the contract on a schedule.** `lastReviewedUtc` exists so a stale integration is visible. A contract nobody has looked at in a year is describing an app that has moved.

**Decommission through the contract.** Mark the publication `deprecated` with a date, sweep the registry for consumers, notify them, then remove. Deleting a published list to see who complains is how a Monday gets ruined.

**The retiring app's `consumes` matters too.** When an app is switched off, the things it consumed may have been kept alive solely for it. The reverse index answers that in both directions.

---

## Anti-Patterns

- **Reading another app's internal list because it is right there.** The single most common failure. The consumer works today and breaks on a refactor the producer had no way to know was dangerous.
- **The shared integration list nobody owns.** Two apps write, both read, no owner, no contract. It becomes load-bearing and unmaintainable at the same time.
- **Two apps writing the same item.** A list item has one etag. "App A owns these columns and App B owns those" is a convention SharePoint has never heard of, and lost updates follow.
- **Trusting a `RequestedBy` field.** Identity is `Author`. Anything else is the caller's opinion.
- **Contracts that document `publishes` but not `consumes`.** Half an index answers none of the questions worth asking.
- **The event feed as system of record.** It is a notification stream with retention, not the truth. The truth is a list or dataset someone owns.
- **Synchronous thinking in an asynchronous queue.** A consumer that submits a request and blocks the UI until it returns has built a worse API than the one it avoided.
- **Secrets in a payload.** A request item is readable by everyone the list is granted to, and it persists. Credentials belong behind a restricted list or a flow.
- **Chatty polling.** A consumer polling every few seconds against a feed that updates hourly is a throttling incident that will be blamed on the producer.
- **Versioning the code instead of the contract.** Version numbers that move on every deploy teach consumers that version numbers mean nothing.

---

## Design Checklist

- Named which app owns each piece of data, and confirmed the two apps are genuinely two apps
- Chosen the shape deliberately — dataset, event feed, request queue, or direct call — and written down why
- Published a projection, not the internal schema
- Written `contract.json` with fields, semantics, freshness, audience, retention, and version for every publication
- Declared every dependency in `consumes`, each with a `degradesTo`
- Added the contract URL to the site registry row
- Granted the published object to a group sized for the consuming audience, and verified an ordinary consumer's view
- Registered every runtime-written published file as seed-only in the deploy script
- Indexed the feed and queue columns, and enabled versioning, while the lists were empty
- Made every consumer a tolerant reader and every handler idempotent
- Implemented the contract check and the replay proof
- Defined the cold-start path for feed consumers, and the give-up path for queue requesters
- Re-checked requester authorization from `Author` at processing time, in the provider
- Set retention and the archive path for the queue and the feed
- Displayed source and age everywhere cross-app data appears

---

## What This Pattern Is Good For

- Giving one app a dependable read of another app's data without merging the two
- Letting an app trigger work that only another app's owner can safely implement
- Fanning one app's business events out to several consumers that come and go
- Decoupling teams: the producer refactors freely behind a published projection
- Making integration dependencies discoverable, reviewable, and decommissionable
- Building an API-shaped entry point with an audit trail, without a server or a service account

## What It Is Not Good For — Escalate Instead

- Guaranteed delivery, guaranteed ordering, or exactly-once semantics
- Transactions spanning two applications — there is no two-phase commit here, only reconciliation
- Sub-second synchronous integration at volume, or high-frequency messaging
- Integration across tenants or with external partners — IT-owned middleware territory
- Regulated data crossing an application boundary
- Anything where a missed or duplicated message is a compliance event rather than an inconvenience

---

## Quick Reference

| Need | Use |
|---|---|
| Give another app a read of your data | Published dataset — JSON snapshot with an envelope, in `<app>_data/` |
| Let another app query your data live | Published list, covered by the contract — never an internal one |
| Tell other apps that something happened | Event feed list, append-only, consumers hold their own cursors |
| Have another app do work for you | Request queue list, response written back on the same item |
| Get an answer in under a second | Power Automate HTTP trigger — and keep the URL out of the browser |
| Declare what you publish and consume | `<app>_data/contract.json`, well-known path, registered in the site registry |
| Discover another app's contract | Site registry `ContractUrl`, then fetch the file |
| Claim a request when several providers may run | MERGE with `If-Match: <etag>` — 204 is yours, 412 is normal coordination |
| Identify the requester | The `Author` SharePoint stamped, never a field the caller wrote |
| Authorize a request | Re-check `Author` against the provider's own grants list, at processing time |
| Make retries safe | Correlation id as the idempotency key; a repeat returns the first result |
| Keep requesters from seeing each other | `ReadSecurity: 2` / `WriteSecurity: 2` on the queue — zero scopes |
| Write into another app's site | Get the digest from **that** web: `POST /sites/<other>/_api/contextinfo` |
| Add a field to a published shape | Additive and optional — no version bump needed |
| Change what a field means | New version alongside the old, deprecation date, sweep `consumes` |
| Catch up after an outage | Feed cursor if inside retention; otherwise cold-start from the dataset |
| Prove the integration works | Contract check at startup, plus the replay proof |
| Find out who depends on you | Sweep the registry's contracts for your app in their `consumes` |
| Retire a publication | Mark deprecated with a date, notify consumers found in the sweep, then remove |
