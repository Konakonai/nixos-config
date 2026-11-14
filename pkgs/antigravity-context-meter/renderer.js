(function () {
  'use strict';
  if (location.protocol !== 'https:' || location.hostname !== '127.0.0.1') return;

  globalThis.__AGContextMeter?.dispose?.();
  const Core = globalThis.__AGContextMeterCore;
  if (!Core) return;
  const { summarize, formatTokens, formatFull } = Core;

  const RING_R = 6;
  const RING_C = 2 * Math.PI * RING_R;

  const ICONS = {
    speed:
      '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/></svg>',
    chart:
      '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 3v18h18"/><path d="M7 16v-4"/><path d="M12 16V8"/><path d="M17 16v-6"/></svg>',
    refresh:
      '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a9 9 0 1 1-2.64-6.36"/><path d="M21 3v6h-6"/></svg>',
    close:
      '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>',
  };

  const CSS = `
    :host {
      position: fixed;
      top: 6px;
      right: 138px;
      z-index: 2147483000;
      display: inline-flex;
      align-items: center;
      gap: 2px;
      height: 28px;
      flex-shrink: 0;
      vertical-align: middle;
      user-select: none;
      -webkit-app-region: no-drag;
      font-family: inherit;
      font-size: 12px;
      line-height: 1.4;

      --cm-fallback-bg: #1e1e24;
      --cm-fallback-fg: #ececef;
      --cm-bg: var(--popover, var(--card, var(--background, var(--cm-fallback-bg))));
      --cm-fg: var(--popover-foreground, var(--foreground, var(--cm-fallback-fg)));
      --cm-muted: var(--muted-foreground, var(--secondary-foreground, color-mix(in srgb, var(--cm-fg) 60%, transparent)));
      --cm-border: var(--border, color-mix(in srgb, var(--cm-fg) 12%, transparent));
      --cm-card: var(--card, color-mix(in srgb, var(--cm-fg) 4%, var(--cm-bg)));
      --cm-hover: var(--accent, var(--secondary, color-mix(in srgb, var(--cm-fg) 8%, transparent)));
      --cm-track: color-mix(in srgb, var(--cm-fg) 14%, transparent);
      --cm-primary: var(--primary, #7c5cfa);
      --cm-primary-fg: var(--primary-foreground, #ffffff);
      --cm-warn: #f59e0b;
      --cm-danger: var(--destructive, #ef4444);
      --cm-ok: #22c55e;
      --cm-shadow: 0 10px 30px rgba(0, 0, 0, 0.28), 0 2px 8px rgba(0, 0, 0, 0.14);

      color: var(--cm-fg);
      color-scheme: dark;
    }

    :host([data-tone="light"]) {
      --cm-fallback-bg: #ffffff;
      --cm-fallback-fg: #18181b;
      --cm-warn: #d97706;
      --cm-danger: var(--destructive, #dc2626);
      --cm-ok: #16a34a;
      --cm-shadow: 0 10px 28px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.06);
      color-scheme: light;
    }

    :host([data-dock="flow"]) {
      position: relative !important;
      top: auto !important;
      right: auto !important;
      left: auto !important;
      bottom: auto !important;
      z-index: 20;
      margin-right: 4px;
    }

    :host([data-window-active="false"]) .cm-pill {
      opacity: 0.72;
    }

    * { box-sizing: border-box; }

    .cm-bar {
      display: inline-flex;
      align-items: center;
      gap: 2px;
    }

    .cm-pill {
      appearance: none;
      border: 1px solid transparent;
      background: transparent;
      color: var(--cm-muted);
      height: 26px;
      padding: 0 7px;
      border-radius: 6px;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font: inherit;
      font-size: 11.5px;
      font-weight: 500;
      font-variant-numeric: tabular-nums;
      cursor: pointer;
      transition: background-color 120ms ease, color 120ms ease, border-color 120ms ease;
      white-space: nowrap;
    }

    .cm-pill:hover,
    .cm-pill:focus-visible,
    .cm-pill[aria-expanded="true"] {
      background: var(--cm-hover);
      color: var(--cm-fg);
      outline: none;
    }

    .cm-pill[hidden] {
      display: none !important;
    }

    .cm-pill[data-level="warn"] {
      color: var(--cm-warn);
    }

    .cm-pill[data-level="danger"] {
      color: var(--cm-danger);
    }

    .cm-ring {
      display: block;
      flex-shrink: 0;
    }

    .cm-ring-track {
      stroke: var(--cm-track);
    }

    .cm-ring-fill {
      stroke: var(--cm-primary);
      transition: stroke-dashoffset 220ms ease, stroke 180ms ease;
    }

    .cm-pill[data-level="warn"] .cm-ring-fill {
      stroke: var(--cm-warn);
    }

    .cm-pill[data-level="danger"] .cm-ring-fill {
      stroke: var(--cm-danger);
    }

    :host([data-compact="true"]) .cm-hide-compact {
      display: none;
    }

    .cm-tooltip {
      position: fixed;
      z-index: 2147483002;
      pointer-events: none;
      background: var(--cm-bg);
      color: var(--cm-fg);
      border: 1px solid var(--cm-border);
      border-radius: 8px;
      padding: 7px 10px;
      box-shadow: var(--cm-shadow);
      font-size: 11px;
      line-height: 1.45;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
      opacity: 0;
      transform: translateY(-3px);
      transition: opacity 120ms ease, transform 120ms ease;
    }

    .cm-tooltip[data-visible="true"] {
      opacity: 1;
      transform: translateY(0);
    }

    .cm-tip-title {
      font-weight: 600;
      color: var(--cm-fg);
    }

    .cm-tip-sub {
      color: var(--cm-muted);
      margin-top: 1px;
    }

    .cm-panel {
      position: fixed;
      z-index: 2147483001;
      width: 336px;
      max-width: calc(100vw - 16px);
      background: var(--cm-bg);
      color: var(--cm-fg);
      border: 1px solid var(--cm-border);
      border-radius: 10px;
      box-shadow: var(--cm-shadow);
      padding: 10px;
      font-variant-numeric: tabular-nums;
    }

    .cm-panel[hidden] {
      display: none !important;
    }

    .cm-panel-hdr {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 10px;
    }

    .cm-tabs {
      display: inline-flex;
      padding: 2px;
      border-radius: 7px;
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      gap: 2px;
    }

    .cm-tab {
      appearance: none;
      border: none;
      background: transparent;
      color: var(--cm-muted);
      font: inherit;
      font-size: 11.5px;
      font-weight: 500;
      padding: 3px 10px;
      border-radius: 5px;
      cursor: pointer;
      transition: background-color 120ms ease, color 120ms ease;
    }

    .cm-tab:hover {
      color: var(--cm-fg);
    }

    .cm-tab[aria-selected="true"] {
      background: var(--cm-hover);
      color: var(--cm-fg);
    }

    .cm-hdr-actions {
      display: inline-flex;
      align-items: center;
      gap: 2px;
    }

    .cm-icon-btn {
      appearance: none;
      border: none;
      background: transparent;
      color: var(--cm-muted);
      width: 24px;
      height: 24px;
      border-radius: 6px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: background-color 120ms ease, color 120ms ease;
    }

    .cm-icon-btn:hover {
      background: var(--cm-hover);
      color: var(--cm-fg);
    }

    .cm-icon-btn[data-spinning="true"] svg {
      animation: cm-spin 0.8s linear infinite;
    }

    @keyframes cm-spin {
      to { transform: rotate(360deg); }
    }

    .cm-meta-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 8px;
    }

    .cm-model-name {
      font-size: 11.5px;
      font-weight: 600;
      color: var(--cm-fg);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      min-width: 0;
    }

    .cm-badge {
      flex-shrink: 0;
      font-size: 10.5px;
      font-weight: 500;
      padding: 1px 7px;
      border-radius: 999px;
      border: 1px solid var(--cm-border);
      color: var(--cm-muted);
      background: var(--cm-card);
    }

    .cm-badge[data-tone="ok"] {
      color: var(--cm-ok);
      border-color: color-mix(in srgb, var(--cm-ok) 35%, transparent);
    }

    .cm-badge[data-tone="warn"] {
      color: var(--cm-warn);
      border-color: color-mix(in srgb, var(--cm-warn) 35%, transparent);
    }

    .cm-badge[data-tone="danger"] {
      color: var(--cm-danger);
      border-color: color-mix(in srgb, var(--cm-danger) 35%, transparent);
    }

    .cm-hero-card {
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      border-radius: 8px;
      padding: 10px 11px;
      margin-bottom: 8px;
    }

    .cm-hero-top {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 7px;
    }

    .cm-hero-val {
      font-size: 18px;
      font-weight: 600;
      color: var(--cm-fg);
      letter-spacing: -0.02em;
    }

    .cm-hero-budget {
      font-size: 11.5px;
      font-weight: 400;
      color: var(--cm-muted);
      margin-left: 4px;
    }

    .cm-hero-pct {
      font-size: 13px;
      font-weight: 600;
      color: var(--cm-primary);
    }

    .cm-hero-pct[data-level="warn"] { color: var(--cm-warn); }
    .cm-hero-pct[data-level="danger"] { color: var(--cm-danger); }

    .cm-bar-track {
      height: 5px;
      border-radius: 999px;
      background: var(--cm-track);
      overflow: hidden;
      margin-bottom: 6px;
    }

    .cm-bar-fill {
      height: 100%;
      width: 0%;
      border-radius: 999px;
      background: var(--cm-primary);
      transition: width 220ms ease, background-color 180ms ease;
    }

    .cm-bar-fill[data-level="warn"] { background: var(--cm-warn); }
    .cm-bar-fill[data-level="danger"] { background: var(--cm-danger); }

    .cm-hero-sub {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      color: var(--cm-muted);
    }

    .cm-alert {
      background: color-mix(in srgb, var(--cm-danger) 10%, var(--cm-bg));
      border: 1px solid color-mix(in srgb, var(--cm-danger) 30%, transparent);
      color: var(--cm-danger);
      border-radius: 8px;
      padding: 7px 9px;
      font-size: 11px;
      margin-bottom: 8px;
      line-height: 1.4;
      word-break: break-word;
    }

    .cm-grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 6px;
    }

    .cm-grid-3 {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 6px;
      margin-bottom: 8px;
    }

    .cm-stat-card {
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      border-radius: 8px;
      padding: 8px 9px;
      min-width: 0;
    }

    .cm-stat-lbl {
      font-size: 10.5px;
      color: var(--cm-muted);
      margin-bottom: 2px;
    }

    .cm-stat-val {
      font-size: 13.5px;
      font-weight: 600;
      color: var(--cm-fg);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .cm-stat-sub {
      font-size: 10px;
      color: var(--cm-muted);
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .cm-empty {
      padding: 18px 8px;
      text-align: center;
      color: var(--cm-muted);
      font-size: 11.5px;
    }

    .cm-src-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      margin-bottom: 8px;
    }

    .cm-seg {
      display: inline-flex;
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      border-radius: 6px;
      padding: 2px;
      gap: 2px;
    }

    .cm-seg-btn {
      appearance: none;
      border: none;
      background: transparent;
      color: var(--cm-muted);
      font: inherit;
      font-size: 10.5px;
      font-weight: 500;
      padding: 2px 8px;
      border-radius: 4px;
      cursor: pointer;
    }

    .cm-seg-btn[aria-pressed="true"] {
      background: var(--cm-hover);
      color: var(--cm-fg);
    }

    .cm-mix-card {
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      border-radius: 8px;
      padding: 8px 10px;
      margin-bottom: 8px;
    }

    .cm-mix-bar {
      display: flex;
      height: 5px;
      border-radius: 999px;
      overflow: hidden;
      background: var(--cm-track);
      gap: 1px;
      margin: 5px 0 6px;
    }

    .cm-mix-seg-in { background: var(--cm-primary); }
    .cm-mix-seg-cache { background: color-mix(in srgb, var(--cm-primary) 45%, var(--cm-track)); }
    .cm-mix-seg-out { background: var(--cm-warn); }

    .cm-mix-legend {
      display: flex;
      justify-content: space-between;
      gap: 6px;
      font-size: 10.5px;
      color: var(--cm-muted);
    }

    .cm-mix-dot {
      display: inline-block;
      width: 6px;
      height: 6px;
      border-radius: 50%;
      margin-right: 4px;
      vertical-align: middle;
    }

    .cm-spark-card {
      background: var(--cm-card);
      border: 1px solid var(--cm-border);
      border-radius: 8px;
      padding: 8px 10px;
    }

    .cm-spark-hdr {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 10.5px;
      color: var(--cm-muted);
      margin-bottom: 7px;
      gap: 6px;
    }

    .cm-spark-hover {
      color: var(--cm-fg);
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .cm-spark-bars {
      display: grid;
      grid-template-columns: repeat(14, 1fr);
      align-items: end;
      gap: 3px;
      height: 44px;
    }

    .cm-spark-col {
      height: 100%;
      display: flex;
      align-items: flex-end;
      cursor: pointer;
    }

    .cm-spark-bar {
      width: 100%;
      min-height: 2px;
      border-radius: 2px 2px 1px 1px;
      background: color-mix(in srgb, var(--cm-primary) 45%, var(--cm-track));
      transition: background-color 100ms ease, opacity 100ms ease;
    }

    .cm-spark-col[data-today="true"] .cm-spark-bar,
    .cm-spark-col:hover .cm-spark-bar {
      background: var(--cm-primary);
    }

    .cm-spark-axis {
      display: flex;
      justify-content: space-between;
      font-size: 9.5px;
      color: var(--cm-muted);
      margin-top: 4px;
    }
  `;

  const TEMPLATE = `
    <div class="cm-bar">
      <button id="cm-ctx-btn" class="cm-pill" type="button" aria-label="上下文窗口占用" aria-expanded="false" hidden>
        <svg class="cm-ring" width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
          <circle class="cm-ring-track" cx="8" cy="8" r="${RING_R}" fill="none" stroke-width="2"></circle>
          <circle id="cm-ring-fill" class="cm-ring-fill" cx="8" cy="8" r="${RING_R}" fill="none" stroke-width="2" stroke-linecap="round" transform="rotate(-90 8 8)" stroke-dasharray="${RING_C.toFixed(2)}" stroke-dashoffset="${RING_C.toFixed(2)}"></circle>
        </svg>
        <span id="cm-ctx-pct">--%</span>
      </button>
      <button id="cm-spd-btn" class="cm-pill cm-hide-compact" type="button" aria-label="输出速度" aria-expanded="false" hidden>
        ${ICONS.speed}
        <span id="cm-spd-val">-- tok/s</span>
      </button>
      <button id="cm-tok-btn" class="cm-pill" type="button" aria-label="Token 历史统计" aria-expanded="false">
        ${ICONS.chart}
        <span id="cm-tok-val" class="cm-hide-compact">--</span>
      </button>
    </div>

    <div id="cm-tooltip" class="cm-tooltip" role="tooltip" data-visible="false">
      <div id="cm-tip-title" class="cm-tip-title"></div>
      <div id="cm-tip-sub" class="cm-tip-sub"></div>
    </div>

    <section id="cm-panel" class="cm-panel" hidden aria-label="上下文与用量详情">
      <div class="cm-panel-hdr">
        <div class="cm-tabs" role="tablist">
          <button id="cm-tab-ctx" class="cm-tab" type="button" role="tab" aria-selected="true">上下文</button>
          <button id="cm-tab-tok" class="cm-tab" type="button" role="tab" aria-selected="false">历史用量</button>
        </div>
        <div class="cm-hdr-actions">
          <button id="cm-refresh-btn" class="cm-icon-btn" type="button" aria-label="刷新" title="刷新">${ICONS.refresh}</button>
          <button id="cm-close-btn" class="cm-icon-btn" type="button" aria-label="关闭" title="关闭">${ICONS.close}</button>
        </div>
      </div>

      <div id="cm-pane-ctx">
        <div id="cm-ctx-empty" class="cm-empty" hidden>进入对话后可查看当前上下文与生成速度</div>
        <div id="cm-ctx-body">
          <div class="cm-meta-row">
            <span id="cm-model" class="cm-model-name">—</span>
            <span id="cm-status-badge" class="cm-badge">等待统计</span>
          </div>
          <div class="cm-hero-card">
            <div class="cm-hero-top">
              <div>
                <span id="cm-used" class="cm-hero-val">—</span>
                <span id="cm-budget" class="cm-hero-budget"></span>
              </div>
              <span id="cm-pct-big" class="cm-hero-pct">—</span>
            </div>
            <div class="cm-bar-track"><div id="cm-bar-fill" class="cm-bar-fill"></div></div>
            <div class="cm-hero-sub">
              <span id="cm-remaining">剩余 —</span>
              <span id="cm-source-note">—</span>
            </div>
          </div>
          <div id="cm-alert" class="cm-alert" hidden></div>
          <div class="cm-grid-2">
            <div class="cm-stat-card">
              <div class="cm-stat-lbl">缓存命中</div>
              <div id="cm-cache-val" class="cm-stat-val">—</div>
              <div id="cm-cache-sub" class="cm-stat-sub">—</div>
            </div>
            <div class="cm-stat-card">
              <div class="cm-stat-lbl">输出速度</div>
              <div id="cm-tps-val" class="cm-stat-val">—</div>
              <div id="cm-tps-sub" class="cm-stat-sub">—</div>
            </div>
            <div class="cm-stat-card">
              <div class="cm-stat-lbl">首字 / 耗时</div>
              <div id="cm-ttft-val" class="cm-stat-val">—</div>
              <div id="cm-ttft-sub" class="cm-stat-sub">—</div>
            </div>
            <div class="cm-stat-card">
              <div class="cm-stat-lbl">本轮输出</div>
              <div id="cm-out-val" class="cm-stat-val">—</div>
              <div id="cm-out-sub" class="cm-stat-sub">—</div>
            </div>
          </div>
        </div>
      </div>

      <div id="cm-pane-tok" hidden>
        <div class="cm-src-bar">
          <div class="cm-seg" role="group" aria-label="来源筛选">
            <button class="cm-seg-btn" data-src="all" aria-pressed="true" type="button">全部</button>
            <button class="cm-seg-btn" data-src="desktop" aria-pressed="false" type="button">桌面</button>
            <button class="cm-seg-btn" data-src="cli" aria-pressed="false" type="button">CLI</button>
          </div>
          <span id="cm-hist-steps" style="font-size:10.5px;color:var(--cm-muted)">—</span>
        </div>

        <div class="cm-grid-3">
          <div class="cm-stat-card">
            <div class="cm-stat-lbl">今日</div>
            <div id="cm-hist-today" class="cm-stat-val">—</div>
          </div>
          <div class="cm-stat-card">
            <div class="cm-stat-lbl">本月</div>
            <div id="cm-hist-month" class="cm-stat-val">—</div>
          </div>
          <div class="cm-stat-card">
            <div class="cm-stat-lbl">累计</div>
            <div id="cm-hist-total" class="cm-stat-val">—</div>
          </div>
        </div>

        <div class="cm-mix-card">
          <div style="display:flex;justify-content:space-between;font-size:10.5px;color:var(--cm-muted)">
            <span>Token 构成</span>
            <span id="cm-mix-cache-pct">—</span>
          </div>
          <div class="cm-mix-bar">
            <div id="cm-mix-in" class="cm-mix-seg-in" style="width:0%"></div>
            <div id="cm-mix-cache" class="cm-mix-seg-cache" style="width:0%"></div>
            <div id="cm-mix-out" class="cm-mix-seg-out" style="width:0%"></div>
          </div>
          <div class="cm-mix-legend">
            <span><i class="cm-mix-dot" style="background:var(--cm-primary)"></i>输入 <span id="cm-mix-in-val">—</span></span>
            <span><i class="cm-mix-dot" style="background:color-mix(in srgb,var(--cm-primary) 45%,var(--cm-track))"></i>缓存 <span id="cm-mix-cache-val">—</span></span>
            <span><i class="cm-mix-dot" style="background:var(--cm-warn)"></i>输出 <span id="cm-mix-out-val">—</span></span>
          </div>
        </div>

        <div class="cm-spark-card">
          <div class="cm-spark-hdr">
            <span>近 14 日</span>
            <span id="cm-spark-hover" class="cm-spark-hover">悬浮查看明细</span>
          </div>
          <div id="cm-spark-bars" class="cm-spark-bars"></div>
          <div class="cm-spark-axis">
            <span id="cm-spark-start">—</span>
            <span id="cm-spark-end">今日</span>
          </div>
        </div>
      </div>
    </section>
  `;

  const host = document.createElement('div');
  host.id = 'ag-context-meter';
  host.setAttribute('data-dock', 'fixed');
  host.setAttribute('data-tone', 'dark');
  host.setAttribute('data-window-active', 'true');
  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = `<style>${CSS}</style>${TEMPLATE}`;
  (document.body || document.documentElement).appendChild(host);

  const el = (id) => shadow.getElementById(id);

  const state = {
    route: null,
    count: 0,
    latest: null,
    requestError: '',
    requestBusy: false,
    requestNext: 0,
    generation: 0,
    controllers: new Set(),
    panelOpen: false,
    activeTab: 'ctx',
    sourceFilter: 'all',
    history: null,
    historyBusy: false,
    lastHistoryAt: 0,
    disposed: false,
  };

  const getRouteId = () => location.pathname.match(/^\/c\/([a-f\d-]{36})(?:\/|$)/i)?.[1] || null;

  function detectHostTone() {
    try {
      const root = document.documentElement;
      const body = document.body;
      if (body?.classList?.contains('light') || root?.classList?.contains('light')) return 'light';
      if (body?.classList?.contains('dark') || root?.classList?.contains('dark')) return 'dark';
      const cs = getComputedStyle(body || root);
      const raw = cs.getPropertyValue('--background')?.trim() || '';
      const bg = raw || (cs.backgroundColor && cs.backgroundColor !== 'rgba(0, 0, 0, 0)' ? cs.backgroundColor : '');
      if (bg) {
        const probe = document.createElement('span');
        probe.style.color = bg;
        probe.style.display = 'none';
        (body || root).appendChild(probe);
        const rgb = getComputedStyle(probe).color.match(/\d+/g);
        probe.remove();
        if (rgb && rgb.length >= 3) {
          const lum = (0.299 * Number(rgb[0]) + 0.587 * Number(rgb[1]) + 0.114 * Number(rgb[2])) / 255;
          return lum > 0.55 ? 'light' : 'dark';
        }
      }
      if (cs.colorScheme === 'light') return 'light';
      if (cs.colorScheme === 'dark') return 'dark';
    } catch {}
    return 'dark';
  }

  function syncTheme() {
    host.setAttribute('data-tone', detectHostTone());
  }

  function findTitlebar() {
    try {
      return document.querySelector('[class*="@container/titlebar"]');
    } catch {
      return null;
    }
  }

  function dockHost() {
    if (state.disposed) return;
    const titlebar = findTitlebar();
    if (titlebar) {
      let target = titlebar;
      const rightGroup = titlebar.querySelector(':scope > div.shrink-0') || titlebar.lastElementChild;
      if (rightGroup && rightGroup !== titlebar.firstElementChild) {
        target = rightGroup;
      }
      if (host.parentElement !== target) {
        if (target !== titlebar && target.firstChild) target.insertBefore(host, target.firstChild);
        else target.appendChild(host);
      }
      host.setAttribute('data-dock', 'flow');
      host.style.right = '';
      host.style.top = '';
      const tbRect = titlebar.getBoundingClientRect?.();
      if (tbRect && tbRect.width > 0) {
        const titleW = titlebar.firstElementChild?.scrollWidth || 160;
        const avail = tbRect.width - Math.min(280, Math.max(140, titleW)) - 80;
        host.setAttribute('data-compact', avail < 150 ? 'true' : 'false');
      }
    } else {
      const parent = document.body || document.documentElement;
      if (parent && host.parentElement !== parent) parent.appendChild(host);
      host.setAttribute('data-dock', 'fixed');
      host.style.top = '6px';
      host.style.right = '140px';
      host.setAttribute('data-compact', window.innerWidth < 640 ? 'true' : 'false');
    }
    if (state.panelOpen) positionPanel();
  }

  function positionPanel() {
    const panel = el('cm-panel');
    if (!panel || panel.hidden) return;
    const anchor =
      (!el('cm-ctx-btn').hidden && el('cm-ctx-btn')) ||
      (!el('cm-tok-btn').hidden && el('cm-tok-btn')) ||
      host;
    const rect = anchor.getBoundingClientRect();
    const w = panel.offsetWidth || 336;
    const h = panel.offsetHeight || 300;
    const left = Math.max(8, Math.min(window.innerWidth - w - 8, rect.right - w));
    const top = Math.max(8, Math.min(window.innerHeight - h - 8, rect.bottom + 6));
    panel.style.left = `${Math.round(left)}px`;
    panel.style.top = `${Math.round(top)}px`;
  }

  function showTooltip() {
    const d = state.latest;
    const btn = el('cm-ctx-btn');
    const tip = el('cm-tooltip');
    if (!d || !btn || btn.hidden || state.panelOpen) return;

    const pctStr = d.exceeded ? '超限' : d.percent != null ? `${d.percent.toFixed(1)}%` : '—';
    const usedStr = d.used != null ? `${formatTokens(d.used)} / ${formatTokens(d.budget)}` : '等待统计';
    el('cm-tip-title').textContent = `上下文 ${pctStr} · ${usedStr}${d.estimated ? ' (估算)' : ''}`;

    const parts = [];
    if (d.cacheHit != null) parts.push(`缓存命中 ${d.cacheHit}%`);
    if (d.model) parts.push(d.model);
    el('cm-tip-sub').textContent = parts.join(' · ') || '等待请求返回';

    const r = btn.getBoundingClientRect();
    tip.style.top = `${Math.round(r.bottom + 6)}px`;
    const tipLeft = Math.max(8, Math.min(window.innerWidth - 260, r.left));
    tip.style.left = `${Math.round(tipLeft)}px`;
    tip.setAttribute('data-visible', 'true');
  }

  function hideTooltip() {
    el('cm-tooltip')?.setAttribute('data-visible', 'false');
  }

  function levelFor(d) {
    if (!d) return 'normal';
    if (d.exceeded || (d.percent != null && d.percent >= 85)) return 'danger';
    if (d.percent != null && d.percent >= 70) return 'warn';
    return 'normal';
  }

  function renderCapsules() {
    const inChat = Boolean(state.route);
    const d = state.latest;
    const ctxBtn = el('cm-ctx-btn');
    const spdBtn = el('cm-spd-btn');
    const tokBtn = el('cm-tok-btn');

    ctxBtn.hidden = !inChat;
    if (inChat) {
      const lvl = levelFor(d);
      ctxBtn.setAttribute('data-level', lvl);
      const pct = d?.exceeded ? 100 : d?.percent ?? 0;
      const clamped = Math.max(0, Math.min(100, pct));
      el('cm-ring-fill').style.strokeDashoffset = (RING_C * (1 - clamped / 100)).toFixed(2);
      el('cm-ctx-pct').textContent = d?.exceeded
        ? '超限'
        : d?.percent != null
          ? `${d.estimated ? '~' : ''}${Math.round(d.percent)}%`
          : '--%';
    }

    const tps = d?.speed?.tps;
    spdBtn.hidden = !inChat || tps == null;
    if (!spdBtn.hidden) {
      el('cm-spd-val').textContent = `${tps >= 100 ? Math.round(tps) : tps.toFixed(1)} tok/s`;
    }

    const hist = state.history?.sources?.all;
    const tokNum = hist ? (hist.today > 0 ? hist.today : hist.total) : null;
    el('cm-tok-val').textContent = tokNum != null ? formatTokens(tokNum) : '--';

    ctxBtn.setAttribute('aria-expanded', String(state.panelOpen && state.activeTab === 'ctx'));
    spdBtn.setAttribute('aria-expanded', String(state.panelOpen && state.activeTab === 'ctx'));
    tokBtn.setAttribute('aria-expanded', String(state.panelOpen && state.activeTab === 'tok'));
  }

  function renderContextPane() {
    const emptyEl = el('cm-ctx-empty');
    const bodyEl = el('cm-ctx-body');
    if (!state.route) {
      emptyEl.hidden = false;
      bodyEl.hidden = true;
      return;
    }
    emptyEl.hidden = true;
    bodyEl.hidden = false;

    const d = state.latest;
    const lvl = levelFor(d);

    el('cm-model').textContent = d?.model || '当前对话';
    el('cm-model').title = d?.model || '';

    const badge = el('cm-status-badge');
    if (state.requestError) {
      badge.textContent = '读取异常';
      badge.setAttribute('data-tone', 'danger');
    } else if (!d) {
      badge.textContent = state.requestBusy ? '读取中' : '等待统计';
      badge.setAttribute('data-tone', '');
    } else if (d.errorInfo?.kind && d.errorInfo.kind !== 'none') {
      badge.textContent = d.errorInfo.label;
      badge.setAttribute('data-tone', d.errorInfo.kind === 'canceled' ? 'warn' : 'danger');
    } else if (d.estimated) {
      badge.textContent = '本地估算';
      badge.setAttribute('data-tone', 'warn');
    } else {
      badge.textContent = '实际统计';
      badge.setAttribute('data-tone', 'ok');
    }

    el('cm-used').textContent = d?.used != null ? formatTokens(d.used) : '—';
    el('cm-budget').textContent = d?.budget ? `/ ${formatTokens(d.budget)}` : '';
    const pctEl = el('cm-pct-big');
    pctEl.textContent = d?.exceeded ? '已超限' : d?.percent != null ? `${d.percent.toFixed(1)}%` : '—';
    pctEl.setAttribute('data-level', lvl);

    const fillEl = el('cm-bar-fill');
    const barPct = d?.exceeded ? 100 : Math.max(0, Math.min(100, d?.percent ?? 0));
    fillEl.style.width = `${barPct}%`;
    fillEl.setAttribute('data-level', lvl);

    el('cm-remaining').textContent = d?.remaining != null ? `剩余 ${formatTokens(d.remaining)}` : '剩余 —';
    el('cm-source-note').textContent = d?.actual != null ? `精确 ${formatFull(d.actual)} tok` : d?.estimate ? '等待服务端返回' : '—';

    const alertEl = el('cm-alert');
    const errMsg = state.requestError || (d?.errorInfo?.kind !== 'none' ? d?.errorInfo?.detail : '');
    if (errMsg) {
      alertEl.hidden = false;
      alertEl.textContent = errMsg;
    } else {
      alertEl.hidden = true;
    }

    // 4 metric cards
    el('cm-cache-val').textContent = d?.cacheHit != null ? `${d.cacheHit}%` : '—';
    el('cm-cache-sub').textContent =
      d?.promptTokens != null ? `${formatTokens(d.cacheReadTokens)} / ${formatTokens(d.promptTokens)}` : '—';

    const sp = d?.speed;
    el('cm-tps-val').textContent = sp?.tps != null ? `${sp.tps} tok/s` : '—';
    el('cm-tps-sub').textContent = sp?.streamingTps != null ? `流式 ${sp.streamingTps} tok/s` : '—';

    el('cm-ttft-val').textContent = sp?.ttft != null ? `${sp.ttft}s` : '—';
    el('cm-ttft-sub').textContent = sp?.duration != null ? `总耗时 ${sp.duration}s` : '—';

    el('cm-out-val').textContent = d?.outputTokens != null ? formatTokens(d.outputTokens) : '—';
    el('cm-out-sub').textContent =
      sp?.thinkingTokens > 0
        ? `含思考 ${formatTokens(sp.thinkingTokens)}`
        : d?.inputTokens != null
          ? `未缓存输入 ${formatTokens(d.inputTokens)}`
          : '—';
  }

  function renderHistoryPane() {
    const h = state.history;
    const src = state.sourceFilter;
    const segBtns = shadow.querySelectorAll('.cm-seg-btn[data-src]');
    for (const btn of segBtns) {
      btn.setAttribute('aria-pressed', String(btn.getAttribute('data-src') === src));
    }

    const s = h?.sources?.[src];
    el('cm-hist-steps').textContent = s ? `${formatFull(s.steps)} 次请求` : state.historyBusy ? '扫描中…' : '—';
    el('cm-hist-today').textContent = s ? formatTokens(s.today) : '—';
    el('cm-hist-month').textContent = s ? formatTokens(s.month) : '—';
    el('cm-hist-total').textContent = s ? formatTokens(s.total) : '—';

    const sumMix = s ? s.input + s.cache + s.output : 0;
    const pIn = sumMix > 0 ? (s.input / sumMix) * 100 : 0;
    const pCache = sumMix > 0 ? (s.cache / sumMix) * 100 : 0;
    const pOut = sumMix > 0 ? (s.output / sumMix) * 100 : 0;
    el('cm-mix-in').style.width = `${pIn.toFixed(1)}%`;
    el('cm-mix-cache').style.width = `${pCache.toFixed(1)}%`;
    el('cm-mix-out').style.width = `${pOut.toFixed(1)}%`;
    el('cm-mix-cache-pct').textContent =
      s && s.input + s.cache > 0 ? `平均缓存命中 ${((s.cache / (s.input + s.cache)) * 100).toFixed(1)}%` : '—';
    el('cm-mix-in-val').textContent = s ? formatTokens(s.input) : '—';
    el('cm-mix-cache-val').textContent = s ? formatTokens(s.cache) : '—';
    el('cm-mix-out-val').textContent = s ? formatTokens(s.output) : '—';

    const barsEl = el('cm-spark-bars');
    barsEl.replaceChildren();
    const days = h?.recentDays || [];
    if (!days.length) {
      el('cm-spark-start').textContent = '—';
      return;
    }

    el('cm-spark-start').textContent = days[0].date.slice(5);
    const maxVal = Math.max(1, ...days.map((d) => d[src]?.total || 0));
    const hoverEl = el('cm-spark-hover');
    const todayKey = h.todayKey;

    days.forEach((day) => {
      const rec = day[src] || { total: 0, input: 0, cache: 0, output: 0 };
      const col = document.createElement('div');
      col.className = 'cm-spark-col';
      if (day.date === todayKey) col.setAttribute('data-today', 'true');

      const bar = document.createElement('div');
      bar.className = 'cm-spark-bar';
      const hPct = rec.total > 0 ? Math.max(8, Math.round((rec.total / maxVal) * 100)) : 4;
      bar.style.height = `${hPct}%`;
      if (rec.total === 0) bar.style.opacity = '0.35';
      col.appendChild(bar);

      col.addEventListener('mouseenter', () => {
        hoverEl.textContent =
          rec.total > 0
            ? `${day.date.slice(5)} · ${formatTokens(rec.total)} (入 ${formatTokens(rec.input)} / 存 ${formatTokens(rec.cache)} / 出 ${formatTokens(rec.output)})`
            : `${day.date.slice(5)} · 0`;
      });
      col.addEventListener('mouseleave', () => {
        hoverEl.textContent = '悬浮查看明细';
      });
      barsEl.appendChild(col);
    });
  }

  function render() {
    if (state.disposed) return;
    renderCapsules();
    if (!state.panelOpen) return;
    el('cm-tab-ctx').setAttribute('aria-selected', String(state.activeTab === 'ctx'));
    el('cm-tab-tok').setAttribute('aria-selected', String(state.activeTab === 'tok'));
    el('cm-pane-ctx').hidden = state.activeTab !== 'ctx';
    el('cm-pane-tok').hidden = state.activeTab !== 'tok';
    if (state.activeTab === 'ctx') renderContextPane();
    else renderHistoryPane();
    positionPanel();
  }

  function setPanel(open, tab) {
    if (tab) state.activeTab = tab;
    state.panelOpen = open;
    el('cm-panel').hidden = !open;
    if (open) {
      hideTooltip();
      syncTheme();
      if (state.activeTab === 'tok' && !state.history) void syncHistory(false);
    }
    render();
  }

  async function pollCurrentConversation(generation, id) {
    state.requestBusy = true;
    const controller = new AbortController();
    state.controllers.add(controller);
    const timeout = setTimeout(() => controller.abort(), 12000);
    try {
      const csrf = window.__APP_CONFIG__?.csrfToken;
      if (!csrf) throw new Error('后台尚未就绪');
      const offset = Math.max(0, state.count - 3);
      const res = await fetch('/exa.language_server_pb.LanguageServerService/GetCascadeTrajectoryGeneratorMetadata', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Connect-Protocol-Version': '1',
          'x-codeium-csrf-token': csrf,
        },
        body: JSON.stringify({ cascadeId: id, generatorMetadataOffset: offset, includeMessages: false }),
        signal: controller.signal,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (generation !== state.generation || state.disposed) return;

      const rows = data.generatorMetadata || [];
      state.count = rows.length ? offset + rows.length : 0;
      let nextLatest = null;
      for (let i = rows.length - 1; i >= 0; i--) {
        const s = summarize(rows[i], { previousValidContext: state.latest });
        if (s) {
          nextLatest = s;
          break;
        }
      }
      if (nextLatest) state.latest = nextLatest;
      state.requestError = '';
    } catch (err) {
      if (generation === state.generation && !state.disposed) {
        state.requestError = err.name === 'AbortError' ? '读取超时' : err.message;
      }
    } finally {
      clearTimeout(timeout);
      state.controllers.delete(controller);
      if (generation === state.generation && !state.disposed) {
        state.requestBusy = false;
        state.requestNext = Date.now() + (document.hidden ? 15000 : 3000);
        render();
      }
    }
  }

  async function syncHistory(force = false) {
    if (state.historyBusy || typeof window.contextMeterAPI?.getTokenHistory !== 'function') return;
    state.historyBusy = true;
    el('cm-refresh-btn')?.setAttribute('data-spinning', 'true');
    try {
      const res = await window.contextMeterAPI.getTokenHistory(force);
      if (res?.ok && res.data && !state.disposed) {
        state.history = res.data;
        state.lastHistoryAt = Date.now();
        render();
      }
    } catch {} finally {
      state.historyBusy = false;
      el('cm-refresh-btn')?.removeAttribute('data-spinning');
    }
  }

  function tick() {
    if (state.disposed) return;
    if (!host.isConnected) dockHost();

    const id = getRouteId();
    if (id !== state.route) {
      for (const c of state.controllers) c.abort();
      state.controllers.clear();
      state.generation++;
      state.route = id;
      state.count = 0;
      state.latest = null;
      state.requestError = '';
      state.requestBusy = false;
      state.requestNext = 0;
      if (!id && state.panelOpen && state.activeTab === 'ctx') {
        state.activeTab = 'tok';
      }
      hideTooltip();
      render();
      void syncHistory(false);
    }

    if (id && !state.requestBusy && Date.now() >= state.requestNext) {
      void pollCurrentConversation(state.generation, id);
    }
    if (Date.now() - state.lastHistoryAt > 15000) {
      state.lastHistoryAt = Date.now();
      void syncHistory(false);
    }
  }

  // Event bindings
  const ctxBtn = el('cm-ctx-btn');
  const spdBtn = el('cm-spd-btn');
  const tokBtn = el('cm-tok-btn');

  ctxBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    setPanel(!(state.panelOpen && state.activeTab === 'ctx'), 'ctx');
  });
  spdBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    setPanel(!(state.panelOpen && state.activeTab === 'ctx'), 'ctx');
  });
  tokBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    setPanel(!(state.panelOpen && state.activeTab === 'tok'), 'tok');
  });

  ctxBtn.addEventListener('mouseenter', showTooltip);
  ctxBtn.addEventListener('mouseleave', hideTooltip);
  ctxBtn.addEventListener('focus', showTooltip);
  ctxBtn.addEventListener('blur', hideTooltip);

  el('cm-tab-ctx').addEventListener('click', () => setPanel(true, 'ctx'));
  el('cm-tab-tok').addEventListener('click', () => setPanel(true, 'tok'));
  el('cm-close-btn').addEventListener('click', () => setPanel(false));
  el('cm-refresh-btn').addEventListener('click', () => {
    if (state.activeTab === 'ctx' && state.route) {
      state.requestNext = 0;
      void pollCurrentConversation(state.generation, state.route);
    } else {
      void syncHistory(true);
    }
  });

  for (const btn of shadow.querySelectorAll('.cm-seg-btn[data-src]')) {
    btn.addEventListener('click', () => {
      state.sourceFilter = btn.getAttribute('data-src') || 'all';
      renderHistoryPane();
    });
  }

  const onOutsideClick = (e) => {
    if (!state.panelOpen) return;
    if (typeof e.composedPath === 'function' && e.composedPath().includes(host)) return;
    setPanel(false);
  };
  const onKeyDown = (e) => {
    if (e.key === 'Escape') {
      if (state.panelOpen) setPanel(false);
      hideTooltip();
    }
  };
  const onResize = () => dockHost();
  const onFocus = () => host.setAttribute('data-window-active', 'true');
  const onBlur = () => host.setAttribute('data-window-active', 'false');

  document.addEventListener('click', onOutsideClick);
  document.addEventListener('keydown', onKeyDown);
  window.addEventListener('resize', onResize);
  window.addEventListener('focus', onFocus);
  window.addEventListener('blur', onBlur);

  let themeObs = null;
  let domObs = null;
  let resizeObs = null;
  try {
    themeObs = new MutationObserver(() => syncTheme());
    themeObs.observe(document.documentElement, { attributes: true, attributeFilter: ['style', 'class', 'data-theme'] });
    if (document.body) {
      themeObs.observe(document.body, { attributes: true, attributeFilter: ['style', 'class', 'data-theme'] });
    }
    domObs = new MutationObserver(() => {
      if (!host.isConnected || host.getAttribute('data-dock') !== 'flow') dockHost();
    });
    if (document.body) domObs.observe(document.body, { childList: true, subtree: true });
    resizeObs = new ResizeObserver(() => dockHost());
    const tb = findTitlebar();
    if (tb) resizeObs.observe(tb);
  } catch {}

  const timer = setInterval(tick, 500);

  globalThis.__AGContextMeter = {
    version: '1.0.0',
    ensureAlive: () => {
      if (state.disposed) return false;
      syncTheme();
      dockHost();
      render();
      return true;
    },
    snapshot: () => ({
      route: state.route,
      latest: state.latest,
      history: state.history,
      panelOpen: state.panelOpen,
      activeTab: state.activeTab,
    }),
    dispose: () => {
      state.disposed = true;
      for (const c of state.controllers) c.abort();
      clearInterval(timer);
      try { themeObs?.disconnect(); } catch {}
      try { domObs?.disconnect(); } catch {}
      try { resizeObs?.disconnect(); } catch {}
      document.removeEventListener('click', onOutsideClick);
      document.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('resize', onResize);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('blur', onBlur);
      host.remove();
    },
  };

  syncTheme();
  dockHost();
  render();
  tick();
})();
