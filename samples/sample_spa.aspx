<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Contoso — Demo</title>
  <style>
    /* ── Reset & tokens ─────────────────────────────────────── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --ps-blue:    #004B9B;
      --ps-blue-d:  #003370;
      --ps-blue-l:  #e8f0fb;
      --ps-orange:  #F5821F;
      --ps-orange-d:#d96d0a;
      --ps-gray:    #f4f6f9;
      --ps-border:  #dde3ec;
      --ps-text:    #1a2a3a;
      --ps-muted:   #6b7a90;
      --radius:     8px;
      --shadow:     0 2px 10px rgba(0,0,0,.10);
      --transition: 260ms cubic-bezier(.4,0,.2,1);
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--ps-gray);
      color: var(--ps-text);
      min-height: 100vh;
    }

    /* ── Top nav bar ────────────────────────────────────────── */
    .topbar {
      background: var(--ps-blue);
      color: #fff;
      height: 56px;
      display: flex;
      align-items: center;
      padding: 0 24px;
      gap: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,.2);
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .topbar-logo {
      font-size: 20px; font-weight: 700; letter-spacing: -.3px;
      display: flex; align-items: center; gap: 8px;
    }
    .topbar-logo span { color: var(--ps-orange); }
    .topbar-pill {
      background: rgba(255,255,255,.15);
      border-radius: 20px;
      padding: 2px 10px;
      font-size: 11px; letter-spacing: .5px; text-transform: uppercase;
    }
    .topbar-spacer { flex: 1; }
    .topbar-user { display: flex; align-items: center; gap: 8px; font-size: 14px; opacity: .9; }
    .avatar {
      width: 32px; height: 32px;
      background: var(--ps-orange);
      border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; font-size: 13px;
    }

    /* ── Breadcrumb ─────────────────────────────────────────── */
    .breadcrumb-bar {
      background: #fff;
      border-bottom: 1px solid var(--ps-border);
      padding: 10px 24px;
      display: flex; align-items: center; gap: 6px;
      font-size: 13px; min-height: 40px;
    }
    .bc-item {
      color: var(--ps-blue); cursor: pointer; font-weight: 500;
      transition: color var(--transition);
    }
    .bc-item:hover { color: var(--ps-orange); text-decoration: underline; }
    .bc-item.active { color: var(--ps-muted); cursor: default; font-weight: 400; }
    .bc-item.active:hover { color: var(--ps-muted); text-decoration: none; }
    .bc-sep { color: var(--ps-border); user-select: none; }

    /* ── Main layout ────────────────────────────────────────── */
    .main { padding: 28px 24px; max-width: 1100px; margin: 0 auto; }

    /* ── View animation ─────────────────────────────────────── */
    .view { display: none; animation: fadeSlide var(--transition) forwards; }
    .view.active { display: block; }
    @keyframes fadeSlide {
      from { opacity: 0; transform: translateY(12px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* ── Page heading ───────────────────────────────────────── */
    .page-title { font-size: 22px; font-weight: 700; color: var(--ps-blue); margin-bottom: 4px; }
    .page-subtitle { font-size: 14px; color: var(--ps-muted); margin-bottom: 24px; }

    /* ── Cards ──────────────────────────────────────────────── */
    .card {
      background: #fff; border-radius: var(--radius);
      box-shadow: var(--shadow); padding: 20px 24px; margin-bottom: 20px;
    }
    .card-title {
      font-size: 13px; font-weight: 600; text-transform: uppercase;
      letter-spacing: .6px; color: var(--ps-muted); margin-bottom: 16px;
    }
    .card-header {
      display: flex; align-items: center; justify-content: space-between;
      margin-bottom: 16px;
    }
    .card-header .card-title { margin-bottom: 0; }

    /* ── Stat grid ──────────────────────────────────────────── */
    .stat-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px; margin-bottom: 20px;
    }
    .stat-card {
      background: #fff; border-radius: var(--radius); padding: 18px 20px;
      box-shadow: var(--shadow); border-left: 4px solid var(--ps-blue);
    }
    .stat-card.orange { border-left-color: var(--ps-orange); }
    .stat-card.green  { border-left-color: #22c55e; }
    .stat-card.red    { border-left-color: #ef4444; }
    .stat-label { font-size: 12px; color: var(--ps-muted); font-weight: 500; }
    .stat-value { font-size: 28px; font-weight: 700; color: var(--ps-text); margin-top: 4px; }
    .stat-delta { font-size: 12px; margin-top: 2px; }
    .stat-delta.up   { color: #22c55e; }
    .stat-delta.down { color: #ef4444; }

    /* ── Chart ──────────────────────────────────────────────── */
    canvas#chart { width: 100%; height: 220px; display: block; }

    /* ── Category grid ──────────────────────────────────────── */
    .cat-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 16px;
    }
    .cat-card {
      background: #fff; border-radius: var(--radius); box-shadow: var(--shadow);
      padding: 20px; cursor: pointer; border: 2px solid transparent;
      transition: border-color var(--transition), transform var(--transition), box-shadow var(--transition);
      display: flex; flex-direction: column; gap: 8px;
    }
    .cat-card:hover {
      border-color: var(--ps-blue); transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0,75,155,.15);
    }
    .cat-icon-badge {
      width: 48px; height: 48px; border-radius: 12px; flex-shrink: 0;
      display: flex; align-items: center; justify-content: center;
      font-size: 14px; font-weight: 800; color: #fff; letter-spacing: .5px;
    }
    .cat-name { font-weight: 600; font-size: 15px; }
    .cat-count { font-size: 12px; color: var(--ps-muted); }

    /* ── Table ──────────────────────────────────────────────── */
    .table-controls {
      display: flex; gap: 12px; margin-bottom: 14px;
      flex-wrap: wrap; align-items: center;
    }
    .search-box {
      flex: 1; min-width: 200px; max-width: 340px;
      padding: 8px 12px; border: 1px solid var(--ps-border);
      border-radius: var(--radius); font-size: 14px; outline: none;
      transition: border-color var(--transition), box-shadow var(--transition);
    }
    .search-box:focus {
      border-color: var(--ps-blue);
      box-shadow: 0 0 0 3px rgba(0,75,155,.12);
    }
    select.filter-select {
      padding: 8px 12px; border: 1px solid var(--ps-border);
      border-radius: var(--radius); font-size: 14px; outline: none;
      background: #fff; cursor: pointer;
    }
    .row-count { font-size: 13px; color: var(--ps-muted); margin-left: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    thead th {
      background: var(--ps-blue); color: #fff;
      padding: 10px 14px; text-align: left; font-weight: 600; font-size: 13px;
      cursor: pointer; user-select: none; white-space: nowrap;
    }
    thead th:hover { background: var(--ps-blue-d); }
    thead th .sort-icon { opacity: .45; margin-left: 4px; font-style: normal; }
    thead th.sorted   .sort-icon { opacity: 1; }
    tbody tr { transition: background var(--transition); cursor: pointer; }
    tbody tr:nth-child(even) { background: var(--ps-blue-l); }
    tbody tr:hover { background: #d5e3f7; }
    tbody td { padding: 10px 14px; border-bottom: 1px solid var(--ps-border); }

    /* ── Badges ─────────────────────────────────────────────── */
    .badge {
      display: inline-block; padding: 2px 8px;
      border-radius: 12px; font-size: 11px; font-weight: 600;
    }
    .badge-green  { background: #dcfce7; color: #16a34a; }
    .badge-yellow { background: #fef9c3; color: #a16207; }
    .badge-red    { background: #fee2e2; color: #b91c1c; }
    .badge-blue   { background: #dbeafe; color: #1d4ed8; }
    .badge-gray   { background: #f1f5f9; color: #475569; }

    /* ── Buttons ────────────────────────────────────────────── */
    .btn {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 8px 16px; border-radius: var(--radius); border: none;
      font-size: 14px; font-weight: 600; cursor: pointer;
      transition: background var(--transition), transform var(--transition);
    }
    .btn:active { transform: scale(.97); }
    .btn-sm { padding: 5px 11px; font-size: 12px; }
    .btn-primary { background: var(--ps-blue); color: #fff; }
    .btn-primary:hover { background: var(--ps-blue-d); }
    .btn-orange  { background: var(--ps-orange); color: #fff; }
    .btn-orange:hover { background: var(--ps-orange-d); }
    .btn-ghost   { background: transparent; color: var(--ps-blue); border: 1px solid var(--ps-blue); }
    .btn-ghost:hover { background: var(--ps-blue-l); }
    .btn-danger  { background: transparent; color: #ef4444; border: 1px solid #ef4444; }
    .btn-danger:hover { background: #fee2e2; }
    .btn:disabled { opacity: .45; cursor: not-allowed; transform: none; }

    /* ── Modal ──────────────────────────────────────────────── */
    .modal-overlay {
      position: fixed; inset: 0; background: rgba(0,0,0,.45);
      display: flex; align-items: center; justify-content: center;
      z-index: 500; opacity: 0; pointer-events: none;
      transition: opacity var(--transition);
    }
    .modal-overlay.open { opacity: 1; pointer-events: all; }
    .modal {
      background: #fff; border-radius: 12px;
      box-shadow: 0 20px 60px rgba(0,0,0,.25);
      width: 100%; max-width: 560px; padding: 28px;
      transform: scale(.93) translateY(8px);
      transition: transform var(--transition);
    }
    .modal-overlay.open .modal { transform: scale(1) translateY(0); }
    .modal-header {
      display: flex; align-items: flex-start; justify-content: space-between;
      margin-bottom: 20px;
    }
    .modal-title { font-size: 18px; font-weight: 700; color: var(--ps-blue); }
    .modal-close {
      background: none; border: none; font-size: 22px; cursor: pointer;
      color: var(--ps-muted); line-height: 1; transition: color var(--transition);
    }
    .modal-close:hover { color: var(--ps-text); }
    .modal-row { display: flex; gap: 12px; margin-bottom: 12px; font-size: 14px; }
    .modal-label { color: var(--ps-muted); min-width: 120px; font-weight: 500; }
    .modal-val   { font-weight: 600; }
    .modal-divider { border: none; border-top: 1px solid var(--ps-border); margin: 16px 0; }
    .modal-footer { display: flex; gap: 10px; justify-content: flex-end; margin-top: 20px; }

    /* ── Back button ────────────────────────────────────────── */
    .back-btn {
      display: inline-flex; align-items: center; gap: 6px;
      font-size: 13px; color: var(--ps-blue); font-weight: 500;
      cursor: pointer; margin-bottom: 16px;
      background: none; border: none; transition: color var(--transition);
    }
    .back-btn:hover { color: var(--ps-orange); }

    /* ── Empty state ────────────────────────────────────────── */
    .empty-state { text-align: center; padding: 40px; color: var(--ps-muted); font-size: 14px; }
    .empty-state .empty-icon { font-size: 40px; margin-bottom: 8px; }

    /* ── Order tray ─────────────────────────────────────────── */
    .order-list { display: flex; flex-direction: column; gap: 8px; }
    .order-item {
      display: flex; align-items: center; gap: 10px;
      padding: 10px 12px;
      background: var(--ps-gray); border-radius: var(--radius);
      font-size: 13px;
    }
    .order-item-id   { font-weight: 700; color: var(--ps-blue); min-width: 80px; }
    .order-item-desc { flex: 1; color: var(--ps-text); }
    .order-item-price { font-weight: 600; min-width: 80px; text-align: right; }
    .order-item-remove {
      background: none; border: none; cursor: pointer; color: var(--ps-muted);
      font-size: 16px; line-height: 1; padding: 0 4px;
      transition: color var(--transition);
    }
    .order-item-remove:hover { color: #ef4444; }
    .order-total {
      display: flex; justify-content: flex-end; align-items: center;
      gap: 8px; padding-top: 12px; margin-top: 4px;
      border-top: 2px solid var(--ps-border);
      font-size: 15px; font-weight: 700; color: var(--ps-text);
    }
    .order-empty { text-align: center; padding: 20px; color: var(--ps-muted); font-size: 13px; }

    /* ── Serialization panel ────────────────────────────────── */
    .sp-context-row {
      display: flex; align-items: center; gap: 12px;
      padding: 10px 14px; border-radius: var(--radius);
      font-size: 13px; margin-bottom: 14px;
    }
    .sp-context-row.sp-live    { background: #dcfce7; color: #14532d; }
    .sp-context-row.sp-local   { background: #fef9c3; color: #713f12; }
    .sp-context-row.sp-probing { background: var(--ps-blue-l); color: var(--ps-blue); }
    .sp-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }
    .sp-live    .sp-dot { background: #16a34a; box-shadow: 0 0 0 3px #bbf7d0; }
    .sp-local   .sp-dot { background: #ca8a04; box-shadow: 0 0 0 3px #fef08a; }
    .sp-probing .sp-dot { background: var(--ps-blue); box-shadow: 0 0 0 3px #bfdbfe; }
    .sp-context-text { flex: 1; }
    .sp-context-text strong { display: block; font-weight: 700; }
    .sp-context-text small   { opacity: .75; }
    .sp-meta-grid {
      display: grid; grid-template-columns: 1fr 1fr; gap: 8px;
      margin-bottom: 14px; font-size: 13px;
    }
    .sp-meta-item { display: flex; flex-direction: column; gap: 2px; }
    .sp-meta-label { color: var(--ps-muted); font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .4px; }
    .sp-meta-val   { font-weight: 600; word-break: break-all; }
    .sp-actions    { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
    .sp-status-msg { font-size: 12px; color: var(--ps-muted); min-height: 18px; }
    .sp-status-msg.ok   { color: #16a34a; }
    .sp-status-msg.err  { color: #b91c1c; }
    .sp-status-msg.busy { color: var(--ps-blue); }
    .json-preview {
      background: #1a2a3a; color: #a5f3a5; border-radius: var(--radius);
      padding: 14px; font-family: "SF Mono", Menlo, Monaco, "Courier New", monospace;
      font-size: 11px; line-height: 1.6; max-height: 200px; overflow-y: auto;
      white-space: pre; margin-top: 12px; display: none;
    }
    .json-preview.visible { display: block; }

    /* ── Toast ──────────────────────────────────────────────── */
    .toast {
      position: fixed; bottom: 28px; right: 28px;
      background: #1a2a3a; color: #fff;
      padding: 12px 20px; border-radius: var(--radius);
      font-size: 14px; font-weight: 500;
      box-shadow: 0 8px 24px rgba(0,0,0,.25);
      opacity: 0; transform: translateY(10px);
      transition: opacity var(--transition), transform var(--transition);
      z-index: 999; pointer-events: none;
    }
    .toast.show { opacity: 1; transform: translateY(0); }
    .toast.success { border-left: 4px solid #22c55e; }
    .toast.error   { border-left: 4px solid #ef4444; }
    .toast.info    { border-left: 4px solid var(--ps-blue); }
  </style>
</head>
<body>

<!-- ── Top navigation bar ─────────────────────────────────── -->
<nav class="topbar">
  <div class="topbar-logo">Con<span>toso</span></div>
  <div class="topbar-pill">SPA Demo</div>
  <div class="topbar-spacer"></div>
  <div class="topbar-user">
    <div class="avatar">SU</div>
    Sample User
  </div>
</nav>

<!-- ── Breadcrumb bar ──────────────────────────────────────── -->
<div class="breadcrumb-bar" id="breadcrumb"></div>

<!-- ── Main content area ──────────────────────────────────── -->
<main class="main">

  <!-- VIEW: Dashboard -->
  <div class="view active" id="view-dashboard">
    <div class="page-title">Dashboard</div>
    <div class="page-subtitle">Welcome back, Ted. Here's your procurement snapshot.</div>

    <div class="stat-grid">
      <div class="stat-card">
        <div class="stat-label">Open Orders</div>
        <div class="stat-value">142</div>
        <div class="stat-delta up">▲ 12% this week</div>
      </div>
      <div class="stat-card orange">
        <div class="stat-label">Pending Approvals</div>
        <div class="stat-value">37</div>
        <div class="stat-delta down">▼ 3 since yesterday</div>
      </div>
      <div class="stat-card green">
        <div class="stat-label">Fill Rate</div>
        <div class="stat-value">96.4%</div>
        <div class="stat-delta up">▲ 0.8 pts MoM</div>
      </div>
      <div class="stat-card red">
        <div class="stat-label">Critical Backorders</div>
        <div class="stat-value">8</div>
        <div class="stat-delta down">▼ 5 resolved today</div>
      </div>
    </div>

    <div class="card">
      <div class="card-title">Monthly Order Volume by Category</div>
      <canvas id="chart"></canvas>
    </div>

    <div class="card">
      <div class="card-title">Browse by Product Category</div>
      <div class="cat-grid" id="cat-grid"></div>
    </div>

    <!-- Current Order tray -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">Current Order</div>
        <button class="btn btn-danger btn-sm" onclick="clearOrder()" id="btn-clear-order" style="display:none">Clear</button>
      </div>
      <div id="order-tray">
        <div class="order-empty">No items yet — browse a category and add parts.</div>
      </div>
    </div>

    <!-- Serialization demo -->
    <div class="card">
      <div class="card-title">SharePoint Serialization Demo</div>

      <div id="sp-context-banner"></div>

      <div class="sp-meta-grid">
        <div class="sp-meta-item">
          <span class="sp-meta-label">Folder</span>
          <span class="sp-meta-val" id="sp-folder-path">—</span>
        </div>
        <div class="sp-meta-item">
          <span class="sp-meta-label">Target File</span>
          <span class="sp-meta-val" id="sp-target-file">orders.json</span>
        </div>
        <div class="sp-meta-item">
          <span class="sp-meta-label">Current User</span>
          <span class="sp-meta-val" id="sp-current-user">—</span>
        </div>
        <div class="sp-meta-item">
          <span class="sp-meta-label">Last Saved</span>
          <span class="sp-meta-val" id="sp-last-saved">Never</span>
        </div>
      </div>

      <div class="sp-actions">
        <button class="btn btn-primary btn-sm" onclick="saveOrder()" id="btn-save">
          &#8593; Save Order to SharePoint
        </button>
        <button class="btn btn-ghost btn-sm" onclick="loadOrder()" id="btn-load">
          &#8595; Load from SharePoint
        </button>
        <button class="btn btn-ghost btn-sm" onclick="toggleJsonPreview()">
          { } Preview JSON
        </button>
      </div>

      <div class="sp-status-msg" id="sp-status-msg"></div>
      <pre class="json-preview" id="json-preview"></pre>
    </div>
  </div>

  <!-- VIEW: Category (drill-down) -->
  <div class="view" id="view-category">
    <button class="back-btn" onclick="navigate('dashboard')">&#8592; Back to Dashboard</button>
    <div class="page-title" id="cat-title"></div>
    <div class="page-subtitle" id="cat-subtitle"></div>

    <div class="card">
      <div class="table-controls">
        <input class="search-box" id="table-search" type="text" placeholder="Search parts…" oninput="filterTable()" />
        <select class="filter-select" id="status-filter" onchange="filterTable()">
          <option value="">All Statuses</option>
          <option value="In Stock">In Stock</option>
          <option value="Low Stock">Low Stock</option>
          <option value="Backordered">Backordered</option>
        </select>
        <div class="row-count" id="row-count"></div>
      </div>
      <table id="parts-table">
        <thead>
          <tr>
            <th onclick="sortTable(0)">Part # <i class="sort-icon" id="si-0">⇅</i></th>
            <th onclick="sortTable(1)">Description <i class="sort-icon" id="si-1">⇅</i></th>
            <th onclick="sortTable(2)">OEM <i class="sort-icon" id="si-2">⇅</i></th>
            <th onclick="sortTable(3)">Unit Price <i class="sort-icon" id="si-3">⇅</i></th>
            <th onclick="sortTable(4)">Status <i class="sort-icon" id="si-4">⇅</i></th>
          </tr>
        </thead>
        <tbody id="parts-tbody"></tbody>
      </table>
      <div class="empty-state" id="empty-state" style="display:none">
        <div class="empty-icon">🔍</div>
        No parts match your search.
      </div>
    </div>
  </div>

</main>

<!-- ── Detail modal ────────────────────────────────────────── -->
<div class="modal-overlay" id="modal-overlay" onclick="closeModal(event)">
  <div class="modal" id="modal">
    <div class="modal-header">
      <div class="modal-title" id="modal-title"></div>
      <button class="modal-close" onclick="closeModal()">×</button>
    </div>
    <div id="modal-body"></div>
    <hr class="modal-divider" />
    <div class="modal-footer">
      <button class="btn btn-ghost" onclick="closeModal()">Close</button>
      <button class="btn btn-orange" onclick="addToOrder()">Add to Order</button>
    </div>
  </div>
</div>

<!-- ── Toast notification ──────────────────────────────────── -->
<div class="toast" id="toast"></div>

<script>
  /* ── Data ──────────────────────────────────────────────────── */
  const CATEGORIES = [
    { id:"imaging",  name:"Imaging",           abbr:"IM", color:"#004B9B", count:284 },
    { id:"monitors", name:"Patient Monitors",  abbr:"PM", color:"#F5821F", count:196 },
    { id:"surgical", name:"Surgical",          abbr:"SR", color:"#22c55e", count:157 },
    { id:"infusion", name:"Infusion Systems",  abbr:"IF", color:"#a855f7", count:131 },
    { id:"lab",      name:"Laboratory",        abbr:"LB", color:"#f59e0b", count:220 },
    { id:"cardio",   name:"Cardiovascular",    abbr:"CV", color:"#ef4444", count:118 },
  ];

  const PARTS_DB = {
    imaging: [
      { id:"IMG-1042", desc:"X-Ray Tube Assembly, High-Speed",   oem:"Proseware Medical",   price:4250.00, status:"In Stock",    compat:"Beacon 198",          warranty:"90 days",  leadtime:"2–3 days"  },
      { id:"IMG-0831", desc:"Flat Panel Detector Module",        oem:"Blue Yonder Health",         price:8900.00, status:"Low Stock",   compat:"Lumen 149",  warranty:"1 year",   leadtime:"1 week"    },
      { id:"IMG-2200", desc:"CT Slip Ring Assembly",             oem:"Lucerne Medical",         price:3100.00, status:"In Stock",    compat:"Cascade 226",    warranty:"90 days",  leadtime:"Same day"  },
      { id:"IMG-0455", desc:"MRI Gradient Amplifier Board",      oem:"Proseware Medical",   price:6750.00, status:"Backordered", compat:"Falcon 240",        warranty:"6 months", leadtime:"3–4 weeks" },
      { id:"IMG-1390", desc:"Collimator Shutter Blade Set",      oem:"Wingtip Biomedical",   price:780.00,  status:"In Stock",    compat:"Atlas 261",         warranty:"90 days",  leadtime:"Next day"  },
      { id:"IMG-3321", desc:"High-Voltage Power Supply",         oem:"Blue Yonder Health",         price:2340.00, status:"In Stock",    compat:"Vertex 107",         warranty:"6 months", leadtime:"2–3 days"  },
      { id:"IMG-0901", desc:"Ultrasound Transducer Array, 5MHz", oem:"Woodgrove Bio",         price:1650.00, status:"Low Stock",   compat:"Zephyr 142",         warranty:"1 year",   leadtime:"5 days"    },
    ],
    monitors: [
      { id:"MON-0110", desc:"SpO2 Circuit Board Assembly",       oem:"Wide World Medical",          price:320.00,  status:"In Stock",    compat:"Meridian 219",     warranty:"1 year",   leadtime:"Same day"  },
      { id:"MON-0245", desc:"NIBP Pump & Valve Kit",             oem:"Relecloud Medical",     price:195.00,  status:"In Stock",    compat:"Cobalt 135",        warranty:"90 days",  leadtime:"Next day"  },
      { id:"MON-0512", desc:"12.1\" TFT Color Display Module",   oem:"Woodgrove Bio",         price:850.00,  status:"In Stock",    compat:"Frost 282",        warranty:"6 months", leadtime:"2 days"    },
      { id:"MON-0788", desc:"ECG Cable & Lead Set, 10-Lead",     oem:"Proseware Medical",   price:140.00,  status:"Low Stock",   compat:"Pulse 114",    warranty:"90 days",  leadtime:"Next day"  },
      { id:"MON-1004", desc:"Main CPU Board Replacement",        oem:"Blue Yonder Health",         price:2100.00, status:"Backordered", compat:"Onyx 191",  warranty:"6 months", leadtime:"2 weeks"   },
    ],
    surgical: [
      { id:"SRG-0044", desc:"Monopolar Generator Handpiece",     oem:"Trey Research",       price:415.00,  status:"In Stock",    compat:"Nova 170",       warranty:"6 months", leadtime:"Next day"  },
      { id:"SRG-0193", desc:"Laparoscope Light Cable, 2.5m",     oem:"Nod Biomedical",         price:285.00,  status:"In Stock",    compat:"Horizon 247",       warranty:"90 days",  leadtime:"Same day"  },
      { id:"SRG-0500", desc:"Insufflator Pressure Sensor",       oem:"Coho Medical",      price:620.00,  status:"Low Stock",   compat:"Ceda 254",      warranty:"1 year",   leadtime:"3 days"    },
      { id:"SRG-0812", desc:"Bipolar Forceps Cable Assembly",    oem:"Alpine Medical",         price:190.00,  status:"In Stock",    compat:"Cirrus 156",           warranty:"90 days",  leadtime:"Next day"  },
    ],
    infusion: [
      { id:"INF-0021", desc:"Peristaltic Pump Drive Motor",      oem:"Contoso Surgical",          price:540.00,  status:"In Stock",    compat:"Tundra 233",    warranty:"1 year",   leadtime:"2 days"    },
      { id:"INF-0305", desc:"Door Latch & Sensor Assembly",      oem:"Fabrikam Medical",        price:145.00,  status:"In Stock",    compat:"Helix 184",   warranty:"90 days",  leadtime:"Next day"  },
      { id:"INF-0490", desc:"Air-in-Line Detector Module",       oem:"Litware Imaging",         price:310.00,  status:"Backordered", compat:"Summit 205",          warranty:"6 months", leadtime:"10 days"   },
    ],
    lab: [
      { id:"LAB-0077", desc:"Centrifuge Rotor, 24-place",        oem:"Northwind Devices", price:1100.00, status:"In Stock",    compat:"Aurora 100",      warranty:"1 year",   leadtime:"2 days"    },
      { id:"LAB-0203", desc:"Hematology Reagent Flow Cell",      oem:"Southridge Medical",          price:890.00,  status:"Low Stock",   compat:"Delta 268",           warranty:"6 months", leadtime:"1 week"    },
      { id:"LAB-0450", desc:"Autosampler Probe Assembly",        oem:"Consolidated Medical",           price:430.00,  status:"In Stock",    compat:"Ember 275",       warranty:"90 days",  leadtime:"Next day"  },
      { id:"LAB-0711", desc:"UV Lamp, 254nm Spectrophotometer",  oem:"VanArsdel Medical",   price:265.00,  status:"In Stock",    compat:"Apex 163", warranty:"90 days",  leadtime:"Same day"  },
      { id:"LAB-0980", desc:"PCR Thermal Cycler Lid Heater",     oem:"Adventure Works",         price:380.00,  status:"Low Stock",   compat:"Nimbus 121",       warranty:"6 months", leadtime:"4 days"    },
    ],
    cardio: [
      { id:"CDV-0052", desc:"Defibrillator Capacitor Pack",      oem:"Lamna Medical",            price:720.00,  status:"In Stock",    compat:"Vantage 212",          warranty:"2 years",  leadtime:"Same day"  },
      { id:"CDV-0140", desc:"AED Battery Module, Li-Ion",        oem:"Blue Yonder Health",         price:260.00,  status:"In Stock",    compat:"Quasar 177",    warranty:"2 years",  leadtime:"Next day"  },
      { id:"CDV-0388", desc:"IABP Drive Shaft Assembly",         oem:"Tailspin Instruments",       price:1840.00, status:"Backordered", compat:"Orbit 128",             warranty:"6 months", leadtime:"3 weeks"   },
    ],
  };

  const CHART_DATA = {
    labels: ["Imaging","Monitors","Surgical","Infusion","Lab","Cardio"],
    values: [284, 196, 157, 131, 220, 118],
    colors: ["#004B9B","#F5821F","#22c55e","#a855f7","#f59e0b","#ef4444"],
  };

  /* ── SharePoint context ─────────────────────────────────────── */
  // Detection via API probe rather than _spPageContextInfo, which is only
  // injected when SP renders through its master page engine — files served
  // directly from a document library do not receive it.
  let IN_SHAREPOINT  = false;
  let SP_SITE_URL    = null;
  let SP_USER        = "local\\dev";
  let SP_DATA_FOLDER = "sample_spa_data";

  // Derive site collection URL from the page URL — avoids hitting the tenant root.
  // SP Online sites live under /sites/ or /teams/; root site collections are at origin.
  function deriveSiteUrl() {
    const path = decodeURIComponent(window.location.pathname);
    const m    = path.match(/^(\/(?:sites|teams)\/[^\/]+)/i);
    return window.location.origin + (m ? m[1] : "");
  }

  async function initSpContext() {
    renderSpContext("probing");

    const siteUrl = deriveSiteUrl();   // correct site collection base, not tenant root

    try {
      const res = await fetch(siteUrl + "/_api/web?$select=Url,CurrentUser/LoginName&$expand=CurrentUser", {
        headers: { "Accept": "application/json;odata=verbose" },
        credentials: "include",
      });
      if (!res.ok) throw new Error("not SP");
      const data = await res.json();

      IN_SHAREPOINT  = true;
      SP_SITE_URL    = data.d.Url;
      SP_USER        = (data.d.CurrentUser && data.d.CurrentUser.LoginName) || "unknown";

      const rawPath  = decodeURIComponent(window.location.pathname);
      SP_DATA_FOLDER = rawPath.substring(0, rawPath.lastIndexOf("/"));
    } catch (_) {
      IN_SHAREPOINT  = false;
    }

    renderSpContext();
    updateJsonPreview();
  }

  /* ── App state ─────────────────────────────────────────────── */
  let currentCatId = null;
  let currentParts = [];
  let sortCol      = -1;
  let sortAsc      = true;
  let selectedPart = null;
  let order        = [];      // items added to current order
  let lastSaved    = null;

  /* ── Toast ─────────────────────────────────────────────────── */
  let toastTimer = null;
  function showToast(msg, type) {
    const el = document.getElementById("toast");
    el.textContent = msg;
    el.className   = "toast " + (type || "info") + " show";
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("show"), 3000);
  }

  /* ── Routing / breadcrumb ───────────────────────────────────── */
  const VIEWS = { dashboard: "view-dashboard", category: "view-category" };

  function navigate(viewId, catId) {
    Object.values(VIEWS).forEach(id => document.getElementById(id).classList.remove("active"));

    if (catId) { currentCatId = catId; loadCategory(catId); }

    const target = document.getElementById(VIEWS[viewId]);
    target.style.animation = "none";
    target.offsetHeight;
    target.style.animation = "";
    target.classList.add("active");

    renderBreadcrumb(viewId, catId);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function renderBreadcrumb(viewId, catId) {
    const bc    = document.getElementById("breadcrumb");
    const parts = [];

    if (viewId === "dashboard") {
      parts.push({ label: "Dashboard", active: true });
    } else if (viewId === "category") {
      const cat = CATEGORIES.find(c => c.id === catId);
      parts.push({ label: "Dashboard",       active: false, action: () => navigate("dashboard") });
      parts.push({ label: "Product Catalog", active: false, action: () => navigate("dashboard") });
      parts.push({ label: cat ? cat.name : "", active: true });
    }

    bc.innerHTML = parts.map((p, i) => {
      const sep = i > 0 ? `<span class="bc-sep">›</span>` : "";
      if (p.active) return `${sep}<span class="bc-item active">${p.label}</span>`;
      return `${sep}<span class="bc-item" onclick="(${p.action.toString()})()">${p.label}</span>`;
    }).join("");
  }

  /* ── Category grid ─────────────────────────────────────────── */
  function renderCatGrid() {
    document.getElementById("cat-grid").innerHTML = CATEGORIES.map(c => `
      <div class="cat-card" onclick="navigate('category','${c.id}')">
        <div class="cat-icon-badge" style="background:${c.color}">${c.abbr}</div>
        <div class="cat-name">${c.name}</div>
        <div class="cat-count">${c.count} parts available</div>
      </div>`).join("");
  }

  /* ── Table ─────────────────────────────────────────────────── */
  function loadCategory(catId) {
    const cat = CATEGORIES.find(c => c.id === catId);
    document.getElementById("cat-title").textContent    = cat.name;
    document.getElementById("cat-subtitle").textContent = `Showing ${PARTS_DB[catId].length} parts in this category.`;
    document.getElementById("table-search").value  = "";
    document.getElementById("status-filter").value = "";
    sortCol = -1; sortAsc = true;
    ["si-0","si-1","si-2","si-3","si-4"].forEach(id => {
      const el = document.getElementById(id);
      if (el) el.textContent = "⇅";
    });
    document.querySelectorAll("thead th").forEach(th => th.classList.remove("sorted"));
    currentParts = [...PARTS_DB[catId]];
    renderTable(currentParts);
  }

  function renderTable(rows) {
    const tbody = document.getElementById("parts-tbody");
    const empty = document.getElementById("empty-state");
    document.getElementById("row-count").textContent = `${rows.length} part${rows.length !== 1 ? "s" : ""}`;

    if (rows.length === 0) { tbody.innerHTML = ""; empty.style.display = ""; return; }
    empty.style.display = "none";
    tbody.innerHTML = rows.map(p => {
      const badge = p.status === "In Stock" ? "badge-green" : p.status === "Low Stock" ? "badge-yellow" : "badge-red";
      return `<tr onclick="openModal('${p.id}')">
        <td><strong>${p.id}</strong></td>
        <td>${p.desc}</td>
        <td>${p.oem}</td>
        <td>$${p.price.toLocaleString("en-US", {minimumFractionDigits:2})}</td>
        <td><span class="badge ${badge}">${p.status}</span></td>
      </tr>`;
    }).join("");
  }

  function sortTable(col) {
    if (sortCol === col) sortAsc = !sortAsc; else { sortCol = col; sortAsc = true; }
    ["si-0","si-1","si-2","si-3","si-4"].forEach((id, i) => {
      const el = document.getElementById(id);
      const th = el?.closest("th");
      if (i === col) { el.textContent = sortAsc ? "▲" : "▼"; th?.classList.add("sorted"); }
      else           { el.textContent = "⇅";                  th?.classList.remove("sorted"); }
    });
    const keys = ["id","desc","oem","price","status"];
    const key  = keys[col];
    const m    = sortAsc ? 1 : -1;
    const rows = getFiltered();
    rows.sort((a,b) => typeof a[key] === "number" ? (a[key]-b[key])*m : a[key].localeCompare(b[key])*m);
    renderTable(rows);
  }

  function getFiltered() {
    const q      = document.getElementById("table-search").value.toLowerCase();
    const status = document.getElementById("status-filter").value;
    return currentParts.filter(p => {
      const matchQ = !q || p.id.toLowerCase().includes(q) || p.desc.toLowerCase().includes(q) || p.oem.toLowerCase().includes(q);
      return matchQ && (!status || p.status === status);
    });
  }

  function filterTable() {
    const rows = getFiltered();
    if (sortCol >= 0) {
      const keys = ["id","desc","oem","price","status"];
      const key  = keys[sortCol];
      const m    = sortAsc ? 1 : -1;
      rows.sort((a,b) => typeof a[key] === "number" ? (a[key]-b[key])*m : a[key].localeCompare(b[key])*m);
    }
    renderTable(rows);
  }

  /* ── Modal ─────────────────────────────────────────────────── */
  function openModal(partId) {
    const all = Object.values(PARTS_DB).flat();
    selectedPart = all.find(p => p.id === partId);
    if (!selectedPart) return;

    document.getElementById("modal-title").textContent = selectedPart.id;
    const alreadyAdded = order.some(o => o.id === selectedPart.id);
    document.getElementById("modal-body").innerHTML = `
      <div class="modal-row"><span class="modal-label">Description</span><span class="modal-val">${selectedPart.desc}</span></div>
      <div class="modal-row"><span class="modal-label">OEM Manufacturer</span><span class="modal-val">${selectedPart.oem}</span></div>
      <div class="modal-row"><span class="modal-label">Unit Price</span><span class="modal-val">$${selectedPart.price.toLocaleString("en-US",{minimumFractionDigits:2})}</span></div>
      <div class="modal-row"><span class="modal-label">Availability</span>
        <span class="modal-val">
          <span class="badge ${selectedPart.status==="In Stock"?"badge-green":selectedPart.status==="Low Stock"?"badge-yellow":"badge-red"}">${selectedPart.status}</span>
        </span>
      </div>
      <div class="modal-row"><span class="modal-label">Compatibility</span><span class="modal-val">${selectedPart.compat}</span></div>
      <div class="modal-row"><span class="modal-label">Warranty</span><span class="modal-val">${selectedPart.warranty}</span></div>
      <div class="modal-row"><span class="modal-label">Lead Time</span><span class="modal-val">${selectedPart.leadtime}</span></div>
      ${alreadyAdded ? '<div style="margin-top:8px"><span class="badge badge-blue">Already in order</span></div>' : ""}
    `;
    const addBtn = document.querySelector(".modal-footer .btn-orange");
    addBtn.textContent = alreadyAdded ? "Add Again" : "Add to Order";
    document.getElementById("modal-overlay").classList.add("open");
  }

  function closeModal(e) {
    if (e && e.target !== document.getElementById("modal-overlay")) return;
    document.getElementById("modal-overlay").classList.remove("open");
    selectedPart = null;
  }

  /* ── Order management ──────────────────────────────────────── */
  function addToOrder() {
    if (!selectedPart) return;
    order.push({ ...selectedPart, addedAt: new Date().toISOString() });
    renderOrderTray();

    const btn = document.querySelector(".modal-footer .btn-orange");
    const orig = btn.textContent;
    btn.textContent = "✓ Added!";
    btn.style.background = "#22c55e";
    setTimeout(() => {
      btn.textContent = orig;
      btn.style.background = "";
      closeModal();
    }, 1000);
    showToast(`${selectedPart.id} added to order`, "success");
  }

  function removeFromOrder(idx) {
    const removed = order.splice(idx, 1)[0];
    renderOrderTray();
    showToast(`${removed.id} removed`, "info");
  }

  function clearOrder() {
    order = [];
    renderOrderTray();
    showToast("Order cleared", "info");
  }

  function renderOrderTray() {
    const tray     = document.getElementById("order-tray");
    const clearBtn = document.getElementById("btn-clear-order");

    if (order.length === 0) {
      tray.innerHTML = `<div class="order-empty">No items yet — browse a category and add parts.</div>`;
      clearBtn.style.display = "none";
      return;
    }

    clearBtn.style.display = "";
    const total = order.reduce((s, p) => s + p.price, 0);
    tray.innerHTML = `
      <div class="order-list">
        ${order.map((p, i) => `
          <div class="order-item">
            <span class="order-item-id">${p.id}</span>
            <span class="order-item-desc">${p.desc}</span>
            <span class="order-item-price">$${p.price.toLocaleString("en-US",{minimumFractionDigits:2})}</span>
            <button class="order-item-remove" onclick="removeFromOrder(${i})" title="Remove">×</button>
          </div>`).join("")}
      </div>
      <div class="order-total">
        <span>Order Total</span>
        <span>$${total.toLocaleString("en-US",{minimumFractionDigits:2})}</span>
      </div>`;

    updateJsonPreview();
  }

  /* ── SharePoint serialization ──────────────────────────────── */

  // Fetch CSRF digest — credentials must be included so the session cookie is sent.
  async function getDigest() {
    const hidden = document.getElementById("__REQUESTDIGEST");
    if (hidden && hidden.value) return hidden.value;

    const res  = await fetch(SP_SITE_URL + "/_api/contextinfo", {
      method: "POST",
      credentials: "include",
      headers: { "Accept": "application/json;odata=verbose" },
    });
    const data = await res.json();
    return data.d.GetContextWebInformation.FormDigestValue;
  }

  // Encode a server-relative path for use inside SharePoint OData function parameters.
  // Slashes must stay as-is; only spaces and single-quotes need escaping.
  function spPath(p) { return p.replace(/'/g, "''").replace(/ /g, "%20"); }

  function buildPayload() {
    return {
      savedBy:   SP_USER,
      savedAt:   new Date().toISOString(),
      dataFolder: SP_DATA_FOLDER,
      itemCount:  order.length,
      total:      order.reduce((s, p) => s + p.price, 0),
      items:      order,
    };
  }

  function setStatus(msg, type) {
    const el = document.getElementById("sp-status-msg");
    el.textContent = msg;
    el.className   = "sp-status-msg " + (type || "");
  }

  async function saveOrder() {
    if (!IN_SHAREPOINT) {
      showToast("Not running in SharePoint — save unavailable", "error");
      setStatus("Not running inside SharePoint. Upload the .aspx to a document library first.", "err");
      return;
    }

    const btn = document.getElementById("btn-save");
    btn.disabled = true;
    setStatus("Saving…", "busy");

    try {
      const digest  = await getDigest();
      const payload = buildPayload();
      const body    = JSON.stringify(payload, null, 2);
      const fileUrl = `${SP_SITE_URL}/_api/web/getfolderbyserverrelativeurl('${spPath(SP_DATA_FOLDER)}')/files/add(overwrite=true,url='orders.json')`;

      const res = await fetch(fileUrl, {
        method: "POST",
        credentials: "include",
        headers: {
          "Accept":          "application/json;odata=verbose",
          "X-RequestDigest": digest,
        },
        body,
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      lastSaved = new Date();
      document.getElementById("sp-last-saved").textContent = lastSaved.toLocaleTimeString();
      updateJsonPreview();
      setStatus(`Saved ${order.length} item${order.length !== 1 ? "s" : ""} to ${SP_DATA_FOLDER}/orders.json`, "ok");
      showToast("Order saved to SharePoint", "success");
    } catch (err) {
      setStatus("Save failed: " + err.message, "err");
      showToast("Save failed — see status panel", "error");
    } finally {
      btn.disabled = false;
    }
  }

  async function loadOrder() {
    if (!IN_SHAREPOINT) {
      showToast("Not running in SharePoint — load unavailable", "error");
      setStatus("Not running inside SharePoint. Upload the .aspx to a document library first.", "err");
      return;
    }

    const btn = document.getElementById("btn-load");
    btn.disabled = true;
    setStatus("Loading…", "busy");

    try {
      const fileUrl = `${SP_SITE_URL}/_api/web/getfilebyserverrelativeurl('${spPath(SP_DATA_FOLDER + "/orders.json")}')/$value`;
      const res = await fetch(fileUrl, {
        credentials: "include",
        headers: { "Accept": "application/json" },
      });

      if (res.status === 404) throw new Error("orders.json not found — save an order first.");
      if (!res.ok)            throw new Error(`HTTP ${res.status}`);

      const payload = await res.json();
      order = payload.items || [];
      renderOrderTray();

      lastSaved = new Date(payload.savedAt);
      document.getElementById("sp-last-saved").textContent =
        `${lastSaved.toLocaleDateString()} ${lastSaved.toLocaleTimeString()} (by ${payload.savedBy})`;
      setStatus(`Loaded ${order.length} item${order.length !== 1 ? "s" : ""} saved by ${payload.savedBy}`, "ok");
      showToast("Order loaded from SharePoint", "success");
    } catch (err) {
      setStatus("Load failed: " + err.message, "err");
      showToast("Load failed — see status panel", "error");
    } finally {
      btn.disabled = false;
    }
  }

  /* ── JSON preview ───────────────────────────────────────────── */
  function updateJsonPreview() {
    const el = document.getElementById("json-preview");
    el.textContent = JSON.stringify(buildPayload(), null, 2);
  }

  function toggleJsonPreview() {
    const el = document.getElementById("json-preview");
    updateJsonPreview();
    el.classList.toggle("visible");
  }

  /* ── SP context UI ──────────────────────────────────────────── */
  function renderSpContext(state) {
    const banner = document.getElementById("sp-context-banner");
    document.getElementById("sp-folder-path").textContent  = SP_DATA_FOLDER;
    document.getElementById("sp-current-user").textContent = SP_USER;

    if (state === "probing") {
      banner.innerHTML = `
        <div class="sp-context-row sp-probing">
          <div class="sp-dot"></div>
          <span class="sp-context-text">
            <strong>Detecting SharePoint context...</strong>
            <small>Probing /_api/web — please wait.</small>
          </span>
        </div>`;
      document.getElementById("btn-save").disabled = true;
      document.getElementById("btn-load").disabled = true;
      return;
    }

    if (IN_SHAREPOINT) {
      banner.innerHTML = `
        <div class="sp-context-row sp-live">
          <div class="sp-dot"></div>
          <span class="sp-context-text">
            <strong>Running inside SharePoint</strong>
            <small>User session active &mdash; save/load use your existing permissions. Write access required on the document library.</small>
          </span>
        </div>`;
      document.getElementById("btn-save").disabled = false;
      document.getElementById("btn-load").disabled = false;
    } else {
      banner.innerHTML = `
        <div class="sp-context-row sp-local">
          <div class="sp-dot"></div>
          <span class="sp-context-text">
            <strong>Running locally (not in SharePoint)</strong>
            <small>Save and Load are disabled. Upload sample_spa.aspx to a SharePoint document library to activate serialization.</small>
          </span>
        </div>`;
      document.getElementById("btn-save").disabled = true;
      document.getElementById("btn-load").disabled = true;
    }
  }

  /* ── Chart ──────────────────────────────────────────────────── */
  function drawChart() {
    const canvas = document.getElementById("chart");
    const dpr    = window.devicePixelRatio || 1;
    const W      = canvas.parentElement.clientWidth;
    const H      = 220;
    canvas.width  = W * dpr;
    canvas.height = H * dpr;
    canvas.style.width  = W + "px";
    canvas.style.height = H + "px";
    const ctx = canvas.getContext("2d");
    ctx.scale(dpr, dpr);

    const padL = 40, padR = 20, padT = 20, padB = 50;
    const chartW = W - padL - padR;
    const chartH = H - padT - padB;
    const n      = CHART_DATA.values.length;
    const maxVal = Math.max(...CHART_DATA.values);
    const barW   = (chartW / n) * 0.55;
    const gap    = (chartW / n) * 0.45;

    ctx.strokeStyle = "#dde3ec"; ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = padT + chartH - (chartH * i / 4);
      ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(padL + chartW, y); ctx.stroke();
      ctx.fillStyle = "#6b7a90"; ctx.font = "11px system-ui"; ctx.textAlign = "right";
      ctx.fillText(Math.round(maxVal * i / 4), padL - 6, y + 4);
    }

    let progress = 0;
    function frame() {
      ctx.clearRect(padL, padT - 1, chartW, chartH + 2);
      ctx.strokeStyle = "#dde3ec"; ctx.lineWidth = 1;
      for (let i = 0; i <= 4; i++) {
        const y = padT + chartH - (chartH * i / 4);
        ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(padL + chartW, y); ctx.stroke();
      }
      CHART_DATA.values.forEach((val, i) => {
        const barH = (val / maxVal) * chartH * progress;
        const x    = padL + i * (barW + gap) + gap / 2;
        const y    = padT + chartH - barH;
        const grad = ctx.createLinearGradient(0, y, 0, padT + chartH);
        grad.addColorStop(0, CHART_DATA.colors[i]);
        grad.addColorStop(1, CHART_DATA.colors[i] + "88");
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.roundRect(x, y, barW, barH, [4, 4, 0, 0]);
        ctx.fill();
        ctx.fillStyle = "#1a2a3a"; ctx.font = "11px system-ui"; ctx.textAlign = "center";
        ctx.fillText(CHART_DATA.labels[i], x + barW / 2, padT + chartH + 16);
        if (progress === 1) {
          ctx.fillStyle = CHART_DATA.colors[i]; ctx.font = "bold 12px system-ui";
          ctx.fillText(val, x + barW / 2, y - 6);
        }
      });
      if (progress < 1) { progress = Math.min(1, progress + 0.035); requestAnimationFrame(frame); }
    }
    requestAnimationFrame(frame);
  }

  /* ── Init ──────────────────────────────────────────────────── */
  renderCatGrid();
  renderBreadcrumb("dashboard");
  initSpContext();   // async — probes /_api/web, then calls renderSpContext()
  window.addEventListener("load", drawChart);
  window.addEventListener("resize", drawChart);
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") document.getElementById("modal-overlay").classList.remove("open");
  });
</script>
</body>
</html>
