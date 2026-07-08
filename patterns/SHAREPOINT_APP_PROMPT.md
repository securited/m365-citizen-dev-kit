# Claude Code — SharePoint App Pattern: Project Prompt

> **SharePoint App Pattern — v1.1** · updated 2026-07-06. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

Copy and paste the block below as your first message when starting a new SharePoint application project. Customize the bracketed sections for your specific project.

---

```
You are building a custom web application that runs inside Microsoft SharePoint Online as a single .aspx page. This is a well-established internal platform. Follow all conventions below exactly — they exist because of hard constraints in how SharePoint serves and scans custom files.

---

## Platform Architecture

### Shell + Data Pattern (required)

Every app consists of:
1. A lightweight shell: `[app-name].aspx` — target under 15KB, single `<script>` block, no external dependencies in the shell itself
2. A data folder: `[app-name]_data/` containing:
   - `styles.css` — all CSS
   - `content.html` — all HTML markup for the app body
   - Additional assets as needed (JS modules, config JSON, images)

The shell loads CSS and HTML at runtime via the SharePoint REST $value endpoint. This is intentional and required — do not collapse everything back into a single file.

### Canonical Helpers (define these first — every snippet below uses them)

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

### File Loading Pattern

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

The `$value` endpoint returns raw file bytes for CSS/HTML/JSON assets. **Do not** use it on `.aspx` files — SharePoint executes them server-side and returns 404 from this endpoint.

The `$value` endpoint returns raw file bytes, bypassing Content-Disposition headers. Do not use any other endpoint for loading text assets.

---

## Authentication & Identity

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

## SharePoint REST API Patterns

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

---

## List Design Rules

1. **Index every column used in $filter or $orderby.** Unindexed column queries fail above 5,000 items.
2. **Always use $select.** Never fetch all columns unless building an admin/export view.
3. **Always use $top.** Default SharePoint page size is 100; set explicitly.
4. **Page large result sets** using `$skiptoken` from the `__next` link in responses.
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

## Navigation Pattern

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

## Shell Code Constraints (enforced by SharePoint content scanner)

- **No `document.write()`** — use `innerHTML` / `textContent` / DOM methods
- **No `window.open()`** — use `<a target="_blank">` or in-page modal overlays
- **No top-level `eval()`**
- **No inline event handlers that pass HTML strings to execution contexts**
- **No external CDN script tags** in the shell — load all dependencies from the `_data` folder or inline them
- **Keep shell under 15KB** — all content goes in `content.html`, all styles in `styles.css`
- **Single `<script>` block** in the shell
- **Max line length: no hard limit but keep under 200 chars** for readability and scanner safety

For JSON preview or any "render user content as HTML" feature, use a pre-existing `<div id="overlay">` in content.html and assign content via `textContent`, never `innerHTML` with user data.

---

## Microsoft Graph

Graph is optional — reach for it deliberately, not by default.

**No-token path (prefer this):** the SharePoint user-profile REST endpoint covers most profile needs (display name, title, department, picture URL) using the page's existing cookie session:
```
GET /_api/SP.UserProfiles.PeopleManager/GetMyProperties
```

**Full Graph calls** (`/me/presence`, `/me/manager`, `/users` directory search, `/me/photo/$value`) require a Bearer token, and a document-library ASPX page has no built-in way to get one — the legacy `/_api/SP.OAuth.Token/Acquire` endpoint does NOT issue Graph tokens for custom pages; do not use it. The supported path is `msal-browser` (loaded from the `_data/` folder — no CDN) against the shared "Contoso EUDA Applications" registration (client id `<your-entra-client-id>`, tenant id `<your-tenant-id>`) — which works only if IT has added this SharePoint origin as a SPA redirect URI on that registration. If that redirect is not confirmed, treat browser Graph as unavailable and get the data through a Power Automate flow instead. Ask before building any feature that depends on Graph.

---

## Power Automate Integration

Use HTTP-triggered Power Automate flows for:
- Sending email or Teams messages
- Any server-side computation
- Calling external APIs with secrets
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

## UI/UX Conventions

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

## List Provisioning Pattern

Apps should auto-provision their required lists on first run rather than requiring manual setup. Show a banner with a "Create List" button when the list doesn't exist (detected by a 404 on the items endpoint).

```js
// Field type constants: 2 = Single line text, 3 = Multi-line text, 4 = Number, 8 = Boolean
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

## Deployment Requirements

Two independent conditions must both be met for an `.aspx` file to execute in the browser rather than download:

**1. Site-level: custom scripts enabled**
The target SharePoint site must have `-DenyAddAndCustomizePages 0` active at the time of upload. This is a 24-hour window opened via a help desk ticket. Files uploaded during the window retain their executable status after it closes. Files in `_data/` (CSS, HTML, JSON) are plain files and are unaffected by this setting.

**2. User-level: "Add and Customize Pages" permission**
The person uploading the `.aspx` file must have this permission at upload time. SharePoint stamps an execute flag on the file based on the uploader's rights — if missing, the file will always download instead of load, even during the window. This permission is only present in **Full Control** and **Design** permission levels. Edit and Contribute do not include it.

Practical split: a designated deployer (Design or Full Control) uploads the `.aspx` shell. The rest of the team can update `_data/` files freely with Contribute access.

---

## What NOT to Build

- Do not add a backend server, database, or external API — everything stays in SharePoint/M365
- Do not use npm, webpack, or a build step — all code must be uploadable as static files
- Do not use React, Vue, or Angular — vanilla JS only (keeps shell small, no build toolchain)
- Do not hardcode site URLs — always derive from `_spPageContextInfo.webAbsoluteUrl` or `window.location`
- Do not store secrets in any file that will be uploaded to the document library

---

Begin by confirming the list schema and views, then scaffold the shell and data folder structure before writing any application logic.
```
