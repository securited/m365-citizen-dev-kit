/*
 * dashboard.js — identity resolution and the Microsoft Graph profile card.
 *
 * A feature module: listed in manifest.json, loaded at runtime by app.js.
 * Adding or removing it never touches the shell.
 */
(function (APP) {
'use strict';

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
APP.loadDashboard = function () {
  APP.clearError('dash-error');
  var ctx = (typeof _spPageContextInfo !== 'undefined') ? _spPageContextInfo : null;

  var nameEl   = document.getElementById('user-name');
  var greeting = document.getElementById('greeting-text');
  var dUser    = document.getElementById('dash-user');
  var dLogin   = document.getElementById('dash-login');
  var dSite    = document.getElementById('dash-site');

  if (dSite) dSite.textContent = APP.SITE_URL;

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
    APP.spFetch(APP.SITE_URL + '/_api/web/currentUser?$select=Title,LoginName')
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
  APP.spFetch(APP.SITE_URL + '/_api/web/lists/getbytitle(\'' + APP.LIST_NAME + '\')' +
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
};

})(window.APP);
