# Controlling Access and Auditing with SharePoint Permissions

> **SharePoint Permissions & Auditing — v1.1** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A supporting pattern for every app that stores data in SharePoint: how to use **site, list, library, folder, and file permissions as the application's authorization layer**, and how to get an audit trail without writing one.

> **Adding access control to an app?** See [SHAREPOINT_PERMISSIONS_PROMPT.md](SHAREPOINT_PERMISSIONS_PROMPT.md) for a prompt you can give Claude. Attach it **together with** [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md) — this pattern shapes the data model that prompt produces.

---

## Executive Summary

Most citizen-built apps carry a home-made permission system: a `Visibility` column, an `AppRoles` list, a bundle of `if (user.isManager)` checks in JavaScript. All of it is decoration. Any user with Contribute access can open a browser console and call the REST API directly, and every rule your UI enforces evaporates.

SharePoint already ships the thing you were building. It has an identity system, a hierarchical permission model, per-object access control lists, automatic security trimming on every query, and a server-stamped record of who did what. The work is not implementing authorization — it is **shaping your storage so SharePoint's authorization lands where you need it**.

That leads to one rule which drives everything else:

> **Divide the storage layer into the smallest unit that could ever need its own access rule — before you write any code.** A permission can only be attached to an object. If a deal, a manager, a region, or a case is a *row* among thousands, the only thing you can secure is the whole table. If it is a *list, folder, or file of its own*, it has its own ACL, its own membership, and its own audit trail, forever.

Granularity cannot be retrofitted without a migration. Choosing it is a day-one decision.

Three consequences follow, and most of this guide is about them:

- **Security trimming is your query filter.** You never write `WHERE user_can_see = true`. You `GET` the collection and SharePoint returns only what the caller may read. The set of objects a user gets back is itself information — enough, in some designs, to reconstruct an entire org hierarchy from nothing but ACLs.
- **Groups are the join table.** ACL writes are expensive and hard to audit; group membership writes are cheap and reversible. Put one group on each unit's ACL and never touch the ACL again.
- **Site owners are your administrators, whether you designed it that way or not.** Full Control includes *Manage Permissions*. An owner can grant themselves anything in the site. Take the free admin role and accept the boundary: the site is your security perimeter.

Because the site is the perimeter, three operational practices are part of the security design rather than housekeeping — **one site per app**, **provisioning through a setup page rather than by hand**, and **an admin page showing the owners the model's real state**. §9 covers why each matters here; the practices themselves are documented in the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx) and [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx).

---

## When This Pattern Applies

This is a **supporting pattern**, not an app shape. It composes with the others:

| Pattern | How permissions apply |
|---|---|
| [SharePoint App](SHAREPOINT_APP_PATTERN.aspx) | Directly. The app's lists, libraries, folders, and `_data/` files are the securable objects; the browser calls the REST API as the signed-in user, so trimming is automatic. |
| [Worker Pool](WORKER_POOL_PATTERN.aspx) | Directly, with a twist — workers run **as each participant**, so a job only sees what its runner can see. Permission-provisioning jobs are a natural fit for the pool. |
| [Packaged Python](PACKAGED_PYTHON_PATTERN.aspx) | Directly. The app signs in as the running user; the same trimming applies to its REST calls. |
| [Claude Artifacts](CLAUDE_ARTIFACTS_PATTERN.aspx) | Not applicable — artifacts have no SharePoint access and no persistence. |
| [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx) | The sibling supporting pattern. It sizes and ages what this one secures — scope budgets, group accumulation, and archive ACLs are shared concerns. |

Reach for this guide when the answer to *"should everyone who can open this app see everything in it?"* is no.

---

## Core Concepts

### 1. The Permissible Unit

Before designing lists or columns, answer one question in a single sentence:

> **What is the smallest thing that two different people might legitimately need different access to?**

That thing is the **permissible unit**, and it must become its own securable object. Some examples:

| Application | Permissible unit | Not the unit |
|---|---|---|
| M&A deal tracker | One deal | The tracker; the deal *stage* |
| HR manager portal | One manager's team data | The HR site; a department |
| Regional sales pipeline | One region | One opportunity |
| Vendor scorecards | One vendor relationship | One scorecard row |
| Incident register | One incident | One comment on an incident |
| Contract repository | One contract | One clause |

The mistake is almost always the same: modelling the unit as a **row in a shared list** because that is the obvious relational shape. A row is not securable at a workable scale (see §2). A deal in an M&A tracker is not a row — it is a folder, or a list, that happens to *contain* rows.

**Design the unit one level finer than today's requirement.** Splitting later means migrating data and re-provisioning ACLs; merging later is free (grant the same group everywhere). If you are unsure whether deals or deal-workstreams are the unit, pick workstreams.

**Corollary — the unit's container is a boundary too.** Everything inside a unit shares the unit's ACL. If a deal folder must hold one document only the two partners may read, that document is a second unit, and it needs its own object (a subfolder with broken inheritance) or its own home (a separate library).

---

### 2. The Securable Ladder (Default — the limits quoted in it are Microsoft's)

SharePoint has exactly four levels of securable object, and permissions flow down from each to the next until something **breaks inheritance**:

```
Site (web)
  └─ List / Document library
       └─ Folder                (a folder is a list item, and is securable)
            └─ Item / File
```

Every object either inherits its parent's ACL or has a **unique scope** of its own. Choosing the level your unit sits at is the central design decision, and each level has a different cost:

| Level | One unit costs | Good for | Watch out for |
|---|---|---|---|
| **Site** | A whole site (and its owners, storage, URL) | Whole-app or whole-department tenancy; anything that must be invisible to another site's owners | Heavyweight; cross-site queries are search-only |
| **List / library** | One list, one scope | 10–200 stable units, each holding many rows; region, entity, business unit splits | **2,000 lists and libraries per site collection** — a hard ceiling |
| **Folder** | One folder, one scope | Hundreds to a few thousand units, each holding mixed artifacts (documents + a JSON record + attachments) | Folders can't break inheritance once the parent library exceeds **100,000 items** |
| **Item / file** | One scope *per row* | Small, high-value sets; one-file-per-principal designs | Unique scopes per list: **5,000 recommended, 50,000 supported** — this is the limit that bites |

The published SharePoint service limits that shape these choices ([Microsoft, SharePoint limits](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits)):

- **Unique permission scopes per list or library: 5,000 recommended, 50,000 supported.** Past the recommendation, permission operations and view rendering degrade; past the supported limit they fail.
- **Lists and libraries per site collection: 2,000 combined.** A list-per-unit design has a hard ceiling — count your units at three years' growth before choosing it.
- **Once a list, library, or folder passes 100,000 items you can no longer break (or restore) inheritance on it** — only on individual items inside it. Break inheritance at creation, while the container is small.
- SharePoint groups: **10,000 per site collection, 5,000 users per group**, and a user may belong to 5,000 groups per site collection.
- Lists hold up to 30 million items; **50,000 major versions** per item.

**The practical reading:** folders are the sweet spot for most apps. One scope per unit, unlimited rows and files inside it, and no explosion of lists. Move up to list-per-unit when units are few and each is a genuine dataset; move down to item-level only when the unit genuinely *is* one record and there are hundreds, not tens of thousands, of them.

**A no-scope alternative for "your own items only."** SharePoint lists have built-in item-level settings that give per-creator privacy **without consuming a single unique scope**, so they scale to any list size:

| Setting | Values |
|---|---|
| `ReadSecurity` | `1` = read all items · `2` = read only items they created |
| `WriteSecurity` | `1` = edit all items · `2` = edit only items they created · `4` = edit none |

```
MERGE /_api/web/lists/getbytitle('Draft Requests')
{ "__metadata": { "type": "SP.List" }, "ReadSecurity": 2, "WriteSecurity": 2 }
```

This is the correct tool for drafts, personal submissions, self-service requests, and scratch data — anywhere the rule is exactly "yours and nobody else's." It does not express sharing (no "and my manager"), and it does not apply to site owners. Confirm the effect on **document libraries** before relying on it there; the setting is reliable on lists and has historically been inconsistent for library write security.

---

### 3. Security Trimming Is the Query Filter (Fixed)

This is the concept most worth internalising, because it inverts how you normally think about authorization.

A `GET` against a SharePoint collection **returns only the objects the calling user may read**. Not a filtered view — the others are simply not in the response. That is true for items in a list, files in a folder, folders in a library, and lists in a site.

```javascript
// Every user calls exactly this. Nobody passes a user id, a role, or a filter.
spFetch(SITE_URL + "/_api/web/getfolderbyserverrelativeurl('" + spPath(DEALS) + "')/folders" +
        '?$select=Name,ServerRelativeUrl,TimeLastModified')
```

An analyst gets three deals back. A partner gets forty. The app is identical. There is no rule in your code, so there is no rule to get wrong, no rule to keep in sync with the ACLs, and nothing a console-savvy user can bypass.

**The stronger move: compose state from what came back.** Because the returned set *is* the answer, you can encode a relationship in ACLs and let the query reconstruct it — no relationship table, no hierarchy column, no drift.

That is the mechanism behind the org-chart shape in §6C, and it generalises: *the set of objects a user can read is itself a queryable fact about that user.*

**What trimming does not do:**

- **Absence is ambiguous.** "Not returned" means *not visible*, which is indistinguishable from *does not exist*. If users must know something exists without seeing it, publish a separate readable-to-all summary (counts, titles only) and secure the detail.
- **Counts are not trimmed.** `list.ItemCount` is the raw total. Never label it "your items."
- **Never cache across users.** A trimmed response is user-specific by definition. Anything cached in `_data/`, in a rollup file, or in a worker's output is the *cache-writer's* view, and publishing it to everyone leaks exactly what trimming prevented.
- **Short pages are normal.** With unique scopes in play, a `$top=100` page can return fewer than 100 items and still have more to come. Follow `d.__next` until it is absent; never infer "end of list" from a short page.
- **Search lags.** Search results are trimmed, but the index updates minutes-to-hours behind. A newly granted user sees the item over REST immediately and in search later. Use REST for anything the user just did.

---

### 4. Groups Are the Join Table (Default)

Never put a person on an ACL.

An ACL entry is a permission write against a securable object. Group membership is a row in a membership list. They cost the same to write once, but they behave completely differently over an application's life:

| | Person on the ACL | Group on the ACL |
|---|---|---|
| Add someone to a unit | Permission write on the unit | Membership write on the group |
| Remove someone | Permission write (and you must find every unit) | One membership write |
| "Who is on this deal?" | Read and interpret role assignments | `GET /sitegroups/getbyname('...')/users` |
| Number of ACL entries | Grows with people × units | Exactly one per unit, forever |
| Reviewable by a non-developer | No | Yes — it is a normal SharePoint group page |

So the shape is fixed: **one group per permissible unit, that group is the only entry on the unit's ACL, and every membership change is the app's "grant access" operation.** The ACL is written once at provisioning and never touched again.

**SharePoint groups vs. Entra security groups.** Use SharePoint groups when the app manages membership — they are creatable and editable over REST, they take effect immediately, and they are visible to site owners in the normal UI. Use Entra security groups when membership is authoritative somewhere else (HR feeds, joiner/mover/leaver automation, an existing access-request process); accept that membership changes can take time to propagate into a live session, so the app should not promise instant effect.

**Removals are the hard part.** Adds are driven by an obvious event (someone joins a deal). Removals are driven by a non-event (someone stopped being on it) and are the failure mode in every home-grown access system. Two defences:

1. **Never grant time-boxed access to an individual.** Grant the group; expire the membership.
2. **Give every grant a written reason and an expiry.** An `AccessGrants` list holding `Unit`, `Principal`, `GrantedBy`, `GrantedUtc`, `Reason`, `ExpiresUtc` — plus a scheduled reconciliation job that removes memberships past their expiry and reports members with no grant row. This list is **provenance, never enforcement** (see §8).

---

### 5. Site Owners Are Automatically Application Administrators

Every SharePoint site ships three groups — **Owners** (Full Control), **Members** (Edit), **Visitors** (Read) — plus site collection administrators above them. This has two consequences that every app on this platform inherits.

#### Your admin role already exists — don't build another one

Full Control includes **Manage Permissions** and **Enumerate Permissions**. A site owner can already read every ACL, grant themselves access to any object in the site, and change any setting. An `AppAdmins` list adds nothing: anyone who could be added to it can already add themselves, and now you have two sources of truth that drift.

So: **derive the admin flag from SharePoint, never store it.** The authoritative check is the current user's effective permissions on the web, which SharePoint computes across every group and nested claim:

```javascript
/* SPBasePermissions bit masks, split into the High/Low pair the REST API returns */
var PERM = {
  manageWeb:            { high: 0x00000000, low: 0x40000000 },  // Full Control / site owner
  managePermissions:    { high: 0x00000000, low: 0x02000000 },  // can grant access
  manageLists:          { high: 0x00000000, low: 0x00000800 },  // can provision lists
  addAndCustomizePages: { high: 0x00000000, low: 0x00040000 },  // can deploy an .aspx shell
  enumeratePermissions: { high: 0x40000000, low: 0x00000000 }   // can read ACLs
};

function hasPerm(eff, mask) {          // eff = d.EffectiveBasePermissions
  return (Number(eff.High) & mask.high) !== 0 || (Number(eff.Low) & mask.low) !== 0;
}

function loadAdminContext() {
  return Promise.all([
    spFetch(SITE_URL + '/_api/web/effectivebasepermissions').then(function (r) { return r.json(); }),
    spFetch(SITE_URL + '/_api/web/currentUser?$select=Id,Title,LoginName,IsSiteAdmin')
      .then(function (r) { return r.json(); })
  ]).then(function (res) {
    var eff  = res[0].d.EffectiveBasePermissions;
    var user = res[1].d;
    return {
      user:        user,
      isSiteAdmin: user.IsSiteAdmin === true,          // site collection administrator
      isOwner:     hasPerm(eff, PERM.manageWeb),       // Full Control on this site
      canGrant:    hasPerm(eff, PERM.managePermissions),
      canProvision:hasPerm(eff, PERM.manageLists)
    };
  });
}
```

Use `.../lists/getbytitle('X')/effectivebasepermissions` and `.../items(N)/effectivebasepermissions` for the same check scoped to one object — that is how you decide whether to render a Delete button on a specific row without guessing.

Prefer this over reading `/_api/web/currentUser/groups` or the members of `associatedOwnerGroup`. Group listings are useful for *displaying* "you are a site owner," but they miss ownership that arrives through a nested Entra group or an M365 group's owners claim. Effective permissions never miss it.

Then apply the rule the base pattern already states: **hiding admin UI is a courtesy, not a control.** The server enforces; your `if (ctx.isOwner)` only spares non-admins a button that would fail.

#### The site is your security perimeter

The other half is the part people discover late.

- **Site collection administrators bypass all ACLs**, everywhere in the site collection, including objects with broken inheritance. There is no configuration that changes this.
- **Site owners** hold Full Control on the web. Breaking a child object's inheritance with `copyRoleAssignments=false` does remove them from that child's ACL — but they still hold *Manage Permissions on the site*, so they can re-grant themselves at will.
- The list-level `ReadSecurity` / `WriteSecurity` settings likewise **do not apply to owners and administrators**.

So the honest statement of the boundary is:

> **You cannot durably hide data from a site's owners. You can only make reaching it a deliberate, visible, audited act.**

That is a perfectly good control for most internal apps — it is what "administrator" means. But it means the *siting* decision is the real security decision. If a dataset must be invisible to the people who own the app's site, it does not belong in that site; it belongs in a **separate site with a different Owners group**, and the app reaches it (or doesn't) across the boundary. Deciding that on day one is cheap. Discovering it after a year of data is a migration.

Two operational rules follow:

- **Never let a site have exactly one owner.** A single owner is an outage and an offboarding problem. Two or three named owners, reviewed when people change roles.
- **Treat the Owners group as a documented part of the app.** Its membership is your administrator list; the app's README should say who is in it and who reviews it.

---

## 6. Design Shapes

Seven shapes that cover most real applications. Pick one; combine them where units nest.

### A. Folder-per-unit — the M&A tracker

**Unit:** one deal. **Object:** one folder in a document library. **Scope count:** one per deal.

```
Deals/                              (library — inherits site; Read for the deal-desk group)
  1042-Project-Halyard/             (folder — inheritance broken; "Deal 1042 Team" = Contribute)
    deal.json                       (structured record the app reads and writes)
    Diligence/  Legal/  Model/      (documents; inherit the deal folder's ACL)
  1043-Project-Kestrel/             ("Deal 1043 Team")
```

Everyone opens the same page. The library listing returns each user's deals and nothing else. Adding someone to a deal is one membership write. The whole deal — record, documents, attachments — moves as one ACL.

**Why a folder and not item-level:** a deal has many artifacts. One folder scope covers all of them; item-level would spend one scope per document and put a busy library into scope-limit territory within a year.

**Rollup for people who can see many deals:** enumerate the folders, fetch each `deal.json` in parallel, compose client-side. The result is automatically correct per user — the partner's dashboard and the analyst's dashboard run identical code.

### B. List-per-unit — the region or entity split

**Unit:** one region, legal entity, or business unit. **Object:** one list. **Scope count:** one per unit.

Use when units are **few and stable** (10–200) and each holds many rows that must never mix — statutory separation, information barriers, or simply "EMEA must not see APAC's pipeline." Rows inside are cheap and unlimited; the scope count stays at one per unit.

```javascript
// Security-trimmed: returns only the lists this user can read.
spFetch(SITE_URL + "/_api/web/lists?$filter=startswith(Title,'Pipeline – ')&$select=Title,Id")
```

Discovery is the same trick as everywhere else: *the lists I can see are my regions.* Budget against the **2,000 lists per site collection** ceiling, and remember every list needs provisioning (fields, indexes, versioning) — a `provisionUnit()` function, not a manual checklist.

### C. File-per-principal, ACL-as-graph — the HR manager portal

**Unit:** one manager's team data. **Object:** one JSON file per manager. **Scope count:** one per manager.

```
managers/
  j.okafor.json     → read: j.okafor  +  every manager above them
  r.singh.json      → read: r.singh   +  every manager above them
  ...
```

A manager opening the app gets one file: their own. A director gets their own plus their reports'. The CHRO gets the whole company. **Nobody stores the hierarchy** — the app enumerates the folder, parses what came back, and composes the reporting tree from the files it was allowed to read. The ACLs *are* the org chart, and they cannot disagree with it, because there is no second copy.

```javascript
function loadVisibleOrg() {
  var folder = "/_api/web/getfolderbyserverrelativeurl('" + spPath(MANAGERS) + "')/files?$select=Name";
  return spFetch(SITE_URL + folder)
    .then(function (r) { return r.json(); })
    .then(function (d) {
      return Promise.all(d.d.results.map(function (f) { return loadJson(MANAGERS + '/' + f.Name); }));
    })
    .then(composeHierarchy);   // pure client-side: each record names its own manager
}
```

**What this shape buys:** the senior view is free (no aggregation job, no rollup table, no "who reports to whom" list to maintain), and it is provably correct — a leader cannot see a team they have no permission to see, because the data never arrives.

**What it costs, and you must budget for it:**

- **Provisioning is a real job.** Every reorg rewrites grants along a chain. This is exactly the shape of work the [Worker Pool pattern](WORKER_POOL_PATTERN.aspx) exists for: a nightly reconciliation job that reads the authoritative HR feed and converges each file's ACL. Make it idempotent — compute the desired grant set, diff it against the current role assignments, apply the difference.
- **Removals matter more than adds.** A manager who moves sideways keeps seeing their old reports until something removes the grant. The reconciler must remove, not just add, and should report every removal it makes.
- **One scope per manager.** Fine at thousands; check it against the 5,000-scope recommendation before assuming it scales to a 40,000-person company. Past that, move the unit up to a folder per department.
- **Chains get deep.** Granting "every manager above" means each file carries a grant per level. Grant to a group per management chain where the chains are stable, or accept the fan-out and let the reconciler own it.

### D. Segregation of duties — approvals as a separate list

**Unit:** the approval act. **Object:** a second list with a different ACL.

The fragile version puts a `Status` field on the request and has JavaScript refuse to set `Approved` unless the user is a manager. Anyone with Contribute can `MERGE` the item and set it anyway.

The durable version:

| List | Requesters | Approvers |
|---|---|---|
| `Requests` | Contribute (or `WriteSecurity: 2` — edit only your own) | Read |
| `Approvals` | Read | Contribute |

An approval is a *new item in `Approvals`*, so the approver's identity is server-stamped in `Author` — not supplied by the app, not spoofable by the requester, and impossible to forge without the permission. The app joins the two lists for display. The audit question "who approved this and when" is answered by two native columns.

Same idea in one line: **anything the app's JavaScript enforces, a user with write access can bypass. Move the rule into an ACL and it becomes real.**

### E. Configuration and secrets — the restricted list

Flow URLs, API endpoints, threshold settings: a list with inheritance broken, Read for the app's users, Contribute for owners only. Anything genuinely secret does not go here at all — it goes behind a Power Automate flow, because a value your browser can read is a value your user can read. (See the base pattern's [Security Considerations](SHAREPOINT_APP_PATTERN.aspx).)

### F. Read-mostly reference data — the inverted default

Lookup tables, code lists, published reports: library or list inheriting the site, Read for everyone, Contribute for a small owners group. No broken inheritance, no scopes, nothing to reconcile. **Most of your app's data should look like this** — reserve unique scopes for the data that genuinely needs them.

### G. Personal drafts — no scopes at all

Anything whose rule is exactly "mine only": set `ReadSecurity: 2` and `WriteSecurity: 2` on the list (§2). Zero unique scopes, unlimited rows, immediate effect. Promote a draft to shared state by copying it into a shared list — the copy's `Author` records who promoted it.

---

## 7. Implementing It

All calls below are the SharePoint REST API using the canonical `spFetch` / `spPath` / `writeHeaders` helpers from the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx). Writes need a fresh digest from `/_api/contextinfo` when the caller is a cookie-authenticated browser session; a [Packaged Python](PACKAGED_PYTHON_PATTERN.aspx) or [worker](WORKER_POOL_PATTERN.aspx) client using a Bearer token does not.

### Reaching a securable object

| Object | REST path |
|---|---|
| Site | `/_api/web` |
| List or library | `/_api/web/lists/getbytitle('Deals')` |
| List item | `/_api/web/lists/getbytitle('Deals')/items(12)` |
| Folder | `/_api/web/getfolderbyserverrelativeurl('/sites/x/Deals/1042')/ListItemAllFields` |
| File | `/_api/web/getfilebyserverrelativeurl('/sites/x/Deals/1042/deal.json')/ListItemAllFields` |

Folders and files are list items underneath, which is why `ListItemAllFields` gets you to the same permission surface. Everything below hangs off any of these paths.

### Provisioning a unit

The whole permission model of a unit is set once, at creation, by code — never by hand in the UI. Hand-made ACLs are unreproducible, undocumented, and impossible to reconcile.

```javascript
function provisionUnit(unitFolderUrl, groupName, roleName) {
  var target = SITE_URL + "/_api/web/getfolderbyserverrelativeurl('" +
               spPath(unitFolderUrl) + "')/ListItemAllFields";
  var digest, groupId, roleId;

  return getDigest()
    .then(function (d) { digest = d; return ensureGroup(groupName, digest); })
    .then(function (id) { groupId = id; return getRoleDefId(roleName); })
    .then(function (id) { roleId = id; })

    /* 1. Break inheritance. copyRoleAssignments=false gives a clean slate;
          clearSubscopes=true discards any stale child scopes underneath. */
    .then(function () {
      return spFetch(target + '/breakroleinheritance(copyRoleAssignments=false,clearSubscopes=true)',
                     { method: 'POST', headers: writeHeaders(digest) });
    })

    /* 2. Grant the unit's group. */
    .then(function () {
      return spFetch(target + '/roleassignments/addroleassignment(principalid=' +
                     groupId + ',roledefid=' + roleId + ')',
                     { method: 'POST', headers: writeHeaders(digest) });
    })

    /* 3. Read the ACL back and assert it is exactly what you intended. */
    .then(function () { return readAcl(unitFolderUrl); });
}

function getRoleDefId(name) {          // role definition ids are per-site — always look them up
  return spFetch(SITE_URL + "/_api/web/roledefinitions/getbyname('" + spPath(name) + "')?$select=Id")
    .then(function (r) { return r.json(); })
    .then(function (d) { return d.d.Id; });
}
```

**Step 3 is not optional.** `copyRoleAssignments=false` does not leave an empty ACL: SharePoint prevents you from locking yourself out by adding **the calling user with Full Control** as the single remaining role assignment. Whoever runs provisioning is therefore on every unit they created, personally, by name — precisely the individual-on-the-ACL situation §4 tells you to avoid. Read the ACL back, and either remove that assignment deliberately or (better) run provisioning as an owner whose presence you're content to document.

Reading it back:

```javascript
function readAcl(folderUrl) {
  var q = SITE_URL + "/_api/web/getfolderbyserverrelativeurl('" + spPath(folderUrl) +
          "')/ListItemAllFields/roleassignments?$expand=Member,RoleDefinitionBindings" +
          '&$select=Member/Title,Member/LoginName,Member/PrincipalType,RoleDefinitionBindings/Name';
  return spFetch(q).then(function (r) { return r.json(); })
    .then(function (d) {
      return d.d.results.map(function (ra) {
        return { principal: ra.Member.Title,
                 type:      ra.Member.PrincipalType,   // 1=User, 4=SecurityGroup, 8=SharePointGroup
                 roles:     ra.RoleDefinitionBindings.results.map(function (b) { return b.Name; }) };
      });
    });
}
```

### The rest of the permission verbs

| Operation | Call |
|---|---|
| Does this object have its own ACL? | `GET <object>/HasUniqueRoleAssignments` |
| Break inheritance | `POST <object>/breakroleinheritance(copyRoleAssignments=false,clearSubscopes=true)` |
| Restore inheritance | `POST <object>/resetroleinheritance` |
| Grant | `POST <object>/roleassignments/addroleassignment(principalid=P,roledefid=R)` |
| Revoke | `POST <object>/roleassignments/removeroleassignment(principalid=P,roledefid=R)` |
| Read the ACL | `GET <object>/roleassignments?$expand=Member,RoleDefinitionBindings` |
| Role definition id by name | `GET /_api/web/roledefinitions/getbyname('Contribute')?$select=Id` |
| Principal id for a user | `POST /_api/web/ensureuser` with `{ "logonName": "<claims login name>" }` |
| Principal id for a SharePoint group | `GET /_api/web/sitegroups/getbyname('Deal 1042 Team')?$select=Id` |
| Create a SharePoint group | `POST /_api/web/sitegroups` with `{ "__metadata": {"type":"SP.Group"}, "Title": "..." }` |
| Add a member | `POST /_api/web/sitegroups(N)/users` with `{ "__metadata": {"type":"SP.User"}, "LoginName": "..." }` |
| Remove a member | `POST /_api/web/sitegroups(N)/users/removeById(M)` |
| The site's default groups | `GET /_api/web/associatedOwnerGroup` · `associatedMemberGroup` · `associatedVisitorGroup` |

**`copyRoleAssignments=true` vs `false`.** `true` copies the parent's ACL down, so nothing changes at the moment of breaking and you then add or remove from a known baseline — safer when you are securing an object that already has content and users. `false` gives a deterministic, minimal ACL — right for provisioning a brand-new unit, where you want exactly the group you are about to add. Pass `clearSubscopes=true` either way unless you know you want existing child scopes preserved.

**Never build permissions in a loop over existing data.** Breaking inheritance is a per-object server operation; a script that walks 3,000 existing rows will run for a long time, throttle, and half-finish. Provision at creation. If you must retro-fit, do it as a resumable [worker-pool](WORKER_POOL_PATTERN.aspx) job that records progress per unit and can be re-run safely.

---

## 8. What SharePoint Records for Free

The audit trail is the second half of this pattern's value, and it costs nothing — as long as calls are made **as the user**.

### Who created and last changed each record

Every list item and file carries `Author` / `Created` and `Editor` / `Modified`, stamped by SharePoint from the calling identity:

```
GET /_api/web/lists/getbytitle('Deals')/items(12)
    ?$select=Title,Created,Modified,Author/Title,Author/EMail,Editor/Title,Editor/EMail
    &$expand=Author,Editor
```

Surface these in the UI. "Raised by Jordan Okafor · 14 Aug 2026" makes the audit trail visible to users, which is what makes them trust it — and is free.

### Every intermediate state

Turn versioning on and each edit becomes a retrievable snapshot with **its own editor and timestamp**:

```
GET /_api/web/lists/getbytitle('Deals')/items(12)/versions
    ?$select=VersionLabel,VersionId,IsCurrentVersion,Created,CreatedBy/Title
    &$expand=CreatedBy
```

`CreatedBy` on a version is the person who saved *that* version — the version equivalent of `Editor`, and the column the audit question actually needs.

`Author`/`Editor` tell you the first and last writer. Versions tell you *everyone in between* — which is the actual audit question. Two hard rules from the base pattern:

- **Enable versioning before the first write.** History for everything written before you switched it on does not exist and cannot be backfilled.
- **Set a version limit** at provisioning (100–500 majors is usually right). The service ceiling is 50,000 majors, but unbounded versions on a busy list consume storage and slow item operations.

### Who deleted what

Deletions are not silent. The recycle bin records the deleter and the time, and it is queryable:

```
GET /_api/web/recyclebin?$select=Title,DeletedByEmail,DeletedDate,ItemState,DirName
```

Visibility follows the same rule as everything else: an ordinary user sees their own deleted items, while a site owner or collection administrator sees the site's. Build the "what was deleted here" view for owners, not for everyone.

### Change feeds for an activity view

For "what happened here recently" across a whole list, `GetChanges` returns a token-based change log (adds, updates, deletes) far more cheaply than diffing versions. Poll it with a stored `ChangeToken` and render an activity feed.

### Who can see this, right now

The ACL read in §7 answers *"who has access to this unit today"* directly, from the system of record. That is a genuine audit answer, and it is one HTTP call.

### What SharePoint does not give you locally

**"Who changed the permissions, and when?"** Grant and revoke events are recorded in the **Microsoft Purview audit log**, which is tenant-scoped and gated behind compliance roles — not something a citizen app can read. So:

> If your app performs permission changes, it must **write its own provenance row** for every grant and revoke — unit, principal, role, actor, timestamp, reason. That row is not enforcement (the ACL is), and it can drift, so the reconciliation job that compares provenance against live ACLs is part of the design, not a nice-to-have.

An `AccessGrants` list with `Unit`, `Principal`, `Role`, `Action` (Grant/Revoke), `Reason`, `ExpiresUtc` does double duty: it is the audit record the app can actually display, and it is the desired-state input the reconciler converges toward.

### The rule that makes all of it true

Every record above is only as good as the identity behind the call. **This platform's no-service-account rule is an audit rule.** The moment writes happen as a shared principal — a service account, an app-only token, or a Power Automate flow whose connection is owned by one person — every row in the audit trail says the same name, and the trail is worthless. Concretely:

- SharePoint App Pattern: browser calls carry the signed-in user's session. ✅
- Packaged Python / Worker Pool: interactive Entra sign-in as the running user. ✅ (This is also why a worker only ever processes what its operator can see.)
- Power Automate: **runs as the flow's connection owner, not the requester.** A flow that writes on a user's behalf collapses attribution to the flow owner. If a flow must write, have it stamp a `RequestedBy` field from the payload — and treat that field as a *claim by the caller*, not as an audited identity.

---

## 9. Where the Permission Model Gets Built and Kept

A correct permission design applied by hand, once, by one person is indistinguishable from no design at all six months later. Three operational practices carry it, and each is documented in full elsewhere — what follows is only the permissions-specific reason each one matters.

**One site per app** — see the [SharePoint App Pattern's siting guidance](SHAREPOINT_APP_PATTERN.aspx).

This is a permission decision before it is anything else. §5 established that the site is the security perimeter and its Owners group is the app's administrator list. It follows that **putting two apps in one site makes them share an administrator list**, whether or not that was ever anyone's intent — and no setting can undo it. Give each app its own site, joined to a hub for navigation, so ownership of one app never implies ownership of another's data.

**Provision through a setup page, never by hand** — see [Storage Shape & Lifecycle §5](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx).

The `provisionUnit()` sequence in §7 belongs in that page, ACL read-back included. Two things follow from putting permissions there rather than in a runbook: the ACL that exists is the ACL somebody reviewed, and standing up a second site — a test instance, another business unit — reproduces the permission model exactly instead of approximately. Setup that creates lists and leaves permissions to be clicked in later has solved the easy half.

**Watch the model from an admin page** — see [Storage Shape & Lifecycle §6](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx).

Two panels there are permissions panels, and nothing else surfaces them: **unique scopes per list against the 5,000 recommendation** (§2 — the limit that degrades silently), and the **access report** — each unit, its group, its member count, and the drift between live ACLs and the grants list. §8 says you have to build that report yourself because Purview holds the system record; the admin page is where it goes. Keep it derived: an admin page that stores its own copy of who-can-see-what is the two-sources-of-truth anti-pattern from §11 with a friendly UI.

---

## 10. Gotchas That Bite

- **Limited Access appears on parents you didn't touch.** Granting access to a folder auto-grants "Limited Access" on the library and site so the user can traverse to it. It confers no read on the parent's contents. Don't delete it, and don't be alarmed when it shows up in an ACL read.
- **Sharing links create scopes behind your back.** A member using "Share" on a file in your app's library creates a unique scope you didn't provision — silently widening access and consuming your scope budget. Restrict who can share at the site and library level as part of deploying an app that relies on ACLs.
- **The 100,000-item wall.** Past 100,000 items in a list, library, or folder, you cannot break or restore inheritance on that container at all. Design the unit before the container gets large.
- **Deleting a group does not tidy the ACLs.** The role assignments remain, pointing at a principal that no longer exists. Remove the assignments first, then the group.
- **Broken inheritance survives restores.** Restoring a deleted folder from the recycle bin brings its old scope back with it — including people since removed.
- **Renaming a folder does not change its ACL, but moving it can.** A move that crosses a scope boundary re-evaluates inheritance. Re-read the ACL after any programmatic move.
- **Entra group membership is not instant.** SharePoint group changes take effect on the next request; Entra security group changes can take significantly longer to reach a live session. Don't build a UI that says "access granted" and then shows the user nothing.
- **`PrincipalType` matters when reading ACLs.** `1` = user, `4` = Entra security group, `8` = SharePoint group. An ACL entry of type 4 means the answer to "who can see this" requires a second lookup you may not be permitted to make.
- **"Everyone except external users" is a claim, not a group you control.** It is often silently in the Members group of a default site. Check for it before assuming a site is private.

---

## 11. Anti-Patterns

| Anti-pattern | Why it fails | Instead |
|---|---|---|
| Filtering by role in JavaScript | Any user can call the REST API directly and get everything | Let security trimming filter; the data must not arrive |
| A `Permissions` or `AppRoles` list the app reads to decide access | Two sources of truth; the ACL is the real one and this one drifts | ACL enforces; a grants list may record *intent and provenance* only |
| Item-level unique permissions on a high-volume list | Scope explosion; degrades past 5,000, fails past 50,000 | Move the unit up to a folder or a list |
| Breaking inheritance by hand in the UI | Unreproducible, undocumented, impossible to reconcile | A `provisionUnit()` code path run at creation |
| Granting to individuals | ACL churn, no removal discipline, no way to answer "who is on this?" | One group per unit; membership is the moving part |
| Deciding granularity later | Splitting a shared list into secured units is a data migration | Name the permissible unit before the first column |
| Relying on site owners *not* looking | Full Control includes Manage Permissions; there is no such control | If it must be hidden from owners, it needs a different site |
| Caching or rolling up a trimmed query result for everyone | Publishes the cache-writer's view and leaks exactly what trimming prevented | Compute per user, or publish a deliberately non-sensitive summary |
| Reading `ItemCount` as "your items" | Counts are not security-trimmed | Count the trimmed result set |
| Provisioning ACLs by clicking through Site Settings | The ACL that exists is one nobody reviewed, and no second site can reproduce it | `provisionUnit()` in a setup page |
| Dropping a new app into an existing shared site | It inherits that site's owners — so it inherits its administrator list | One site per app, joined to a hub for navigation |
| An admin page that stores its own copy of who-can-see-what | A second source of truth with a friendly UI | Derive every panel from live ACLs |
| Writing through a service account or a shared flow connection | Every audit row says the same name | Every write happens as the acting user |

---

## 12. Design Checklist

Work through this before the first list is created.

1. **Name the permissible unit** in one sentence. Then ask whether anything inside it needs to be finer, and if so, name that too.
2. **Count the units** today and at three years' growth. That number picks the level: list-per-unit under ~200 (2,000-list ceiling), folder-per-unit into the low thousands, item-level only in the hundreds.
3. **Choose the securable level** from §2 and write down the scope count it implies. If the number is over 5,000, the unit is at the wrong level.
4. **Define the principals per unit.** One group per unit if membership varies; one shared group across units if it doesn't. Decide SharePoint group vs. Entra group by where membership is authoritative.
5. **Write `provisionUnit()` before writing the UI.** Create object → break inheritance → grant the group → **read the ACL back and assert it**.
6. **Decide the removal trigger.** What event removes access, who fires it, and what job catches the cases where nobody does. If there is no answer, access will only ever accumulate.
7. **Turn versioning on at provisioning**, with a version limit, before the first write.
8. **Derive the admin surface** from `effectivebasepermissions`. Store no role list. Name the site's owners in the app's README and say who reviews them.
9. **Write down what this site must not hold** — data that must be invisible to its owners. If any exists, split the site now.
10. **Add the provenance list** if the app grants access itself, plus the reconciliation job that compares it to live ACLs.
11. **Give the app its own site** — see the [SharePoint App Pattern](SHAREPOINT_APP_PATTERN.aspx). Two apps in one site share an administrator list.
12. **Put `provisionUnit()` in a setup page**, not a runbook — see [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx).
13. **Put the scope budget and the access report on an admin page** — the two permission numbers nothing else surfaces.

---

## What This Pattern Is Good For

- Team apps where each row of "the" table belongs to a different subset of people — deals, cases, clients, vendors, incidents, regions
- Hierarchical visibility (a manager sees their subtree) without maintaining the hierarchy anywhere
- Segregation of duties: approvals, sign-offs, reviews, four-eyes checks
- Any app that will be asked "who could see this, and who changed it?" — the answer is native and one call away

## What It Is Not Good For — Escalate Instead

- **Regulated data** (PHI, payment data, export-controlled material). Out of scope for the citizen tier, same boundary as every other pattern.
- **Anything that must be invisible to the site's owners while living in their site.** Not achievable; needs its own site with its own owners, or IT-hosted storage.
- **Legal-hold, tamper-evident, or attestable audit.** SharePoint versioning is an operational record, not a compliance archive — that is Purview retention and eDiscovery, an IT-owned capability.
- **Row counts in the tens of thousands each needing distinct access.** Past the 5,000-scope recommendation, redesign the unit or move to a system built for row-level security.
- **External or anonymous users.** External sharing is a tenant-governance decision, not an app decision.
- **Sub-second permission changes at scale.** Provisioning is a server operation per object; bulk grants are a background job, not a click.

---

## Quick Reference

| Need | Use |
|---|---|
| Decide the data model | Name the permissible unit first; it becomes the securable object |
| Secure many artifacts per unit | Folder per unit, inheritance broken at creation |
| Secure few, dataset-sized units | List per unit (budget: 2,000 lists per site collection) |
| Secure one record per person | File or item per principal (budget: 5,000 scopes per list) |
| "Only your own items" | `ReadSecurity: 2` / `WriteSecurity: 2` on the list — zero scopes |
| Filter by who may see it | Nothing — issue the plain `GET`; SharePoint trims it |
| Reconstruct a hierarchy | Enumerate what the user can read and compose it client-side |
| Add or remove a person | Group membership write, never an ACL write |
| Break inheritance | `POST <object>/breakroleinheritance(copyRoleAssignments=false,clearSubscopes=true)` — then read the ACL back |
| Grant / revoke | `roleassignments/addroleassignment` · `removeroleassignment` (`principalid`, `roledefid`) |
| Look up a role definition id | `GET /_api/web/roledefinitions/getbyname('Contribute')?$select=Id` — per-site, never hardcode |
| Read who has access | `GET <object>/roleassignments?$expand=Member,RoleDefinitionBindings` |
| Detect an administrator | `GET /_api/web/effectivebasepermissions` → ManageWeb bit (`Low & 0x40000000`) |
| Per-object button gating | `GET <list-or-item>/effectivebasepermissions` |
| Who created / last changed | `$select=Author/Title,Created,Editor/Title,Modified&$expand=Author,Editor` |
| Everyone in between | `GET <item>/versions?$expand=CreatedBy` — versioning must be on **before** the first write |
| Who deleted it | `GET /_api/web/recyclebin?$select=Title,DeletedByEmail,DeletedDate` |
| Recent activity on a list | `GetChanges` with a stored `ChangeToken` |
| Who changed permissions | Your own provenance list — Purview holds the system record, and citizen apps can't read it |
| Keep the audit trail real | Every write happens as the acting user — no service accounts, no shared flow connections |
| Hide data from site owners | Not possible — put it in a different site |
| Stand up a new app | Its own site — two apps in one site share an administrator list |
| Provision ACLs reproducibly | `provisionUnit()` inside the app's setup page, never the SharePoint UI |
| Watch the scope budget | Admin page: unique scopes per list against the 5,000 recommendation |
