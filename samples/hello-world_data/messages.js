/*
 * messages.js — list CRUD: read with paging, create, edit, delete, and
 * first-run list provisioning.
 *
 * A feature module: listed in manifest.json, loaded at runtime by app.js.
 * Its runtime state stays module-local rather than on the APP surface — only
 * the functions other files call are exported.
 */
(function (APP) {
'use strict';

/* ── Module-local runtime state ──────────────────────────────────────────── */
var _pendingDeleteId = null;
var _editingId       = null;
var _nextPageToken   = null;

/* ── First-run provisioning: create the list, then its custom fields ─────── */
APP.ensureMessagesList = function () {
  var statusEl = document.getElementById('setup-status');
  var setupEl  = document.getElementById('list-setup');
  var setupBtn = document.getElementById('btn-setup-list');
  if (statusEl) { statusEl.textContent = 'Creating list…'; statusEl.classList.remove('hidden'); }
  if (setupBtn) setupBtn.disabled = true;

  APP.getDigest()
    .then(function (digest) {
      return APP.createList(digest, APP.LIST_NAME,
          'Messages list — created by hello-world.aspx')
        .then(function () {
          if (statusEl) statusEl.textContent = 'Adding fields…';
          return APP.LIST_FIELD_DEFS.reduce(function (chain, fd) {
            return chain.then(function () {
              return APP.ensureField(digest, APP.LIST_NAME, fd);
            });
          }, Promise.resolve());
        });
    })
    .then(function () {
      if (setupEl) setupEl.classList.add('hidden');
      APP.showToast('List created — ready to post messages!', 'success');
      APP.loadMessages(true);
    })
    .catch(function (err) {
      if (statusEl) statusEl.textContent = 'Failed: ' + err.message;
      if (setupBtn) setupBtn.disabled = false;
    });
};

/* ── Read list with $select, $expand, $orderby, $top, $skiptoken ─────────── */
APP.loadMessages = function (reset) {
  if (reset) _nextPageToken = null;

  var list    = document.getElementById('messages-list');
  var loading = document.getElementById('messages-loading');
  var empty   = document.getElementById('messages-empty');
  var moreBtn = document.getElementById('load-more-container');

  APP.clearError('messages-error');
  if (reset && list) list.innerHTML = '';
  if (loading) loading.classList.remove('hidden');
  if (empty)   empty.classList.add('hidden');
  if (list)    list.classList.add('hidden');
  if (moreBtn) moreBtn.classList.add('hidden');

  var base  = APP.SITE_URL + '/_api/web/lists/getbytitle(\'' + APP.LIST_NAME + '\')/items';
  var query = '?$select=Id,Title,Body,Author/Title,Author/EMail,Created' +
    '&$expand=Author' +
    '&$orderby=Created desc' +
    '&$top=' + APP.PAGE_SIZE;
  if (_nextPageToken) query += '&$skiptoken=' + encodeURIComponent(_nextPageToken);

  APP.spFetch(base + query)
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (data) {
      if (loading) loading.classList.add('hidden');
      var items = data.d.results;

      _nextPageToken = null;
      if (data.d.__next) {
        var m = data.d.__next.match(/\$skiptoken=([^&]+)/);
        if (m) _nextPageToken = decodeURIComponent(m[1]);
      }

      if (items.length === 0 && reset) {
        if (empty) empty.classList.remove('hidden');
        return;
      }
      renderMessages(items);
      if (list)    list.classList.remove('hidden');
      if (moreBtn && _nextPageToken) moreBtn.classList.remove('hidden');
    })
    .catch(function (err) {
      if (loading) loading.classList.add('hidden');
      if (err.message.indexOf('404') !== -1) {
        var setupEl = document.getElementById('list-setup');
        if (setupEl) setupEl.classList.remove('hidden');
      } else {
        APP.showError('messages-error', 'Could not load messages: ' + err.message);
      }
    });
};

/* ── Render message items — DOM methods and textContent, never innerHTML
   with user-authored content ─────────────────────────────────────────────── */
function renderMessages(items) {
  var list = document.getElementById('messages-list');
  if (!list) return;
  items.forEach(function (item) {
    var li = document.createElement('li');
    li.className = 'message-item';
    li.setAttribute('data-id', item.Id);

    var header = document.createElement('div');
    header.className = 'message-header';

    var author = document.createElement('span');
    author.className = 'message-author';
    author.textContent = (item.Author && item.Author.Title) ? item.Author.Title : 'Unknown';

    var date = document.createElement('span');
    date.className = 'message-date';
    date.textContent = item.Created ? new Date(item.Created).toLocaleString() : '';

    var titleEl = document.createElement('p');
    titleEl.className = 'message-title';
    titleEl.textContent = item.Title || '';

    var bodyEl = document.createElement('p');
    bodyEl.className = 'message-body';
    bodyEl.textContent = item.Body || '';

    var actions = document.createElement('div');
    actions.className = 'message-actions';

    var editBtn = document.createElement('button');
    editBtn.className = 'btn-link';
    editBtn.textContent = 'Edit';
    editBtn.setAttribute('data-id', item.Id);
    editBtn.setAttribute('data-title', item.Title || '');
    editBtn.setAttribute('data-body', item.Body || '');
    editBtn.addEventListener('click', function () { APP.openEditForm(this); });

    var delBtn = document.createElement('button');
    delBtn.className = 'btn-link btn-link-danger';
    delBtn.textContent = 'Delete';
    delBtn.setAttribute('data-id', item.Id);
    delBtn.addEventListener('click', function () {
      confirmDelete(this.getAttribute('data-id'));
    });

    var rawBtn = document.createElement('button');
    rawBtn.className = 'btn-link';
    rawBtn.textContent = 'View raw';
    rawBtn.addEventListener('click', (function (i) {
      return function () { APP.showOverlay(JSON.stringify(i, null, 2)); };
    })(item));

    header.appendChild(author);
    header.appendChild(date);
    actions.appendChild(editBtn);
    actions.appendChild(delBtn);
    actions.appendChild(rawBtn);
    li.appendChild(header);
    li.appendChild(titleEl);
    li.appendChild(bodyEl);
    li.appendChild(actions);
    list.appendChild(li);
  });
}

/* ── Form helpers ────────────────────────────────────────────────────────── */
APP.openNewForm = function () {
  _editingId = null;
  var ft = document.getElementById('form-title');
  var ti = document.getElementById('msg-title');
  var bi = document.getElementById('msg-body');
  if (ft) ft.textContent = 'New Message';
  if (ti) ti.value = '';
  if (bi) bi.value = '';
  APP.clearError('form-error');
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.remove('hidden');
  if (ti) ti.focus();
};

APP.openEditForm = function (btn) {
  _editingId = btn.getAttribute('data-id');
  var ft = document.getElementById('form-title');
  var ti = document.getElementById('msg-title');
  var bi = document.getElementById('msg-body');
  if (ft) ft.textContent = 'Edit Message';
  if (ti) ti.value = btn.getAttribute('data-title');
  if (bi) bi.value = btn.getAttribute('data-body');
  APP.clearError('form-error');
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.remove('hidden');
  if (ti) ti.focus();
};

APP.cancelForm = function () {
  _editingId = null;
  var fc = document.getElementById('message-form-container');
  if (fc) fc.classList.add('hidden');
};

/* ── Submit: create (POST) or update (PATCH + MERGE) ─────────────────────── */
APP.submitMessage = function () {
  var titleVal = ((document.getElementById('msg-title') || {}).value || '').trim();
  var bodyVal  = ((document.getElementById('msg-body')  || {}).value || '').trim();
  APP.clearError('form-error');

  if (!titleVal) { APP.showError('form-error', 'Title is required.'); return; }

  var isEdit = !!_editingId;
  var base   = APP.SITE_URL + '/_api/web/lists/getbytitle(\'' + APP.LIST_NAME + '\')/items';
  var url    = isEdit ? base + '(' + _editingId + ')' : base;

  APP.getDigest().then(function (digest) {
    var body = JSON.stringify({
      '__metadata': { 'type': 'SP.Data.' + APP.LIST_NAME + 'ListItem' },
      'Title': titleVal,
      'Body':  bodyVal
    });
    var extraHdrs = isEdit ? { 'IF-MATCH': '*', 'X-HTTP-Method': 'MERGE' } : {};
    return APP.spFetch(url, {
      method:  isEdit ? 'PATCH' : 'POST',
      headers: APP.writeHeaders(digest, extraHdrs),
      body:    body
    });
  }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    APP.cancelForm();
    APP.showToast(isEdit ? 'Message updated.' : 'Message posted!', 'success');
    APP.loadMessages(true);
  }).catch(function (err) {
    APP.showError('form-error', 'Save failed: ' + err.message);
  });
};

/* ── Delete: inline confirmation, then REST DELETE via X-HTTP-Method ─────── */
function confirmDelete(id) {
  _pendingDeleteId = id;
  var dc = document.getElementById('delete-confirm');
  if (dc) dc.classList.remove('hidden');
}

APP.cancelDelete = function () {
  _pendingDeleteId = null;
  var dc = document.getElementById('delete-confirm');
  if (dc) dc.classList.add('hidden');
};

APP.executeDelete = function () {
  if (!_pendingDeleteId) return;
  var id = _pendingDeleteId;
  APP.cancelDelete();
  var url = APP.SITE_URL + '/_api/web/lists/getbytitle(\'' + APP.LIST_NAME +
    '\')/items(' + id + ')';
  APP.getDigest().then(function (digest) {
    return APP.spFetch(url, {
      method:  'POST',
      headers: APP.writeHeaders(digest, { 'IF-MATCH': '*', 'X-HTTP-Method': 'DELETE' })
    });
  }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    APP.showToast('Message deleted.', 'success');
    APP.loadMessages(true);
  }).catch(function (err) {
    APP.showToast('Delete failed: ' + err.message, 'error');
  });
};

})(window.APP);
