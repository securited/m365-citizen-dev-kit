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
/*
 * Boot-only shell — SharePoint App Pattern v1.4.
 *
 * This file contains asset loading, the canonical helpers its assets build
 * on, the loading/error UI, and the hand-off to app.js. It holds NO feature
 * code and NO application state — those live in hello-world_data/, which can
 * be updated with Contribute permission, while changing this file needs a
 * custom-script window plus Design or Full Control.
 *
 * The asset list in boot() is FIXED. New JavaScript modules are added by
 * listing them in hello-world_data/manifest.json — never by editing this file.
 */
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

/* ── Run fetched JavaScript, in order ─────────────────────────────────────
 * Wraps each source in a Blob and appends it as a <script>. No eval(), no
 * CDN. app.js reuses this to load the modules named in manifest.json.
 * async = false is load-bearing: dynamically created scripts are async by
 * default and would otherwise execute in completion order, not list order.
 */
function injectScripts(sources) {
  return new Promise(function (resolve, reject) {
    var last = null;
    sources.forEach(function (src) {
      var url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
      var el  = document.createElement('script');
      el.src     = url;
      el.async   = false;
      el.onerror = function () { reject(new Error('script load failed')); };
      document.head.appendChild(el);
      last = el;
    });
    if (last) { last.onload = resolve; } else { resolve(); }
  });
}

/* ── Loading / error UI ──────────────────────────────────────────────────── */
var _dotsAnim = null;

function startDots() {
  var loadDots = document.getElementById('load-dots');
  _dotsAnim = setInterval(function () {
    if (loadDots) {
      var d = loadDots.textContent.length;
      loadDots.textContent = d < 3 ? loadDots.textContent + '.' : '';
    }
  }, 400);
}

function reveal() {
  if (_dotsAnim) { clearInterval(_dotsAnim); _dotsAnim = null; }
  var loadingEl = document.getElementById('app-loading');
  var container = document.getElementById('app-container');
  if (loadingEl) loadingEl.style.display = 'none';
  if (container) container.style.display = 'block';
}

function bootError(message) {
  if (_dotsAnim) { clearInterval(_dotsAnim); _dotsAnim = null; }
  var loadingEl = document.getElementById('app-loading');
  if (loadingEl) {
    var p = document.createElement('p');
    p.style.color = '#d13438';
    p.textContent = message;
    loadingEl.appendChild(p);
  }
}

/* ── The surface platform.js, app.js and every module build on ───────────── */
window.APP = {
  SITE_URL:      SITE_URL,
  DATA_FOLDER:   DATA_FOLDER,
  spPath:        spPath,
  spFetch:       spFetch,
  fetchAsset:    fetchAsset,
  injectScripts: injectScripts,
  reveal:        reveal,
  bootError:     bootError
};

/* ── Boot: fetch the fixed asset list, inject, hand off to app.js ────────── */
function boot() {
  startDots();

  Promise.all([
    fetchAsset('styles.css'),
    fetchAsset('content.html'),
    fetchAsset('platform.js'),
    fetchAsset('app.js')
  ])
    .then(function (assets) {
      var styleEl = document.createElement('style');
      styleEl.textContent = assets[0];
      document.head.appendChild(styleEl);

      var container = document.getElementById('app-container');
      if (container) {
        container.innerHTML = assets[1]; /* Safe: our own content.html, not user input */
      }

      /* platform.js first — app.js builds on it. app.js then loads the
         modules named in manifest.json, runs init, and calls APP.reveal(). */
      return injectScripts([assets[2], assets[3]]);
    })
    .catch(function (err) {
      bootError('Failed to load application: ' + err.message);
    });
}

boot();
})();
</script>

</body>
</html>
