/*
 * app.js — configuration, module loading, navigation, and init.
 *
 * The shell's asset list is fixed. This file extends the load chain at
 * runtime from manifest.json, so adding a feature module never requires
 * touching the .aspx: upload the module, add one line to manifest.json,
 * both with Contribute permission.
 */
(function (APP) {
'use strict';

/* ── Configuration ───────────────────────────────────────────────────────── */
APP.LIST_NAME = 'HelloWorldMessages';
APP.PAGE_SIZE = 10;
APP.LIST_FIELD_DEFS = [
  { '__metadata': { 'type': 'SP.FieldMultiLineText' }, 'FieldTypeKind': 3,
    'Title': 'Body', 'Required': false, 'NumberOfLines': 6, 'RichText': false }
];

/* ── Module loading ──────────────────────────────────────────────────────
 * Keep FALLBACK_MODULES in sync with manifest.json. It is the reason a
 * missing or corrupt manifest degrades instead of white-screening — a stale
 * fallback is a silent trap.
 */
var FALLBACK_MODULES = ['dashboard.js', 'messages.js', 'metrics.js'];

function loadModules() {
  return APP.fetchAsset('manifest.json')
    .then(function (text) {
      var list = JSON.parse(text).modules;
      return (list && list.length) ? list : FALLBACK_MODULES;
    })
    .catch(function () { return FALLBACK_MODULES; })
    .then(function (modules) {
      /* Fetch in parallel; inject in manifest order — later modules may
         depend on earlier ones. */
      var fetches = modules.map(function (name) { return APP.fetchAsset(name); });
      return Promise.all(fetches).then(function (sources) {
        return APP.injectScripts(sources);
      });
    });
}

/* ── Navigation: in-page view switching ─────────────────────────────────── */
APP.showView = function (view) {
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
  if (view === 'messages')  APP.loadMessages(true);
  if (view === 'dashboard') APP.loadDashboard();
  if (view === 'metrics')   APP.loadMetrics();
};

/* ── Bind DOM events after content.html is injected ─────────────────────── */
function bindEvents() {
  function on(id, ev, fn) {
    var el = document.getElementById(id);
    if (el) el.addEventListener(ev, fn);
  }
  on('btn-new-message',     'click', function () { APP.openNewForm(); });
  on('btn-submit-message',  'click', function () { APP.submitMessage(); });
  on('btn-cancel-message',  'click', function () { APP.cancelForm(); });
  on('btn-confirm-delete',  'click', function () { APP.executeDelete(); });
  on('btn-cancel-delete',   'click', function () { APP.cancelDelete(); });
  on('btn-load-more',       'click', function () { APP.loadMessages(false); });
  on('overlay-close',       'click', function () { APP.closeOverlay(); });
  on('btn-setup-list',      'click', function () { APP.ensureMessagesList(); });
  on('btn-refresh-metrics', 'click', function () { APP.loadMetrics(); });

  document.querySelectorAll('.nav-item').forEach(function (btn) {
    btn.addEventListener('click', function () {
      APP.showView(this.getAttribute('data-view'));
    });
  });
}

/* ── Initialize — modules are loaded and content.html is in the DOM ─────── */
function init() {
  bindEvents();
  /* showView('dashboard') calls loadDashboard() itself — calling both would
     fire the identity and item-count requests twice on every boot. */
  APP.showView('dashboard');
}

/* ── Boot the app: modules first, then init, then reveal ─────────────────── */
loadModules()
  .then(function () {
    init();
    APP.reveal();
  })
  .catch(function (err) {
    APP.bootError('Failed to load application: ' + err.message);
  });

})(window.APP);
