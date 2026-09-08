# Claude Code — SharePoint App Pattern: Project Prompt

> **SharePoint App Pattern — v1.12** · updated 2026-09-03. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

> **Fixed rules and defaults.** Anything labelled **Fixed** is binding — deviating from it breaks the platform, its security model, or its audit trail. Everything else here is a **Default**: the right answer absent a specific reason, and a judgement call you are expected to make rather than a rule to obey. Departing from a default is legitimate — name it, say what makes this case different and what you give up, and record it in the app's README so the next person finds the reasoning instead of the symptom. If a Fixed rule is the obstacle, stop and escalate rather than working around it.

Paste the block below as your first message when starting a new SharePoint application project. Customize the bracketed sections for your project.

---

```
You are building a custom web application that runs inside Microsoft SharePoint Online as a single .aspx page. This is a well-established internal platform. Follow all conventions below exactly — they exist because of hard constraints in how SharePoint serves and scans custom files.

---

## How to read this prompt

Sections marked (fixed) are binding: deviation is a defect. Sections marked
(default) are the recommended choice, NOT a prohibition. If a default does not
fit this project, say so, propose the alternative with its trade-off, and get
the user's agreement before building it — then note the decision in the app's
README.

Never silently deviate from a default, and never tell the user that something a
default merely discourages is impossible. If a (fixed) rule is the real
obstacle, stop and escalate rather than working around it.

## Platform Architecture

### Shell + Data Pattern (fixed)

Every app consists of:
1. A boot-only shell: `[app-name].aspx` — asset loading, the canonical helpers below, loading/error UI, hand-off to init. **No feature code, no application state.** Single `<script>` block, no external dependencies in the shell itself.
2. A data folder: `[app-name]_data/` containing:
   - `styles.css` — all CSS
   - `content.html` — all HTML markup for the app body
   - `app.js` — feature code, plus the module loader below
   - `platform.js` — shared helpers the modules build on
   - `manifest.json` — additional modules to load, in order
   - Additional assets as needed (config JSON, images)

The shell loads CSS and HTML at runtime via the SharePoint REST $value endpoint. This is intentional and required — do not collapse everything back into a single file.

**The shell must not change after initial deployment.** Editing the `.aspx` requires a custom-script window plus Design or Full Control at upload; `_data/` files need only Contribute. So the shell's asset list stays fixed and everything else ships through `_data/`. Do not put feature code, view logic, or app state in the shell, and do not grow its helper surface — new helpers go in `platform.js`.

### Canonical Helpers (fixed — define these first; every snippet below uses them)

```js
// Encode single-quoted path segments for SharePoint REST URLs
function spPath(p) {
  return p.replace(/'/g, "''");
}

// Fetch wrapper — adds session credentials and the default OData Accept header
function spFetch(url, opts) {
  opts = opts || {};
  opts.credentials = 'same-origin';
  opts.headers = opts.headers || {};
  if (!opts.headers['Accept']) {
    opts.headers['Accept'] = 'application/json;odata=verbose';
  }
  return fetch(url, opts);
}
```

### File Loading Pattern (fixed)

The shell derives the site URL and data folder path dynamically:

```js
function deriveSiteUrl() {
  // _spPageContextInfo is NOT injected for ASPX files in document libraries —
  // only in Site Pages with a master page. Always implement this regex fallback.
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

var SITE_URL    = deriveSiteUrl();
var PAGE_PATH   = decodeURIComponent(window.location.pathname);
var PAGE_FOLDER = PAGE_PATH.substring(0, PAGE_PATH.lastIndexOf('/'));
var DATA_FOLDER = PAGE_FOLDER + '/[app-name]_data';

function fetchAsset(filename) {
  var apiUrl = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
               spPath(DATA_FOLDER + '/' + filename) + '\')/$value';
  return spFetch(apiUrl, { headers: { 'Accept': 'text/plain' } })
    .then(function(r) {
      if (r.ok) return r.text();
      // Fallback to relative path for local dev
      return fetch('./' + '[app-name]_data/' + filename).then(function(r2) { return r2.text(); });
    })
    .catch(function() {
      return fetch('./' + '[app-name]_data/' + filename).then(function(r2) { return r2.text(); });
    });
}
```

The `$value` endpoint returns raw file bytes for CSS/HTML/JSON assets, bypassing Content-Disposition headers. **Do not** use it on `.aspx` files — SharePoint executes them server-side and returns 404. Do not use any other endpoint for loading text assets.

### Module Loading (fixed for any app beyond one JS file)

The shell fetches a **fixed** asset list. Never add a module by editing it — that is a shell redeploy, which needs a custom-script window and Design or Full Control. Instead `app.js`, itself a `_data/` file, extends the load chain at runtime using the same mechanism the shell used to load it: fetch text, wrap in a Blob, append a `<script>`. No `eval()`, no CDN.

`manifest.json` in `_data/` lists modules in load order:

```json
{ "modules": ["views.js", "catalog.js", "reports.js"] }
```

Loader at the top of `app.js`:

```js
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

Adding a feature = upload the module + add one line to `manifest.json`. Both `_data/`, both Contribute-level, no window. Fetch the manifest alongside the app's largest data asset so its round trip overlaps existing work.

**Keep `FALLBACK_MODULES` byte-identical to the manifest's module list, and update both in the same commit.** A manifest naming a module that was never uploaded, and a drifted fallback list, both deploy cleanly and fail only in the browser — the second only on the day the manifest itself fails to load. The deploy script enforces this pre-flight (parses every `manifest.json`, checks each module exists, compares against `FALLBACK_MODULES`) and aborts rather than shipping a broken app.

---

## Authentication & Identity (fixed)

### No login required — ever.

SharePoint injects `_spPageContextInfo` into pages rendered with a master page (Site Pages). **ASPX files served from document libraries do NOT get `_spPageContextInfo` injected.** Always implement a REST fallback for user identity:

```js
// _spPageContextInfo fields (only available in Site Pages, not document library ASPX):
_spPageContextInfo.webAbsoluteUrl    // site root URL  — use deriveSiteUrl() instead
_spPageContextInfo.userDisplayName   // "First Last"
_spPageContextInfo.userLoginName     // "user@company.com"
_spPageContextInfo.userId            // SP integer user ID
_spPageContextInfo.formDigestValue   // write digest  — use getDigest() instead
_spPageContextInfo.siteAbsoluteUrl   // site collection root
```

Always check `typeof _spPageContextInfo !== 'undefined'` before accessing. When undefined (document library ASPX or local dev), resolve identity via REST:

```js
// Fallback identity resolution for document library ASPX files
var CURRENT_USER = null;
spFetch(SITE_URL + '/_api/web/currentUser?$select=Id,Title,LoginName')
  .then(function(r) { return r.ok ? r.json() : null; })
  .then(function(d) {
    if (!d || !d.d) return;
    CURRENT_USER = {
      id:          d.d.Id,        // SP integer user ID — needed for AuthorId/people filters
      displayName: d.d.Title,     // equivalent to userDisplayName
      loginName:   d.d.LoginName  // equivalent to userLoginName
    };
  });
```

### Write Operations

All POST/PATCH/DELETE calls to the SharePoint REST API require:
```
X-RequestDigest: [digest value]
Accept: application/json;odata=verbose
Content-Type: application/json;odata=verbose
```

```js
// Canonical write-headers helper — used by every write snippet below
function writeHeaders(digest) {
  return {
    'X-RequestDigest': digest,
    'Accept': 'application/json;odata=verbose',
    'Content-Type': 'application/json;odata=verbose'
  };
}
```

**Never read `_spPageContextInfo.formDigestValue` directly** — it won't be set in document library ASPX. Always use a `getDigest()` helper that calls `/_api/contextinfo`:

```js
function getDigest() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.formDigestValue) {
    return Promise.resolve(_spPageContextInfo.formDigestValue);
  }
  return spFetch(SITE_URL + '/_api/contextinfo', {
    method: 'POST',
    headers: { 'Accept': 'application/json;odata=verbose',
               'Content-Type': 'application/json;odata=verbose' }
  }).then(function(r) { return r.json(); })
    .then(function(d) { return d.d.GetContextWebInformation.FormDigestValue; });
}
```

The digest expires after 30 minutes; calling `getDigest()` on every write ensures a fresh value.

---

## SharePoint REST API Patterns (fixed)

Base URL: `SITE_URL + '/_api/web'` (use `deriveSiteUrl()` — do not reference `_spPageContextInfo.webAbsoluteUrl` directly)

### Read items
```
GET /_api/web/lists/getbytitle('[ListName]')/items
  ?$select=Id,Title,Column1,Column2
  &$filter=Status eq 'Active'
  &$orderby=Created desc
  &$top=500
```

### Create item
```
POST /_api/web/lists/getbytitle('[ListName]')/items
Body: { "__metadata": { "type": "SP.Data.[ListName]ListItem" }, "Title": "...", ... }
```

### Update item
```
PATCH /_api/web/lists/getbytitle('[ListName]')/items([Id])
Headers: { "IF-MATCH": "*", "X-HTTP-Method": "MERGE" }
```

### Delete item
```
POST /_api/web/lists/getbytitle('[ListName]')/items([Id])
Headers: { "IF-MATCH": "*", "X-HTTP-Method": "DELETE" }
```

`IF-MATCH: *` overwrites unconditionally — fine for single-user CRUD. If multiple users may edit the same item concurrently, condition the write on the item's etag (`IF-MATCH: <etag from __metadata.etag>`) and treat HTTP 412 as "someone else changed it first" — the Worker Pool pattern is built entirely on this.

### Get current user full profile
```
GET /_api/SP.UserProfiles.PeopleManager/GetMyProperties
```

### Search
```
GET /_api/search/query?querytext='[term]'&selectproperties='Title,Path,Author'&rowlimit=20
```

### Read a JSON file from the _data folder
```js
spFetch(SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' + spPath(DATA_FOLDER + '/data.json') + '\')/$value',
  { headers: { 'Accept': 'text/plain' } })
  .then(function(r) { return r.ok ? r.json() : null; });
```

### Write (overwrite) a JSON file
```js
var bytes = new TextEncoder().encode(JSON.stringify(payload, null, 2));
spFetch(SITE_URL + '/_api/web/getfolderbyserverrelativeurl(\'' + spPath(DATA_FOLDER) +
  '\')/files/add(url=\'data.json\',overwrite=true)', {
  method: 'POST',
  headers: { 'X-RequestDigest': digest, 'Accept': 'application/json;odata=verbose' },
  body: bytes.buffer
});
```

Use JSON files (not lists) for: app config, static lookup tables, reference data, seed data loaded once. Use lists when data needs OData querying, grows unbounded, is written by end users, or requires item-level permissions. Files have no transaction safety — avoid concurrent writes.

**Any file the app writes back is a seed locally and live state remotely.** The deployed copy holds what an admin configured; the copy in the repo is only a first-run seed. A deploy that uploads it silently reverts every setting, with no error. Every file passed to `files/add(overwrite=true)` at runtime must be registered as seed-only in the deploy script (`-SeedOnlyFiles`), which uploads it when missing, never overwrites it, and never cleans it up as stale. Rule: **if the app can write it, the deploy must not.**

### Writing list items

- The payload needs `__metadata.type` = the list's `ListItemEntityTypeFullName`. **Fetch it, never guess it** — it derives from the list title, which a configurable prefix makes unpredictable. Cache it; it is stable per list.

```js
var _entityTypeCache = {};
function getEntityTypeName(listTitle) {
  if (_entityTypeCache[listTitle]) return Promise.resolve(_entityTypeCache[listTitle]);
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(listTitle) +
    '\')?$select=ListItemEntityTypeFullName')
    .then(function (r) { if (!r.ok) throw new Error('No schema for ' + listTitle); return r.json(); })
    .then(function (d) {
      var name = d.d.ListItemEntityTypeFullName;
      _entityTypeCache[listTitle] = name;
      return name;
    });
}
```

- **Person columns take a numeric id in `<FieldName>Id`**, not a login name. Resolve with `POST /_api/web/ensureuser` (body `{ "logonName": "user@company.com" }`) and use `d.d.Id`.
- `FieldTypeKind` must agree with the `__metadata` type on field creation or SharePoint rejects the column. See the table in List Provisioning below.

---

## List Design Rules (fixed: indexes and versioning at provisioning. default: the schema)

1. **Index every column used in $filter or $orderby**, and create the index at provisioning time from the app — not from List Settings later. An index added after the list passes 5,000 items will not take.
2. **Always use $select.** Never fetch all columns unless building an admin/export view.
3. **Always use $top.** Default SharePoint page size is 100; set explicitly.
4. **Page large result sets** by following the ready-made `d.__next` URL that verbose OData returns — do not reconstruct a `$skiptoken` query. Always cap the page count so a too-broad filter fails loudly instead of looping; paging alone does not beat the threshold, so still `$filter` on an indexed column.
5. **Use $expand for lookups** — e.g. `$expand=AssignedTo&$select=AssignedTo/Title,AssignedTo/EMail`
6. The list view threshold is 5,000 items per query, not a list size limit. A list can hold millions of items.

### OData Filter Syntax
```
$filter=Status eq 'Active'                    // string equality
$filter=Priority gt 2                         // numeric comparison
$filter=DueDate le datetime'2026-12-31T00:00:00Z'  // date comparison
$filter=AuthorId eq [CURRENT_USER.id]         // current user's items — the Id fetched from /_api/web/currentUser (never _spPageContextInfo.userId, which is undefined in document-library ASPX)
$filter=substringof('search', Title)          // contains (use Search API for full-text)
```

---

## Navigation Pattern (default)

All navigation is in-page view switching. No page loads between sections.

```js
function showView(view) {
  document.querySelectorAll('.view-section').forEach(el => el.classList.add('hidden'));
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  document.getElementById(view + '-section').classList.remove('hidden');
  document.getElementById('nav-' + view).classList.add('active');
}
```

- Default view shown after data loads, not on DOM ready
- Show loading state immediately; reveal UI only after initial data fetch completes
- After form submit: clear form, show success toast, navigate to list/entries view

---

## Shell Code Constraints (fixed — enforced by the SharePoint content scanner)

- **No `document.write()`** — use `innerHTML` / `textContent` / DOM methods
- **No `window.open()`** — use `<a target="_blank">` or in-page modal overlays
- **No top-level `eval()`**
- **No inline event handlers that pass HTML strings to execution contexts**
- **No external CDN script tags** in the shell — load all dependencies from the `_data` folder or inline them
- **Shell holds boot logic only** — no feature code, no app state; content in `content.html`, styles in `styles.css`, logic in `_data/` modules. The test is behavioural: would this code ever change in order to add a feature? If yes, it goes in `_data/`
- **There is NO size limit on the shell.** Do not invent one, do not minify or golf to hit a number, and do not tell the user a shell is "too big". Reference shells run 6–8 KB; past roughly 15 KB, suspect that logic has leaked in and move it out — that is a smell to investigate, not a budget
- **Single `<script>` block** in the shell
- **Max line length: no hard limit but keep under 200 chars** for readability and scanner safety

For JSON preview or any "render user content as HTML" feature, use a pre-existing `<div id="overlay">` in content.html and assign content via `textContent`, never `innerHTML` with user data.

---

## Microsoft Graph (fixed — the token path is the only supported one)

Graph is optional — reach for it deliberately, not by default.

**No-token path (prefer this):** the SharePoint user-profile REST endpoint covers most profile needs (display name, title, department, picture URL) using the page's existing cookie session:
```
GET /_api/SP.UserProfiles.PeopleManager/GetMyProperties
```

**Full Graph calls** (`/me/presence`, `/me/manager`, `/users` directory search, `/me/photo/$value`) require a Bearer token, and a document-library ASPX page has no built-in way to get one — the legacy `/_api/SP.OAuth.Token/Acquire` endpoint does NOT issue Graph tokens for custom pages; do not use it. The supported path is `msal-browser` (loaded from the `_data/` folder — no CDN) against the shared "Contoso EUDA Applications" registration (client id `<your-entra-client-id>`, tenant id `<your-tenant-id>`). It needs a SPA redirect URI for THIS page on that registration: give IT the exact page URL down to the `.aspx` file (Entra matches redirect URIs exactly — no wildcards; trailing slash and case count), IT adds it under the Single-page application platform, and set MSAL `redirectUri` to that exact string (a mismatch fails with AADSTS50011). Already-consented scopes cover mail (`Mail.Read`), calendar (`Calendars.Read`), Planner tasks (`Tasks.Read`), and directory search (`People.Read`, `User.ReadBasic.All`); `Group.Read.All` is NOT consented (Planner may need it for plan names — a separate scope add). Until this page's redirect URI is registered, use a Power Automate flow instead.

---

## External APIs (fixed: where the call is made. default: which route)

Consuming a third-party API is supported. Never call one directly from the
shell or a `_data/` module when it needs a key, token, or secret of any kind —
a browser reads everything the page reads, so the credential is published the
moment you ship it. That part is fixed.

Route by what the API needs:

- **Public, no auth, and sends CORS headers** — a direct `fetch()` from the
  browser is fine. Confirm CORS actually works from the SharePoint origin
  before designing around it; most APIs do not allow it.
- **Needs a key, token, or any credential** — the call happens somewhere the
  user cannot read. Two routes, and the choice is usually made for you:
  - **Power Automate flow.** Always-on, no machine required. BUT the generic
    HTTP action is a PREMIUM connector — if the app owner has no premium or
    per-flow licence, this route is simply unavailable. Confirm the licence
    before recommending it; do not assume it.
  - **A companion Packaged Python app** that calls the API and writes results
    into a SharePoint list, which this app then reads normally. No premium
    licence, real Python for parsing and transformation, and it runs as a named
    person so the audit trail stays attributable. Use Pattern B with Task
    Scheduler for one owner's machine, or the Worker Pool pattern when the team
    should keep it running. Ask for PACKAGED_PYTHON_PROMPT.md before building it.
- **Guaranteed uptime, or the data is regulated** — neither citizen route
  qualifies; escalate to IT-hosted.

State which route you are taking and why. If you propose a flow, say that it
depends on premium licensing so the user can check before you build on it.

## Power Automate Integration (default)

Use HTTP-triggered Power Automate flows for:
- Sending email or Teams messages
- Any server-side computation
- Calling external APIs with secrets — **subject to the premium-connector
  caveat above**
- Scheduled operations
- Approval workflows

Pattern:
```js
fetch('[flow-http-trigger-url]', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ field1: value1, field2: value2 })
})
```

Store flow trigger URLs in a restricted SharePoint list (broken permissions inheritance, readable only to the app's users), not in the shell file. There are no service accounts anywhere on this platform.

---

## UI/UX Conventions (default)

- **Loading state**: Show immediately on shell load; use animated dots or spinner
- **Error state**: Display inline near the affected component, not as alert()
- **Toast notifications**: Non-blocking, auto-dismiss after 3-4 seconds, positioned fixed bottom-right or top-right
- **Confirmation for destructive actions**: Inline confirm prompt, not browser confirm()
- **Empty states**: Always handle the case where a list/query returns 0 items
- **Responsive**: Design for 1024px+ desktop-first; SharePoint is an enterprise intranet tool

---

## Project-Specific Context

**Application name:** [App Name]
**Site URL:** [https://tenant.sharepoint.com/sites/sitename]
**Document library:** [Library Name]
**Shell file:** [app-name].aspx
**Data folder:** [app-name]_data/

**Lists used:**
| List Name | Purpose | Key Columns |
|---|---|---|
| [ListName] | [purpose] | [Col1 (Indexed), Col2, ...] |

**Views/Sections:**
| View ID | Purpose | Default? |
|---|---|---|
| [view-name] | [purpose] | [yes/no] |

**Power Automate flows:**
| Flow | Trigger | Purpose |
|---|---|---|
| [Flow Name] | HTTP POST | [purpose] |

**Access control:**
- [Who can read data]
- [Who can write data]
- [Admin-only features]

---

## List Provisioning Pattern (fixed)

Apps should auto-provision their required lists on first run rather than requiring manual setup. Show a banner with a "Create List" button when the list doesn't exist (detected by a 404 on the items endpoint).

**Name every provisioned list after the app.** Sites are shared: bare names like `Settings` or `Evidence` collide with the next app and are unattributable in site contents. Resolve names through a single helper so the prefix is never applied inconsistently:

```js
function getListName(baseName, prefix) {
  var p = (prefix || '').trim();
  return p ? p + baseName : baseName;      // 'ControlCatalog' + 'Evidence'
}
```

Set the prefix **before** provisioning and treat it as permanent — changing it later does not rename anything; the app looks for new names and the existing lists, with all their data, are stranded. If the prefix is user-configurable, say that in the app's own admin UI.

`FieldTypeKind` must agree with the `__metadata` type or the column is rejected:

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

```js
var LIST_FIELD_DEFS = [
  { '__metadata': { 'type': 'SP.FieldMultiLineText' }, 'FieldTypeKind': 3,
    'Title': 'Body', 'Required': false, 'NumberOfLines': 6, 'RichText': false },
  // Add more field definitions as needed
];

function listExists() {
  return spFetch(SITE_URL + '/_api/web/lists?$filter=Title eq \'' + spPath(LIST_NAME) + '\'&$select=Id')
    .then(function(r) { return r.json(); })
    .then(function(d) { return d.d.results.length > 0; });
}

function createListOnSite(digest) {
  return spFetch(SITE_URL + '/_api/web/lists', {
    method: 'POST',
    headers: writeHeaders(digest),
    body: JSON.stringify({
      '__metadata': { 'type': 'SP.List' },
      'AllowContentTypes': false, 'BaseTemplate': 100, 'ContentTypesEnabled': false,
      'Description': 'Created by [app-name].aspx',
      'Title': LIST_NAME
    })
  }).then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); });
}

function ensureField(digest, fieldDef) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(LIST_NAME) + '\')/fields', {
    method: 'POST', headers: writeHeaders(digest), body: JSON.stringify(fieldDef)
  }).then(function(r) {
    if (!r.ok) return r.json().catch(function() { return {}; }).then(function(b) {
      var code = (b && b.error && b.error.code) || '';
      if (code.indexOf('-2130575306') === -1)  // -2130575306 = field already exists, safe to ignore
        throw new Error('Add field "' + fieldDef.Title + '" failed: ' + (code || r.status));
    });
  });
}

// Index columns and enable versioning AT PROVISIONING, while the list is empty.
// Both are effectively irreversible: an index added after 5,000 items will not
// take, and versioning enabled after writes begin has no history for them.
// Run after field creation — a column cannot be indexed before it exists.
function setFieldIndexed(digest, fieldTitle, fieldType) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(LIST_NAME) +
    '\')/fields/getbytitle(\'' + spPath(fieldTitle) + '\')', {
    method: 'POST',
    headers: writeHeaders(digest, { 'X-HTTP-Method': 'MERGE', 'IF-MATCH': '*' }),
    body: JSON.stringify({ '__metadata': { 'type': fieldType || 'SP.Field' }, 'Indexed': true })
  });
}

function enableVersioning(digest) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(LIST_NAME) + '\')', {
    method: 'POST',
    headers: writeHeaders(digest, { 'X-HTTP-Method': 'MERGE', 'IF-MATCH': '*' }),
    body: JSON.stringify({ '__metadata': { 'type': 'SP.List' },
                           'EnableVersioning': true, 'MajorVersionLimit': 500 })
  });
}
```

In `loadMessages` / the main data-load function, detect 404 and show the setup banner instead of a generic error:
```js
.catch(function(err) {
  if (err.message.indexOf('404') !== -1) {
    document.getElementById('list-setup').classList.remove('hidden');
  } else {
    showError('data-error', 'Could not load data: ' + err.message);
  }
});
```

---

## Deployment Requirements (fixed)

Two independent conditions must both be met for an `.aspx` file to execute in the browser rather than download:

**1. Site-level: custom scripts enabled**
The target SharePoint site must have `-DenyAddAndCustomizePages 0` active at the time of upload. This is a 24-hour window, and it is **self-service** — the site owner opens it themselves in seconds from the enablement page, or from the deploy script, with no help desk ticket and no admin rights. Access is granted per site once, by an EUDA admin approving a registration. Files uploaded during the window retain their executable status after it closes. Files in `_data/` (CSS, HTML, JSON) are plain files and are unaffected by this setting.

Never tell the user that deploying a shell requires a ticket or a wait — it does not, and that belief is what pushes people into redesigning an app to avoid a shell change they could have made in seconds.

**2. User-level: "Add and Customize Pages" permission**
The person uploading the `.aspx` file must have this permission at upload time. SharePoint stamps an execute flag on the file based on the uploader's rights — if missing, the file will always download instead of load, even during the window. This permission is only present in **Full Control** and **Design** permission levels. Edit and Contribute do not include it.

Practical split: a designated deployer (Design or Full Control) uploads the `.aspx` shell. The rest of the team can update `_data/` files freely with Contribute access.

Both conditions apply **only when a shell actually changes**. The deploy script compares local shells against the remote inventory and skips enablement entirely for a `_data/`-only deploy — which, with runtime module loading, is nearly every deploy; `-ForceEnablement` runs the check anyway. Never re-upload an unchanged `.aspx` outside the window: doing so strips its executable flag and the app starts downloading instead of running.

Deploy into a **dedicated document library named for the app**, never Site Pages and never the site's default "Documents" library — "Documents" is where people drop unrelated files, which puts them in reach of the deploy's cleanup sweep and widens the Design/Full Control grant the deployer needs.

Deploy with a script rather than manual uploads: it fixes the upload order (`_data/` deepest-first, shells last), skips unchanged files, and opens the window only when a shell needs it. Copy `deploy/examples/Deploy-MyApp.Example.ps1` from the platform repo, which does all three and calls `Enable-CustomScriptWindow` for the self-service window. If the target library is shared with another app, exclude that app's files from cleanup — a sweep that deletes everything absent from the local source will delete the other app.

---

## What NOT to Build (fixed)

- Do not add a backend server or a separate hosting environment. Everything runs in SharePoint/M365 — this is the premise the platform exists to protect
- Do not add an app-owned database outside SharePoint. Lists and `_data/` files are the store. (Reading data that ALREADY lives in SQL Server is a different thing and is supported — via Packaged Python, as that user)
- Consuming an external API is ALLOWED and is a normal thing to build. What is fixed is *where the call is made from*, not whether it happens — see External APIs below
- Do not introduce a build step — npm, webpack, bundlers, transpilers. Every file must be uploadable as-is and readable as-is in the library. This is the fixed constraint; the next line is its consequence
- Use vanilla JS. React, Vue, and Angular are out because they normally imply a build toolchain, not because a framework is forbidden by name — a no-build library loaded from `_data/` as a plain ES module does not break the rule. It is still not the default: say what it buys, confirm it needs no build and no CDN, and record the decision
- Do not hardcode site URLs — always derive from `_spPageContextInfo.webAbsoluteUrl` or `window.location`
- Do not store SECRETS — anything that grants access, such as API keys, connection strings, tokens, or flow trigger URLs — in any file uploaded to the document library. A browser reads everything the page reads
- Confidential business data (salaries, deal terms, HR records) is a different thing and IS supported: store it in lists and protect it with permissions, not by hiding it in the UI. Never tell the user this platform cannot hold confidential data
- Do not read another EUDA application's internal lists, even though SharePoint will allow it — that is a dependency its owner does not know exists and will break on their next refactor. Read only what that app has published in its contract (`<app>_data/contract.json`). If it publishes nothing you need, that is a conversation with its owner, not a query. When this app must exchange data with another one, ask for CROSS_APP_COMMUNICATION_PROMPT.md before designing the integration

---

Begin by confirming the list schema and views, then scaffold the shell and data folder structure before writing any application logic.
```
