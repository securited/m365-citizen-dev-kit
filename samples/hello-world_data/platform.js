/*
 * platform.js — shared SharePoint helpers for hello-world.
 *
 * This is where new shared helpers go, NOT the shell. Everything here is a
 * plain _data/ file: deployable with Contribute permission, no custom-script
 * window, no ticket. Each helper hangs off the APP surface the shell defined.
 */
(function (APP) {
'use strict';

/* ── Refresh the form digest (expires after 30 min) ─────────────────────── */
APP.getDigest = function () {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.formDigestValue) {
    return Promise.resolve(_spPageContextInfo.formDigestValue);
  }
  return APP.spFetch(APP.SITE_URL + '/_api/contextinfo', {
    method: 'POST',
    headers: {
      'Accept': 'application/json;odata=verbose',
      'Content-Type': 'application/json;odata=verbose'
    }
  }).then(function (r) { return r.json(); })
    .then(function (d) { return d.d.GetContextWebInformation.FormDigestValue; });
};

/* ── Build write headers for POST/PATCH/DELETE calls ────────────────────── */
APP.writeHeaders = function (digest, extra) {
  var h = {
    'Accept': 'application/json;odata=verbose',
    'Content-Type': 'application/json;odata=verbose',
    'X-RequestDigest': digest
  };
  if (extra) { Object.keys(extra).forEach(function (k) { h[k] = extra[k]; }); }
  return h;
};

/* ── Toast — non-blocking, fixed bottom-right, auto-dismiss ─────────────── */
APP.showToast = function (msg, type) {
  var t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg;
  t.className = 'toast ' + (type || 'success');
  t.classList.remove('hidden');
  clearTimeout(t._tid);
  t._tid = setTimeout(function () { t.classList.add('hidden'); }, 3500);
};

/* ── Inline error display ────────────────────────────────────────────────── */
APP.showError = function (id, msg) {
  var el = document.getElementById(id);
  if (!el) return;
  el.textContent = msg;
  el.classList.remove('hidden');
};

APP.clearError = function (id) {
  var el = document.getElementById(id);
  if (el) { el.textContent = ''; el.classList.add('hidden'); }
};

/* ── Safe content overlay — textContent only, never innerHTML with user data */
APP.showOverlay = function (content) {
  var overlay = document.getElementById('overlay');
  var pre     = document.getElementById('overlay-content');
  if (!overlay || !pre) return;
  pre.textContent = content;
  overlay.classList.remove('hidden');
};

APP.closeOverlay = function () {
  var overlay = document.getElementById('overlay');
  if (overlay) overlay.classList.add('hidden');
};

/* ── List provisioning: detect on 404, create on demand ─────────────────── */
APP.listExists = function (listName) {
  return APP.spFetch(APP.SITE_URL + '/_api/web/lists?$filter=Title eq \'' +
      APP.spPath(listName) + '\'&$select=Id')
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (d) { return d.d.results.length > 0; });
};

APP.createList = function (digest, listName, description) {
  return APP.spFetch(APP.SITE_URL + '/_api/web/lists', {
    method: 'POST',
    headers: APP.writeHeaders(digest),
    body: JSON.stringify({
      '__metadata': { 'type': 'SP.List' },
      'AllowContentTypes': false,
      'BaseTemplate': 100,
      'ContentTypesEnabled': false,
      'Description': description || '',
      'Title': listName
    })
  }).then(function (r) {
    if (!r.ok) throw new Error('Create list failed: HTTP ' + r.status);
  });
};

/* Error code -2130575306 means "field already exists" — treat as success so
   re-running setup is safe. */
APP.ensureField = function (digest, listName, fieldDef) {
  return APP.spFetch(APP.SITE_URL + '/_api/web/lists/getbytitle(\'' +
      APP.spPath(listName) + '\')/fields', {
    method: 'POST',
    headers: APP.writeHeaders(digest),
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
};

/* ── Power Automate: read the flow URL from a restricted AppConfig list at
   runtime — never stored in a deployed file. ───────────────────────────── */
APP.triggerFlow = function (flowUrlKey, payload) {
  var cfgUrl = APP.SITE_URL + '/_api/web/lists/getbytitle(\'AppConfig\')/items' +
    '?$select=Title,Value&$filter=Title eq \'' + APP.spPath(flowUrlKey) + '\'&$top=1';
  return APP.spFetch(cfgUrl)
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) {
      if (!d || !d.d.results.length) throw new Error('Flow URL not configured');
      return fetch(d.d.results[0].Value, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
    });
};

})(window.APP);
