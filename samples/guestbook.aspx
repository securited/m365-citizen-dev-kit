<%@ Page Language="C#" %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Contoso — Guest Book</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@300;400;600;700&display=swap" rel="stylesheet" />
  <style>
    /* ── Design tokens (sample design system template) ───────────────── */
    :root {
      --ps-blue:        #005BA6;
      --ps-blue-hover:  #004A84;
      --ps-midnight:    #002F48;
      --ps-cyan:        #009CF4;
      --ps-airway:      #DCEAED;
      --ps-orange:      #FF9505;
      --ps-white:       #FFFFFF;
      --ps-gray-50:     #FAFAFA;
      --ps-gray-100:    #F5F5F5;
      --ps-gray-200:    #E6E6E6;
      --ps-gray-300:    #DCDCDC;
      --ps-gray-400:    #949494;
      --ps-gray-500:    #4A4A4A;
      --ps-gray-600:    #2B2B2B;
      --ps-success:     #17AB78;
      --ps-success-bg:  #E5F9F2;
      --ps-warning:     #FF9505;
      --ps-warning-bg:  #FFF4E5;
      --ps-danger:      #D14343;
      --ps-danger-bg:   #FFEBEB;
      --ps-info:        #009CF4;
      --ps-info-bg:     #D0EEFC;
      --ps-font: 'Source Sans 3', 'Source Sans Pro', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      --s-1:4px; --s-2:8px; --s-3:12px; --s-4:16px; --s-5:20px;
      --s-6:24px; --s-8:32px; --s-10:40px; --s-12:48px;
      --r-sm:4px; --r-md:6px; --r-lg:8px; --r-pill:20px; --r-full:9999px;
      --sh-sm: 0 1px 4px rgba(0,47,72,.08);
      --sh-md: 0 2px 10px rgba(0,47,72,.10);
      --sh-lg: 0 6px 20px rgba(0,47,72,.18);
      --header-h: 60px;
      --sidebar-w: 240px;
    }

    /* ── Base ───────────────────────────────────────────────── */
    *, *::before, *::after { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }
    body {
      font-family: var(--ps-font);
      font-size: 14px; line-height: 1.5;
      color: var(--ps-gray-600);
      background: var(--ps-gray-50);
      -webkit-font-smoothing: antialiased;
    }
    h1,h2,h3,h4,h5,h6 { margin: 0; font-family: inherit; line-height: 1.2; color: var(--ps-midnight); }
    h1 { font-size: 34px; font-weight: 300; letter-spacing: -.4px; }
    h3 { font-size: 24px; font-weight: 300; letter-spacing: -.2px; }
    h4 { font-size: 18px; font-weight: 600; }
    p  { margin: 0; }
    a  { color: var(--ps-blue); text-decoration: none; }
    a:hover { color: var(--ps-blue-hover); text-decoration: underline; }
    button { font-family: inherit; cursor: pointer; }

    /* ── App shell ──────────────────────────────────────────── */
    .app {
      min-height: 100vh;
      display: grid;
      grid-template-columns: var(--sidebar-w) 1fr;
      grid-template-rows: var(--header-h) 1fr auto;
      grid-template-areas:
        "header  header"
        "sidebar main"
        "footer  footer";
    }

    /* ── Header ─────────────────────────────────────────────── */
    .app-header {
      grid-area: header;
      background: var(--ps-white);
      border-bottom: 1px solid var(--ps-gray-300);
      display: flex; align-items: center; gap: var(--s-6);
      padding: 0 var(--s-6);
      position: sticky; top: 0; z-index: 20;
    }
    .brand-lockup {
      display: flex; align-items: center; gap: var(--s-3);
      text-decoration: none;
      padding-right: var(--s-4);
      border-right: 1px solid var(--ps-gray-200);
      margin-right: var(--s-2);
      flex-shrink: 0;
    }
    .brand-lockup:hover { text-decoration: none; }
    .brand-wordmark { font-size: 19px; font-weight: 700; color: var(--ps-blue); letter-spacing: -.3px; }
    .brand-divider-label { font-size: 18px; font-weight: 300; color: var(--ps-midnight); letter-spacing: .3px; }
    .header-spacer { flex: 1; }
    .user-chip {
      display: flex; align-items: center; gap: var(--s-2);
      padding: 4px 10px 4px 4px;
      border-radius: var(--r-full);
      background: transparent; border: 1px solid transparent;
      transition: all .15s ease;
    }
    .user-chip:hover { background: var(--ps-gray-100); border-color: var(--ps-gray-200); }
    .avatar {
      width: 30px; height: 30px; border-radius: var(--r-full);
      background: var(--ps-airway); color: var(--ps-midnight);
      display: inline-flex; align-items: center; justify-content: center;
      font-weight: 600; font-size: 12px; flex-shrink: 0;
    }
    .user-chip-name { font-size: 13px; font-weight: 600; color: var(--ps-midnight); }

    /* ── Sidebar ─────────────────────────────────────────────── */
    .app-sidebar {
      grid-area: sidebar;
      background: var(--ps-white);
      border-right: 1px solid var(--ps-gray-200);
      padding: var(--s-5) var(--s-3);
      display: flex; flex-direction: column; gap: var(--s-6);
      position: sticky; top: var(--header-h);
      height: calc(100vh - var(--header-h));
      overflow-y: auto;
    }
    .nav-group { display: flex; flex-direction: column; gap: 2px; }
    .nav-group-label {
      font-size: 11px; font-weight: 700; letter-spacing: 1.5px;
      text-transform: uppercase; color: var(--ps-gray-400);
      padding: 0 var(--s-3); margin-bottom: var(--s-2);
    }
    .nav-item {
      display: flex; align-items: center; gap: var(--s-3);
      padding: 9px var(--s-3); border-radius: var(--r-md);
      color: var(--ps-gray-500); font-size: 14px; font-weight: 400;
      text-decoration: none; cursor: pointer; border: none; background: none;
      width: 100%; text-align: left;
      transition: background .15s ease, color .15s ease;
      white-space: nowrap;
    }
    .nav-item:hover { background: var(--ps-gray-100); color: var(--ps-midnight); text-decoration: none; }
    .nav-item.active { background: var(--ps-airway); color: var(--ps-midnight); font-weight: 600; }
    .nav-item svg { width: 18px; height: 18px; flex-shrink: 0; }
    .nav-item-meta {
      margin-left: auto; font-size: 11px;
      background: var(--ps-blue); color: var(--ps-white);
      padding: 1px 7px; border-radius: var(--r-pill); font-weight: 600;
    }
    .sidebar-footer {
      margin-top: auto; padding: var(--s-3);
      background: var(--ps-airway); border-radius: var(--r-md);
      font-size: 13px; color: var(--ps-midnight);
    }
    .sidebar-footer-title { font-weight: 600; margin-bottom: 2px; }

    /* ── Main ───────────────────────────────────────────────── */
    .app-main { grid-area: main; padding: var(--s-8) var(--s-10); min-width: 0; }
    .page-max { max-width: 1100px; margin: 0 auto; }

    /* ── Page header ─────────────────────────────────────────── */
    .page-header {
      display: flex; align-items: flex-start; justify-content: space-between;
      gap: var(--s-6); margin-bottom: var(--s-8);
      padding-bottom: var(--s-6); border-bottom: 1px solid var(--ps-gray-200);
      flex-wrap: wrap;
    }
    .page-header > div:first-child { flex: 1 1 400px; min-width: 0; }
    .breadcrumbs {
      display: flex; align-items: center; gap: var(--s-2);
      font-size: 13px; color: var(--ps-gray-400);
      margin-bottom: var(--s-2);
    }
    .breadcrumbs .sep { color: var(--ps-gray-300); }
    .page-title { display: flex; align-items: center; gap: var(--s-3); flex-wrap: wrap; }
    .page-subtitle { color: var(--ps-gray-500); margin-top: var(--s-2); font-size: 15px; }
    .page-actions { display: flex; gap: var(--s-2); align-items: center; flex-shrink: 0; padding-top: 6px; }

    /* ── Banner ─────────────────────────────────────────────── */
    .banner {
      display: flex; align-items: flex-start; gap: var(--s-3);
      padding: var(--s-4) var(--s-5); border-radius: var(--r-sm);
      border-left: 3px solid; font-size: 14px;
      margin-bottom: var(--s-6);
    }
    .banner svg { width: 20px; height: 20px; flex-shrink: 0; margin-top: 1px; }
    .banner-title { font-weight: 600; color: var(--ps-midnight); margin-bottom: 2px; }
    .banner-info    { background: var(--ps-info-bg);    border-color: var(--ps-blue);    color: var(--ps-midnight); }
    .banner-success { background: var(--ps-success-bg); border-color: var(--ps-success); color: var(--ps-midnight); }
    .banner-warning { background: var(--ps-warning-bg); border-color: var(--ps-warning); color: var(--ps-midnight); }
    .banner-danger  { background: var(--ps-danger-bg);  border-color: var(--ps-danger);  color: var(--ps-midnight); }
    .banner.hidden  { display: none; }

    /* Setup step list inside banner */
    .setup-steps { display: flex; flex-direction: column; gap: var(--s-2); margin-top: var(--s-3); }
    .setup-step  { display: flex; align-items: center; gap: var(--s-2); font-size: 13px; }
    .step-dot {
      width: 8px; height: 8px; border-radius: var(--r-full); flex-shrink: 0;
    }
    .step-dot.pending { background: var(--ps-gray-300); }
    .step-dot.active  { background: var(--ps-blue); }
    .step-dot.done    { background: var(--ps-success); }
    .step-dot.error   { background: var(--ps-danger); }
    .step-text.pending { color: var(--ps-gray-400); }
    .step-text.active  { color: var(--ps-midnight); font-weight: 600; }
    .step-text.done    { color: var(--ps-gray-500); }

    @keyframes spin { to { transform: rotate(360deg); } }
    .spin { display: inline-block; animation: spin .7s linear infinite; }

    /* ── Card ───────────────────────────────────────────────── */
    .card {
      background: var(--ps-white);
      border: 1px solid var(--ps-gray-300);
      border-radius: var(--r-md);
      box-shadow: var(--sh-sm);
    }
    .card-header {
      padding: var(--s-5) var(--s-6);
      border-bottom: 1px solid var(--ps-gray-200);
      display: flex; align-items: center; justify-content: space-between;
      gap: var(--s-4);
    }
    .card-title { font-size: 16px; font-weight: 600; color: var(--ps-midnight); }
    .card-body  { padding: var(--s-6); }
    .card-footer {
      padding: var(--s-4) var(--s-6);
      border-top: 1px solid var(--ps-gray-200);
      background: var(--ps-gray-50);
      border-radius: 0 0 var(--r-md) var(--r-md);
      display: flex; justify-content: flex-end; align-items: center; gap: var(--s-2);
    }

    /* ── Buttons ────────────────────────────────────────────── */
    .btn {
      display: inline-flex; align-items: center; justify-content: center;
      gap: var(--s-2); height: 38px; padding: 0 var(--s-5);
      border-radius: var(--r-sm); font-size: 14px; font-weight: 600;
      border: 1px solid transparent; font-family: inherit;
      transition: background .15s ease, border-color .15s ease, color .15s ease;
      white-space: nowrap; text-decoration: none;
    }
    .btn svg { width: 16px; height: 16px; }
    .btn:active { opacity: .85; }
    .btn:disabled { opacity: .45; cursor: not-allowed; }
    .btn-primary   { background: var(--ps-blue);    color: var(--ps-white); }
    .btn-primary:hover:not(:disabled)   { background: var(--ps-blue-hover); }
    .btn-secondary { background: var(--ps-white);   color: var(--ps-blue); border-color: var(--ps-blue); }
    .btn-secondary:hover:not(:disabled) { background: var(--ps-info-bg); }
    .btn-ghost     { background: transparent; color: var(--ps-gray-500); }
    .btn-ghost:hover:not(:disabled)     { background: var(--ps-gray-100); color: var(--ps-midnight); }
    .btn-sm { height: 30px; padding: 0 var(--s-3); font-size: 13px; }

    /* ── Badges ─────────────────────────────────────────────── */
    .badge {
      display: inline-flex; align-items: center; gap: 4px;
      height: 22px; padding: 0 10px; border-radius: var(--r-pill);
      font-size: 12px; font-weight: 600; line-height: 1; white-space: nowrap;
    }
    .badge .dot { width: 6px; height: 6px; border-radius: var(--r-full); background: currentColor; }
    .badge-success { background: var(--ps-success-bg); color: var(--ps-success); }
    .badge-info    { background: var(--ps-info-bg);    color: var(--ps-blue); }
    .badge-neutral { background: var(--ps-gray-100);   color: var(--ps-gray-500); }

    /* ── Form ───────────────────────────────────────────────── */
    .form-row { display: flex; flex-direction: column; gap: 6px; margin-bottom: var(--s-4); }
    .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 var(--s-5); }
    @media (max-width: 640px) { .form-grid { grid-template-columns: 1fr; } }
    .form-grid .full { grid-column: 1 / -1; }
    .form-label { font-size: 13px; font-weight: 600; color: var(--ps-midnight); }
    .form-label .req { color: var(--ps-danger); margin-left: 2px; }
    .form-help  { font-size: 12px; color: var(--ps-gray-400); }
    .form-input, .form-textarea {
      height: 38px; padding: 0 var(--s-3);
      border: 1px solid var(--ps-gray-300); border-radius: var(--r-sm);
      background: var(--ps-white); font: inherit; color: var(--ps-gray-600);
      transition: border-color .15s ease, box-shadow .15s ease; width: 100%;
    }
    .form-textarea { height: auto; padding: var(--s-3); resize: vertical; min-height: 88px; }
    .form-input:focus, .form-textarea:focus {
      outline: 0; border-color: var(--ps-blue);
      box-shadow: 0 0 0 3px var(--ps-info-bg);
    }
    .form-input.invalid, .form-textarea.invalid { border-color: var(--ps-danger); }
    .char-count { font-size: 12px; color: var(--ps-gray-400); text-align: right; }
    .char-count.warn { color: var(--ps-warning); }
    .char-count.over { color: var(--ps-danger); }
    .form-error-msg { font-size: 13px; color: var(--ps-danger); }

    /* ── Label overline ─────────────────────────────────────── */
    .label-overline {
      font-size: 11px; font-weight: 700; letter-spacing: 1.5px;
      text-transform: uppercase; color: var(--ps-gray-400);
    }

    /* ── Entries ─────────────────────────────────────────────── */
    .entries-toolbar {
      display: flex; align-items: center; justify-content: space-between;
      gap: var(--s-4); margin-bottom: var(--s-5); flex-wrap: wrap;
    }
    .section-title { font-size: 20px; font-weight: 300; color: var(--ps-midnight); }
    .section-count { font-size: 13px; color: var(--ps-gray-400); margin-top: 2px; }
    .header-search {
      display: flex; align-items: center; gap: var(--s-2);
      height: 38px; padding: 0 var(--s-3);
      background: var(--ps-gray-100);
      border: 1px solid transparent; border-radius: var(--r-md);
      transition: all .15s ease; flex: 0 1 280px;
    }
    .header-search:focus-within {
      background: var(--ps-white); border-color: var(--ps-blue);
      box-shadow: 0 0 0 3px var(--ps-info-bg);
    }
    .header-search input {
      flex: 1; border: 0; background: transparent; outline: 0;
      font: inherit; color: var(--ps-gray-600);
    }
    .header-search input::placeholder { color: var(--ps-gray-400); }
    .header-search svg { width: 16px; height: 16px; color: var(--ps-gray-400); flex-shrink: 0; }

    /* ── Entry cards grid ───────────────────────────────────── */
    .entries-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
      gap: var(--s-4);
    }
    @media (max-width: 500px) { .entries-grid { grid-template-columns: 1fr; } }

    .entry-card {
      background: var(--ps-white);
      border: 1px solid var(--ps-gray-300);
      border-radius: var(--r-md);
      box-shadow: var(--sh-sm);
      padding: var(--s-5);
      transition: border-color .15s ease, box-shadow .15s ease;
      animation: fadeUp 220ms ease forwards;
    }
    .entry-card:hover { border-color: var(--ps-blue); box-shadow: var(--sh-md); }

    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(8px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .entry-card.new-entry { animation: highlightNew 2.5s ease forwards; }
    @keyframes highlightNew {
      0%,20% { background: var(--ps-info-bg); border-color: var(--ps-blue); }
      100%   { background: var(--ps-white);   border-color: var(--ps-gray-300); }
    }

    .entry-top {
      display: flex; align-items: flex-start; gap: var(--s-3); margin-bottom: var(--s-3);
    }
    .entry-avatar {
      width: 36px; height: 36px; border-radius: var(--r-full); flex-shrink: 0;
      display: flex; align-items: center; justify-content: center;
      font-weight: 600; font-size: 14px;
    }
    .entry-meta { flex: 1; min-width: 0; }
    .entry-name { font-weight: 600; font-size: 15px; color: var(--ps-midnight); }
    .entry-from { font-size: 12px; color: var(--ps-gray-400); margin-top: 1px; }
    .entry-date { font-size: 11px; color: var(--ps-gray-400); white-space: nowrap; }
    .entry-message {
      font-size: 14px; line-height: 1.65; color: var(--ps-gray-600);
      padding-left: 48px; white-space: pre-wrap; word-break: break-word;
    }

    /* ── Empty state ─────────────────────────────────────────── */
    .entries-empty {
      text-align: center; padding: var(--s-12) var(--s-6);
      color: var(--ps-gray-500);
    }
    .entries-empty strong { display: block; color: var(--ps-midnight); font-size: 16px; margin-bottom: var(--s-2); }

    /* ── Footer ─────────────────────────────────────────────── */
    .app-footer {
      grid-area: footer;
      background: var(--ps-midnight); color: rgba(255,255,255,.7);
      padding: var(--s-6) var(--s-10); font-size: 13px;
      display: flex; justify-content: space-between; align-items: center; gap: var(--s-6);
    }
    .app-footer a { color: var(--ps-cyan); }
    .footer-links { display: flex; gap: var(--s-6); }

    /* ── Toast ───────────────────────────────────────────────── */
    .toast {
      position: fixed; bottom: 28px; right: 28px;
      background: var(--ps-midnight); color: #fff;
      padding: var(--s-3) var(--s-5); border-radius: var(--r-md);
      font-size: 14px; font-weight: 600;
      box-shadow: var(--sh-lg);
      opacity: 0; transform: translateY(8px); pointer-events: none;
      transition: opacity .2s ease, transform .2s ease; z-index: 999;
    }
    .toast.show { opacity: 1; transform: translateY(0); }
    .toast.success { border-left: 3px solid var(--ps-success); }
    .toast.error   { border-left: 3px solid var(--ps-danger); }
    .toast.info    { border-left: 3px solid var(--ps-blue); }

    /* ── Helpers ─────────────────────────────────────────────── */
    .hidden { display: none !important; }
    .row { display: flex; gap: var(--s-4); align-items: center; }
    .stack-4 > * + * { margin-top: var(--s-4); }
  </style>
</head>
<body>
<div class="app">

  <!-- ── Header ──────────────────────────────────────────────── -->
  <header class="app-header">
    <a href="#" class="brand-lockup">
      <span class="brand-wordmark">Contoso</span>
      <span class="brand-divider-label">Guest Book</span>
    </a>
    <div class="header-spacer"></div>
    <button class="user-chip" id="user-chip">
      <span class="avatar" id="user-avatar">?</span>
      <span class="user-chip-name" id="user-name">Connecting...</span>
      <span style="display:inline-flex;align-items:center;color:var(--ps-gray-400)">
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
      </span>
    </button>
  </header>

  <!-- ── Sidebar ─────────────────────────────────────────────── -->
  <aside class="app-sidebar">
    <div class="nav-group">
      <div class="nav-group-label">Guest Book</div>
      <button class="nav-item" id="nav-sign" onclick="showView('sign')">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z"/></svg>
        Sign the Book
      </button>
      <button class="nav-item active" id="nav-entries" onclick="showView('entries')">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 21a8 8 0 0 0-16 0"/><circle cx="10" cy="8" r="5"/><path d="M22 20c0-3.37-2-6.5-4-8a5 5 0 0 0-.45-8.3"/></svg>
        All Entries
        <span class="nav-item-meta" id="nav-entry-count" style="display:none"></span>
      </button>
    </div>

    <div class="sidebar-footer">
      <div class="sidebar-footer-title">About this Guest Book</div>
      <div style="margin-bottom:6px;font-size:12px;color:var(--ps-gray-500);">
        Entries are saved to a SharePoint list and visible to everyone with site access.
      </div>
      <div style="font-size:11px;color:var(--ps-gray-400);">List: SPADB - GuestListSample</div>
    </div>
  </aside>

  <!-- ── Main ────────────────────────────────────────────────── -->
  <main class="app-main">
    <div class="page-max">

      <!-- Setup progress banner -->
      <div class="banner banner-info" id="setup-banner">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
        <div style="flex:1">
          <div class="banner-title" id="setup-title">Connecting to SharePoint</div>
          <div id="setup-detail" style="font-size:13px;color:var(--ps-gray-500)">Detecting site context...</div>
          <div class="setup-steps" id="setup-steps"></div>
        </div>
      </div>

      <!-- Page header -->
      <div class="page-header hidden" id="page-header">
        <div>
          <nav class="breadcrumbs">
            <span>Contoso</span>
            <span class="sep">&#8250;</span>
            <span>Guest Book</span>
          </nav>
          <div class="page-title">
            <h1>Guest Book</h1>
            <span class="badge badge-success" id="header-badge" style="display:none">
              <span class="dot"></span>
              <span id="header-badge-count">0 guests</span>
            </span>
          </div>
          <p class="page-subtitle">Sign in and leave a note. All entries are saved to SharePoint.</p>
        </div>
        <div class="page-actions">
          <button class="btn btn-secondary" id="btn-refresh" onclick="refreshEntries()">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" id="refresh-icon"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>
            Refresh
          </button>
        </div>
      </div>

      <!-- Sign form -->
      <div id="sign-section" class="hidden">
        <section class="card" id="sign-card" style="margin-bottom:var(--s-8)">
          <div class="card-header">
            <div class="card-title">Sign the Guest Book</div>
          </div>
          <div class="card-body">
            <div class="form-grid">
              <div class="form-row">
                <label class="form-label" for="f-name">Your Name <span class="req">*</span></label>
                <input class="form-input" id="f-name" type="text" placeholder="Full name" maxlength="100" />
              </div>
              <div class="form-row">
                <label class="form-label" for="f-from">Where are you from?</label>
                <input class="form-input" id="f-from" type="text" placeholder="City, State or Country" maxlength="100" />
              </div>
              <div class="form-row">
                <label class="form-label" for="f-rel">Your connection to the host</label>
                <input class="form-input" id="f-rel" type="text" placeholder="e.g. Friend, Colleague, Family" maxlength="100" />
              </div>
              <div></div>
              <div class="form-row full">
                <label class="form-label" for="f-message">Your Message <span class="req">*</span></label>
                <textarea class="form-textarea" id="f-message" placeholder="Leave a note..." maxlength="500" rows="4" oninput="updateCharCount()"></textarea>
                <div class="char-count" id="char-count">0 / 500</div>
              </div>
            </div>
            <div id="sign-error"></div>
          </div>
          <div class="card-footer">
            <button class="btn btn-ghost" onclick="clearForm()">Clear</button>
            <button class="btn btn-primary" id="btn-submit" onclick="submitEntry()">Sign the Book</button>
          </div>
        </section>
      </div>

      <!-- Entries -->
      <div id="entries-section" class="hidden">
        <div class="entries-toolbar" id="entries-toolbar">
          <div>
            <div class="section-title">Guest Entries</div>
            <div class="section-count" id="entries-count"></div>
          </div>
          <div class="header-search">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
            <input type="text" id="search-box" placeholder="Search entries..." oninput="filterEntries()" />
          </div>
        </div>
        <div class="entries-grid" id="entries-grid"></div>
        <div class="entries-empty hidden" id="entries-empty">
          <strong id="empty-title">No entries yet</strong>
          <div id="empty-subtitle">Be the first to sign the guest book!</div>
        </div>
      </div>

    </div>
  </main>

  <!-- ── Footer ──────────────────────────────────────────────── -->
  <footer class="app-footer">
    <div class="row">
      <span style="font-size:18px;font-weight:700;color:rgba(255,255,255,.85);letter-spacing:-.3px">Contoso</span>
      <span style="opacity:.4">&#183;</span>
      <span>Guest Book Demo &mdash; SharePoint List Integration</span>
    </div>
    <div class="footer-links">
      <span style="opacity:.4">&#169; 2026 Contoso, Inc.</span>
    </div>
  </footer>

</div><!-- /.app -->

<div class="toast" id="toast"></div>

<script>
  /* ── Constants ──────────────────────────────────────────────── */
  const SP_LIST_NAME = "SPADB - GuestListSample";

  const LIST_FIELD_DEFS = [
    { "__metadata": { "type": "SP.FieldMultiLineText" }, "FieldTypeKind": 3,
      "Title": "GuestMessage", "Required": true, "NumberOfLines": 6, "RichText": false },
    { "__metadata": { "type": "SP.Field" }, "FieldTypeKind": 2,
      "Title": "GuestFrom", "Required": false },
    { "__metadata": { "type": "SP.Field" }, "FieldTypeKind": 2,
      "Title": "Relationship", "Required": false },
  ];

  // Avatar tints: background / foreground pairs from the PS design system
  const AVATAR_TINTS = [
    { bg: "#DCEAED", fg: "#002F48" },
    { bg: "#FFEACC", fg: "#C56F00" },
    { bg: "#D0EEFC", fg: "#005BA6" },
    { bg: "#E5F9F2", fg: "#0D7A54" },
    { bg: "#FFEBEB", fg: "#A83232" },
    { bg: "#F3EBFF", fg: "#6B3EA0" },
  ];

  /* ── SharePoint state ───────────────────────────────────────── */
  let IN_SHAREPOINT  = false;
  let SP_SITE_URL    = null;
  let SP_USER        = "Guest";
  let SP_ENTITY_TYPE = null;

  /* ── App state ──────────────────────────────────────────────── */
  let allEntries  = [];
  let searchQuery = "";

  /* ── Helpers ────────────────────────────────────────────────── */
  function spEnc(s)    { return s.replace(/'/g, "''").replace(/ /g, "%20"); }
  function initial(n)  { return (n || "?").trim().charAt(0).toUpperCase(); }

  function avatarTint(name) {
    let h = 0;
    for (let i = 0; i < name.length; i++) h = (h << 5) - h + name.charCodeAt(i);
    return AVATAR_TINTS[Math.abs(h) % AVATAR_TINTS.length];
  }

  function formatDate(iso) {
    const d = new Date(iso);
    return d.toLocaleDateString("en-US", { month:"short", day:"numeric", year:"numeric" }) +
           " at " + d.toLocaleTimeString("en-US", { hour:"numeric", minute:"2-digit" });
  }

  function esc(s) {
    return String(s)
      .replace(/&/g,"&amp;").replace(/</g,"&lt;")
      .replace(/>/g,"&gt;").replace(/"/g,"&quot;");
  }

  let toastTimer = null;
  function showToast(msg, type) {
    const el = document.getElementById("toast");
    el.textContent = msg;
    el.className   = "toast " + (type || "info") + " show";
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("show"), 3200);
  }

  function deriveSiteUrl() {
    const path = decodeURIComponent(window.location.pathname);
    const m    = path.match(/^(\/(?:sites|teams)\/[^\/]+)/i);
    return window.location.origin + (m ? m[1] : "");
  }

  async function getDigest() {
    const res  = await fetch(SP_SITE_URL + "/_api/contextinfo", {
      method: "POST", credentials: "include",
      headers: { "Accept": "application/json;odata=verbose" },
    });
    const data = await res.json();
    return data.d.GetContextWebInformation.FormDigestValue;
  }

  /* ── Setup banner helpers ───────────────────────────────────── */
  const STEPS_CONFIG = [
    { key: "detect", label: "Connecting to SharePoint" },
    { key: "list",   label: "Checking guest list"      },
    { key: "fields", label: "Creating list fields"     },
    { key: "load",   label: "Loading entries"          },
  ];
  let stepStates = {};

  function initSetupSteps(visibleKeys) {
    const c = document.getElementById("setup-steps");
    c.innerHTML = "";
    STEPS_CONFIG.forEach(s => {
      stepStates[s.key] = visibleKeys.includes(s.key) ? "pending" : "skip";
      if (stepStates[s.key] === "skip") return;
      const el = document.createElement("div");
      el.className = "setup-step";
      el.id = "sstep-" + s.key;
      el.innerHTML = `<div class="step-dot pending" id="sdot-${s.key}"></div>
                      <span class="step-text pending" id="stxt-${s.key}">${s.label}</span>`;
      c.appendChild(el);
    });
  }

  function setStep(key, state, detail) {
    const dot = document.getElementById("sdot-" + key);
    const txt = document.getElementById("stxt-" + key);
    if (!dot) return;
    dot.className = "step-dot " + state;
    txt.className = "step-text " + state;
    if (detail) txt.textContent = STEPS_CONFIG.find(s => s.key === key)?.label + " — " + detail;
  }

  function setBanner(type, title, detail) {
    const el  = document.getElementById("setup-banner");
    el.className = "banner banner-" + type;
    document.getElementById("setup-title").textContent  = title;
    document.getElementById("setup-detail").textContent = detail || "";
  }

  /* ── SharePoint List API ────────────────────────────────────── */
  async function listExists() {
    const url = `${SP_SITE_URL}/_api/web/lists?$filter=Title eq '${spEnc(SP_LIST_NAME)}'&$select=Id`;
    const res = await fetch(url, {
      credentials: "include",
      headers: { "Accept": "application/json;odata=verbose" },
    });
    if (!res.ok) throw new Error("Could not query lists: HTTP " + res.status);
    const data = await res.json();
    return data.d.results.length > 0;
  }

  async function createList(digest) {
    const res = await fetch(`${SP_SITE_URL}/_api/web/lists`, {
      method: "POST", credentials: "include",
      headers: {
        "Accept":          "application/json;odata=verbose",
        "Content-Type":    "application/json;odata=verbose",
        "X-RequestDigest": digest,
      },
      body: JSON.stringify({
        "__metadata":          { "type": "SP.List" },
        "AllowContentTypes":   false,
        "BaseTemplate":        100,
        "ContentTypesEnabled": false,
        "Description":         "Guest book entries — created by guestbook.aspx",
        "Title":               SP_LIST_NAME,
      }),
    });
    if (!res.ok) throw new Error("Create list failed: HTTP " + res.status);
  }

  async function ensureField(digest, fieldDef) {
    const url = `${SP_SITE_URL}/_api/web/lists/getbytitle('${spEnc(SP_LIST_NAME)}')/fields`;
    const res = await fetch(url, {
      method: "POST", credentials: "include",
      headers: {
        "Accept":          "application/json;odata=verbose",
        "Content-Type":    "application/json;odata=verbose",
        "X-RequestDigest": digest,
      },
      body: JSON.stringify(fieldDef),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      const code = body?.error?.code || "";
      if (!code.includes("-2130575306"))
        throw new Error("Add field '" + fieldDef.Title + "' failed: " + (code || res.status));
    }
  }

  async function fetchEntityType() {
    const url = `${SP_SITE_URL}/_api/web/lists/getbytitle('${spEnc(SP_LIST_NAME)}')?$select=ListItemEntityTypeFullName`;
    const res = await fetch(url, {
      credentials: "include",
      headers: { "Accept": "application/json;odata=verbose" },
    });
    if (!res.ok) throw new Error("Could not fetch list metadata: HTTP " + res.status);
    const data = await res.json();
    return data.d.ListItemEntityTypeFullName;
  }

  async function fetchEntries() {
    const url = `${SP_SITE_URL}/_api/web/lists/getbytitle('${spEnc(SP_LIST_NAME)}')/items` +
                `?$select=Id,Title,GuestMessage,GuestFrom,Relationship,Created` +
                `&$orderby=Created desc&$top=500`;
    const res = await fetch(url, {
      credentials: "include",
      headers: { "Accept": "application/json;odata=verbose" },
    });
    if (!res.ok) throw new Error("Could not load entries: HTTP " + res.status);
    const data = await res.json();
    return data.d.results;
  }

  async function postEntry(item) {
    const digest = await getDigest();
    const body   = { "__metadata": { "type": SP_ENTITY_TYPE }, ...item };
    const url    = `${SP_SITE_URL}/_api/web/lists/getbytitle('${spEnc(SP_LIST_NAME)}')/items`;
    const res    = await fetch(url, {
      method: "POST", credentials: "include",
      headers: {
        "Accept":          "application/json;odata=verbose",
        "Content-Type":    "application/json;odata=verbose",
        "X-RequestDigest": digest,
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err?.error?.message?.value || "Submit failed: HTTP " + res.status);
    }
    return (await res.json()).d;
  }

  /* ── Rendering ──────────────────────────────────────────────── */
  function renderEntries(highlightId) {
    const grid  = document.getElementById("entries-grid");
    const empty = document.getElementById("entries-empty");
    const count = document.getElementById("entries-count");
    const q     = searchQuery.toLowerCase();

    const filtered = allEntries.filter(e =>
      !q ||
      (e.Title        || "").toLowerCase().includes(q) ||
      (e.GuestMessage || "").toLowerCase().includes(q) ||
      (e.GuestFrom    || "").toLowerCase().includes(q)
    );

    const total = allEntries.length;

    // Update sidebar badge
    const badge = document.getElementById("nav-entry-count");
    if (total > 0) {
      badge.textContent = total;
      badge.style.display = "";
    }

    // Update header badge
    const hBadge = document.getElementById("header-badge");
    const hCount = document.getElementById("header-badge-count");
    if (total > 0) {
      hCount.textContent = total + " guest" + (total !== 1 ? "s" : "");
      hBadge.style.display = "";
    }

    count.textContent = total === 0 ? "" :
      total + " guest" + (total !== 1 ? "s" : "") + " have signed" +
      (q ? " — " + filtered.length + " match" + (filtered.length !== 1 ? "es" : "") : "");

    if (filtered.length === 0) {
      grid.innerHTML = "";
      empty.classList.remove("hidden");
      document.getElementById("empty-title").textContent =
        q ? "No entries match your search" : "No entries yet";
      document.getElementById("empty-subtitle").textContent =
        q ? "Try a different search term." : "Be the first to sign the guest book!";
      return;
    }

    empty.classList.add("hidden");
    grid.innerHTML = filtered.map(e => {
      const tint  = avatarTint(e.Title || "?");
      const init  = initial(e.Title || "?");
      const from  = [e.GuestFrom, e.Relationship].filter(Boolean).join(" · ");
      const isNew = highlightId && e.Id === highlightId;
      return `<div class="entry-card${isNew ? " new-entry" : ""}">
        <div class="entry-top">
          <div class="entry-avatar" style="background:${tint.bg};color:${tint.fg}">${init}</div>
          <div class="entry-meta">
            <div class="entry-name">${esc(e.Title || "Anonymous")}</div>
            ${from ? `<div class="entry-from">${esc(from)}</div>` : ""}
          </div>
          <div class="entry-date">${formatDate(e.Created)}</div>
        </div>
        <div class="entry-message">${esc(e.GuestMessage || "")}</div>
      </div>`;
    }).join("");
  }

  function filterEntries() {
    searchQuery = document.getElementById("search-box").value;
    renderEntries();
  }

  /* ── Form ───────────────────────────────────────────────────── */
  function updateCharCount() {
    const len = document.getElementById("f-message").value.length;
    const el  = document.getElementById("char-count");
    el.textContent = len + " / 500";
    el.className   = "char-count" + (len >= 500 ? " over" : len > 450 ? " warn" : "");
  }

  function clearForm() {
    ["f-name","f-message","f-from","f-rel"].forEach(id => {
      document.getElementById(id).value = "";
      document.getElementById(id).classList.remove("invalid");
    });
    document.getElementById("sign-error").innerHTML = "";
    updateCharCount();
  }

  async function submitEntry() {
    const name    = document.getElementById("f-name").value.trim();
    const message = document.getElementById("f-message").value.trim();
    const from    = document.getElementById("f-from").value.trim();
    const rel     = document.getElementById("f-rel").value.trim();
    const errEl   = document.getElementById("sign-error");
    const btn     = document.getElementById("btn-submit");

    // Clear previous errors
    errEl.innerHTML = "";
    ["f-name","f-message"].forEach(id => document.getElementById(id).classList.remove("invalid"));

    if (!name) {
      document.getElementById("f-name").classList.add("invalid");
      errEl.innerHTML = `<div class="banner banner-danger" style="margin-top:var(--s-3)">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
        <div>Please enter your name.</div></div>`;
      return;
    }
    if (!message) {
      document.getElementById("f-message").classList.add("invalid");
      errEl.innerHTML = `<div class="banner banner-danger" style="margin-top:var(--s-3)">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
        <div>Please leave a message.</div></div>`;
      return;
    }

    btn.disabled    = true;
    btn.textContent = "Signing...";

    try {
      const item = { "Title": name, "GuestMessage": message };
      if (from) item.GuestFrom    = from;
      if (rel)  item.Relationship = rel;

      const created = await postEntry(item);

      // Optimistic prepend
      allEntries.unshift({
        Id: created.Id, Title: name, GuestMessage: message,
        GuestFrom: from || null, Relationship: rel || null,
        Created: created.Created || new Date().toISOString(),
      });
      renderEntries(created.Id);
      clearForm();
      showToast("Your entry has been added. Thank you!", "success");
      showView("entries");

      btn.textContent = "Sign the Book";
      btn.disabled    = false;

      // Re-sync from SP after a short delay
      setTimeout(async () => {
        allEntries = await fetchEntries();
        renderEntries(created.Id);
      }, 1500);

    } catch (err) {
      errEl.innerHTML = `<div class="banner banner-danger" style="margin-top:var(--s-3)">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
        <div><div class="banner-title">Could not save</div>${esc(err.message)}</div></div>`;
      btn.textContent = "Sign the Book";
      btn.disabled    = false;
      showToast("Save failed.", "error");
    }
  }

  /* ── Refresh ────────────────────────────────────────────────── */
  async function refreshEntries() {
    const btn  = document.getElementById("btn-refresh");
    const icon = document.getElementById("refresh-icon");
    btn.disabled = true;
    icon.classList.add("spin");
    try {
      allEntries = await fetchEntries();
      renderEntries();
      showToast("Entries refreshed.", "success");
    } catch (err) {
      showToast("Refresh failed: " + err.message, "error");
    } finally {
      btn.disabled = false;
      icon.classList.remove("spin");
    }
  }

  /* ── View switching ─────────────────────────────────────────── */
  function showView(view) {
    document.querySelectorAll(".nav-item").forEach(el => el.classList.remove("active"));
    document.getElementById("nav-" + view).classList.add("active");
    document.getElementById("sign-section").classList.toggle("hidden", view !== "sign");
    document.getElementById("entries-section").classList.toggle("hidden", view !== "entries");
    document.getElementById("btn-refresh").classList.toggle("hidden", view !== "entries");
  }

  /* ── Init ───────────────────────────────────────────────────── */
  async function initApp() {
    const siteUrl = deriveSiteUrl();
    initSetupSteps(["detect","list","fields","load"]);

    // Step 1: detect SharePoint
    setStep("detect", "active");
    try {
      const res = await fetch(
        siteUrl + "/_api/web?$select=Url,CurrentUser/LoginName,CurrentUser/Title&$expand=CurrentUser",
        { credentials: "include", headers: { "Accept": "application/json;odata=verbose" } }
      );
      if (!res.ok) throw new Error("HTTP " + res.status);
      const data = await res.json();

      IN_SHAREPOINT = true;
      SP_SITE_URL   = data.d.Url;
      SP_USER       = data.d.CurrentUser?.Title || data.d.CurrentUser?.LoginName || "Guest";

      document.getElementById("user-name").textContent   = SP_USER;
      document.getElementById("user-avatar").textContent = initial(SP_USER);
      setStep("detect", "done", SP_SITE_URL);
    } catch (err) {
      setStep("detect", "error", err.message);
      setBanner("warning", "Not connected to SharePoint",
        "Open this file from a SharePoint document library to use the guest book.");
      document.getElementById("setup-steps").classList.add("hidden");
      document.getElementById("user-name").textContent = "Not connected";
      return;
    }

    // Step 2: check / create list
    setBanner("info", "Setting up guest list", "");
    setStep("list", "active");
    try {
      const exists = await listExists();
      if (!exists) {
        setStep("list",   "active", "not found, creating...");
        setStep("fields", "active");
        const digest = await getDigest();
        await createList(digest);
        for (const fd of LIST_FIELD_DEFS) await ensureField(digest, fd);
        setStep("fields", "done", LIST_FIELD_DEFS.length + " fields added");
        setStep("list",   "done", "created");
      } else {
        setStep("list",   "done", "found");
        setStep("fields", "done", "verified");
      }
      SP_ENTITY_TYPE = await fetchEntityType();
    } catch (err) {
      setStep("list", "error", err.message);
      setBanner("danger", "Could not set up guest list", err.message);
      return;
    }

    // Step 3: load entries
    setBanner("info", "Loading entries", "");
    setStep("load", "active");
    try {
      allEntries = await fetchEntries();
      setStep("load", "done", allEntries.length + " loaded");
    } catch (err) {
      setStep("load", "error", err.message);
      setBanner("danger", "Could not load entries", err.message);
      return;
    }

    // Done — show content
    setTimeout(() => {
      document.getElementById("setup-banner").classList.add("hidden");
      document.getElementById("page-header").classList.remove("hidden");
      showView("entries");
      renderEntries();
    }, 400);
  }

  initApp();
</script>
</body>
</html>
