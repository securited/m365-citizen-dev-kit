# Claude Code — SharePoint Permissions & Auditing: Project Prompt

> **SharePoint Permissions & Auditing — v1.1** · updated 2026-08-20. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Copy the block below as your first message when an app needs access control or an audit trail. **Attach the prompt for the app's own pattern with the same message** — [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md) for a browser app, [PACKAGED_PYTHON_PROMPT.md](PACKAGED_PYTHON_PROMPT.md) for a local app, [WORKER_POOL_PROMPT.md](WORKER_POOL_PROMPT.md) if a job will provision permissions — and [SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md](SHAREPOINT_STORAGE_LIFECYCLE_PROMPT.md) when the app will create many units or accumulate data over time. This prompt does not replace them; it constrains the data model they produce. Customize the bracketed sections and replace every `<...>` placeholder.

---

```
You are designing the access-control and audit layer of an application whose
data lives in SharePoint. The prompt for the app's own pattern is included with
this message and every rule there is binding; this prompt adds the permission
rules and takes precedence where they overlap. Deviation from either is a
defect.

SharePoint's own permission system IS the authorization layer. You are not
building one. Your job is to shape the storage so SharePoint's ACLs, security
trimming, and system-stamped audit columns land where the requirements need
them.

## How to read this prompt

Sections marked (fixed) are binding: deviation is a defect. Sections marked
(default) are the recommended choice, NOT a prohibition. If a default does not
fit this project, say so, propose the alternative with its trade-off, and get
the user's agreement before building it — then note the decision in the app's
README.

Never silently deviate from a default, and never tell the user that something a
default merely discourages is impossible. If a (fixed) rule is the real
obstacle, stop and escalate rather than working around it.

## Rule 0 — the permissible unit comes first (fixed as a process step)

Before proposing lists, columns, or UI, state in one sentence: what is the
smallest thing that two different people might legitimately need different
access to? That is the permissible unit, and it MUST become its own securable
object (a site, a list/library, a folder, or an item/file).

Confirm the unit with the user before designing anything else. If the answer
implies a permissible unit that is a ROW in a shared list, say so and propose
the folder-per-unit or list-per-unit alternative — granularity cannot be
retrofitted without a data migration, so this is a day-one decision. When in
doubt, choose the finer unit; merging later is free, splitting later is not.

## Choosing the securable level (default — but the budgets below are Microsoft's)

  Site           — whole-app / whole-department tenancy; the ONLY way to hide
                   data from another site's owners
  List/library   — 10-200 stable units each holding many rows.
                   Ceiling: 2,000 lists and libraries per site collection
  Folder         — hundreds to low thousands of units holding mixed artifacts.
                   DEFAULT CHOICE for most apps
  Item/file      — one record per principal, in the hundreds.
                   Ceiling: 5,000 unique scopes per list recommended,
                   50,000 supported

Also fixed: past 100,000 items in a list, library, or folder you can no longer
break or restore inheritance on that container. State the projected scope count
for the design you propose. If it exceeds 5,000, the unit is at the wrong level
— move it up and say so.

For data whose rule is exactly "yours and nobody else's" (drafts, personal
submissions), do NOT create scopes: MERGE the list with ReadSecurity: 2 and
WriteSecurity: 2. Zero scopes, any list size. It cannot express sharing, and it
does not apply to site owners.

## Enforcement rules (fixed)

1. NEVER filter by role in JavaScript or Python and call it access control.
   Any user with write access can call the REST API directly. If the user must
   not see it, the data must not be returned. Issue the plain GET and let
   security trimming do the filtering.
2. NEVER create a Permissions / AppRoles / Visibility list that the app reads
   to decide access. The ACL is the only source of truth. A grants list may
   record intent and provenance ONLY (see Auditing).
3. NEVER store an admin role. Derive it (see Administrators). A stored role
   list drifts from the permissions that actually apply, and site owners can
   edit themselves into it anyway.
4. NEVER cache or roll up a security-trimmed result for other users. A trimmed
   response is the caller's view; publishing it leaks what trimming prevented.
5. Every write happens as the acting user. No service accounts, no app-only
   tokens. This is an AUDIT rule: shared identity collapses the trail.
6. NEVER break inheritance in a loop over existing data at runtime. It is a
   per-object server operation; it will throttle and half-finish. A retrofit
   is a resumable background job.

## Operational defaults

These are strongly recommended and cost maintenance rather than safety when
broken, so they are decisions rather than prohibitions. Propose the default,
and if the user wants otherwise, say what it costs and record it.

- **One group per permissible unit, and the group is the only ACL entry.**
  Adding or removing a person is then a group-membership write, the ACL is
  written once at provisioning, and "who is on this?" has a one-call answer.
  Putting an individual directly on an ACL is not insecure, it is unmaintainable
  at scale — ACL entries grow with people times units and removals get missed.
  For a genuine one-off (a single long-lived unit, one named reviewer), an
  individual grant is a reasonable call: make it deliberately and write it down.
  Use SharePoint groups when the app manages membership (immediate,
  REST-manageable); Entra security groups when membership is authoritative
  elsewhere (and warn that propagation is not instant).
- **Provision permissions from code, not the SharePoint UI.** provisionUnit()
  run at unit creation means the ACL that exists is one somebody reviewed, and
  a second site reproduces it exactly. Clicking through Site Settings works and
  is sometimes the pragmatic answer for a single fixed unit; it just cannot be
  reproduced, reviewed, or audited later.

## Provisioning a unit (fixed sequence)

Write provisionUnit() before writing any UI. For each new unit:

  a. Create the object (folder / list / file).
  b. Ensure the unit's group exists:
     GET  /_api/web/sitegroups/getbyname('<name>')?$select=Id
     POST /_api/web/sitegroups  { "__metadata":{"type":"SP.Group"}, "Title":... }
  c. Look up the role definition id BY NAME — ids are per-site, never hardcode:
     GET /_api/web/roledefinitions/getbyname('Contribute')?$select=Id
  d. Break inheritance:
     POST <object>/breakroleinheritance(copyRoleAssignments=false,clearSubscopes=true)
     Use copyRoleAssignments=true instead when securing an object that already
     has content and users, so you start from a known baseline.
  e. Grant the group:
     POST <object>/roleassignments/addroleassignment(principalid=P,roledefid=R)
  f. READ THE ACL BACK AND ASSERT IT. This step is mandatory, not a debug aid:
     breakroleinheritance(false) does not leave an empty ACL — SharePoint adds
     THE CALLING USER with Full Control so they cannot lock themselves out. If
     that assignment is not wanted, remove it explicitly.
     GET <object>/roleassignments?$expand=Member,RoleDefinitionBindings

Object paths: /_api/web · /_api/web/lists/getbytitle('X') ·
.../items(N) · /_api/web/getfolderbyserverrelativeurl('...')/ListItemAllFields ·
/_api/web/getfilebyserverrelativeurl('...')/ListItemAllFields

Other verbs: resetroleinheritance · removeroleassignment(principalid,roledefid)
· HasUniqueRoleAssignments · /_api/web/ensureuser (user principal id) ·
/_api/web/sitegroups(N)/users (add member) · .../users/removeById(M).

## Administrators (fixed)

Site owners are the application's administrators. Full Control includes Manage
Permissions, so an owner can grant themselves anything in the site. Do not
build a second admin list — it adds nothing and drifts.

Derive the admin flag from GET /_api/web/effectivebasepermissions, testing the
SPBasePermissions bit against the returned High/Low pair:

  manageWeb            Low  & 0x40000000   (Full Control / site owner)
  managePermissions    Low  & 0x02000000
  manageLists          Low  & 0x00000800
  addAndCustomizePages Low  & 0x00040000
  enumeratePermissions High & 0x40000000

Use this rather than /_api/web/currentuser/groups or the associatedOwnerGroup
membership — those miss ownership arriving through a nested Entra group.
Add GET /_api/web/currentUser?$select=Id,Title,LoginName,IsSiteAdmin for site
collection administrators. Use <list-or-item>/effectivebasepermissions to gate
per-object buttons.

Hiding admin UI is a courtesy, never a control — the server enforces.

State plainly in the README and to the user: data in this site is reachable by
its owners and by site collection administrators, and no setting changes that
(ReadSecurity/WriteSecurity do not apply to them either). If any data must be
invisible to the site's owners, it belongs in a SEPARATE SITE — say so and stop
rather than designing around it. Recommend at least two named site owners.

## Auditing (fixed)

Use what SharePoint stamps; do not write a parallel audit log for these:

- Author/Created and Editor/Modified on every item and file. Surface them in
  the UI ($select=Author/Title,Created,Editor/Title,Modified&$expand=Author,Editor).
- Versioning: enable it AT PROVISIONING, before the first write — history
  cannot be backfilled — and set a version limit (100-500 majors). Read via
  <item>/versions?$expand=CreatedBy — a version's saver is CreatedBy, NOT
  Editor. Author/Editor give first and last writer; versions give everyone in
  between.
- Deletions: GET /_api/web/recyclebin?$select=Title,DeletedByEmail,DeletedDate
  — an ordinary user sees only their own deletions, so build this view for
  owners.
- Activity feed: GetChanges with a stored ChangeToken, not version diffing.
- "Who can see this now": read the ACL — one call, from the system of record.

Segregation of duties: express an approval as a NEW ITEM in a separate list
where only approvers have Contribute, so the approver's identity is the
server-stamped Author. Never as a status field an app-side check refuses to
change — that is bypassable with one REST call.

The one thing SharePoint does not give the app: who changed the PERMISSIONS.
That lives in the Microsoft Purview audit log, which citizen apps cannot read.
So IF AND ONLY IF the app grants or revokes access itself, add an AccessGrants
list (Unit, Principal, Role, Action, GrantedBy, GrantedUtc, Reason, ExpiresUtc)
as provenance and desired state, plus a reconciliation job that converges live
ACLs toward it and reports drift. It is never enforcement.

Power Automate caveat: a flow runs as its connection owner, not the requester.
If a flow writes, have it stamp RequestedBy from the payload and treat that
field as a caller's claim, not an audited identity.

## Where the permission model gets built (default)

SITING. This app gets its OWN SharePoint site. A site's Owners group holds
Manage Permissions, so the site's owners are the app's administrators — putting
two apps in one site makes them share an administrator list, and no setting
undoes that. Adding the app to an existing shared site, a department team
site, or anyone's OneDrive inherits that site's owners as this app's
administrators. That is sometimes acceptable — a team tool inside the team's
own site, owned by the same people — and sometimes exactly the thing to avoid.
Name the site's current owners, say that they will administer this app's data,
and let the user decide with that in front of them.

PROVISIONING. The provisionUnit() sequence above goes in the app's SETUP PAGE,
ACL read-back included. An ACL created by hand is one nobody reviewed and no
second site can reproduce, so prefer the page. For a single unit whose
permissions will never change, clicking it in is a reasonable call — make it
deliberately and record it, rather than arriving there by default. The setup page
must gate on effectivebasepermissions (manageLists, managePermissions) with a
plain-English message rather than failing halfway through and leaving a
half-built site, and it must verify itself by re-reading the ACLs it wrote.

ADMIN SURFACE. Put two permission panels on the app's admin page, because
nothing else surfaces them: unique permission scopes per list against the 5,000
recommendation, and an access report (each unit, its group, its member count,
and drift between live ACLs and the grants list). Both are DERIVED from live
state — an admin page that stores its own copy of who-can-see-what is the
two-sources-of-truth anti-pattern with a friendly UI. Gate the page on
effectivebasepermissions and degrade with a clear message; state on the page
that the report shows what THIS VIEWER may enumerate.

OWNERSHIP. Require at least two named site owners, and put the last-reviewed
date where owners will see it.

The full siting, setup-page, and admin-page requirements are in the SharePoint
App Pattern and the Storage Shape & Lifecycle pattern. If those prompts are
attached, follow them; this section is the permissions-specific subset.

## Design the removal path (fixed as a question to answer)

Adds are event-driven; removals are not, and that is where every home-grown
access system fails. For each unit type, state: what event removes access, who
fires it, and what scheduled job catches the cases where nobody does. Never
grant time-boxed access to an individual — grant the group and expire the
membership. If the user cannot answer the removal question, say that access
will only ever accumulate and propose the reconciliation job.

## Gotchas to honor in the design (fixed — these are platform behaviours)

- Absence is ambiguous: a trimmed-away item is indistinguishable from a
  non-existent one. If users must know something exists without seeing it,
  publish a separate readable summary.
- ItemCount is NOT security-trimmed — never label it "your items".
- A $top page may return fewer items than requested and still have more.
  Always follow d.__next; never infer end-of-list from a short page.
- Search is trimmed but lags minutes to hours; use REST for anything the user
  just did.
- "Limited Access" appears automatically on parent objects for traversal.
  Do not delete it.
- Sharing links create unique scopes you did not provision. Recommend
  restricting who can share on any library the app secures.
- Deleting a group leaves its role assignments behind — remove assignments
  first. Restoring a deleted folder restores its old scope.
- PrincipalType in an ACL read: 1=User, 4=Entra security group, 8=SharePoint
  group.

## Out of scope — stop and escalate (fixed)

- Regulated data (PHI, payment data, export-controlled)
- Anything that must be invisible to the hosting site's owners
- Legal-hold, tamper-evident, or attestable audit (Purview retention /
  eDiscovery, IT-owned)
- Tens of thousands of rows each needing distinct access — redesign the unit
  or escalate to a system with row-level security
- External or anonymous access — a tenant governance decision, not an app one

---

## Project-Specific Context

**Application name:** [App Name]
**Owner:** [name + email]
**SharePoint site:** [site URL — its own site; new or existing?]
**Hub site / site registry:** [hub URL, registry list]
**Site owners (= the app's administrators):** [names — at least two]

**Permissible unit (one sentence):** [e.g. "one M&A deal"]
**Unit count today / in 3 years:** [n / n]
**Securable level chosen:** [site | list | folder | item] — **projected scopes:** [n]

**Access model:**
| Unit | Group on its ACL | Role | Who is in the group | Membership authority |
|---|---|---|---|---|
| [deal] | [Deal <id> Team] | [Contribute] | [deal team] | [app-managed SP group] |

**Data NOT secured per unit (shared, read-mostly):** [lists/libraries that just inherit the site]
**Data that must be invisible to site owners:** [none — or STOP and site it separately]

**Setup page name:** [<app>-setup.aspx — provisions the ACLs, run once by an owner]
**Removal trigger per unit:** [event, who fires it, reconciliation job]
**Audit requirements:** [what questions must the app answer, and for whom]
**Does the app grant access itself?** [yes → AccessGrants provenance list + reconciler | no]

Begin by confirming the permissible unit and the projected scope count. Do not
design lists, columns, or UI until both are agreed, and state the securable
level you are choosing and why before writing provisionUnit(). Build the setup
page before anything is provisioned by hand — if you ever find yourself writing
"now go into Site Settings and...", stop and put that step in the setup page
instead.
```
