<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Artifacts Pattern | End-User Developed Applications</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --blue:     #0078d4;
  --bg:       #f3f2f1;
  --surface:  #ffffff;
  --border:   #e1dfdd;
  --text:     #323130;
  --text-mid: #605e5c;
  --nav-h:    48px;
  --max-w:    860px;
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
  font-size: 15px;
}
.sp-spinner {
  width: 36px; height: 36px;
  border: 3px solid #e1dfdd;
  border-top-color: var(--blue);
  border-radius: 50%;
  animation: sp-spin .8s linear infinite;
}
@keyframes sp-spin { to { transform: rotate(360deg); } }

/* ── Header ── */
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

/* ── Prompt banner ── */
.prompt-banner {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 4px solid var(--blue);
  border-radius: 6px;
  padding: 14px 18px;
  margin-bottom: 28px;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
}
.prompt-banner-text { flex: 1; min-width: 260px; }
.prompt-banner-title {
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 2px;
}
.prompt-banner-desc {
  font-size: 13px;
  color: var(--text-mid);
}
.prompt-banner-btn {
  display: inline-block;
  background: var(--blue);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  padding: 8px 16px;
  border-radius: 4px;
  text-decoration: none;
  white-space: nowrap;
  transition: background .12s;
}
.prompt-banner-btn:hover { background: #106ebe; text-decoration: none; color: #fff; }

/* ── Body ── */
.guide-body {
  max-width: var(--max-w);
  margin: 0 auto;
  padding: 40px 24px 80px;
}

/* ── Content typography ── */
.guide-content h1 {
  font-size: 28px;
  font-weight: 700;
  margin: 0 0 6px;
}
.guide-content h2 {
  font-size: 20px;
  font-weight: 600;
  margin: 44px 0 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border);
}
.guide-content h3 {
  font-size: 16px;
  font-weight: 600;
  margin: 28px 0 10px;
}
.guide-content h4 {
  font-size: 14px;
  font-weight: 600;
  margin: 20px 0 8px;
}
.guide-content p {
  margin: 0 0 14px;
}
.guide-content a {
  color: var(--blue);
  text-decoration: none;
}
.guide-content a:hover { text-decoration: underline; }

.guide-content hr {
  border: none;
  border-top: 1px solid var(--border);
  margin: 36px 0;
}

/* ── Lists ── */
.guide-content ul {
  margin: 0 0 14px 24px;
}
.guide-content li {
  margin-bottom: 5px;
}

/* ── Inline code ── */
.guide-content code {
  font-family: "Cascadia Code", "Consolas", "Courier New", monospace;
  font-size: 12px;
  background: rgba(0,0,0,.06);
  padding: 1px 5px;
  border-radius: 3px;
  color: #a31515;
}

/* ── Code blocks ── */
.guide-content pre {
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 16px 20px;
  border-radius: 4px;
  overflow-x: auto;
  margin: 0 0 16px;
  font-size: 12px;
  line-height: 1.55;
}
.guide-content pre code {
  background: none;
  color: inherit;
  padding: 0;
  border-radius: 0;
  font-size: inherit;
}

/* ── Tables ── */
.guide-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 16px;
  font-size: 13px;
}
.guide-content th {
  background: var(--bg);
  font-weight: 600;
  text-align: left;
  padding: 8px 12px;
  border: 1px solid var(--border);
}
.guide-content td {
  padding: 8px 12px;
  border: 1px solid var(--border);
  vertical-align: top;
}
.guide-content tr:nth-child(even) td { background: #faf9f8; }

/* ── Blockquote callouts ── */
.guide-content blockquote {
  background: #deecf9;
  border-left: 4px solid var(--blue);
  padding: 10px 16px;
  margin: 0 0 16px;
  border-radius: 0 4px 4px 0;
  font-size: 13px;
}

/* ── Strong ── */
.guide-content strong { font-weight: 600; }

/* ── Sample apps ── */
.samples-section {
  margin-bottom: 32px;
}
.section-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .07em;
  color: var(--text-mid);
  margin-bottom: 8px;
}
.samples-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.sample-pill {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 5px 12px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 20px;
  font-size: 13px;
  color: var(--blue);
  text-decoration: none;
  white-space: nowrap;
  transition: background .12s, border-color .12s;
}
.sample-pill:hover {
  background: #deecf9;
  border-color: var(--blue);
  text-decoration: none;
}
.sample-pill-icon {
  font-size: 11px;
  opacity: .6;
}

/* ── Pattern versions ── */
.versions-section {
  margin-top: 48px;
  padding-top: 32px;
  border-top: 1px solid var(--border);
}
.versions-section h2 {
  font-size: 20px;
  font-weight: 600;
  margin-bottom: 20px;
}
.pattern-block {
  margin-bottom: 32px;
}
.pattern-block-header {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 12px;
}
.pattern-name {
  font-size: 15px;
  font-weight: 600;
}
.version-badge {
  font-size: 11px;
  font-weight: 600;
  background: var(--blue);
  color: #fff;
  padding: 2px 8px;
  border-radius: 10px;
  letter-spacing: .03em;
}
.version-entry {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  margin-bottom: 10px;
  overflow: hidden;
}
.version-entry-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  cursor: pointer;
  user-select: none;
}
.version-entry-header:hover { background: #faf9f8; }
.version-num {
  font-size: 13px;
  font-weight: 600;
  color: var(--blue);
  min-width: 36px;
}
.version-date {
  font-size: 12px;
  color: var(--text-mid);
}
.version-summary {
  font-size: 13px;
  flex: 1;
}
.version-chevron {
  font-size: 10px;
  color: var(--text-mid);
  transition: transform .15s;
}
.version-entry.open .version-chevron { transform: rotate(90deg); }
.version-changes {
  display: none;
  padding: 0 14px 12px 52px;
}
.version-entry.open .version-changes { display: block; }
.version-changes ul {
  margin: 0;
  padding: 0 0 0 16px;
}
.version-changes li {
  font-size: 13px;
  color: var(--text-mid);
  margin-bottom: 4px;
  line-height: 1.5;
}

/* ── Error ── */
.load-error {
  color: #d13438;
  background: #fde7e9;
  border: 1px solid #f1707b;
  border-radius: 4px;
  padding: 16px 20px;
  margin: 40px auto;
  max-width: var(--max-w);
}
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
    <span class="guide-subtitle">/ Claude Artifacts Pattern</span>
  </header>
  <div class="guide-body">
    <div class="prompt-banner">
      <div class="prompt-banner-text">
        <div class="prompt-banner-title">Creating a new artifact?</div>
        <div class="prompt-banner-desc">Start with the Claude project prompt &mdash; copy it as your first message to get a portable, handoff-ready artifact that follows this pattern's conventions.</div>
      </div>
      <a class="prompt-banner-btn" href="CLAUDE_ARTIFACTS_PROMPT.md">Open the Project Prompt</a>
    </div>
    <div id="samples-section" class="samples-section" style="display:none">
      <div class="section-label">Sample Applications</div>
      <div id="samples-list" class="samples-list"></div>
    </div>
    <div id="guide-content" class="guide-content"></div>
    <div id="versions-section" class="versions-section" style="display:none">
      <h2>Pattern Versions</h2>
      <div id="versions-body"></div>
    </div>
  </div>
</div>

<script>
(function () {
'use strict';

/* ── Site URL derivation ─────────────────────────────────────────────────── */
function deriveSiteUrl() {
  if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
    return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
  }
  var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
  return m ? window.location.origin + m[1] : window.location.origin;
}

var SITE_URL   = deriveSiteUrl();
var PAGE_DIR   = decodeURIComponent(window.location.pathname).replace(/\/[^\/]+$/, '');
var MD_PATH    = PAGE_DIR + '/CLAUDE_ARTIFACTS_PATTERN.md';
var DATA_FOLDER = PAGE_DIR + '/DEVELOPMENT_PATTERNS_data';
var PATTERN_ID  = 'claude-artifacts';

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

/* ── Markdown → HTML ─────────────────────────────────────────────────────── */
function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function inline(s) {
  s = esc(s);
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return s;
}

function mdToHtml(md) {
  var lines   = md.split('\n');
  var out     = '';
  var inCode  = false;
  var inList  = false;
  var inTable = false;

  function closeBlocks() {
    if (inList)  { out += '</ul>';              inList  = false; }
    if (inTable) { out += '</tbody></table>';   inTable = false; }
  }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];

    /* Code fence */
    if (/^```/.test(line)) {
      if (!inCode) { closeBlocks(); out += '<pre><code>'; inCode = true; }
      else         { out += '</code></pre>';               inCode = false; }
      continue;
    }
    if (inCode) { out += esc(line) + '\n'; continue; }

    /* Blockquote (single-line callouts) */
    if (/^>\s?/.test(line)) {
      closeBlocks();
      out += '<blockquote>' + inline(line.replace(/^>\s?/, '')) + '</blockquote>';
      continue;
    }

    /* Horizontal rule */
    if (/^---+\s*$/.test(line)) { closeBlocks(); out += '<hr>'; continue; }

    /* Heading */
    var hm = line.match(/^(#{1,4})\s+(.*)/);
    if (hm) {
      closeBlocks();
      var lv = hm[1].length;
      out += '<h' + lv + '>' + inline(hm[2]) + '</h' + lv + '>';
      continue;
    }

    /* Table row */
    if (line.charAt(0) === '|') {
      if (/^\|[\s\-:|]+\|/.test(line)) continue; /* separator row */
      var cells = line.split('|').slice(1, -1);
      if (!inTable) {
        if (inList) { out += '</ul>'; inList = false; }
        out += '<table><thead><tr>';
        cells.forEach(function (c) { out += '<th>' + inline(c.trim()) + '</th>'; });
        out += '</tr></thead><tbody>';
        inTable = true;
        continue;
      }
      out += '<tr>';
      cells.forEach(function (c) { out += '<td>' + inline(c.trim()) + '</td>'; });
      out += '</tr>';
      continue;
    }

    /* List item */
    var lm = line.match(/^[-*]\s+(.*)/);
    if (lm) {
      if (inTable) { out += '</tbody></table>'; inTable = false; }
      if (!inList) { out += '<ul>'; inList = true; }
      out += '<li>' + inline(lm[1]) + '</li>';
      continue;
    }

    /* Blank line */
    if (!line.trim()) { closeBlocks(); continue; }

    /* Paragraph */
    closeBlocks();
    out += '<p>' + inline(line) + '</p>';
  }

  closeBlocks();
  if (inCode) out += '</code></pre>';
  return out;
}

/* ── Boot ────────────────────────────────────────────────────────────────── */
function boot() {
  var dotsEl    = document.getElementById('load-dots');
  var dotsTimer = setInterval(function () {
    if (dotsEl) {
      dotsEl.textContent = dotsEl.textContent.length < 3
        ? dotsEl.textContent + '.' : '';
    }
  }, 400);

  var apiUrl = SITE_URL + '/_api/web/getfilebyserverrelativeurl(\'' +
    MD_PATH.replace(/'/g, "''") + '\')/$value';

  fetch(apiUrl, { credentials: 'same-origin', headers: { 'Accept': 'text/plain' } })
    .then(function (r) {
      if (r.ok) return r.text();
      return fetch('./CLAUDE_ARTIFACTS_PATTERN.md').then(function (r2) { return r2.text(); });
    })
    .catch(function () {
      return fetch('./CLAUDE_ARTIFACTS_PATTERN.md').then(function (r2) { return r2.text(); });
    })
    .then(function (md) {
      clearInterval(dotsTimer);
      var el = document.getElementById('guide-content');
      if (el) el.innerHTML = mdToHtml(md); /* Safe: developer-authored content, not user input */
      document.getElementById('app-loading').style.display   = 'none';
      document.getElementById('app-container').style.display = 'block';

      /* Load sample apps */
      fetchAsset('samples.json')
        .then(function (text) {
          var all = JSON.parse(text);
          var entry = all.filter(function (g) { return g.patternId === PATTERN_ID; })[0];
          var samples = entry ? entry.samples : [];
          var list = document.getElementById('samples-list');
          samples.forEach(function (s) {
            var a = document.createElement('a');
            a.className = 'sample-pill';
            a.href = s.url;
            a.target = '_blank';
            a.rel = 'noopener noreferrer';
            a.title = s.description;
            a.innerHTML = '<span class="sample-pill-icon">&#9654;</span>' + s.title;
            list.appendChild(a);
          });
          document.getElementById('samples-section').style.display = 'block';
        })
        .catch(function () { /* optional */ });

      /* Load pattern versions */
      fetchAsset('versions.json')
        .then(function (text) {
          var patterns = JSON.parse(text);
          var body = document.getElementById('versions-body');

          /* Version badge in header — show the current version of THIS page's pattern */
          var thisPattern = patterns.filter(function (p) { return p.id === PATTERN_ID; })[0];
          if (thisPattern) {
            var badge = document.createElement('span');
            badge.className = 'version-badge';
            badge.textContent = 'v' + thisPattern.current;
            badge.style.marginLeft = '10px';
            document.querySelector('.guide-subtitle').appendChild(badge);
          }

          patterns.forEach(function (pattern) {
            var block = document.createElement('div');
            block.className = 'pattern-block';

            var header = '<div class="pattern-block-header">' +
              '<span class="pattern-name">' + pattern.name + '</span>' +
              '<span class="version-badge">v' + pattern.current + '</span>' +
              '</div>';

            var entries = pattern.versions.map(function (v) {
              var items = v.changes.map(function (c) {
                return '<li>' + c + '</li>';
              }).join('');
              return '<div class="version-entry">' +
                '<div class="version-entry-header">' +
                  '<span class="version-num">v' + v.version + '</span>' +
                  '<span class="version-date">' + v.date + '</span>' +
                  '<span class="version-summary">' + v.summary + '</span>' +
                  '<span class="version-chevron">&#9654;</span>' +
                '</div>' +
                '<div class="version-changes"><ul>' + items + '</ul></div>' +
              '</div>';
            }).join('');

            block.innerHTML = header + entries;
            body.appendChild(block);
          });

          /* Toggle expand/collapse */
          body.addEventListener('click', function (e) {
            var hdr = e.target.closest('.version-entry-header');
            if (hdr) hdr.parentElement.classList.toggle('open');
          });

          document.getElementById('versions-section').style.display = 'block';
        })
        .catch(function () { /* optional */ });
    })
    .catch(function (err) {
      clearInterval(dotsTimer);
      document.getElementById('app-loading').innerHTML =
        '<div class="load-error">Failed to load guide: ' + err.message + '</div>';
    });
}

boot();
}());
</script>
</body>
</html>
