<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>EUDA Worker Status</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --blue:    #0078d4;
  --green:   #107c10;
  --red:     #d13438;
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

.body {
  max-width: 980px;
  margin: 0 auto;
  padding: 36px 24px 80px;
}

.intro {
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 4px solid var(--blue);
  border-radius: 4px;
  padding: 14px 18px;
  margin-bottom: 28px;
  font-size: 13px;
  color: var(--mid);
  line-height: 1.5;
}
.intro strong { color: var(--text); }

.section-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .07em;
  color: var(--mid);
  margin-bottom: 8px;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  margin-bottom: 24px;
  overflow: hidden;
}
.card-empty { padding: 16px; color: var(--mid); font-size: 13px; }

/* Metric tiles */
.metrics { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; }
.metric {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 14px 16px;
}
.metric-label { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: var(--mid); }
.metric-value { font-size: 24px; font-weight: 600; margin-top: 4px; }
.metric-value small { font-size: 13px; font-weight: 400; color: var(--mid); }

/* Data tables */
table.data { width: 100%; border-collapse: collapse; font-size: 13px; }
table.data th {
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: var(--mid);
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  background: #faf9f8;
}
table.data td {
  padding: 9px 14px;
  border-bottom: 1px solid var(--border);
  color: var(--text);
  vertical-align: top;
  word-break: break-word;
}
table.data tr:last-child td { border-bottom: none; }
td.dim { color: var(--mid); }

.pill {
  display: inline-block;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 10px;
  white-space: nowrap;
}
.pill-ok   { background: #dff6dd; color: var(--green); }
.pill-warn { background: #fff4ce; color: #7a5c00; }
.pill-err  { background: #fde7e9; color: var(--red); }
.pill-info { background: #f3f2f1; color: var(--mid); }
.pill-run  { background: #e0ecff; color: #004e8c; }

/* Worker chips */
.chips { padding: 12px 14px; display: flex; flex-wrap: wrap; gap: 8px; }
.chip {
  background: #e0ecff;
  color: #004e8c;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  padding: 4px 12px;
}

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
  <span class="header-sub">/ Worker Status</span>
</div>

<div class="body">

  <div class="intro">
    <strong>Server automation with no server.</strong> Colleagues who keep the EUDA Worker app
    open form a worker pool: scheduled jobs live in the <strong>EUDA Schedules</strong> list, and
    when a job comes due, every open worker races to claim it &mdash; SharePoint lets exactly one
    win, so each run happens on exactly one machine. This page is the read-only window into that
    coordination: the schedules, who is winning the runs, and the run history. It refreshes
    automatically every 30 seconds.
  </div>

  <div class="metrics">
    <div class="metric"><div class="metric-label">Active schedules</div><div class="metric-value" id="m-schedules">&mdash;</div></div>
    <div class="metric"><div class="metric-label">Next run</div><div class="metric-value" id="m-next">&mdash;</div></div>
    <div class="metric"><div class="metric-label">Runs (24 h)</div><div class="metric-value" id="m-runs">&mdash;</div></div>
    <div class="metric"><div class="metric-label">Machines running jobs (24 h)</div><div class="metric-value" id="m-workers">&mdash;</div></div>
  </div>

  <div class="section-label">Latest output (euda-worker_data/latest.json)</div>
  <div class="card"><div class="card-empty" id="latest-card">Loading&hellip;</div></div>

  <div class="section-label">Workers seen in the last 24 hours</div>
  <div class="card"><div class="chips" id="worker-chips"><span class="card-empty">Loading&hellip;</span></div></div>

  <div class="section-label">Schedules</div>
  <div class="card" id="schedules-card"><div class="card-empty">Loading&hellip;</div></div>

  <div class="section-label">Recent runs</div>
  <div class="card" id="runs-card"><div class="card-empty">Loading&hellip;</div></div>

  <div class="footer" id="footer">Loading&hellip;</div>

</div>

<script>
(function () {
'use strict';

var SCHEDULES_LIST = 'EUDA Schedules';
var JOBRUNS_LIST   = 'EUDA JobRuns';
var REFRESH_MS     = 30000;

function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}
var SITE_URL = deriveSiteUrl();

function getItems(list, query) {
  var url = SITE_URL + "/_api/web/lists/getbytitle('" + encodeURIComponent(list) + "')/items" + (query || '');
  return fetch(url, {
    credentials: 'same-origin',
    cache: 'no-store',
    headers: { 'Accept': 'application/json;odata=verbose' }
  }).then(function (r) {
    if (r.status === 404) return null;            /* list not provisioned yet */
    if (!r.ok) return Promise.reject('HTTP ' + r.status);
    return r.json().then(function (d) { return d.d.results; });
  });
}

function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
  });
}

function fmtDt(isoStr) {
  if (!isoStr) return '—';
  var d = new Date(isoStr);
  return isNaN(d) ? esc(isoStr) : d.toLocaleString();
}

function age(isoStr) {
  var ms = Date.now() - new Date(isoStr).getTime();
  if (isNaN(ms)) return '';
  var min = Math.round(ms / 60000);
  if (min < 1)  return 'just now';
  if (min < 60) return min + ' min ago';
  var h = Math.round(min / 60);
  return h < 48 ? h + ' h ago' : Math.round(h / 24) + ' d ago';
}

function machineOf(runBy) {
  var m = String(runBy || '').match(/via\s+(\S+)/);
  return m ? m[1] : (runBy || '').slice(0, 40);
}

function notProvisioned(cardId) {
  document.getElementById(cardId).innerHTML =
    '<div class="card-empty">The coordination lists don&rsquo;t exist yet &mdash; ' +
    'open the EUDA Worker app once to create them.</div>';
}

function renderSchedules(items) {
  var card = document.getElementById('schedules-card');
  if (items === null) return notProvisioned('schedules-card');
  if (!items.length) {
    card.innerHTML = '<div class="card-empty">No schedules defined yet.</div>';
    return;
  }
  var now = Date.now();
  var html = '<table class="data"><tr><th>Schedule</th><th>Job type</th><th>Every</th>' +
             '<th>Next due</th><th>State</th><th>Last claimed by</th></tr>';
  items.forEach(function (it) {
    var due = it.NextRunDue ? new Date(it.NextRunDue).getTime() : null;
    var pill;
    if (!it.Enabled)                 pill = '<span class="pill pill-info">Disabled</span>';
    else if (due && due <= now)      pill = '<span class="pill pill-err">Due now</span>';
    else if (due && due - now < 5 * 60000) pill = '<span class="pill pill-warn">Due soon</span>';
    else                             pill = '<span class="pill pill-ok">Scheduled</span>';
    html += '<tr><td>' + esc(it.Title) + '</td><td>' + esc(it.JobType) + '</td>' +
      '<td class="dim">' + esc(it.IntervalMinutes ? it.IntervalMinutes + ' min' : '—') + '</td>' +
      '<td class="dim">' + fmtDt(it.NextRunDue) + '</td>' +
      '<td>' + pill + '</td>' +
      '<td class="dim">' + esc(it.ClaimedBy || '—') + '</td></tr>';
  });
  card.innerHTML = html + '</table>';
}

function renderRuns(items) {
  var card = document.getElementById('runs-card');
  if (items === null) return notProvisioned('runs-card');
  if (!items.length) {
    card.innerHTML = '<div class="card-empty">No runs logged yet.</div>';
    return;
  }
  var pills = {
    Succeeded: '<span class="pill pill-ok">Succeeded</span>',
    Failed:    '<span class="pill pill-err">Failed</span>',
    Running:   '<span class="pill pill-run">Running</span>'
  };
  var html = '<table class="data"><tr><th>Job</th><th>Status</th><th>Run by</th>' +
             '<th>Started</th><th>Duration</th><th>Output / error</th></tr>';
  items.slice(0, 15).forEach(function (r) {
    var detail = r.JobStatus === 'Failed' ? (r.ErrorText || '') : (r.Output || '');
    html += '<tr><td>' + esc(r.JobTitle) + '<br><span class="dim" style="font-size:11px">' + esc(r.Title) + '</span></td>' +
      '<td>' + (pills[r.JobStatus] || esc(r.JobStatus)) + '</td>' +
      '<td class="dim">' + esc(r.RunBy || '—') + '</td>' +
      '<td class="dim">' + fmtDt(r.StartedUtc) + '<br><span style="font-size:11px">' + age(r.StartedUtc) + '</span></td>' +
      '<td class="dim">' + (r.DurationMs ? (r.DurationMs / 1000).toFixed(1) + ' s' : '—') + '</td>' +
      '<td class="dim">' + esc(String(detail).slice(0, 160)) + '</td></tr>';
  });
  card.innerHTML = html + '</table>';
}

function renderMetricsAndChips(schedules, runs) {
  var dayAgo = Date.now() - 24 * 3600 * 1000;
  var recent = (runs || []).filter(function (r) {
    return r.StartedUtc && new Date(r.StartedUtc).getTime() > dayAgo;
  });
  var ok = 0, fail = 0, machines = {};
  recent.forEach(function (r) {
    if (r.JobStatus === 'Succeeded') ok++;
    if (r.JobStatus === 'Failed') fail++;
    machines[machineOf(r.RunBy)] = true;
  });
  var names = Object.keys(machines).filter(Boolean);

  var active = (schedules || []).filter(function (s) { return s.Enabled; });
  document.getElementById('m-schedules').textContent = schedules === null ? '—' : active.length;
  document.getElementById('m-runs').innerHTML = runs === null ? '&mdash;'
    : ok + ' <small>ok</small> / ' + fail + ' <small>failed</small>';
  document.getElementById('m-workers').textContent = runs === null ? '—' : names.length;

  var nextDue = null;
  active.forEach(function (s) {
    var t = s.NextRunDue ? new Date(s.NextRunDue).getTime() : null;
    if (t && (nextDue === null || t < nextDue)) nextDue = t;
  });
  var nextEl = document.getElementById('m-next');
  if (nextDue === null) nextEl.textContent = '—';
  else if (nextDue <= Date.now()) nextEl.innerHTML = 'now <small>(waiting for a worker)</small>';
  else nextEl.innerHTML = Math.max(1, Math.round((nextDue - Date.now()) / 60000)) + ' <small>min</small>';

  var chips = document.getElementById('worker-chips');
  if (runs === null) {
    chips.innerHTML = '<span class="card-empty">Lists not provisioned yet.</span>';
  } else if (!names.length) {
    chips.innerHTML = '<span class="card-empty">No machines have run a job in the last 24 hours — ' +
      'is anyone in the pool? Open the EUDA Worker app to join.</span>';
  } else {
    chips.innerHTML = names.map(function (n) { return '<span class="chip">&#128225; ' + esc(n) + '</span>'; }).join('');
  }
}

function loadLatest() {
  var onSP = window.location.hostname.indexOf('sharepoint.com') !== -1;
  var url = onSP
    ? SITE_URL + "/_api/web/getfilebyserverrelativeurl('" +
      decodeURIComponent(window.location.pathname).replace(/\/[^\/]+$/, '') +
      "/euda-worker_data/latest.json')/$value"
    : 'euda-worker_data/latest.json';
  var el = document.getElementById('latest-card');
  fetch(url, { credentials: 'same-origin', cache: 'no-store', headers: { 'Accept': 'text/plain' } })
    .then(function (r) { return r.ok ? r.text() : Promise.reject('HTTP ' + r.status); })
    .then(function (text) {
      var d = JSON.parse(text);
      el.innerHTML = '<strong>' + esc(d.summary || '(no summary)') + '</strong><br>' +
        '<span style="color:var(--mid)">Written ' + fmtDt(d.updatedAt) + ' (' + age(d.updatedAt) + ') by ' +
        esc(d.runBy || d.source || 'unknown') + '</span> ' +
        '<span class="pill ' + (d.source === 'worker' ? 'pill-run' : 'pill-info') + '">' +
        esc(d.source || '?') + '</span>';
    })
    .catch(function (e) {
      el.textContent = 'No output file yet (' + e + ') — a worker will create it on the first demo run.';
    });
}

function load() {
  loadLatest();
  Promise.all([
    getItems(SCHEDULES_LIST, '?$top=50&$orderby=Title'),
    getItems(JOBRUNS_LIST, '?$top=200&$orderby=Id desc')
  ])
  .then(function (res) {
    renderSchedules(res[0]);
    renderRuns(res[1] || []);
    renderMetricsAndChips(res[0], res[1]);
    document.getElementById('footer').textContent =
      'Auto-refreshes every 30 s · last refreshed ' + new Date().toLocaleTimeString();
  })
  .catch(function (e) {
    document.getElementById('footer').textContent = 'Could not load status: ' + e +
      (window.location.hostname.indexOf('sharepoint.com') === -1 ? ' (expected — not running on SharePoint)' : '');
  });
}

load();
setInterval(load, REFRESH_MS);

}());
</script>
</body>
</html>
