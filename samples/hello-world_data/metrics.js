/*
 * metrics.js — renders the large JSON dataset as status cards with sparklines.
 *
 * A feature module: listed in manifest.json, loaded at runtime by app.js.
 * Demonstrates file-based data (metrics.json) as an alternative to a list
 * for read-mostly reference data.
 */
(function (APP) {
'use strict';

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

  var loadingEl = document.getElementById('metrics-loading');
  var contentEl = document.getElementById('metrics-content');
  if (loadingEl) loadingEl.classList.add('hidden');
  if (contentEl) contentEl.classList.remove('hidden');
}

APP.loadMetrics = function () {
  var loading = document.getElementById('metrics-loading');
  var content = document.getElementById('metrics-content');
  if (loading) loading.classList.remove('hidden');
  if (content) content.classList.add('hidden');
  APP.clearError('metrics-error');

  var t0 = Date.now();
  APP.fetchAsset('metrics.json')
    .then(function (text) {
      var sizeKb = Math.round(text.length / 1024);
      var data   = JSON.parse(text);
      renderMetrics(data, sizeKb, Date.now() - t0);
    })
    .catch(function (err) {
      if (loading) loading.classList.add('hidden');
      APP.showError('metrics-error', 'Could not load metrics: ' + err.message);
    });
};

})(window.APP);
