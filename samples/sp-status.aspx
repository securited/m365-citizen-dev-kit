<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SharePoint Status</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --blue:    #0078d4;
  --green:   #107c10;
  --red:     #d13438;
  --amber:   #797673;
  --bg:      #f3f2f1;
  --surface: #ffffff;
  --border:  #e1dfdd;
  --text:    #323130;
  --mid:     #605e5c;
}

body {
  font-family: "Segoe UI", system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  font-size: 14px;
  min-height: 100vh;
}

/* Header */
.header {
  background: var(--blue);
  color: #fff;
  height: 48px;
  display: flex;
  align-items: center;
  padding: 0 24px;
  gap: 8px;
  box-shadow: 0 2px 6px rgba(0,0,0,.2);
}
.header-brand { font-size: 15px; font-weight: 600; }
.header-sub   { font-size: 13px; opacity: .7; }

/* Body */
.body {
  max-width: 680px;
  margin: 0 auto;
  padding: 36px 24px 80px;
}

/* Page status banner */
.page-status {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 4px solid var(--green);
  border-radius: 4px;
  padding: 14px 18px;
  margin-bottom: 28px;
  font-size: 14px;
  font-weight: 600;
}
.page-status-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  background: var(--green);
  flex-shrink: 0;
}

/* Section label */
.section-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .07em;
  color: var(--mid);
  margin-bottom: 8px;
}

/* Status rows */
.status-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  margin-bottom: 24px;
  overflow: hidden;
}
.status-row {
  display: grid;
  grid-template-columns: 180px 1fr auto;
  align-items: center;
  padding: 11px 16px;
  border-bottom: 1px solid var(--border);
  gap: 12px;
}
.status-row:last-child { border-bottom: none; }
.status-row-label {
  font-weight: 600;
  font-size: 13px;
  color: var(--text);
  white-space: nowrap;
}
.status-row-value {
  font-size: 13px;
  color: var(--mid);
  word-break: break-all;
}
.status-row-value.loading { color: #a19f9d; font-style: italic; }
.status-indicator {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 10px;
  white-space: nowrap;
  flex-shrink: 0;
}
.ind-ok   { background: #dff6dd; color: var(--green); }
.ind-warn { background: #fff4ce; color: #7a5c00; }
.ind-err  { background: #fde7e9; color: var(--red); }
.ind-info { background: #f3f2f1; color: var(--mid); }

/* Footer */
.footer {
  font-size: 12px;
  color: #a19f9d;
  margin-top: 12px;
  text-align: right;
}
</style>
</head>
<body>

<div class="header">
  <span class="header-brand">&#9671; End-User Developed Applications</span>
  <span class="header-sub">/ Site Status</span>
</div>

<div class="body">

  <div class="page-status">
    <div class="page-status-dot"></div>
    Page loaded and executing on SharePoint
  </div>

  <div class="section-label">Location</div>
  <div class="status-card">
    <div class="status-row">
      <span class="status-row-label">Site URL</span>
      <span class="status-row-value" id="val-site-url">—</span>
      <span class="status-indicator ind-info" id="ind-site-url">—</span>
    </div>
    <div class="status-row">
      <span class="status-row-label">Page path</span>
      <span class="status-row-value" id="val-page-path">—</span>
      <span class="status-indicator ind-info"></span>
    </div>
    <div class="status-row">
      <span class="status-row-label">Site title</span>
      <span class="status-row-value loading" id="val-site-title">Loading…</span>
      <span class="status-indicator" id="ind-site-title"></span>
    </div>
    <div class="status-row">
      <span class="status-row-label">_spPageContextInfo</span>
      <span class="status-row-value" id="val-spctx">—</span>
      <span class="status-indicator" id="ind-spctx"></span>
    </div>
  </div>

  <div class="section-label">Current User</div>
  <div class="status-card">
    <div class="status-row">
      <span class="status-row-label">Display name</span>
      <span class="status-row-value loading" id="val-display-name">Loading…</span>
      <span class="status-indicator" id="ind-user"></span>
    </div>
    <div class="status-row">
      <span class="status-row-label">Login name</span>
      <span class="status-row-value loading" id="val-login-name">Loading…</span>
      <span class="status-indicator"></span>
    </div>
    <div class="status-row">
      <span class="status-row-label">User ID</span>
      <span class="status-row-value loading" id="val-user-id">Loading…</span>
      <span class="status-indicator"></span>
    </div>
  </div>

  <div class="section-label">API Access</div>
  <div class="status-card">
    <div class="status-row">
      <span class="status-row-label">REST API</span>
      <span class="status-row-value loading" id="val-rest">Loading…</span>
      <span class="status-indicator" id="ind-rest"></span>
    </div>
    <div class="status-row">
      <span class="status-row-label">Form digest</span>
      <span class="status-row-value loading" id="val-digest">Loading…</span>
      <span class="status-indicator" id="ind-digest"></span>
    </div>
  </div>

  <div class="footer" id="footer"></div>

</div>

<script>
(function () {
'use strict';

var t0 = Date.now();

/* ── Helpers ─────────────────────────────────────────────────────────────── */
function set(id, text) {
  var el = document.getElementById(id);
  if (el) { el.textContent = text; el.classList.remove('loading'); }
}

function badge(id, label, cls) {
  var el = document.getElementById(id);
  if (el) { el.textContent = label; el.className = 'status-indicator ' + cls; }
}

function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

var SITE_URL = deriveSiteUrl();

/* ── Location ────────────────────────────────────────────────────────────── */
set('val-site-url',  SITE_URL);
set('val-page-path', decodeURIComponent(window.location.pathname));

var spCtx = typeof _spPageContextInfo !== 'undefined';
if (spCtx) {
  set('val-spctx', 'Present (Site Pages master page)');
  badge('ind-spctx', 'Present', 'ind-ok');
} else {
  set('val-spctx', 'Absent — document library mode (expected)');
  badge('ind-spctx', 'Expected', 'ind-info');
}

/* Detect whether URL is SharePoint or local */
var isSharePoint = window.location.hostname.indexOf('sharepoint.com') !== -1;
badge('ind-site-url', isSharePoint ? 'SharePoint' : 'Local', isSharePoint ? 'ind-ok' : 'ind-warn');

/* ── Site title ──────────────────────────────────────────────────────────── */
fetch(SITE_URL + '/_api/web?$select=Title', {
  credentials: 'same-origin',
  headers: { 'Accept': 'application/json;odata=verbose' }
})
.then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
.then(function (d) {
  set('val-site-title', d.d.Title);
  badge('ind-site-title', 'OK', 'ind-ok');
})
.catch(function (e) {
  set('val-site-title', 'Error: ' + e);
  badge('ind-site-title', 'Error', 'ind-err');
});

/* ── Current user ────────────────────────────────────────────────────────── */
fetch(SITE_URL + '/_api/web/currentUser?$select=Title,LoginName,Id', {
  credentials: 'same-origin',
  headers: { 'Accept': 'application/json;odata=verbose' }
})
.then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
.then(function (d) {
  var u = d.d;
  set('val-display-name', u.Title);
  set('val-login-name',   u.LoginName);
  set('val-user-id',      u.Id);
  badge('ind-user', 'Authenticated', 'ind-ok');
})
.catch(function (e) {
  set('val-display-name', 'Error: ' + e);
  set('val-login-name',   '—');
  set('val-user-id',      '—');
  badge('ind-user', 'Error', 'ind-err');
});

/* ── REST + digest ───────────────────────────────────────────────────────── */
fetch(SITE_URL + '/_api/contextinfo', {
  method: 'POST',
  credentials: 'same-origin',
  headers: {
    'Accept': 'application/json;odata=verbose',
    'Content-Type': 'application/json;odata=verbose'
  }
})
.then(function (r) {
  badge('ind-rest', 'HTTP ' + r.status, r.ok ? 'ind-ok' : 'ind-err');
  set('val-rest', r.ok ? 'Reachable' : 'HTTP ' + r.status);
  return r.ok ? r.json() : Promise.reject(r.status);
})
.then(function (d) {
  var digest = d.d.GetContextWebInformation.FormDigestValue;
  var expires = d.d.GetContextWebInformation.FormDigestTimeoutSeconds;
  set('val-digest', 'Available — expires in ' + expires + 's');
  badge('ind-digest', 'Available', 'ind-ok');
})
.catch(function (e) {
  set('val-digest', 'Error: ' + e);
  badge('ind-digest', 'Error', 'ind-err');
});

/* ── Footer ──────────────────────────────────────────────────────────────── */
window.addEventListener('load', function () {
  var el = document.getElementById('footer');
  if (el) el.textContent = 'Loaded in ' + (Date.now() - t0) + ' ms · ' + new Date().toLocaleString();
});

}());
</script>
</body>
</html>
