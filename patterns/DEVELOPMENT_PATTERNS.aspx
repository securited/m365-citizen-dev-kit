<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Development Patterns | End-User Developed Applications</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --blue:     #0078d4;
  --blue-lt:  #deecf9;
  --bg:       #f3f2f1;
  --surface:  #ffffff;
  --border:   #e1dfdd;
  --text:     #323130;
  --text-mid: #605e5c;
  --nav-h:    48px;
  --max-w:    900px;
}

body {
  font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
  font-size: 14px;
  color: var(--text);
  background: var(--bg);
  line-height: 1.6;
}

/* ── Loading ── */
#app-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  gap: 16px;
  color: var(--text-mid);
}
.sp-spinner {
  width: 36px; height: 36px;
  border: 3px solid var(--border);
  border-top-color: var(--blue);
  border-radius: 50%;
  animation: spin .8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* ── Layout ── */
#app-container { display: none; }

.guide-header {
  position: sticky;
  top: 0;
  z-index: 100;
  height: var(--nav-h);
  background: var(--blue);
  color: #fff;
  display: flex;
  align-items: center;
  padding: 0 24px;
  gap: 8px;
  box-shadow: 0 2px 6px rgba(0,0,0,.2);
}
.guide-brand {
  font-size: 16px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}
.guide-subtitle {
  font-size: 13px;
  opacity: .7;
}

.page-body {
  max-width: var(--max-w);
  margin: 0 auto;
  padding: 40px 24px 80px;
}

/* ── Page heading ── */
.page-heading {
  margin-bottom: 32px;
}
.page-heading h1 {
  font-size: 26px;
  font-weight: 700;
  margin-bottom: 6px;
}
.page-heading p {
  font-size: 14px;
  color: var(--text-mid);
  max-width: 600px;
}

/* ── Pattern cards ── */
.pattern-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 14px;
  margin-bottom: 48px;
}
.pattern-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 20px;
  text-decoration: none;
  color: inherit;
  display: flex;
  flex-direction: column;
  gap: 8px;
  transition: box-shadow .15s, border-color .15s;
  position: relative;
}
.pattern-card:not(.pattern-card--disabled):hover {
  box-shadow: 0 2px 10px rgba(0,0,0,.1);
  border-color: var(--blue);
  text-decoration: none;
}
.pattern-card--disabled {
  opacity: .65;
  cursor: default;
}
.pattern-card-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--blue);
  display: flex;
  align-items: center;
  gap: 8px;
}
.pattern-card--disabled .pattern-card-title {
  color: var(--text);
}
.coming-soon-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  background: #edebe9;
  color: var(--text-mid);
  padding: 2px 7px;
  border-radius: 10px;
}
.version-chip {
  font-size: 10px;
  font-weight: 600;
  background: var(--blue);
  color: #fff;
  padding: 2px 7px;
  border-radius: 10px;
}
.pattern-card-desc {
  font-size: 13px;
  color: var(--text-mid);
  line-height: 1.5;
  flex: 1;
}
.supporting-note {
  font-size: 13px;
  color: var(--text-mid);
  line-height: 1.5;
  margin: -8px 0 14px;
}

/* ── Comparison table ── */
.section-heading {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .07em;
  color: var(--text-mid);
  margin-bottom: 12px;
}
.compare-wrap {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 6px;
  overflow: hidden;
}
.compare-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.compare-table th {
  background: #faf9f8;
  font-weight: 600;
  text-align: left;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}
.compare-table th:first-child {
  color: var(--text-mid);
  font-weight: 400;
  width: 160px;
}
.compare-table td {
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  vertical-align: top;
  color: var(--text-mid);
}
.compare-table td:first-child {
  font-weight: 600;
  color: var(--text);
  white-space: nowrap;
}
.compare-table tr:last-child td { border-bottom: none; }
.compare-table tr:nth-child(even) td { background: #faf9f8; }
.compare-table .col-soon { opacity: .55; font-style: italic; }
</style>
</head>
<body>

<div id="app-loading">
  <div class="sp-spinner"></div>
  <p>Loading<span id="load-dots"></span></p>
</div>

<div id="app-container">
  <header class="guide-header">
    <div class="guide-brand">
      <span>&#9671;</span>
      <span>End-User Developed Applications</span>
    </div>
    <span class="guide-subtitle">/ Development Patterns</span>
  </header>

  <div class="page-body">

    <div class="page-heading">
      <h1>Development Patterns</h1>
      <p>A collection of reusable patterns for building applications without traditional infrastructure. Each pattern is designed to be self-contained, low-overhead, and deployable by a single developer.</p>
    </div>

    <div class="section-heading">Patterns</div>
    <div id="pattern-cards" class="pattern-cards"></div>

    <div id="supporting-section" style="display:none">
      <div class="section-heading">Supporting Patterns</div>
      <p class="supporting-note">Not app shapes &mdash; cross-cutting guides that apply on top of the pattern you chose above.</p>
      <div id="supporting-cards" class="pattern-cards"></div>
    </div>

    <div class="section-heading">Pattern Comparison</div>
    <div class="compare-wrap">
      <table class="compare-table">
        <thead>
          <tr>
            <th></th>
            <th>SharePoint App</th>
            <th>Claude Artifact</th>
            <th>Packaged Python</th>
            <th>Worker Pool</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Runs on</td>
            <td>SharePoint Online &mdash; any browser, any device</td>
            <td>claude.ai &mdash; any browser</td>
            <td>Local machine</td>
            <td>Participants' machines, coordinated via SharePoint</td>
          </tr>
          <tr>
            <td>Audience</td>
            <td>Anyone in the M365 tenant</td>
            <td>Anyone with a Claude account</td>
            <td>Individuals who run the package</td>
            <td>A team that shares scheduled automation</td>
          </tr>
          <tr>
            <td>Authentication</td>
            <td>Automatic &mdash; M365 session, no login screen</td>
            <td>Claude account login</td>
            <td>Inherited from local machine</td>
            <td>Each participant's own Entra sign-in</td>
          </tr>
          <tr>
            <td>Data storage</td>
            <td>SharePoint Lists and document library files</td>
            <td>Embedded in the artifact &mdash; no persistence</td>
            <td>Local files, APIs, databases</td>
            <td>SharePoint Lists (schedules + run audit), outputs to SharePoint</td>
          </tr>
          <tr>
            <td>Internet required</td>
            <td>Yes</td>
            <td>Yes</td>
            <td>Optional</td>
            <td>Yes</td>
          </tr>
          <tr>
            <td>Operating cost</td>
            <td>M365 subscription (existing)</td>
            <td>Claude subscription (existing)</td>
            <td>None</td>
            <td>None</td>
          </tr>
          <tr>
            <td>Distribution</td>
            <td>SharePoint URL &mdash; no install</td>
            <td>Artifact link &mdash; no install</td>
            <td>Easy sharing with uv scripts</td>
            <td>Copy the worker folder; status page is a SharePoint URL</td>
          </tr>
          <tr>
            <td>Best for</td>
            <td>Team tools, forms, dashboards, shared data</td>
            <td>Prototypes, one-off tools, visualizations</td>
            <td>Automation, data processing, local integrations</td>
            <td>Scheduled / background automation with no server</td>
          </tr>
        </tbody>
      </table>
    </div>

  </div>
</div>

<script>
(function () {
'use strict';

function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

var SITE_URL    = deriveSiteUrl();
var PAGE_DIR    = decodeURIComponent(window.location.pathname).replace(/\/[^\/]+$/, '');
var DATA_FOLDER = PAGE_DIR + '/DEVELOPMENT_PATTERNS_data';

function fetchAsset(filename) {
  var apiUrl = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
    (DATA_FOLDER + '/' + filename).replace(/'/g, "''") + '\')/$value';
  return fetch(apiUrl, { credentials: 'same-origin', headers: { 'Accept': 'text/plain' } })
    .then(function (r) {
      if (r.ok) return r.text();
      return fetch('./DEVELOPMENT_PATTERNS_data/' + filename).then(function (r2) { return r2.text(); });
    })
    .catch(function () {
      return fetch('./DEVELOPMENT_PATTERNS_data/' + filename).then(function (r2) { return r2.text(); });
    });
}

/* Guide URLs relative to this page */
var GUIDE_URLS = {
  'sharepoint-app':   'SHAREPOINT_APP_PATTERN.aspx',
  'claude-artifacts': 'CLAUDE_ARTIFACTS_PATTERN.aspx',
  'packaged-python':  'PACKAGED_PYTHON_PATTERN.aspx',
  'worker-pool':      'WORKER_POOL_PATTERN.aspx',

  /* Supporting patterns (kind: 'supporting' in versions.json) */
  'sharepoint-permissions': 'SHAREPOINT_PERMISSIONS_PATTERN.aspx',
  'storage-lifecycle':      'SHAREPOINT_STORAGE_LIFECYCLE_PATTERN.aspx'
};

function boot() {
  var dotsEl    = document.getElementById('load-dots');
  var dotsTimer = setInterval(function () {
    if (dotsEl) dotsEl.textContent = dotsEl.textContent.length < 3 ? dotsEl.textContent + '.' : '';
  }, 400);

  fetchAsset('versions.json')
    .then(function (text) {
      clearInterval(dotsTimer);
      var patterns = JSON.parse(text);
      var container  = document.getElementById('pattern-cards');
      var supporting = document.getElementById('supporting-cards');

      patterns.forEach(function (p) {
        var isSoon = p.status === 'coming-soon';
        var url    = GUIDE_URLS[p.id];

        var el = document.createElement(url ? 'a' : 'div');
        el.className = 'pattern-card' + (isSoon ? ' pattern-card--disabled' : '');
        if (url) {
          el.href   = url;
        }

        var badge = isSoon
          ? '<span class="coming-soon-badge">Coming Soon</span>'
          : '<span class="version-chip">v' + p.current + '</span>';

        var desc = isSoon ? p.summary : (p.versions.length > 0 ? p.versions[0].summary : '');

        el.innerHTML =
          '<div class="pattern-card-title">' + p.name + badge + '</div>' +
          '<div class="pattern-card-desc">' + desc + '</div>';

        if (p.kind === 'supporting') {
          supporting.appendChild(el);
          document.getElementById('supporting-section').style.display = 'block';
        } else {
          container.appendChild(el);
        }
      });

      document.getElementById('app-loading').style.display  = 'none';
      document.getElementById('app-container').style.display = 'block';
    })
    .catch(function (err) {
      clearInterval(dotsTimer);
      document.getElementById('app-loading').innerHTML =
        '<p style="color:#d13438;padding:24px">Failed to load: ' + err.message + '</p>';
    });
}

boot();
}());
</script>
</body>
</html>
