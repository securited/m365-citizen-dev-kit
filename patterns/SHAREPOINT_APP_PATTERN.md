# Building Applications with the SharePoint App Pattern

> **SharePoint App Pattern — v1.12** · updated 2026-09-03. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

A guide for designing and deploying custom web applications on SharePoint as a complete application platform — no external servers, no separate hosting.

> **Starting a new app?** See [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md) for a complete prompt you can give Claude to constrain development to this pattern's conventions. Copy it as your first message when beginning a new project.

---

## Executive Summary

This platform turns SharePoint into an application hosting environment using only files, lists, and Microsoft 365 services you already have. Every application follows the same pattern:

**A boot-only `.aspx` shell** lives in a document library and serves as the entry point. It loads assets from a companion `_data/` subfolder at runtime, defines the handful of helpers those assets build on, and shows loading and error states — **no feature code and no application state**. Two reasons: SharePoint's content scanner scrutinizes `.aspx` files, so a small, inert shell reduces the surface area for false positives; and updating an `.aspx` costs a custom-script window plus Design or Full Control while `_data/` files cost neither, so a shell holding only boot logic never has to change again.

**SharePoint Lists are the database.** Each list is a table; columns are fields; items are rows. The SharePoint REST API provides full OData querying — filtering, sorting, pagination, and lookups — with no external database or API server. Lists hold millions of items and auto-provision on first use.

**JSON files in the `_data/` folder are a lightweight data layer** for configuration, static lookup tables, and reference data that doesn't need per-row querying. They're read at runtime via the same REST endpoint as CSS and HTML.

**Every user is already authenticated.** There is no login screen to build. Identity is resolved via a single REST call (`/_api/web/currentUser`) — no OAuth flows, no token management, no session handling.

**Power Automate handles all server-side logic.** Sending email, calling external APIs, running approvals, executing on a schedule — these are HTTP-triggered flows your application calls with a `fetch()`. No backend server required.

**Microsoft Graph extends the platform** with rich user data: full profile, photo, manager, presence, and directory search — using the same authenticated session.

The result is a complete application stack deployed as a handful of files inside your existing M365 tenant. Anyone in your organization can access it, secured by your existing identity system, with no infrastructure to maintain.

### Enabling Deployments

Before uploading `.aspx` files to a SharePoint site, custom scripts must be enabled on that site. **You open that window yourself, in seconds** — from the [self-service enablement page](https://contoso.sharepoint.com/sites/euda-sample/script-enablement/script-enablement.aspx) or from your deploy script. No help desk ticket, no admin rights. Once enabled, the site has a 24-hour window to upload and register your application files; after it closes, the setting resets automatically.

Access is granted per site, once. Register your site on the enablement page and an EUDA admin approves it with one click; from then on you enable that site whenever you deploy. Several people can each hold a grant for the same site.

Updating the shell (`.aspx`) later means opening the window again — seconds, not a ticket. Files in the `_data/` folder — CSS, HTML, JSON — can be updated any time with no enablement at all, because they are plain document files, not executable scripts.

> Enabling a site is a tenant-admin operation performed on your behalf by a service that re-checks your grant server-side. You never hold admin rights, and asking for a site you have no grant for is simply denied.

---

## What This Platform Is

SharePoint is usually seen as a document management and intranet tool. With custom script support enabled, it becomes an application hosting environment: files live in document libraries, data lives in lists, users are already authenticated, and backend logic runs through Power Automate.

The result is a complete application stack that deploys inside your existing Microsoft 365 tenant — accessible to anyone in your organization, secured by your existing identity system, and maintained without external hosting.

---

## Core Concepts

### The Shell + Data Pattern

Every application follows a two-part structure:

**The shell** is a boot-only `.aspx` file that SharePoint executes as a web page. It contains:
- A loading indicator, shown immediately
- The canonical helpers its assets build on (`deriveSiteUrl`, `spPath`, `spFetch`, `fetchAsset`)
- Asset loading from the companion `_data/` folder, and injection into the page
- Loading and error UI, then a hand-off to the app's init

**It contains no feature code and no application state (Fixed).** Everything else lives in `_data/`. The test is behavioural, and you can apply it to any line: *would this code ever have to change in order to add a feature?* If yes, it belongs in `_data/`.

**There is no size limit on the shell.** SharePoint does not impose one and neither does this pattern. Reference shells happen to run 6–8 KB, and a shell drifting past roughly 15 KB is a useful hint that logic has leaked in — but that is a smell worth investigating, not a budget to spend or a ceiling to fit under. Never minify, compress, or golf a shell to hit a number: either it is holding logic that should move to `_data/`, in which case move it, or it is not, in which case its size is fine. Reports of this figure hardening into an invented hard limit are why it is spelled out this plainly.

**The data folder** is a document library subfolder containing the actual application files:
- `styles.css` — all visual styling
- `content.html` — all HTML markup
- Optionally: additional JS modules, images, config files

Two reasons for the split. **Scanner surface:** SharePoint's content scanner scrutinizes `.aspx` files closely, so a small, inert shell reduces false positives; companion files load as raw text through the REST API, bypassing content-type enforcement. **Deployment friction:** changing the `.aspx` requires a custom-script window *and* Design or Full Control at upload, while `_data/` files need only Contribute. That asymmetry is the platform's most important operational constraint — see **Adding Modules Without Redeploying the Shell** below for how to keep the shell fixed for the life of the app.

**Naming convention:** If the shell is `my-app.aspx`, the data folder is `my-app_data/`.

---

### Authentication Is Free

Every user visiting your application is already authenticated by Microsoft 365. You never build a login screen or manage tokens. If a user can reach your page, you know who they are.

Identity is resolved in one of two ways depending on where your file lives:

**Site Pages** (`.aspx` files in the Site Pages library with a master page) receive a global object called `_spPageContextInfo` automatically:
```
_spPageContextInfo.userDisplayName   — "Ted Kieffer"
_spPageContextInfo.userLoginName     — "sample.user@company.com"
_spPageContextInfo.userId            — SharePoint user ID (integer)
_spPageContextInfo.webAbsoluteUrl    — current site URL
_spPageContextInfo.formDigestValue   — security token for write operations
```

**Document library ASPX files** — the deployment model this platform uses — do **not** receive `_spPageContextInfo`. The object will be undefined. Resolve identity via a single REST call instead:
```
GET /_api/web/currentUser?$select=Title,LoginName
```
This returns the same display name and login name with no additional authentication. Implement it as the primary identity path, treating `_spPageContextInfo` as a bonus when present.

Similarly, derive the site URL from `window.location` rather than `_spPageContextInfo.webAbsoluteUrl`:
```javascript
function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}
```

---

### Lists Are Your Database

SharePoint Lists are the primary data store for every application. Think of each list as a database table:

- **Columns** are your fields — text, number, date, boolean, choice, person, lookup, calculated
- **Items** are your rows
- **Views** are pre-defined filtered and sorted subsets
- **Versioning** gives you a built-in audit trail at no cost
- **Item-level permissions** let you control who can read or write individual records

Query lists via the SharePoint REST API using OData syntax — filtering, sorting, selecting columns, expanding lookups, and paging through large result sets.

A single list holds millions of items. The 5,000-item query threshold is a per-query limit, not a list size limit. With indexed columns and paginated queries, applications handle very large data sets.

---

### Files as a Data Source

Not all data belongs in a list. For read-mostly, structured data that doesn't need per-row querying or user-level permissions, JSON files in the `_data` folder are a lighter-weight alternative.

**Good fits for file-based data:**
- Application configuration (feature flags, thresholds, display labels)
- Static lookup tables (department codes, status options, category trees)
- Reference data shared across the app but rarely updated (product catalogs, region maps)
- Seed data loaded once on first use

The snippets below use two canonical helpers every app defines once: `spPath()` escapes apostrophes in REST path segments (`p.replace(/'/g, "''")`), and `spFetch()` wraps `fetch()` with `credentials: 'same-origin'` and a default `Accept: application/json;odata=verbose` header. Full definitions are in the [project prompt](SHAREPOINT_APP_PROMPT.md) and the hello-world reference app.

**Reading a JSON file:**

```javascript
function loadConfig(filename) {
  var url = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
    spPath(DATA_FOLDER + '/' + filename) + '\')/$value';
  return spFetch(url, { headers: { 'Accept': 'text/plain' } })
    .then(function (r) { return r.ok ? r.text() : null; })
    .then(function (text) { return text ? JSON.parse(text) : null; });
}
// Usage: loadConfig('lookup-data.json').then(function(data) { ... });
```

**Writing a JSON file** (for app-managed config, not user content):

```javascript
function saveConfig(filename, data, digest) {
  var url = SITE_URL + '/_api/web/getfolderbyserverrelativeurl(\'' +
    spPath(DATA_FOLDER) + '\')/files/add(url=\'' + filename + '\',overwrite=true)';
  var bytes = new TextEncoder().encode(JSON.stringify(data, null, 2));
  return spFetch(url, {
    method: 'POST',
    headers: { 'X-RequestDigest': digest, 'Accept': 'application/json;odata=verbose' },
    body: bytes.buffer
  });
}
```

#### Files the App Rewrites at Runtime Are Seeds Locally, State Remotely

The moment an app writes a JSON file back to `_data/`, that file stops being deployment output and becomes **live state**. The copy in your repo is only a first-run seed; the deployed copy holds whatever an admin has configured since. A deploy that uploads the local copy silently reverts every setting — no error, no warning, and nothing visibly wrong until someone notices the app is back to defaults.

Register every such file as **seed-only** in the deploy script's `-SeedOnlyFiles` list. Seed-only files are uploaded when missing remotely, never overwritten, and never removed as stale:

```powershell
.\Deploy-SampleLibrary.ps1 -SeedOnlyFiles 'samples/euda-worker_data/latest.json','samples/my-app_data/site-config.json'
```

The rule is mechanical: **if the app can write it, the deploy must not.** Any file passed to `files/add(overwrite=true)` at runtime belongs on that list the day it is introduced — not the day someone discovers their settings reset.

**When to use a file vs. a list:**

| Situation | Use |
|---|---|
| Data has many rows, needs filtering or sorting | List |
| Data is written by end users through a form | List |
| Data needs item-level permissions | List |
| Data is a small static table (< a few hundred rows) | JSON file |
| Data is app configuration read at startup | JSON file |
| Data is written by admins, not end users | JSON file |
| Data is written frequently or concurrently | List (files have no transaction safety) |

The main limitation of file-based data is no querying — you load the entire file and filter in JavaScript. Fine for small datasets; for anything that could grow large or needs server-side filtering, use a list.

---

### Power Automate Is Your Backend

For any logic that shouldn't run in the browser — sending emails, processing data, calling external APIs, running on a schedule, enforcing approvals — use Power Automate.

The common pattern is the **HTTP-triggered flow**: your application POSTs a JSON payload to a Power Automate HTTP trigger URL, and the flow handles the rest. From the application's side it's an API call; the flow runs all server-side logic with no code deployment.

When the caller is **another EUDA application** rather than this app's own UI, a flow is one of four integration shapes and usually not the first to reach for: a SharePoint list carries the request with an audit trail and no bearer-secret URL to protect. See [Cross-Application Communication](CROSS_APP_COMMUNICATION_PATTERN.aspx).

Power Automate can:
- Send emails and Teams messages
- Call external REST APIs — **but see the licensing caveat below**
- Read and write SharePoint lists
- Run approval workflows with notifications and responses
- Execute on a schedule
- Respond synchronously with a result

#### Getting External API Data Into SharePoint

Consuming a third-party API is a normal thing to build here. The only fixed rule is **where the call is made from**: never from the browser when it needs a credential, because a browser reads everything the page reads.

Beyond that, the route is a Default, and one licensing fact usually decides it. **Power Automate's generic HTTP action is a premium connector** ([Microsoft, Power Automate licensing](https://learn.microsoft.com/en-us/power-platform/admin/power-automate-licensing/types)). Without a premium or per-flow licence, a flow cannot call an arbitrary external API at all — which makes "just use a flow" advice that quietly fails for most citizen developers. Check the licence before designing around it.

| The API… | Route |
|---|---|
| Is public, needs no auth, and sends CORS headers for our origin | Direct `fetch()` from the browser. Verify CORS from the SharePoint origin first — most APIs don't allow it |
| Needs a key or token, and premium licensing **is** available | Power Automate flow holding the credential; the app calls the flow |
| Needs a key or token, and premium licensing is **not** available | **A companion [Packaged Python](PACKAGED_PYTHON_PATTERN.aspx) app** that calls the API and writes results to a SharePoint list this app reads normally |
| Must refresh on a guaranteed schedule regardless of who is online | Neither citizen route — escalate to IT-hosted |

**The companion-app route is the workhorse, and it is not a fallback.** It needs no premium licence, gives you real Python for parsing and transformation, and runs as a named person, so every row it writes carries a real identity and the audit trail stays intact. Two shapes: **Pattern B plus Task Scheduler** when one owner's machine is reliably on, or the [Worker Pool](WORKER_POOL_PATTERN.aspx) pattern when the team should keep it running rather than one person.

The seam is the list. The browser app never knows the API exists — it reads a SharePoint list like any other data, which also means the ingestion route can change later without touching the app.

---

## Designing Your Application

### Where the App Lives: One Site Per App

**Default to a new site for every app you build.** Not another list in an existing site, and never a folder in someone's OneDrive or in a general-purpose department Team site.

The reason is ownership. A site's **Owners group holds Full Control, which includes Manage Permissions** — so the people who own the site can reach everything in it and grant themselves anything they cannot already reach. That makes the site's owners the administrators of every app inside it. Putting two apps in one site means they share an administrator list, whether or not that was ever anyone's intent, and no setting undoes it.

Everything else is a bonus, and it all points the same way:

- **Capacity ceilings stop being shared.** The 2,000-lists-and-libraries limit and each list's permission-scope budget are per site collection. One app per site means one app's growth can never crowd out another's.
- **Storage and growth are legible.** One quota, one recycle bin, one set of numbers. In a shared site, "which app is consuming this?" has no answer.
- **The custom-script window is scoped to it.** The 24-hour enablement you open to deploy one app's shell touches nothing else.
- **Sharing settings are per site.** You can restrict external sharing and members' ability to reshare for the app that needs it, without imposing that on unrelated teams.
- **Decommission is one delete.** When the app is retired, its data, lists, groups, and permissions go with it. Apps that lived in a shared site leave orphaned lists nobody dares remove.

**Conventions that keep this manageable:**

- **Create a Communication site, not a Team site**, unless the app genuinely needs an M365 group, a Teams tab, or a shared mailbox. A Team site drags along a group, a Teams presence, and a second membership model that will drift from whatever groups the app manages.
- **Name sites on a visible convention** — `euda-<app-name>` — so growth stays readable in the admin center and in search.
- **Join them to a hub site** for shared navigation, search scope, and branding. A hub links sites without merging their permissions: one place to find every app, no shared administrator list.
- **Keep a site registry** — a list on the hub naming each app, its site URL, its owners, its purpose, and its last-reviewed date. One site per app trades crowding for sprawl, and the registry is what makes sprawl answerable. It is itself a small app on this platform.

**The honest cost:** cross-app rollups get harder. Within one site you can query lists directly; across sites you are into search, which is security-trimmed but index-lagged by minutes to hours. If two "apps" genuinely need to query each other's data row by row, they are one app in one site — decide that before splitting them. When they are genuinely two apps and one still needs what the other holds, the answer is a published contract, not a direct read of the other app's lists.

Access control *within* the app is a separate question, and a deep one: see [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx). How many objects the app creates and what happens to old data are covered in [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx). What this app publishes to other apps, and what it may read from them, is [Cross-Application Communication](CROSS_APP_COMMUNICATION_PATTERN.aspx).

---

### Start With the Data Model

Before writing application code, design your SharePoint lists. Ask:

1. What are the core entities? (People, projects, requests, items, events?)
2. What are the relationships between them? (Use Lookup columns)
3. What columns will you filter or sort on? (Index those immediately)
4. What columns are rarely needed? (Leave them out of default queries using `$select`)
5. Do you need history? (Enable versioning)
6. Does any data need to be restricted? (Plan item-level permissions)

Getting the list schema right before building the UI saves significant rework.

---

### Navigation: Views, Not Pages

Because the shell is a single `.aspx` file, navigation happens entirely in JavaScript. The recommended pattern is **view switching** — showing and hiding sections of the page rather than navigating to new URLs.

Each "page" in your app is a `<div>` with an ID. A central `showView(viewName)` function manages which is visible:

```javascript
function showView(view) {
    document.querySelectorAll('.view').forEach(el => el.classList.add('hidden'));
    document.getElementById(view + '-view').classList.remove('hidden');
    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
    document.getElementById('nav-' + view).classList.add('active');
}
```

No page loads between views keeps the app fast and keeps all application state in memory while the user navigates.

---

### Query Design for Large Lists

The 5,000-item query threshold is the most common performance concern for list-backed applications. Follow these rules:

**Index every column you filter or sort on.** An indexed column filter bypasses the threshold. Add the index **at provisioning time, from your app** — see Provisioning Lists From Your Application. An index added after a list passes 5,000 items will not take, which means the lists big enough to need indexing are exactly the ones that can no longer be fixed from the UI.

**Always use `$select`** to request only the columns your query needs. Fetching all columns on a large list is slow.

**Filter before you sort.** Combine `$filter` (on indexed columns) with `$orderby` to reduce the result set before ordering it.

**Page your results.** Use `$top` to limit results per request. Verbose OData responses return a ready-made next-page URL in `d.__next` — follow it rather than reconstructing a `$skiptoken` query yourself. Always cap the number of pages, so a filter that matches far more than expected fails loudly instead of looping:

```javascript
function queryAll(url, maxPages) {
  var limit = maxPages || 50;
  var all   = [];

  function page(nextUrl, depth) {
    if (!nextUrl) return Promise.resolve(all);
    if (depth >= limit) {
      return Promise.reject(new Error('queryAll exceeded ' + limit + ' pages — narrow the $filter.'));
    }
    return spFetch(nextUrl)
      .then(function (r) {
        if (!r.ok) throw new Error('Query failed: HTTP ' + r.status);
        return r.json();
      })
      .then(function (d) {
        var body = (d && d.d) ? d.d : {};
        (body.results || []).forEach(function (item) { all.push(item); });
        return page(body.__next || null, depth + 1);
      });
  }

  return page(url, 0);
}
```

Paging does not beat the threshold on its own — every caller still needs a `$filter` on an indexed column.

**Design for the common case.** Most users look at recent items, their own items, or items in a specific status. Design default queries around those cases. Handle bulk exports and administrative views separately.

---

### File and Asset Management

Keep all application assets in the `_data` subfolder. Load them at runtime using the SharePoint REST `$value` endpoint:

```
/_api/web/getfilebyserverrelativeurl('/sites/mysite/myapp_data/styles.css')/$value
```

This endpoint returns raw file content, bypassing the Content-Disposition headers that would otherwise force a download. It's how your shell loads CSS and HTML at runtime.

**Important limitation:** the `$value` endpoint only works for static files (CSS, HTML, JSON, images). It returns 404 for `.aspx` files — SharePoint executes those server-side rather than returning their source bytes. Do not use it to read or modify ASPX files.

For images and other binary assets, reference them by their direct SharePoint URL. SharePoint serves images inline by default.

---

### Adding Modules Without Redeploying the Shell

A shell that hardcodes its asset list forces a redeploy every time the app gains a JavaScript file:

```javascript
// The trap: adding a module here means editing the .aspx
Promise.all([fetchAsset('styles.css'), fetchAsset('content.html'),
             fetchAsset('platform.js'), fetchAsset('app.js')])
```

Editing the `.aspx` costs a custom-script window plus Design or Full Control at upload; adding a `_data/` file costs nothing but Contribute. Design that difference out: keep the shell's asset list fixed and let `app.js` — itself a `_data/` file — extend the load chain at runtime.

The mechanism is the one the shell already uses to load `app.js`: fetch text over `$value`, wrap it in a Blob, append a `<script>`. No `eval()`, no CDN, no new capability.

**`manifest.json`** in `_data/`, listing modules in load order:

```json
{ "modules": ["views.js", "catalog.js", "reports.js"] }
```

**Loader at the top of `app.js`:**

```javascript
// Fallback list: a missing or corrupt manifest degrades, never breaks the app.
var FALLBACK_MODULES = ['views.js', 'catalog.js', 'reports.js'];

function loadModules() {
  return fetchAsset('manifest.json')
    .then(function (text) {
      var list = JSON.parse(text).modules;
      return (list && list.length) ? list : FALLBACK_MODULES;
    })
    .catch(function () { return FALLBACK_MODULES; })
    .then(function (modules) {
      // Fetch in parallel; inject in manifest order — later modules may
      // depend on earlier ones.
      var fetches = modules.map(function (name) { return fetchAsset(name); });
      return Promise.all(fetches).then(function (sources) {
        return new Promise(function (resolve, reject) {
          var last = null;
          sources.forEach(function (src) {
            var url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
            var el  = document.createElement('script');
            el.src = url;
            el.async = false;   // dynamic scripts are async by default; this keeps order
            el.onerror = function () { reject(new Error('module load failed')); };
            document.head.appendChild(el);
            last = el;
          });
          if (last) { last.onload = resolve; } else { resolve(); }
        });
      });
    });
}

// The shell loads app.js and hands off to its entry point; app.js gates that
// entry point behind loadModules(), so modules are ready before init runs.
loadModules().then(initApp);
```

Adding a feature is now: upload the module, add one line to `manifest.json`. Both are `_data/` files, both Contribute-level, no window, live on the next page load.

**Caveats:**

- **One extra round trip** before init, for the manifest. Fetch it alongside the app's largest data asset rather than ahead of it, so the cost overlaps work already happening.
- **Keep the fallback list current.** It is the reason a bad manifest degrades instead of white-screening. A stale fallback is a silent trap — update it whenever the manifest changes.
- **Validate the manifest at deploy time.** Both failure modes here — a manifest naming a module that was never uploaded, and a `FALLBACK_MODULES` list that has drifted from it — deploy perfectly cleanly and only fail in the browser, the second one only on the day the manifest itself fails to load. Since nothing at runtime can catch them, the deploy script does: it parses every `manifest.json`, checks each named module exists on disk, and compares the manifest against `FALLBACK_MODULES` in the sibling `app.js`, aborting before it uploads a broken app.
- **Load order is the manifest's order**, preserved by `async = false`. Dynamically created scripts are async by default and would otherwise execute in completion order.

**New shared helpers go in `platform.js`, not the shell.** The shell is the natural place to define the app's helper surface and exactly the wrong place to grow it — every addition costs a shell redeploy, and a shell redeploy needs Design or Full Control on top of the window. Keep a companion `platform.js` in `_data/` for helpers the modules share, and let the shell define only what boot itself needs.

---

### Using Microsoft Graph

Graph reaches beyond SharePoint-specific data — treat it as opt-in, not a default.

**Start with what needs no token.** The SharePoint user-profile REST endpoint (`/_api/SP.UserProfiles.PeopleManager/GetMyProperties`) returns display name, title, department, and a picture URL using the page's existing cookie session. That's enough for most personalization.

**Full Graph calls need a Bearer token**, and a document-library ASPX page has no built-in way to get one — the legacy `/_api/SP.OAuth.Token/Acquire` endpoint does not issue Graph tokens for custom pages. What Graph offers once you have a token:

- **`/me`** — full user profile including office location and phone
- **`/me/photo/$value`** — profile photo as a blob
- **`/me/manager`** — reporting manager
- **`/me/joinedTeams`** — Teams memberships
- **`/users`** — directory lookups (with appropriate permissions)
- **`/me/presence`** — availability status

The supported token path is **MSAL Browser** (`msal-browser`, served from the `_data/` folder — no CDN) against the shared **Contoso EUDA Applications** registration (see the [Packaged Python pattern](PACKAGED_PYTHON_PATTERN.md) for its IDs). It works once IT adds your page as a SPA redirect URI on that registration — a supported, per-page change IT will make on request.

**Enabling browser Graph:**

1. **Give IT the exact page URL**, all the way to the `.aspx` file — e.g. `https://contoso.sharepoint.com/sites/<site>/<library>/<app>.aspx`. Entra matches redirect URIs by exact string: no wildcards, no folder- or site-level shortcuts, and trailing slash and case count. Open the page, copy the address bar, drop everything from `?` onward.
2. **IT adds it under the Single-page application platform** (not "Web") — that platform is what enables the MSAL.js auth-code + PKCE flow and CORS. Each distinct page that signs in needs its own redirect URI, so centralize sign-in on one page where you can.
3. **Set MSAL's `redirectUri` to that exact string** so it matches byte-for-byte; a mismatch fails with `AADSTS50011`.

Most Graph read scopes are already consented on the shared registration — `Mail.Read`, `Calendars.Read`, `Tasks.Read`/`Tasks.ReadWrite`, `People.Read`, `User.ReadBasic.All`, `Presence.Read` — so mail, calendar, Planner tasks, and directory search need no extra consent. `Group.Read.All` is **not** consented; Planner sometimes needs it to resolve plan/bucket names, which is a separate scope add. Until a page's redirect URI is registered, get Graph-only data through a Power Automate flow instead.

---

### Write Operations and the Form Digest

Every POST, PATCH, or DELETE request to the SharePoint REST API must include an `X-RequestDigest` header — a time-limited token proving the request came from an authenticated session.

Do not read it from `_spPageContextInfo.formDigestValue` — that property is undefined in document library ASPX files. Always fetch a fresh digest before writes:

```
POST /_api/contextinfo
→ returns d.GetContextWebInformation.FormDigestValue
```

The digest expires after 30 minutes. Fetching it on every write, rather than caching it, ensures long-running sessions never fail with authentication errors.

---

### Provisioning Lists From Your Application

Rather than requiring users to create SharePoint lists manually, apps should auto-provision their required lists on first run. The recommended pattern:

1. When the data-loading call returns HTTP 404, infer the list doesn't exist yet
2. Show a banner explaining the situation with a "Create List" button
3. On click: call `/_api/web/lists` to create the list, then call the `/fields` endpoint for each custom column
4. On success: hide the banner, show a toast, reload the data

First deployment then becomes: upload the files, navigate to the app, click "Create List", done. The `Title` column is always present on new lists; only add columns beyond that.

When adding fields, error code `-2130575306` means "field already exists" — treat it as success so re-running setup is safe.

#### Name Provisioned Lists After the App

Sites are shared. An app that claims bare names like `Settings`, `Evidence`, or `Documents` will collide with the next app onto the site, and leaves anyone browsing site contents with no way to tell which app owns what. Prefix every provisioned list with the app's name, and resolve the name through one helper so the prefix can never be applied in one place and forgotten in another:

```javascript
function getListName(baseName, prefix) {
  var p = (prefix || '').trim();
  return p ? p + baseName : baseName;
}
// getListName('Evidence', 'ControlCatalog') -> 'ControlCatalogEvidence'
```

**Set the prefix before provisioning, and treat it as permanent.** Changing it later does not rename anything: the app simply starts looking for lists under new names, and the existing lists — with all their data — are left behind. If your app exposes the prefix as a configurable setting, say so plainly in its own admin UI, next to the field.

#### Index and Enable Versioning While the List Is Empty

Provisioning is the only moment a list is guaranteed to have no items, and both of these are effectively irreversible afterwards:

- **An index must exist before the list passes 5,000 items.** Added later it will not take, and the filtered queries this guide recommends start failing on exactly the lists that grew big enough to need them.
- **Versioning must be on before the first write.** Switched on later, the audit history for everything written up to that point simply does not exist — it cannot be backfilled.

Each is one REST call, and both run **after** field creation, since a column cannot be indexed before it exists:

```javascript
/* Index a column — a MERGE on the field, with the field's own __metadata type. */
function setFieldIndexed(listTitle, fieldTitle, fieldType, digest) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(listTitle) +
    '\')/fields/getbytitle(\'' + spPath(fieldTitle) + '\')', {
    method: 'POST',
    headers: writeHeaders(digest, { 'X-HTTP-Method': 'MERGE', 'IF-MATCH': '*' }),
    body: JSON.stringify({ __metadata: { type: fieldType || 'SP.Field' }, Indexed: true })
  });
}

/* Enable versioning — a MERGE on the list. */
function enableVersioning(listTitle, digest, majorVersionLimit) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(listTitle) + '\')', {
    method: 'POST',
    headers: writeHeaders(digest, { 'X-HTTP-Method': 'MERGE', 'IF-MATCH': '*' }),
    body: JSON.stringify({
      __metadata: { type: 'SP.List' },
      EnableVersioning: true,
      MajorVersionLimit: majorVersionLimit || 500
    })
  });
}
```

Provisioning order is therefore: **create list → create fields → index → enable versioning.** Create fields sequentially rather than in parallel; SharePoint rejects concurrent schema changes on the same list.

---

### Writing List Items

Creating lists and columns is only half of it. Three things bite the first time an app writes an item:

**The item type must be fetched, not guessed.** Every item payload needs `__metadata.type` set to the list's `ListItemEntityTypeFullName`. It is derived from the list title, so any app with a configurable prefix cannot construct it reliably — ask SharePoint. It is stable for the life of the list, so cache it:

```javascript
var _entityTypeCache = {};

function getEntityTypeName(listTitle) {
  if (_entityTypeCache[listTitle]) return Promise.resolve(_entityTypeCache[listTitle]);
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(listTitle) +
    '\')?$select=ListItemEntityTypeFullName')
    .then(function (r) {
      if (!r.ok) throw new Error('Could not read list schema for ' + listTitle);
      return r.json();
    })
    .then(function (d) {
      var name = d && d.d ? d.d.ListItemEntityTypeFullName : null;
      if (!name) throw new Error('No entity type for ' + listTitle);
      _entityTypeCache[listTitle] = name;
      return name;
    });
}

function createItem(listTitle, fields) {
  return getEntityTypeName(listTitle).then(function (entityType) {
    return getDigest().then(function (digest) {
      var body = { __metadata: { type: entityType } };
      Object.keys(fields).forEach(function (k) { body[k] = fields[k]; });
      return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(listTitle) + '\')/items', {
        method: 'POST',
        headers: writeHeaders(digest),
        body: JSON.stringify(body)
      });
    });
  });
}
```

**`FieldTypeKind` must agree with the `__metadata` type** on field creation, or SharePoint rejects the column:

| Column | `__metadata.type` | `FieldTypeKind` |
|---|---|---|
| Single line text | `SP.FieldText` | 2 |
| Multi-line text | `SP.FieldMultiLineText` | 3 |
| Date and time | `SP.FieldDateTime` | 4 |
| Choice | `SP.FieldChoice` | 6 |
| Yes/No | `SP.Field` | 8 |
| Number | `SP.FieldNumber` | 9 |
| Currency | `SP.FieldCurrency` | 10 |
| Person or group | `SP.FieldUser` | 20 |

**Person columns take a numeric id, not a login name.** Write to `<FieldName>Id`, resolving the id first:

```javascript
function ensureUser(loginName, digest) {
  return spFetch(SITE_URL + '/_api/web/ensureuser', {
    method: 'POST',
    headers: writeHeaders(digest),
    body: JSON.stringify({ logonName: loginName })
  }).then(function (r) {
    if (!r.ok) throw new Error('Could not resolve user: ' + loginName);
    return r.json();
  }).then(function (d) { return d.d.Id; });
}
// then: createItem(listTitle, { Title: 'Review', AssignedToId: userId })
```

---

### Security Considerations

**Three different things get called "sensitive," and the rules for them are not the same.** Collapsing them is the most common misreading of this guide — it leads people to believe the platform cannot hold confidential business data, which is exactly backwards.

**Secrets — Fixed.** Anything that *grants access* — API keys, connection strings, tokens, Power Automate trigger URLs — must never be embedded in the shell or in `_data/`. A browser can read everything the page can read, so "hidden in JavaScript" is not hidden at all. Put them in a restricted list with broken inheritance, or behind a Power Automate flow that holds the credential server-side.

**Confidential business data — supported, and this is what the platform is for.** Salaries, deal terms, HR records, customer contracts, performance reviews, anything confidential-but-not-regulated: store it. Nothing in this guide says such data cannot live in SharePoint. What it says is that **the ACL protects it, not your JavaScript** — which is the entire subject of [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx). Hiding a field in the UI is not protection; giving it its own securable object is.

**Regulated data — escalate.** PHI, payment card data, export-controlled material. Out of scope for the citizen tier, not because SharePoint cannot hold it but because the retention, attestation, and controls around it are IT-owned. That makes it a conversation to start, not a permanent no.

**Use SharePoint groups for access control.** Check group membership via the REST API to conditionally show or hide features. For true enforcement, restrict item-level permissions on the underlying lists — don't rely solely on UI hiding.

**Validate on write.** Column-level validation in SharePoint lists is your last line of defense against bad data. Set it up even if your form already validates client-side.

---

## Deploying Your Application

### Requirements

1. **Custom scripts must be enabled on the target site before uploading `.aspx` files.** Open the window yourself on the [self-service enablement page](https://contoso.sharepoint.com/sites/euda-sample/script-enablement/script-enablement.aspx), or from your deploy script — see **Opening the Window From Your Deploy Script** below. The window is 24 hours; upload all shell files during it. Files uploaded and registered while it is active retain their allowed status after the reset.

   The grant comes first, once per site: register the site on the enablement page, an EUDA admin approves it, and after that you enable that site yourself whenever you deploy. A request for a site you hold no grant for is denied — the service re-checks server-side and does not take the client's word for who is asking.

   Updating the shell `.aspx` later means opening the window again. Files in the `_data/` folder (CSS, HTML, JSON) can be updated any time with no window at all.

   **This cost applies only when a shell actually changes.** The deploy script compares local shells against the remote inventory and skips enablement entirely when none needs uploading, so a `_data/`-only deploy — which, with runtime module loading, is nearly all of them — needs Contribute and nothing more. Use `-ForceEnablement` to run the check anyway.

   Never re-upload an *unchanged* `.aspx` outside the window: it strips the executable flag, and the app starts downloading instead of running.

2. **Deploy to the app's own site**, per [One Site Per App](#where-the-app-lives-one-site-per-app) — the enablement window above is scoped to that site, which is one of the reasons not to share one.

3. **Files must be uploaded to a dedicated document library** — not Site Pages, and not the site's default "Documents" library. Site Pages processes `.aspx` files through SharePoint's master page and publishing pipeline, which conflicts with this platform; uploading there by accident makes the app fail to load its CSS and HTML assets.

   Create a standard document library named for the app — `sample-sites`, `script-enablement`, `myapp` — and deploy into that. **Using the site's existing "Documents" library is not recommended**, even though it technically works. "Documents" is where people drop files: it is the default target of the Add button, of Teams file uploads, and of anything synced with OneDrive, so an app deployed there shares a namespace with arbitrary user content. Three consequences follow:

   - **The cleanup sweep becomes dangerous.** A deploy script that deletes everything absent from the local source will happily delete someone's spreadsheet. Every deploy then depends on `-PreservePaths` being remembered and kept current.
   - **The Design or Full Control grant gets wider than it should be.** The deployer needs it on the library holding the shell (see the next point); on "Documents" that means over the site's general file store rather than over the app.
   - **The app's files stop being identifiable.** Anyone browsing the library sees `myapp.aspx` and `myapp_data/` mixed into unrelated files, with nothing marking which are load-bearing — the same collision problem that [the list-naming rule](#name-provisioned-lists-after-the-app) solves for lists.

   A dedicated library costs one click to create, keeps the deploy sweep safe by construction, and scopes the elevated permission to the app.

4. **The person uploading the `.aspx` shell file must have the "Add and Customize Pages" permission.** This is a separate, user-level requirement on top of the site-level enablement window. SharePoint stamps an execute flag on uploaded files based on the uploader's permissions at upload time — without it, the file downloads instead of loading in the browser.

   This permission is only included in two built-in SharePoint permission levels:

| Permission level | Add and Customize Pages |
|---|---|
| Full Control (Site Owner) | ✅ Yes |
| Design | ✅ Yes |
| Edit | ❌ No |
| Contribute | ❌ No |
| Read | ❌ No |

   Users with Edit or Contribute access can upload the file but it will never execute — it downloads instead, even during the enablement window. The fix is to grant the deploying user **Design** or **Full Control** on the document library.

   > **Practical workflow:** a designated deployer (Design or Full Control) uploads the `.aspx` shell file. Everyone else updates `_data/` files freely — those are plain files and work with Contribute access.

### Upload Order

1. Navigate to the app's **dedicated document library** — create one named for the app if it does not exist yet (not Site Pages, not the default "Documents")
2. Create the `_data` subfolder in that library
3. Upload `styles.css` and `content.html` to the `_data` folder
4. Upload the shell `.aspx` file to the parent folder
5. Check the file in if required
6. Test immediately while the custom script window is active

### Deploying With a Script

Clicking files into a library works once. After that it is a chore that silently breaks apps: someone uploads the shell before its `_data/` assets, or re-uploads an unchanged `.aspx` outside the window and strips its executable flag. A deploy script fixes the order, skips files that have not changed, and makes the deploy reviewable.

The platform repo ships both halves: `deploy/Deploy-SampleLibrary.ps1` is the platform's own script — pre-flight, connect, enable only when needed, clean up, upload — and `deploy/examples/Deploy-MyApp.Example.ps1` is a complete minimal script for a single app, meant to be copied. The shape of both:

```powershell
# 1. Sign in as yourself. No admin rights, no service account, no secret in a file.
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $PnPClientId

# 2. Read the remote inventory BEFORE deciding anything, so enablement is
#    decided from evidence rather than from a switch someone remembered to pass.
$remoteIndex = @{}
Get-PnPFolderItem -FolderSiteRelativeUrl $LibraryName -ItemType File -Recursive |
    ForEach-Object { $remoteIndex[$_.Name] = $_ }

# 3. Only open a window if an .aspx shell actually changed.
if ($shellsToUpload.Count -gt 0) { Enable-CustomScriptWindow -SiteUrl $SiteUrl }

# 4. Upload _data/ deepest-first, shells last: the shell fetches its assets on
#    first load, so it must never be the thing that arrives first.
foreach ($file in $orderedFiles) {
    Add-PnPFile -Path $file.FullName -Folder $remoteFolder
}
```

Two rules worth stating outright, because both fail quietly:

- **Deploy to the app's own document library, never Site Pages and never the default "Documents".** Site Pages runs `.aspx` through the publishing pipeline and the app fails to load its assets; "Documents" mixes the app into arbitrary user files and puts them within reach of the cleanup sweep.
- **Register every file the app rewrites at runtime as seed-only.** The local copy is a first-run seed; the deployed copy is live state. See **Files the App Rewrites at Runtime Are Seeds Locally, State Remotely**.

If the library is shared with another app, the cleanup pass needs to know: a sweep that deletes everything absent from your local source will happily delete the other app. The platform script takes `-PreservePaths` for exactly this.

### Opening the Window From Your Deploy Script

Enabling a site is self-service, so the deploy script can do it — you sign in as yourself and hold no admin rights at any point. The platform's script does this by default, because the site it deploys to holds a grant:

```powershell
.\Deploy-SampleLibrary.ps1
```

For an app's own script, `deploy/examples/Enable-CustomScriptWindow.ps1` is a paste-in function. It queues a request, wakes the service, and waits for the window:

```powershell
. "$PSScriptRoot/Enable-CustomScriptWindow.ps1"

Enable-CustomScriptWindow -SiteUrl 'https://contoso.sharepoint.com/sites/euda-myapp'
# -> Queued request 12 for .../euda-myapp
# -> Window is OPEN (closes 2026-08-26T15:50:46Z UTC).

# then upload as usual, inside the window
Add-PnPFile -Path ./myapp.aspx -Folder 'myapp'
```

What it does under the hood is worth knowing, because it explains why a script is allowed to do this at all. It writes an item to a request list; SharePoint stamps `Author` on that item and no client can set it. A service re-checks `(Author, SiteUrl)` against an admin-curated grants list before flipping anything, so the identity being authorized is the one SharePoint vouched for, not one the script claimed. A request for a site you hold no grant for comes back `Denied`.

The function key in that config is anti-DoS, not authorization — the same model as a Power Automate SAS URL. It confers no authority, so it is configuration rather than a secret. That is why it can sit in a page's config file where a browser reads it.

Three failure modes to expect:

- **Denied** — you hold no grant for that site. Register it on the enablement page and ask an EUDA admin to approve.
- **Timed out** — the request stays queued and a safety-net timer collects it within about 10 minutes. Re-run shortly rather than re-requesting.
- **Window open, upload still downloads** — the window is site-level; the uploader also needs Design or Full Control, which is the separate requirement above.

### Updating Your Application

**No update should require changing the shell.** Because the shell loads assets at runtime, features, styles, markup, and entirely new JavaScript modules all ship by replacing or adding files in `_data/` — Contribute-level, no window, effective on the next page load.

If an update appears to need a shell edit, that is a signal, not a scheduling problem: the shell is holding logic that belongs in `_data/`. Move it instead of booking a custom-script window. The genuine exceptions are boot-level changes — renaming the data folder, adding a canonical helper — which should be rare to nonexistent after initial deployment.

---

## What This Platform Is Good For

- **Forms and submissions** — expense requests, IT tickets, intake forms, feedback collection
- **Team dashboards** — status boards, KPI displays, team activity feeds
- **Lightweight CRMs** — contact tracking, relationship management, interaction logs
- **Project trackers** — task management, milestone tracking, status reporting
- **Knowledge bases** — searchable FAQs, documentation, how-to libraries
- **Approval workflows** — request → review → approve/reject with notifications
- **Internal directories** — people finders, org chart supplements, skill registries
- **Event and scheduling tools** — signup sheets, room requests, calendar overlays

## What It Is Not Good For

- Applications requiring real-time collaboration (no WebSocket support)
- High-volume transactional systems (list writes have latency; this is not a relational DB)
- Applications with complex server-side computation (use Power Automate or Azure Functions for heavy lifting)
- Public-facing applications (SharePoint requires M365 authentication)
- Applications requiring sub-second query response on millions of rows

---

## Quick Reference

| Need | Use |
|---|---|
| Current user info | `/_api/web/currentUser` (primary); `_spPageContextInfo` (bonus, Site Pages only) |
| Site URL | `deriveSiteUrl()` — regex fallback from `window.location` |
| Read list data | SharePoint REST API (`$select`, `$filter`, `$orderby`, `$top`) |
| Write list data | REST POST/PATCH with `X-RequestDigest` from `/_api/contextinfo` |
| Auto-provision lists | `listExists()` + `createList()` + `ensureField()` on first load |
| User profile / photo | `/_api/SP.UserProfiles.PeopleManager/GetMyProperties` (no token); Graph `/me` only with MSAL + SPA redirect — see Using Microsoft Graph |
| Send email | Power Automate HTTP flow |
| Run logic on schedule | Power Automate scheduled flow |
| Store app config / lookup tables | JSON file in `_data` folder — fetch via `$value`, parse with `JSON.parse()` |
| Write a JSON file | REST `files/add(url='...',overwrite=true)` with `ArrayBuffer` body — then register it in `-SeedOnlyFiles` so deploys never overwrite it |
| Write a list item | Fetch `ListItemEntityTypeFullName` for `__metadata.type` (cache it); person columns take `<Field>Id` from `/_api/web/ensureuser` |
| Index a column / enable versioning | At provisioning, while the list is empty — MERGE `Indexed:true` on the field, `EnableVersioning:true` on the list |
| Name a provisioned list | Prefix with the app name via one `getListName()` helper; set the prefix before provisioning — changing it later strands the existing lists |
| Page a large result set | Follow `d.__next` with a page cap, plus a `$filter` on an indexed column |
| Load CSS/HTML at runtime | REST `$value` endpoint (static files only — not `.aspx`) |
| Add a JS module without a shell redeploy | `manifest.json` + loader in `app.js` — see Adding Modules Without Redeploying the Shell |
| How big may the shell be? | There is no size limit. The test is behavioural: no feature code, no application state |
| Open the custom-script window | Self-service: the enablement page, or the deploy script doing it for you — no admin rights |
| Deploy an app | A script, not manual uploads — `_data/` deepest-first, shells last; see Deploying With a Script |
| Share a library with another app | `-PreservePaths` in the deploy script, so cleanup does not delete the other app |
| Where to deploy files | A dedicated document library named for the app — **not** Site Pages, and **not** the default "Documents" |
| Where to put a new app | Its own communication site, `euda-<app>`, joined to a hub and listed in the site registry |
| Access control | SharePoint groups + item-level permissions — see [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx) |
| Audit trail | List versioning — see [Permissions & Auditing](SHAREPOINT_PERMISSIONS_PATTERN.aspx) |
| Sizing, sprawl, and archiving | See [Storage Shape & Lifecycle](SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx) |
| Large data sets | Indexed columns + paged queries |
