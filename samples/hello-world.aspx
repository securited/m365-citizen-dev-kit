<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Hello World | End-User Developed Applications</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:"Segoe UI",sans-serif;background:#f3f2f1;color:#323130}
#app-loading{display:flex;flex-direction:column;align-items:center;justify-content:center;
  min-height:100vh;gap:16px;color:#605e5c}
#app-loading p{font-size:15px}
.sp-spinner{width:36px;height:36px;border:3px solid #e1dfdd;border-top-color:#0078d4;
  border-radius:50%;animation:sp-spin .8s linear infinite}
@keyframes sp-spin{to{transform:rotate(360deg)}}
#app-container{display:none}
</style>
</head>
<body>

<div id="app-loading">
  <div class="sp-spinner"></div>
  <p>Loading<span id="load-dots"></span></p>
</div>
<div id="app-container"></div>

<script>
(function () {
'use strict';

/* ── Path and URL derivation ─────────────────────────────────────────────── */
function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

var SITE_URL    = deriveSiteUrl();
var PAGE_PATH   = decodeURIComponent(window.location.pathname);
var PAGE_FOLDER = PAGE_PATH.substring(0, PAGE_PATH.lastIndexOf('/'));
var DATA_FOLDER = PAGE_FOLDER + '/hello-world_data';
var LIST_NAME   = 'HelloWorldMessages';
var PAGE_SIZE   = 10;

var LIST_FIELD_DEFS = [
  { '__metadata': { 'type': 'SP.FieldMultiLineText' }, 'FieldTypeKind': 3,
    'Title': 'Body', 'Required': false, 'NumberOfLines': 6, 'RichText': false }
];

/* ── Runtime state ───────────────────────────────────────────────────────── */
var _pendingDeleteId = null;
var _editingId       = null;
var _nextPageToken   = null;

/* ── Encode single-quoted path segments for SharePoint REST URLs ─────────── */
function spPath(p) {
  return p.replace(/'/g, "''");
}

/* ── Fetch wrapper — adds credentials and default Accept header ──────────── */
function spFetch(url, opts) {
  opts = opts || {};
  opts.credentials = 'same-origin';
  opts.headers = opts.headers || {};
  if (!opts.headers['Accept']) {
    opts.headers['Accept'] = 'application/json;odata=verbose';
  }
  return fetch(url, opts);
}

/* ── Load a file from the _data folder via the SharePoint $value endpoint ── */
function fetchAsset(filename) {
  var apiUrl = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
    spPath(DATA_FOLDER + '/' + filename) + '\')/$value';
  return spFetch(apiUrl, { headers: { 'Accept': 'text/plain' } })
    .then(function (r) {
      if (r.ok) return r.text();
      return fetch('./hello-world_data/' + filename).then(function (r2) { return r2.text(); });
    })
    .catch(function () {
      return fetch('./hello-world_data/' + filename).then(function (r2) { return r2.text(); });
    });
}

/* ── Refresh the form digest (expires after 30 min) ─────────────────────── */
function getDigest() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.formDigestValue) {
    return Promise.resolve(_spPageContextInfo.formDigestValue);
  }
  return spFetch(SITE_URL + '/_api/contextinfo', {
    method: 'POST',
    headers: {
      'Accept': 'application/json;odata=verbose',
      'Content-Type': 'application/json;odata=verbose'
    }
  }).then(function (r) { return r.json(); })
    .then(function (d) { return d.d.GetContextWebInformation.FormDigestValue; });
}

/* ── Build write headers for POST/PATCH/DELETE calls ────────────────────── */
function writeHeaders(digest, extra) {
  var h = {
    'Accept': 'application/json;odata=verbose',
    'Content-Type': 'application/json;odata=verbose',
    'X-RequestDigest': digest
  };
  if (extra) { Object.keys(extra).forEach(function (k) { h[k] = extra[k]; }); }
  return h;
}

/* ── Toast — non-blocking, fixed bottom-right, auto-dismiss ─────────────── */
function showToast(msg, type) {
  var t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg;
  t.className = 'toast ' + (type || 'success');
  t.classList.remove('hidden');
  clearTimeout(t._tid);
  t._tid = setTimeout(function () { t.classList.add('hidden'); }, 3500);
}

/* ── Inline error display ────────────────────────────────────────────────── */
function showError(id, msg) {
  var el = document.getElementById(id);
  if (!el) return;
  el.textContent = msg;
  el.classList.remove('hidden');
}
function clearError(id) {
  var el = document.getElementById(id);
  if (el) { el.textContent = ''; el.classList.add('hidden'); }
}

/* ── Navigation: in-page view switching ─────────────────────────────────── */
function showView(view) {
  document.querySelectorAll('.view-section').forEach(function (el) {
    el.classList.add('hidden');
  });
  document.querySelectorAll('.nav-item').forEach(function (el) {
    el.classList.remove('active');
  });
  var section = document.getElementById(view + '-section');
  var navBtn  = document.getElementById('nav-' + view);
  if (section) section.classList.remove('hidden');
  if (navBtn)  navBtn.classList.add('active');
  if (view === 'messages')  loadMessages(true);
  if (view === 'dashboard') loadDashboard();
  if (view === 'metrics')   loadMetrics();
}

/* ── Safe content overlay — textContent only, never innerHTML with user data */
function showOverlay(content) {
  var overlay = document.getElementById('overlay');
  var pre     = document.getElementById('overlay-content');
  if (!overlay || !pre) return;
  pre.textContent = content;
  overlay.classList.remove('hidden');
}
function closeOverlay() {
  var overlay = document.getElementById('overlay');
  if (overlay) overlay.classList.add('hidden');
}

/* ── Microsoft Graph: current user profile ───────────────────────────────── */
function loadGraphProfile() {
  var token = window._graphToken || '';
  return fetch('https://graph.microsoft.com/v1.0/me', {
    headers: { 'Authorization': 'Bearer ' + token }
  }).then(function (r) {
    if (!r.ok) throw new Error('Graph unavailable');
    return r.json();
  });
}

/* ── Microsoft Graph: profile photo ─────────────────────────────────────── */
function loadUserPhoto() {
  var img   = document.getElementById('user-photo');
  var token = window._graphToken || '';
  if (!img) return;
  fetch('https://graph.microsoft.com/v1.0/me/photo/$value', {
    headers: { 'Authorization': 'Bearer ' + token }
  }).then(function (r) {
    if (!r.ok) throw new Error('no photo');
    return r.blob();
  }).then(function (blob) {
    img.src = URL.createObjectURL(blob);
    img.classList.remove('hidden');
  }).catch(function () { /* photo unavailable — silent */ });
}

/* ── Dashboard ───────────────────────────────────────────────────────────── */
function loadDashboard() {
  clearError('dash-error');
  var ctx = (typeof _spPageContextInfo !== 'undefined') ? _spPageContextInfo : null;

  var nameEl   = document.getElementById('user-name');
  var greeting = document.getElementById('greeting-text');
  var dUser    = document.getElementById('dash-user');
  var dLogin   = document.getElementById('dash-login');
  var dSite    = document.getElementById('dash-site');

  if (dSite) dSite.textContent = SITE_URL;

  if (ctx) {
    var name = ctx.userDisplayName || 'there';
    if (greeting) greeting.textContent = 'Hello, ' + name + '!';
    if (nameEl)   nameEl.textContent   = name;
    if (dUser)    dUser.textContent    = ctx.userDisplayName || '—';
    if (dLogin)   dLogin.textContent   = ctx.userLoginName   || '—';
  } else {
    if (greeting) greeting.textContent = 'Hello, World!';
    if (nameEl)   nameEl.textContent   = '…';
    if (dUser)    dUser.textContent    = '…';
    if (dLogin)   dLogin.textContent   = '…';
    spFetch(SITE_URL + '/_api/web/currentUser?$select=Title,LoginName')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d || !d.d) return;
        var displayName = d.d.Title || '';
        var loginName   = d.d.LoginName || '';
        if (greeting) greeting.textContent = 'Hello, ' + (displayName || 'World') + '!';
        if (nameEl)   nameEl.textContent   = displayName;
        if (dUser)    dUser.textContent    = displayName || '—';
        if (dLogin)   dLogin.textContent   = loginName   || '—';
      })
      .catch(function () {
        if (greeting) greeting.textContent = 'Hello, World!';
        if (nameEl)   nameEl.textContent   = 'Dev';
        if (dUser)    dUser.textContent    = 'Dev Mode';
        if (dLogin)   dLogin.textContent   = 'dev@local';
      });
  }

  var countEl = document.getElementById('dash-count');
  spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + LIST_NAME + '\')' +
    '?$select=ItemCount')
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) {
      if (countEl && d && d.d) countEl.textContent = d.d.ItemCount;
    })
    .catch(function () { if (countEl) countEl.textContent = 'N/A'; });

  loadGraphProfile()
    .then(function (profile) {
      var container = document.getElementById('dash-graph-info');
      var details   = document.getElementById('graph-details');
      if (!container || !details) return;
      var fields = [
        ['Display Name', profile.displayName],
        ['Job Title',    profile.jobTitle],
        ['Department',   profile.department],
        ['Office',       profile.officeLocation],
        ['Email',        profile.mail || profile.userPrincipalName]
      ];
      var html = '';
      fields.forEach(function (f) {
        if (f[1]) {
          html += '<div class="graph-row"><span class="graph-label">' + f[0] +
            '</span><span class="graph-val">' + f[1] + '</span></div>';
        }
      });
      details.innerHTML = html; /* Safe: Graph profile data, not user-authored content */
      container.classList.remove('hidden');
      loadUserPhoto();
    })
    .catch(function () { /* Graph unavailable in this context — silent */ });
}

/* ── List provisioning ───────────────────────────────────────────────────── */
function listExists() {
  return spFetch(SITE_URL + '/_api/web/lists?$filter=Title eq \'' + spPath(LIST_NAME) + '\'&$select=Id')
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (d) { return d.d.results.length > 0; });
}

function createListOnSite(digest) {
  return spFetch(SITE_URL + '/_api/web/lists', {
    method: 'POST',
    headers: writeHeaders(digest),
    body: JSON.stringify({
      '__metadata': { 'type': 'SP.List' },
      'AllowContentTypes': false,
      'BaseTemplate': 100,
      'ContentTypesEnabled': false,
      'Description': 'Messages list — created by hello-world.aspx',
      'Title': LIST_NAME
    })
  }).then(function (r) {
    if (!r.ok) throw new Error('Create list failed: HTTP ' + r.status);
  });
}

function ensureField(digest, fieldDef) {
  return spFetch(SITE_URL + '/_api/web/lists/getbytitle(\'' + spPath(LIST_NAME) + '\')/fields', {
    method: 'POST',
    headers: writeHeaders(digest),
    body: JSON.stringify(fieldDef)
  }).then(function (r) {
    if (!r.ok) {
      return r.json().catch(function () { return {}; }).then(function (body) {
        var code = (body && body.error && body.error.code) || '';
        if (code.indexOf('-2130575306') === -1) {
          throw new Error('Add field "' + fieldDef.Title + '" failed: ' + (code || r.status));
        }
      });
    }
  });
}

function ensureList() {
  var statusEl = document.getElementById('setup-status');
  var setupEl  = document.getElementById('list-setup');
  var setupBtn = document.getElementById('btn-setup-list');
  if (statusEl) { statusEl.textContent = 'Creating list…'; statusEl.classList.remove('hidden'); }
  if (setupBtn) setupBtn.disabled = true;

  getDigest()
    .then(function (digest) {
      return createListOnSite(digest).then(function () {
        if (statusEl) statusEl.textContent = 'Adding fields…';
        return LIST_FIELD_DEFS.reduce(function (chain, fd) {
          return chain.then(function () { return ensureField(digest, fd); });
        }, Promise.resolve());
      });
    })
    .then(function () {
      if (setupEl) setupEl.classList.add('hidden');
      showToast('List created — ready to post messages!', 'success');
      loadMessages(true);
    })
    .catch(function (err) {
      if (statusEl) statusEl.textContent = 'Failed: ' + err.message;
      if (setupBtn) setupBtn.disabled = false;
    });
}

/* ── Messages: read list with $select, $expand, $orderby, $top, $skiptoken ─ */
function loadMessages(reset) {
  if (reset) _nextPageToken = null;

  var list    = document.getElementById('messages-list');
  var loading = document.getElementById('messages-loading');
  var empty   = document.getElementById('messages-empty');
  var moreBtn = document.getElementById('load-more-container');

  clearError('messages-error');
  if (reset && list) list.innerHTML = '';
  if (loading) loading.classList.remove('hidden');
  if (empty)   empty.classList.add('hidden');
  if (list)    list.classList.add('hidden');
  if (moreBtn) moreBtn.classList.add('hidden');

  var base  = SITE_URL + '/_api/web/lists/getbytitle(\'' + LIST_NAME + '\')/items';
  var query = '?$select=Id,Title,Body,Author/Title,Author/EMail,Created' +
    '&$expand=Author' +
    '&$orderby=Created desc' +
    '&$top=' + PAGE_SIZE;
  if (_nextPageToken) query += '&$skiptoken=' + encodeURIComponent(_nextPageToken);

  spFetch(base + query)
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (data) {
      if (loading) loading.classList.add('hidden');
      var items = data.d.results;

      _nextPageToken = null;
      if (data.d.__next) {
        var m = data.d.__next.match(/\$skiptoken=([^&]+)/);
        if (m) _nextPageToken = decodeURIComponent(m[1]);
      }

      if (items.length === 0 && reset) {
        if (empty) empty.classList.remove('hidden');
        return;
      }
      renderMessages(items);
      if (list)    list.classList.remove('hidden');
      if (moreBtn && _nextPageToken) moreBtn.classList.remove('hidden');
    })
    .catch(function (err) {
      if (loading) loading.classList.add('hidden');
      if (err.message.indexOf('404') !== -1) {
        var setupEl = document.getElementById('list-setup');
        if (setupEl) setupEl.classList.remove('hidden');
      } else {
        showError('messages-error', 'Could not load messages: ' + err.message);
      }
    });
}

/* ── Render message items ────────────────────────────────────────────────── */
function renderMessages(items) {
  var list = document.getElementById('messages-list');
  if (!list) return;
  items.forEach(function (item) {
    var li = document.createElement('li');
    li.className = 'message-item';
    li.setAttribute('data-id', item.Id);

    var header = document.createElement('div');
    header.className = 'message-header';

    var author = document.createElement('span');
    author.className = 'message-author';
    author.textContent = (item.Author && item.Author.Title) ? item.Author.Title : 'Unknown';

    var date = document.createElement('span');
    date.className = 'message-date';
    date.textContent = item.Created ? new Date(item.Created).toLocaleString() : '';

    var titleEl = document.createElement('p');
    titleEl.className = 'message-title';
    titleEl.textContent = item.Title || '';

    var bodyEl = document.createElement('p');
    bodyEl.className = 'message-body';
    bodyEl.textContent = item.Body || '';

    var actions = document.createElement('div');
    actions.className = 'message-actions';

    var editBtn = document.createElement('button');
    editBtn.className = 'btn-link';
    editBtn.textContent = 'Edit';
    editBtn.setAttribute('data-id', item.Id);
    editBtn.setAttribute('data-title', item.Title || '');
    editBtn.setAttribute('data-body', item.Body || '');
    editBtn.addEventListener('click', function () { openEditForm(this); });

    var delBtn = document.createElement('button');
    delBtn.className = 'btn-link btn-link-danger';
    delBtn.textContent = 'Delete';
    delBtn.setAttribute('data-id', item.Id);
    delBtn.addEventListener('click', function () {
      confirmDelete(this.getAttribute('data-id'));
    });

    var rawBtn = document.createElement('button');
    rawBtn.className = 'btn-link';
    rawBtn.textContent = 'View raw';
    rawBtn.addEventListener('click', (function (i) {
      return function () { showOverlay(JSON.stringify(i, null, 2)); };
    })(item));

    header.appendChild(author);
    header.appendChild(date);
    actions.appendChild(editBtn);
    actions.appendChild(delBtn);
    actions.appendChild(rawBtn);
    li.appendChild(header);
    li.appendChild(titleEl);
    li.appendChild(bodyEl);
    li.appendChild(actions);
    list.appendChild(li);
  });
}

/* ── Form helpers ────────────────────────────────────────────────────────── */
function openNewForm() {
  _editingId = null;
  var ft = document.getElementById('form-title');
  var ti = document.getElementById('msg-title');
  var bi = document.getElementById('msg-body');
  if (ft) ft.textContent = 'New Message';
  if (ti) ti.value = '';
  if (bi) bi.value = '';
  clearError('form-error');
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.remove('hidden');
  if (ti) ti.focus();
}

function openEditForm(btn) {
  _editingId = btn.getAttribute('data-id');
  var ft = document.getElementById('form-title');
  var ti = document.getElementById('msg-title');
  var bi = document.getElementById('msg-body');
  if (ft) ft.textContent = 'Edit Message';
  if (ti) ti.value = btn.getAttribute('data-title');
  if (bi) bi.value = btn.getAttribute('data-body');
  clearError('form-error');
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.remove('hidden');
  if (ti) ti.focus();
}

function cancelForm() {
  _editingId = null;
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.add('hidden');
}

/* ── Submit message: create (POST) or update (PATCH + MERGE) ─────────────── */
function submitMessage() {
  var titleVal = ((document.getElementById('msg-title') || {}).value || '').trim();
  var bodyVal  = ((document.getElementById('msg-body')  || {}).value || '').trim();
  clearError('form-error');

  if (!titleVal) { showError('form-error', 'Title is required.'); return; }

  var isEdit = !!_editingId;
  var base   = SITE_URL + '/_api/web/lists/getbytitle(\'' + LIST_NAME + '\')/items';
  var url    = isEdit ? base + '(' + _editingId + ')' : base;

  getDigest().then(function (digest) {
    var body = JSON.stringify({
      '__metadata': { 'type': 'SP.Data.' + LIST_NAME + 'ListItem' },
      'Title': titleVal,
      'Body':  bodyVal
    });
    var extraHdrs = isEdit ? { 'IF-MATCH': '*', 'X-HTTP-Method': 'MERGE' } : {};
    return spFetch(url, {
      method:  isEdit ? 'PATCH' : 'POST',
      headers: writeHeaders(digest, extraHdrs),
      body:    body
    });
  }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    cancelForm();
    showToast(isEdit ? 'Message updated.' : 'Message posted!', 'success');
    loadMessages(true);
  }).catch(function (err) {
    showError('form-error', 'Save failed: ' + err.message);
  });
}

/* ── Delete: inline confirmation, then REST DELETE via X-HTTP-Method ─────── */
function confirmDelete(id) {
  _pendingDeleteId = id;
  var dc = document.getElementById('delete-confirm');
  if (dc) dc.classList.remove('hidden');
}

function cancelDelete() {
  _pendingDeleteId = null;
  var dc = document.getElementById('delete-confirm');
  if (dc) dc.classList.add('hidden');
}

function executeDelete() {
  if (!_pendingDeleteId) return;
  var id = _pendingDeleteId;
  cancelDelete();
  var url = SITE_URL + '/_api/web/lists/getbytitle(\'' + LIST_NAME + '\')/items(' + id + ')';
  getDigest().then(function (digest) {
    return spFetch(url, {
      method:  'POST',
      headers: writeHeaders(digest, { 'IF-MATCH': '*', 'X-HTTP-Method': 'DELETE' })
    });
  }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    showToast('Message deleted.', 'success');
    loadMessages(true);
  }).catch(function (err) {
    showToast('Delete failed: ' + err.message, 'error');
  });
}

/* ── Power Automate: read flow URL from restricted AppConfig list at runtime  */
function triggerFlow(flowUrlKey, payload) {
  var cfgUrl = SITE_URL + '/_api/web/lists/getbytitle(\'AppConfig\')/items' +
    '?$select=Title,Value&$filter=Title eq \'' + spPath(flowUrlKey) + '\'&$top=1';
  return spFetch(cfgUrl)
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) {
      if (!d || !d.d.results.length) throw new Error('Flow URL not configured');
      return fetch(d.d.results[0].Value, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
    });
}

/* ── Metrics: load JSON file, render status cards with sparklines ────────── */
function statusColor(s) {
  return s === 'healthy' ? '#107c10' : s === 'warning' ? '#ffaa44' : s === 'degraded' ? '#d13438' : '#a19f9d';
}

function sparkline(history, color) {
  var pts = (history || []).filter(function (v) { return v !== null; });
  var last = pts.slice(-24);
  if (last.length < 2) return '';
  var min = Math.min.apply(null, last);
  var max = Math.max.apply(null, last);
  var range = max - min || 1;
  var W = 64, H = 22;
  var coords = last.map(function (v, i) {
    return (i / (last.length - 1) * W).toFixed(1) + ',' + (H - (v - min) / range * H).toFixed(1);
  }).join(' ');
  return '<svg width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '" class="sparkline">' +
    '<polyline points="' + coords + '" fill="none" stroke="' + color + '" stroke-width="1.5" stroke-linejoin="round"/>' +
    '</svg>';
}

function fmtValue(v, unit) {
  if (v === null || v === undefined) return '—';
  if (unit === 'ms') {
    return v >= 1000 ? (v / 1000).toFixed(1) + 's' : v + 'ms';
  }
  if (unit === '%') return v.toFixed(2) + '%';
  if (unit === 'rpm') return v >= 1000 ? (v / 1000).toFixed(1) + 'k' : String(v);
  return String(v);
}

function metricClass(v, warn, crit) {
  if (v === null || v === undefined) return 'null-val';
  if (crit !== null && v >= crit) return 'crit';
  if (warn !== null && v >= warn) return 'warn';
  return '';
}

function renderMetrics(data, sizeKb, loadMs) {
  var summary = document.getElementById('metrics-summary');
  var body    = document.getElementById('metrics-body');
  var meta    = document.getElementById('metrics-meta');
  if (!summary || !body) return;

  var s = data.summary;
  summary.innerHTML =
    ['healthy', 'warning', 'degraded', 'offline'].map(function (st) {
      return '<span class="status-pill ' + st + '">' +
        '<span class="pill-dot ' + st + '"></span>' +
        s[st] + ' ' + st + '</span>';
    }).join('');

  body.innerHTML = data.categories.map(function (cat) {
    var cards = cat.services.map(function (svc) {
      var col = statusColor(svc.status);
      var m   = svc.metrics;
      var rows = [
        { label: 'p95 latency', key: 'p95ms' },
        { label: 'error rate',  key: 'errorPct' },
        { label: 'uptime',      key: 'uptime' },
        { label: 'throughput',  key: 'rpm' }
      ].map(function (r) {
        var metric = m[r.key];
        var val    = metric ? metric.current : null;
        var unit   = metric ? metric.unit : '';
        var warn   = metric ? metric.warn : null;
        var crit   = metric ? metric.crit : null;
        /* uptime: lower = worse; all other metrics: higher = worse */
      var cls    = r.key === 'uptime'
        ? (val !== null && crit !== null && val < crit ? 'crit' : val !== null && warn !== null && val < warn ? 'warn' : '')
        : metricClass(val, warn, crit);
        var spark  = metric ? sparkline(metric.history, col) : '';
        return '<div class="metrics-row">' +
          '<span class="metrics-row-label">' + r.label + '</span>' +
          '<span class="metrics-row-value ' + cls + '">' + fmtValue(val, unit) + '</span>' +
          spark + '</div>';
      }).join('');

      return '<div class="metrics-card ' + svc.status + '">' +
        '<div class="metrics-card-header">' +
          '<div><div class="metrics-card-name">' + svc.name + '</div>' +
          '<div class="metrics-card-owner">' + svc.owner + '</div></div>' +
          '<span class="status-badge ' + svc.status + '">' + svc.status + '</span>' +
        '</div>' +
        '<div class="metrics-rows">' + rows + '</div>' +
        '</div>';
    }).join('');

    return '<div>' +
      '<div class="metrics-category-title">' + cat.name + '</div>' +
      '<div class="metrics-cards">' + cards + '</div>' +
      '</div>';
  }).join('');

  if (meta) {
    meta.textContent = sizeKb + ' KB loaded in ' + loadMs + 'ms · ' +
      data.meta.points + ' data points per metric · generated ' + data.meta.generated;
  }

  document.getElementById('metrics-loading').classList.add('hidden');
  document.getElementById('metrics-content').classList.remove('hidden');
}

function loadMetrics() {
  var loading = document.getElementById('metrics-loading');
  var content = document.getElementById('metrics-content');
  if (loading) { loading.classList.remove('hidden'); loading.querySelector && (loading.querySelector('.dots') || {}); }
  if (content) content.classList.add('hidden');
  clearError('metrics-error');

  var t0 = Date.now();
  fetchAsset('metrics.json')
    .then(function (text) {
      var sizeKb = Math.round(text.length / 1024);
      var data   = JSON.parse(text);
      renderMetrics(data, sizeKb, Date.now() - t0);
    })
    .catch(function (err) {
      if (loading) loading.classList.add('hidden');
      showError('metrics-error', 'Could not load metrics: ' + err.message);
    });
}

/* ── Bind DOM events after content.html is injected ─────────────────────── */
function bindEvents() {
  function on(id, ev, fn) {
    var el = document.getElementById(id);
    if (el) el.addEventListener(ev, fn);
  }
  on('btn-new-message',    'click', openNewForm);
  on('btn-submit-message', 'click', submitMessage);
  on('btn-cancel-message', 'click', cancelForm);
  on('btn-confirm-delete', 'click', executeDelete);
  on('btn-cancel-delete',  'click', cancelDelete);
  on('btn-load-more',      'click', function () { loadMessages(false); });
  on('overlay-close',      'click', closeOverlay);
  on('btn-setup-list',      'click', ensureList);
  on('btn-refresh-metrics', 'click', loadMetrics);

  document.querySelectorAll('.nav-item').forEach(function (btn) {
    btn.addEventListener('click', function () {
      showView(this.getAttribute('data-view'));
    });
  });
}

/* ── Initialize app — called after CSS and HTML assets are loaded ────────── */
function initApp() {
  bindEvents();
  loadDashboard();
  showView('dashboard');
}

/* ── Boot: fetch assets, inject into page, reveal app ───────────────────── */
function boot() {
  var loadDots = document.getElementById('load-dots');
  var dotsAnim = setInterval(function () {
    if (loadDots) {
      var d = loadDots.textContent.length;
      loadDots.textContent = d < 3 ? loadDots.textContent + '.' : '';
    }
  }, 400);

  Promise.all([fetchAsset('styles.css'), fetchAsset('content.html')])
    .then(function (assets) {
      clearInterval(dotsAnim);

      var styleEl = document.createElement('style');
      styleEl.textContent = assets[0];
      document.head.appendChild(styleEl);

      var container = document.getElementById('app-container');
      if (container) {
        container.innerHTML = assets[1]; /* Safe: our own content.html, not user input */
        container.style.display = 'block';
      }

      var loadingEl = document.getElementById('app-loading');
      if (loadingEl) loadingEl.style.display = 'none';

      initApp();
    })
    .catch(function (err) {
      clearInterval(dotsAnim);
      var loadingEl = document.getElementById('app-loading');
      if (loadingEl) {
        var p = document.createElement('p');
        p.style.color = '#d13438';
        p.textContent = 'Failed to load application: ' + err.message;
        loadingEl.appendChild(p);
      }
    });
}

boot();
}());
</script>
</body>
</html>
