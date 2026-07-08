<%@ Page Language="C#" %><!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>SP Load Test</title>
<style>
  body { font-family: monospace; padding: 24px; background: #111; color: #ccc; margin: 0; }
  h2 { color: #fff; font-size: 1.1rem; margin: 0 0 16px; }
  .row { margin: 5px 0; font-size: 0.875rem; display: flex; gap: 8px; }
  .label { color: #555; min-width: 200px; flex-shrink: 0; }
  .pass { color: #4c4; }
  .fail { color: #f55; }
  .info { color: #aaa; }
</style>
</head>
<body>
<h2>SharePoint Load Test</h2>
<div id="results"></div>

<script>
(function () {
  var out = document.getElementById('results');

  function row(label, value, ok) {
    var d = document.createElement('div');
    d.className = 'row';
    var cls = ok === true ? 'pass' : ok === false ? 'fail' : 'info';
    d.innerHTML = '<span class="label">' + label + ':</span> <span class="' + cls + '">' + value + '</span>';
    out.appendChild(d);
  }

  function deriveSiteUrl() {
    if (typeof _spPageContextInfo !== 'undefined' && _spPageContextInfo.webAbsoluteUrl) {
      return _spPageContextInfo.webAbsoluteUrl.replace(/\/$/, '');
    }
    var m = window.location.pathname.match(/^(\/sites\/[^\/]+)/);
    return m ? window.location.origin + m[1] : window.location.origin;
  }

  var siteUrl = deriveSiteUrl();

  // 1. Context
  var spCtx = typeof _spPageContextInfo !== 'undefined';
  row('_spPageContextInfo', spCtx ? 'present' : 'absent (document library mode)', null);
  row('derived site URL', siteUrl, !!siteUrl);

  // 2. Current user
  fetch(siteUrl + '/_api/web/currentUser?$select=Title,LoginName', {
    headers: { 'Accept': 'application/json;odata=verbose' },
    credentials: 'same-origin'
  })
  .then(function (r) {
    row('currentUser HTTP', r.status, r.ok);
    return r.ok ? r.json() : null;
  })
  .then(function (d) {
    if (d && d.d) {
      row('user display name', d.d.Title, true);
      row('user login', d.d.LoginName, true);
    }
  })
  .catch(function (e) { row('currentUser', e.message, false); });

  // 4. Contextinfo / digest
  fetch(siteUrl + '/_api/contextinfo', {
    method: 'POST',
    headers: {
      'Accept': 'application/json;odata=verbose',
      'Content-Type': 'application/json;odata=verbose'
    },
    credentials: 'same-origin'
  })
  .then(function (r) {
    row('contextinfo HTTP', r.status, r.ok);
    return r.ok ? r.json() : null;
  })
  .then(function (d) {
    if (d && d.d && d.d.GetContextWebInformation) {
      var digest = d.d.GetContextWebInformation.FormDigestValue;
      row('form digest', digest ? digest.substring(0, 24) + '…' : 'empty', !!digest);
    }
  })
  .catch(function (e) { row('contextinfo', e.message, false); });

})();
</script>
</body>
</html>
