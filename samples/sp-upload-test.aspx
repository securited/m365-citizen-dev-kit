<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SP Upload Test</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: monospace;
  background: #111;
  color: #ccc;
  padding: 24px;
  font-size: 13px;
  line-height: 1.6;
}

h2 { color: #fff; font-size: 1rem; margin-bottom: 20px; letter-spacing: .05em; text-transform: uppercase; }

.section { margin-bottom: 28px; }
.section-label { font-size: 11px; color: #555; text-transform: uppercase; letter-spacing: .08em; margin-bottom: 8px; }

/* Controls */
.controls { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-bottom: 16px; }
input[type="text"] {
  background: #1e1e1e;
  border: 1px solid #333;
  color: #ddd;
  padding: 6px 10px;
  font-family: monospace;
  font-size: 13px;
  border-radius: 3px;
  width: 280px;
}
input[type="text"]:focus { outline: none; border-color: #0078d4; }

button {
  background: #0078d4;
  color: #fff;
  border: none;
  padding: 6px 14px;
  font-family: monospace;
  font-size: 13px;
  border-radius: 3px;
  cursor: pointer;
}
button:hover { background: #106ebe; }
button:disabled { background: #333; color: #666; cursor: default; }

/* Log */
.log {
  background: #0a0a0a;
  border: 1px solid #222;
  border-radius: 3px;
  padding: 12px 14px;
  min-height: 48px;
}
.log-row { display: flex; gap: 10px; margin: 2px 0; }
.log-time { color: #444; flex-shrink: 0; }
.log-label { color: #666; flex-shrink: 0; min-width: 220px; }
.pass { color: #4c4; }
.fail { color: #f55; }
.info { color: #888; }
.warn { color: #cc8; }

/* Upload target display */
.target-path {
  color: #0078d4;
  word-break: break-all;
}
</style>
</head>
<body>

<h2>&#9671; SharePoint Upload Test</h2>

<div class="section">
  <div class="section-label">Upload target</div>
  <div class="log" id="target-info">
    <div class="log-row"><span class="info">Deriving upload path from current URL…</span></div>
  </div>
</div>

<div class="section">
  <div class="section-label">Test file name</div>
  <div class="controls">
    <input type="text" id="filename" value="sp-upload-test-canary.txt" />
    <button id="btn-run">Run Upload Test</button>
    <button id="btn-cleanup" disabled>Delete Test File</button>
  </div>
</div>

<div class="section">
  <div class="section-label">Results</div>
  <div class="log" id="log"></div>
</div>

<script>
(function () {
'use strict';

var t0 = Date.now();
var uploadedFileUrl = null;

/* ── Helpers ─────────────────────────────────────────────────────────────── */
function ts() { return ((Date.now() - t0) / 1000).toFixed(2) + 's'; }

function log(label, value, state) {
  var out = document.getElementById('log');
  var row = document.createElement('div');
  row.className = 'log-row';
  row.innerHTML =
    '<span class="log-time">' + ts() + '</span>' +
    '<span class="log-label">' + label + '</span>' +
    '<span class="' + (state || 'info') + '">' + value + '</span>';
  out.appendChild(row);
}

function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

function spPath(p) { return p.replace(/'/g, "''"); }

var SITE_URL   = deriveSiteUrl();
var PAGE_PATH  = decodeURIComponent(window.location.pathname);
var PAGE_FOLDER = PAGE_PATH.substring(0, PAGE_PATH.lastIndexOf('/'));

/* ── Show upload target ──────────────────────────────────────────────────── */
(function showTarget() {
  var el = document.getElementById('target-info');
  el.innerHTML =
    '<div class="log-row"><span class="log-label">Site URL</span>' +
      '<span class="target-path">' + SITE_URL + '</span></div>' +
    '<div class="log-row"><span class="log-label">Upload folder</span>' +
      '<span class="target-path">' + PAGE_FOLDER + '</span></div>' +
    '<div class="log-row"><span class="log-label">Full upload URL</span>' +
      '<span class="info">SITE_URL/_api/web/getfolderbyserverrelativeurl(folder)/files/add(url=filename,overwrite=true)</span></div>';
}());

/* ── Get digest ──────────────────────────────────────────────────────────── */
function getDigest() {
  return fetch(SITE_URL + '/_api/contextinfo', {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Accept': 'application/json;odata=verbose',
      'Content-Type': 'application/json;odata=verbose'
    }
  })
  .then(function (r) {
    if (!r.ok) throw new Error('contextinfo HTTP ' + r.status);
    return r.json();
  })
  .then(function (d) {
    return d.d.GetContextWebInformation.FormDigestValue;
  });
}

/* ── Upload ──────────────────────────────────────────────────────────────── */
function runTest() {
  document.getElementById('btn-run').disabled = true;
  document.getElementById('btn-cleanup').disabled = true;
  document.getElementById('log').innerHTML = '';
  uploadedFileUrl = null;

  var filename = (document.getElementById('filename').value || 'sp-upload-test-canary.txt').trim();
  var content  = 'SharePoint upload test\nFile: ' + filename + '\nTime: ' + new Date().toISOString() +
                 '\nSite: ' + SITE_URL + '\nPage: ' + PAGE_PATH;
  var bytes    = new TextEncoder().encode(content);

  log('target site', SITE_URL, 'info');
  log('target folder', PAGE_FOLDER, 'info');
  log('filename', filename, 'info');
  log('payload size', bytes.length + ' bytes', 'info');

  /* Step 1 — digest */
  log('step 1 — get digest', 'requesting…', 'info');
  getDigest()
    .then(function (digest) {
      log('digest', digest.substring(0, 28) + '…', 'pass');

      /* Step 2 — upload */
      log('step 2 — upload file', 'posting…', 'info');
      var uploadUrl = SITE_URL +
        '/_api/web/getfolderbyserverrelativeurl(\'' + spPath(PAGE_FOLDER) + '\')' +
        '/files/add(url=\'' + spPath(filename) + '\',overwrite=true)';

      return fetch(uploadUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'X-RequestDigest': digest,
          'Accept': 'application/json;odata=verbose'
        },
        body: bytes.buffer
      });
    })
    .then(function (r) {
      log('upload HTTP', r.status + ' ' + r.statusText, r.ok ? 'pass' : 'fail');
      if (!r.ok) throw new Error('Upload failed: HTTP ' + r.status);
      return r.json();
    })
    .then(function (d) {
      var serverUrl = d.d.ServerRelativeUrl;
      uploadedFileUrl = serverUrl;
      log('server relative URL', serverUrl, 'pass');

      /* Step 3 — read back */
      log('step 3 — read back', 'verifying…', 'info');
      var readUrl = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
        spPath(serverUrl) + '\')/$value';
      return fetch(readUrl, {
        credentials: 'same-origin',
        headers: { 'Accept': 'text/plain' }
      });
    })
    .then(function (r) {
      log('read-back HTTP', r.status + ' ' + r.statusText, r.ok ? 'pass' : 'fail');
      if (!r.ok) throw new Error('Read-back failed: HTTP ' + r.status);
      return r.text();
    })
    .then(function (text) {
      log('read-back size', text.length + ' bytes', text.length > 0 ? 'pass' : 'fail');
      log('content match', text.indexOf('SharePoint upload test') !== -1 ? 'verified' : 'MISMATCH',
          text.indexOf('SharePoint upload test') !== -1 ? 'pass' : 'fail');
      log('— upload test complete —', 'all steps passed', 'pass');
      document.getElementById('btn-cleanup').disabled = false;
    })
    .catch(function (err) {
      log('error', err.message, 'fail');
    })
    .finally(function () {
      document.getElementById('btn-run').disabled = false;
    });
}

/* ── Delete test file ────────────────────────────────────────────────────── */
function cleanup() {
  if (!uploadedFileUrl) { log('cleanup', 'no file to delete', 'warn'); return; }
  document.getElementById('btn-cleanup').disabled = true;

  var target = uploadedFileUrl;
  log('cleanup — deleting', target, 'info');

  getDigest()
    .then(function (digest) {
      return fetch(SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' + spPath(target) + '\')', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'X-RequestDigest': digest,
          'X-HTTP-Method': 'DELETE',
          'Accept': 'application/json;odata=verbose'
        }
      });
    })
    .then(function (r) {
      log('delete HTTP', r.status + ' ' + r.statusText, r.ok ? 'pass' : 'fail');
      if (r.ok) { uploadedFileUrl = null; log('cleanup complete', 'file deleted', 'pass'); }
    })
    .catch(function (err) {
      log('cleanup error', err.message, 'fail');
      document.getElementById('btn-cleanup').disabled = false;
    });
}

document.getElementById('btn-run').addEventListener('click', runTest);
document.getElementById('btn-cleanup').addEventListener('click', cleanup);

}());
</script>
</body>
</html>
