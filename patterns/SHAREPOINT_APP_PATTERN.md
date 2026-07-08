# Building Applications with the SharePoint App Pattern

> **SharePoint App Pattern — v1.1** · updated 2026-07-06. This is a point-in-time copy; the authoritative version and changelog live on the [Development Patterns hub](https://contoso.sharepoint.com/sites/euda-sample/Sample%20Sites/DEVELOPMENT_PATTERNS.aspx) — check there if you're unsure this is current.

A guide for designing and deploying custom web applications using SharePoint as a complete application platform — no external servers, no external infrastructure, no separate hosting.

> **Starting a new app?** See [SHAREPOINT_APP_PROMPT.md](SHAREPOINT_APP_PROMPT.md) for a complete prompt you can give Claude to constrain development to this pattern's conventions. Copy it as your first message when beginning a new project.

---

## Executive Summary

This platform turns SharePoint into a full application hosting environment using only files, lists, and Microsoft 365 services you already have. Every application follows the same pattern:

**A lightweight `.aspx` shell** (under 15KB) lives in a document library and serves as the entry point. It loads its CSS and HTML from a companion `_data/` subfolder at runtime, keeping the shell itself small and inert. All application logic, styles, and markup live in those companion files — which means most updates never touch the shell.

**SharePoint Lists are the database.** Each list is a table; columns are fields; items are rows. The SharePoint REST API provides full OData querying — filtering, sorting, pagination, and lookups — without any external database or API server. Lists can hold millions of items and auto-provision themselves on first use.

**JSON files in the `_data/` folder serve as a lightweight data layer** for configuration, static lookup tables, and reference data that doesn't need per-row querying. They're read at runtime via the same REST endpoint as CSS and HTML.

**Every user is already authenticated.** There is no login screen to build. Identity is resolved via a single REST call (`/_api/web/currentUser`) — no OAuth flows, no token management, no session handling.

**Power Automate handles all server-side logic.** Sending email, calling external APIs, running approvals, executing on a schedule — these are HTTP-triggered flows your application calls with a `fetch()`. No backend server required.

**Microsoft Graph extends the platform** with rich user data: full profile, photo, manager, presence, and directory search — using the same authenticated session, no additional login needed.

The result is a complete application stack deployed as a handful of files inside your existing M365 tenant. Anyone in your organization can access it, secured by your existing identity system, with no infrastructure to maintain.

### Enabling Deployments

Before uploading `.aspx` files to a SharePoint site, custom scripts must be enabled on that site. **Open a help desk ticket and request that your SharePoint site be enabled for custom script deployments.** Once enabled, the site has a 24-hour deployment window during which you can upload and register your application files. After that window closes, the setting resets automatically.

If you need to make updates to the shell (`.aspx`) file in the future, you will need to request enablement again. Files in the `_data/` folder — CSS, HTML, JSON — can be updated at any time with no re-enablement required, because they are plain document files, not executable scripts.

> The self-service process for enabling custom scripts is planned for a future update and will remove the need to file a ticket.

---

## What This Platform Is

SharePoint is typically thought of as a document management and intranet tool. But with custom script support enabled, it becomes a fully functional application hosting environment: your files live in document libraries, your data lives in lists, your users are already authenticated, and your backend logic runs through Power Automate.

The result is a complete application stack that deploys inside your existing Microsoft 365 tenant — accessible to anyone in your organization, secured by your existing identity system, and maintained without any external hosting.

---

## Core Concepts

### The Shell + Data Pattern

Every application follows a two-part structure:

**The shell** is a lightweight `.aspx` file — typically under 15KB — that contains only enough code to load the rest of the application. SharePoint executes this file as a web page. The shell:
- Displays a loading indicator immediately
- Fetches CSS and HTML content from companion files
- Injects the loaded content into the page
- Initializes any runtime behavior (event listeners, data fetching, etc.)

**The data folder** is a document library subfolder containing the actual application files:
- `styles.css` — all visual styling
- `content.html` — all HTML markup
- Optionally: additional JS modules, images, config files

This separation exists because SharePoint's content scanner scrutinizes `.aspx` files closely. Keeping the shell small and inert reduces the surface area for false positives, and the companion files load as raw text through SharePoint's REST API, bypassing content-type enforcement entirely.

**Naming convention:** If the shell is `my-app.aspx`, the data folder is `my-app_data/`.

---

### Authentication Is Free

Every user visiting your application is already authenticated by Microsoft 365. You never build a login screen. You never manage tokens. If a user can reach your page, you know exactly who they are.

Identity is resolved in one of two ways depending on where your file lives:

**Site Pages** (`.aspx` files in the Site Pages library with a master page) receive a global object called `_spPageContextInfo` automatically:
```
_spPageContextInfo.userDisplayName   — "First Last"
_spPageContextInfo.userLoginName     — "user@company.com"
_spPageContextInfo.userId            — SharePoint user ID (integer)
_spPageContextInfo.webAbsoluteUrl    — current site URL
_spPageContextInfo.formDigestValue   — security token for write operations
```

**Document library ASPX files** — the deployment model this platform uses — do **not** receive `_spPageContextInfo`. The object will be undefined. Resolve identity via a single REST call instead:
```
GET /_api/web/currentUser?$select=Title,LoginName
```
This returns the same display name and login name with no additional authentication needed. All applications on this platform should implement this as the primary identity path, treating `_spPageContextInfo` as a bonus when present.

Similarly, the site URL must be derived from `window.location` rather than `_spPageContextInfo.webAbsoluteUrl`:
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

Lists are queried via the SharePoint REST API using OData syntax — filtering, sorting, selecting specific columns, expanding lookups, and paging through large result sets are all supported.

A single list can hold millions of items. There is a query threshold of 5,000 items per request, but this is a per-query limit, not a list size limit. Applications designed with indexed columns and paginated queries can work effectively with very large data sets.

---

### Files as a Data Source

Not all data belongs in a list. For read-mostly, structured data that doesn't need per-row querying or user-level permissions, JSON files stored in the `_data` folder are a lighter-weight alternative.

**Good fits for file-based data:**
- Application configuration (feature flags, thresholds, display labels)
- Static lookup tables (department codes, status options, category trees)
- Reference data shared across the app but rarely updated (product catalogs, region maps)
- Seed data loaded once on first use

The snippets below (and throughout this guide) use two canonical helpers every app defines once: `spPath()` escapes apostrophes in REST path segments (`p.replace(/'/g, "''")`), and `spFetch()` wraps `fetch()` with `credentials: 'same-origin'` and a default `Accept: application/json;odata=verbose` header. Full definitions are in the [project prompt](SHAREPOINT_APP_PROMPT.md) and the hello-world reference app.

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

The main limitation of file-based data is that there is no querying — you load the entire file and filter in JavaScript. For small datasets this is fine; for anything that could grow large or needs server-side filtering, use a list.

---

### Power Automate Is Your Backend

For any logic that shouldn't run in the browser — sending emails, processing data, calling external APIs, running on a schedule, enforcing approvals — Power Automate is the answer.

A common pattern is the **HTTP-triggered flow**: your application makes a POST request to a Power Automate HTTP trigger URL, passes a JSON payload, and the flow handles the rest. From the application's perspective, it's a simple API call. The flow handles all server-side logic without any code deployment.

Power Automate can:
- Send emails and Teams messages
- Call external REST APIs
- Read and write SharePoint lists
- Run approval workflows with notifications and responses
- Execute on a schedule
- Respond synchronously with a result

---

## Designing Your Application

### Start With the Data Model

Before writing a line of application code, design your SharePoint lists. Ask:

1. What are the core entities? (People, projects, requests, items, events?)
2. What are the relationships between them? (Use Lookup columns)
3. What columns will you filter or sort on? (Index those immediately)
4. What columns are rarely needed? (Leave them out of default queries using `$select`)
5. Do you need history? (Enable versioning)
6. Does any data need to be restricted? (Plan item-level permissions)

Getting the list schema right before building the UI saves significant rework.

---

### Navigation: Views, Not Pages

Because the shell is a single `.aspx` file, navigation is handled entirely in JavaScript. The recommended pattern is **view switching** — showing and hiding sections of the page rather than navigating to new URLs.

Each "page" in your app is a `<div>` with an ID. A central `showView(viewName)` function manages which is visible:

```javascript
function showView(view) {
    document.querySelectorAll('.view').forEach(el => el.classList.add('hidden'));
    document.getElementById(view + '-view').classList.remove('hidden');
    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
    document.getElementById('nav-' + view).classList.add('active');
}
```

This keeps the application feeling fast — there are no page loads between views — and keeps all application state in memory while the user navigates.

---

### Query Design for Large Lists

The 5,000-item query threshold is the most common performance concern for list-backed applications. Follow these rules:

**Index every column you filter or sort on.** An indexed column filter bypasses the threshold entirely. Add indexes in List Settings → Indexed Columns.

**Always use `$select`** to request only the columns your query needs. Fetching all columns on a large list is slow and wasteful.

**Filter before you sort.** Combine `$filter` (on indexed columns) with `$orderby` to reduce the result set before ordering it.

**Page your results.** Use `$top` to limit results per request. Use `$skiptoken` (returned in the response) to fetch subsequent pages. Load more results on demand rather than up front.

**Design for the common case.** Most users will look at recent items, their own items, or items in a specific status. Design your default queries around those cases. Bulk exports and administrative views of everything are edge cases — handle them separately.

---

### File and Asset Management

Keep all application assets in the `_data` subfolder. Load them at runtime using the SharePoint REST `$value` endpoint:

```
/_api/web/getfilebyserverrelativeurl('/sites/mysite/myapp_data/styles.css')/$value
```

This endpoint returns raw file content, bypassing SharePoint's Content-Disposition headers that would otherwise force a download. It's the mechanism that lets your shell load CSS and HTML at runtime.

**Important limitation:** the `$value` endpoint only works for static files (CSS, HTML, JSON, images). It returns 404 for `.aspx` files — SharePoint executes those server-side rather than returning their source bytes. Do not attempt to read or modify ASPX files via this endpoint.

For images and other binary assets, reference them by their direct SharePoint URL. SharePoint serves images inline by default.

---

### Using Microsoft Graph

Graph extends what you can access beyond SharePoint-specific data — but treat it as an opt-in capability, not a default.

**Start with what needs no token.** The SharePoint user-profile REST endpoint (`/_api/SP.UserProfiles.PeopleManager/GetMyProperties`) returns display name, title, department, and a picture URL using the page's existing cookie session. For most personalization, that's enough.

**Full Graph calls need a Bearer token**, and a document-library ASPX page has no built-in way to get one — the legacy `/_api/SP.OAuth.Token/Acquire` endpoint does not issue Graph tokens for custom pages. What Graph offers once you have a token:

- **`/me`** — full user profile including office location and phone
- **`/me/photo/$value`** — profile photo as a blob
- **`/me/manager`** — reporting manager
- **`/me/joinedTeams`** — Teams memberships
- **`/users`** — directory lookups (with appropriate permissions)
- **`/me/presence`** — availability status

The supported token path is **MSAL Browser** (`msal-browser`, served from the `_data/` folder — no CDN) against the shared **Contoso EUDA Applications** registration (see the [Packaged Python pattern](PACKAGED_PYTHON_PATTERN.md) for its details) — which requires IT to add the SharePoint origin as a SPA redirect URI on that registration first. Until that redirect is in place, get Graph-only data through a Power Automate flow instead, and don't build features that depend on browser-side Graph.

---

### Write Operations and the Form Digest

Every POST, PATCH, or DELETE request to the SharePoint REST API must include an `X-RequestDigest` header. This is a time-limited security token that proves the request originated from an authenticated session.

Do not read this from `_spPageContextInfo.formDigestValue` directly — that property will be undefined in document library ASPX files. Always fetch a fresh digest before writes:

```
POST /_api/contextinfo
→ returns d.GetContextWebInformation.FormDigestValue
```

The digest expires after 30 minutes. Fetching it on every write (rather than caching it) ensures long-running sessions never fail with authentication errors.

---

### Provisioning Lists From Your Application

Rather than requiring users to manually create SharePoint lists before using your application, apps should auto-provision their required lists on first run. The recommended pattern:

1. When the data-loading call returns HTTP 404, infer the list doesn't exist yet
2. Show a banner explaining the situation with a "Create List" button
3. On click: call `/_api/web/lists` to create the list, then call the `/fields` endpoint for each custom column
4. On success: hide the banner, show a toast, reload the data

This makes first deployment seamless — upload the files, navigate to the app, click "Create List", and you're ready. The `Title` column is always present on new lists; only add columns beyond that.

When adding fields, error code `-2130575306` means "field already exists" — treat this as a success rather than a failure so re-running setup is safe.

---

### Security Considerations

**Never put sensitive data in JavaScript.** Any config values, connection strings, or API keys embedded in your shell or data files are readable by anyone with access to the document library. Store secrets in a restricted SharePoint list with broken inheritance and read them via a Power Automate flow.

**Use SharePoint groups for access control.** Check group membership via the REST API to conditionally show or hide features. For true enforcement, restrict item-level permissions on the underlying lists — don't rely solely on UI hiding.

**Validate on write.** Column-level validation in SharePoint lists is your last line of defense against bad data. Set it up even if your form already validates client-side.

---

## Deploying Your Application

### Requirements

1. **Custom scripts must be enabled on the target site before uploading `.aspx` files.** Open a help desk ticket and request that your SharePoint site be enabled for custom script deployments. The enablement window is 24 hours — upload all application shell files during this window. Files uploaded and registered during the active window retain their allowed status after the reset.

   If you need to update the shell `.aspx` file in the future, request enablement again before uploading. Files in the `_data/` folder (CSS, HTML, JSON) can be updated at any time with no ticket required.

   > A self-service process for enabling custom scripts is planned and will eventually replace the help desk ticket step.

2. **Files must be uploaded to a standard Document Library** — not Site Pages. Site Pages is a special page library that processes `.aspx` files through SharePoint's master page and publishing pipeline, which conflicts with how this platform works. Use any regular document library (the default "Documents" library works, or create a dedicated one such as "Sample Sites"). If you accidentally upload to Site Pages, the app will fail to load its CSS and HTML assets.

3. **The person uploading the `.aspx` shell file must have the "Add and Customize Pages" permission.** This is a separate, user-level requirement on top of the site-level enablement window. SharePoint stamps an execute flag on uploaded files based on the uploader's permissions at the time of upload — if that flag is not set, the file downloads instead of loading in the browser.

   This permission is only included in two built-in SharePoint permission levels:

   | Permission level | Add and Customize Pages |
   |---|---|
   | Full Control (Site Owner) | ✅ Yes |
   | Design | ✅ Yes |
   | Edit | ❌ No |
   | Contribute | ❌ No |
   | Read | ❌ No |

   Users with Edit or Contribute access can upload the file but it will never execute — it will download instead, even during the enablement window. The fix is to grant the deploying user **Design** or **Full Control** on the document library.

   > **Practical workflow:** the IT admin or a designated deployer (with Design or Full Control) uploads the `.aspx` shell file. Everyone else on the team can update files in the `_data/` folder freely — those are plain files and work with Contribute-level access.

### Upload Order

1. Navigate to a standard **Document Library** (not Site Pages)
2. Create the `_data` subfolder in that library
3. Upload `styles.css` and `content.html` to the `_data` folder
4. Upload the shell `.aspx` file to the parent folder
5. Check the file in if required
6. Test immediately while the custom script window is active

### Updating Your Application

Because the shell only loads assets at runtime, most updates only require replacing files in the `_data` folder. The shell itself rarely needs to change after initial deployment. CSS and HTML updates take effect immediately on next page load with no re-registration required.

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
| Write a JSON file | REST `files/add(url='...',overwrite=true)` with `ArrayBuffer` body |
| Load CSS/HTML at runtime | REST `$value` endpoint (static files only — not `.aspx`) |
| Where to deploy files | Standard Document Library only — **not** Site Pages |
| Access control | SharePoint groups + item-level permissions |
| Audit trail | List versioning |
| Large data sets | Indexed columns + paged queries |
