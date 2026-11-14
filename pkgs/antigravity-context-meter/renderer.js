(function () {
  'use strict';
  if (location.protocol !== 'https:' || location.hostname !== '127.0.0.1') return;

  globalThis.__AGContextMeter?.dispose?.();
  const Core = globalThis.__AGContextMeterCore;
  if (!Core) return;
  const { summarize, formatTokens, formatFull } = Core;

  const RING_R = 5.2;
  const RING_C = 2 * Math.PI * RING_R;

  const ICONS = {
    cache:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m12 2 9 4.5-9 4.5L3 6.5 12 2Z"/><path d="m3 12 9 4.5 9-4.5"/><path d="m3 17.5 9 4.5 9-4.5"/></svg>',
    speed:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/></svg>',
    clock:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    output:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17 17 7"/><path d="M7 7h10v10"/></svg>',
    info:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>',
    spark:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9.5 3 8 8l-5 1.5L8 11l1.5 5L11 11l5-1.5L11 8 9.5 3Z"/><path d="M18 14l-.75 2.25L15 17l2.25.75L18 20l.75-2.25L21 17l-2.25-.75L18 14Z"/></svg>',
    alert:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>',
  };

  const CSS = `
    :host {
      display: block;
      align-self: flex-start;
      box-sizing: border-box;
      user-select: none;
      font-family: inherit;
      font-size: 11.5px;
      line-height: 1.35;

      --cm-fallback-bg: #1e1e24;
      --cm-fallback-fg: #ececef;
      --cm-bg: var(--popover, var(--card, var(--background, var(--cm-fallback-bg))));
      --cm-fg: var(--popover-foreground, var(--foreground, var(--cm-fallback-fg)));
      --cm-muted: var(--muted-foreground, var(--secondary-foreground, color-mix(in srgb, var(--cm-fg) 58%, transparent)));
      --cm-border: var(--border, color-mix(in srgb, var(--cm-fg) 12%, transparent));
      --cm-hover: var(--accent, var(--secondary, color-mix(in srgb, var(--cm-fg) 6%, transparent)));
      --cm-track: color-mix(in srgb, var(--cm-fg) 15%, transparent);
      --cm-primary: var(--primary, #7c5cfa);
      --cm-warn: #f59e0b;
      --cm-danger: var(--destructive, #ef4444);
      --cm-shadow: 0 10px 28px rgba(0, 0, 0, 0.34), 0 2px 8px rgba(0, 0, 0, 0.16);

      color: var(--cm-muted);
      color-scheme: dark;
    }

    :host([hidden]) {
      display: none !important;
    }

    :host([data-tone="light"]) {
      --cm-fallback-bg: #ffffff;
      --cm-fallback-fg: #18181b;
      --cm-warn: #d97706;
      --cm-danger: var(--destructive, #dc2626);
      --cm-shadow: 0 8px 24px rgba(0, 0, 0, 0.08), 0 2px 6px rgba(0, 0, 0, 0.04);
      color-scheme: light;
    }

    * { box-sizing: border-box; }

    .cm-strip {
      display: flex;
      align-items: center;
      justify-content: center;
      flex-wrap: wrap;
      gap: 4px 12px;
      padding: 0 6px;
      min-height: 20px;
      font-variant-numeric: tabular-nums;
    }

    .cm-item {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 5px;
      border-radius: 6px;
      white-space: nowrap;
      cursor: default;
      transition: background-color 120ms ease, color 120ms ease;
    }

    .cm-item:hover {
      background: var(--cm-hover);
      color: var(--cm-fg);
    }

    .cm-item[hidden] {
      display: none !important;
    }

    .cm-item svg {
      flex-shrink: 0;
      opacity: 0.78;
    }

    .cm-strong {
      color: var(--cm-fg);
      font-weight: 500;
    }

    .cm-sep {
      opacity: 0.45;
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
      transition: stroke-dashoffset 200ms ease, stroke 160ms ease;
    }

    .cm-ctx[data-level="warn"] .cm-pct {
      color: var(--cm-warn);
      font-weight: 600;
    }
    .cm-ctx[data-level="warn"] .cm-ring-fill {
      stroke: var(--cm-warn);
    }

    .cm-ctx[data-level="danger"] .cm-pct,
    .cm-ctx[data-level="danger"] .cm-strong {
      color: var(--cm-danger);
      font-weight: 600;
    }
    .cm-ctx[data-level="danger"] .cm-ring-fill {
      stroke: var(--cm-danger);
    }

    .cm-err {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 1px 7px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 500;
      color: var(--cm-danger);
      background: color-mix(in srgb, var(--cm-danger) 12%, transparent);
      border: 1px solid color-mix(in srgb, var(--cm-danger) 28%, transparent);
      cursor: default;
    }

    .cm-err[hidden] {
      display: none !important;
    }

    .cm-tooltip {
      position: fixed;
      z-index: 2147483000;
      pointer-events: none;
      min-width: 170px;
      max-width: 280px;
      padding: 10px 12px;
      border-radius: 12px;
      background: var(--cm-bg);
      color: var(--cm-fg);
      border: 1px solid var(--cm-border);
      box-shadow: var(--cm-shadow);
      opacity: 0;
      transform: translateY(4px);
      transition: opacity 110ms ease, transform 110ms ease;
    }

    .cm-tooltip[data-visible="true"] {
      opacity: 1;
      transform: translateY(0);
    }

    .cm-tip-title {
      font-size: 12px;
      font-weight: 500;
      color: var(--cm-fg);
      line-height: 1.35;
      font-variant-numeric: tabular-nums;
    }

    .cm-tip-rows {
      margin-top: 6px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .cm-tip-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: var(--cm-muted);
      line-height: 1.35;
      font-variant-numeric: tabular-nums;
    }

    .cm-tip-row svg {
      flex-shrink: 0;
      opacity: 0.78;
    }

    :host([data-width="tight"]) .cm-hide-tight {
      display: none !important;
    }
  `;

  const TEMPLATE = `
    <div class="cm-strip">
      <span id="cm-tps" class="cm-item" data-tip="speed" hidden>
        ${ICONS.speed}
        <span id="cm-tps-val" class="cm-strong">—</span>
      </span>

      <span id="cm-cache" class="cm-item" data-tip="cache" hidden>
        ${ICONS.cache}
        <span>缓存 <span id="cm-cache-val" class="cm-strong">—</span></span>
      </span>

      <span id="cm-out" class="cm-item cm-hide-tight" data-tip="output" hidden>
        ${ICONS.output}
        <span>输出 <span id="cm-out-val" class="cm-strong">—</span></span>
      </span>

      <span id="cm-ctx" class="cm-item cm-ctx" data-tip="ctx" data-level="normal">
        <svg class="cm-ring" width="14" height="14" viewBox="0 0 14 14" aria-hidden="true">
          <circle class="cm-ring-track" cx="7" cy="7" r="${RING_R}" fill="none" stroke-width="1.8"></circle>
          <circle id="cm-ring-fill" class="cm-ring-fill" cx="7" cy="7" r="${RING_R}" fill="none" stroke-width="1.8" stroke-linecap="round" transform="rotate(-90 7 7)" stroke-dasharray="${RING_C.toFixed(2)}" stroke-dashoffset="${RING_C.toFixed(2)}"></circle>
        </svg>
        <span id="cm-used" class="cm-strong">—</span>
        <span id="cm-budget"></span>
        <span id="cm-pct" class="cm-pct"></span>
      </span>

      <span id="cm-ttft" class="cm-item cm-hide-tight" data-tip="timing" hidden>
        ${ICONS.clock}
        <span id="cm-ttft-val">—</span>
      </span>

      <span id="cm-err" class="cm-err" data-tip="err" hidden>${ICONS.alert}<span id="cm-err-text"></span></span>
    </div>

    <div id="cm-tooltip" class="cm-tooltip" role="tooltip" data-visible="false">
      <div id="cm-tip-title" class="cm-tip-title"></div>
      <div id="cm-tip-rows" class="cm-tip-rows"></div>
    </div>
  `;

  const host = document.createElement('div');
  host.id = 'ag-context-meter';
  host.hidden = true;
  host.setAttribute('data-tone', 'dark');
  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = `<style>${CSS}</style>${TEMPLATE}`;

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
    card: null,
    hoveredItem: null,
    disposed: false,
  };

  let layoutObserver = null;

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

  function isVisibleRect(rect) {
    return (
      rect &&
      rect.width >= 180 &&
      rect.height >= 16 &&
      rect.bottom > 0 &&
      rect.top < window.innerHeight
    );
  }

  function findComposerCard() {
    try {
      const candidates = document.querySelectorAll(
        '[data-lexical-editor="true"], [contenteditable="true"][role="textbox"], [contenteditable="true"], textarea'
      );
      let bestEditor = null;
      let bestScore = -1;

      for (const node of candidates) {
        if (
          node.closest('#ag-context-meter, .monaco-editor, .xterm, [role="dialog"], [aria-hidden="true"]')
        ) {
          continue;
        }
        const cs = getComputedStyle(node);
        if (cs.display === 'none' || cs.visibility === 'hidden') continue;
        const rect = node.getBoundingClientRect();
        if (!isVisibleRect(rect)) continue;
        if (rect.bottom < window.innerHeight * 0.32) continue;

        let hasButtons = false;
        let p = node.parentElement;
        for (let i = 0; i < 6 && p && p !== document.body; i++) {
          const pr = p.getBoundingClientRect();
          if (pr.height > 360) break;
          if (p.querySelector('button')) {
            hasButtons = true;
            break;
          }
          p = p.parentElement;
        }

        const score = rect.bottom + (hasButtons ? 1000 : 0);
        if (score > bestScore) {
          bestScore = score;
          bestEditor = node;
        }
      }

      if (!bestEditor) return null;

      let card = bestEditor.parentElement || bestEditor;
      let cur = bestEditor.parentElement;
      for (let i = 0; i < 8 && cur && cur !== document.body; i++) {
        const rect = cur.getBoundingClientRect();
        if (rect.height > 340 || rect.width < 200) break;
        const cs = getComputedStyle(cur);
        const overflowY = cs.overflowY;
        const isScrollContainer =
          (overflowY === 'auto' || overflowY === 'scroll') && cur.scrollHeight > cur.clientHeight + 120;
        if (isScrollContainer && i > 1) break;

        if (cur.querySelector('button')) {
          card = cur;
        }
        cur = cur.parentElement;
      }

      return card;
    } catch {
      return null;
    }
  }

  function findVerticalParent(node) {
    let target = node;
    let parent = node?.parentElement;
    for (let i = 0; i < 5 && parent && parent !== document.body; i++) {
      const cs = getComputedStyle(parent);
      const isRowFlex = cs.display.includes('flex') && !cs.flexDirection.startsWith('column');
      const isMultiColGrid =
        cs.display.includes('grid') && cs.gridTemplateColumns.trim().split(/\s+/).length > 1;
      if (!isRowFlex && !isMultiColGrid) {
        return { parent, beforeNode: target };
      }
      target = parent;
      parent = parent.parentElement;
    }
    return parent ? { parent, beforeNode: target } : null;
  }

  function alignToCard(parent, card) {
    const cardRect = card.getBoundingClientRect();
    const parentRect = parent.getBoundingClientRect();
    if (cardRect.width <= 0 || parentRect.width <= 0) return;

    const ps = getComputedStyle(parent);
    const contentLeft =
      parentRect.left + parseFloat(ps.borderLeftWidth || '0') + parseFloat(ps.paddingLeft || '0');
    const leftOffset = Math.max(0, Math.round(cardRect.left - contentLeft));
    const rowGap = parseFloat(ps.rowGap || '0') || 0;

    host.style.width = `${Math.round(cardRect.width)}px`;
    host.style.marginLeft = `${leftOffset}px`;
    host.style.marginBottom = `${Math.max(0, Math.round(6 - rowGap))}px`;

    host.setAttribute('data-width', cardRect.width < 360 ? 'tight' : 'full');
  }

  function dockHost() {
    if (state.disposed) return;
    const card = findComposerCard();
    if (!card) {
      state.card = null;
      host.removeAttribute('data-dock');
      if (host.isConnected) host.hidden = true;
      hideTooltip();
      return;
    }

    const slot = findVerticalParent(card);
    if (!slot) return;

    const { parent, beforeNode } = slot;
    if (host.parentElement !== parent || host.nextElementSibling !== beforeNode) {
      parent.insertBefore(host, beforeNode);
    }
    host.setAttribute('data-dock', 'composer');

    if (state.card !== card) {
      state.card = card;
      try {
        layoutObserver?.disconnect();
        layoutObserver = new ResizeObserver(() => {
          if (!state.disposed && state.card && parent.isConnected) {
            alignToCard(parent, state.card);
            if (state.hoveredItem) positionTooltip(state.hoveredItem);
          }
        });
        layoutObserver.observe(card);
        layoutObserver.observe(parent);
      } catch {}
    }

    alignToCard(parent, card);
  }

  function buildTooltipData(kind) {
    const d = state.latest;
    if (kind === 'err') {
      if (d?.errorInfo && d.errorInfo.kind !== 'none') {
        return {
          title: d.errorInfo.label,
          rows: d.errorInfo.detail ? [{ icon: ICONS.alert, text: d.errorInfo.detail }] : [],
        };
      }
      if (state.requestError) {
        return {
          title: '连接状态异常',
          rows: [{ icon: ICONS.alert, text: state.requestError }],
        };
      }
      return null;
    }
    if (!d) return null;

    if (kind === 'speed') {
      const sp = d.speed;
      if (!sp) return null;
      const primary = sp.tps ?? sp.streamingTps;
      const rows = [];
      if (sp.streamingTps != null) rows.push({ icon: ICONS.speed, text: `流式速率 ${sp.streamingTps} tok/s` });
      if (sp.duration != null) rows.push({ icon: ICONS.clock, text: `耗时 ${sp.duration}s` });
      if (sp.outputTokens > 0) rows.push({ icon: ICONS.output, text: `本轮输出 ${formatFull(sp.outputTokens)} tok` });
      return {
        title: `输出速度 ${primary != null ? `${primary} tok/s` : '—'}`,
        rows,
      };
    }

    if (kind === 'cache') {
      if (d.cacheHit == null) return null;
      const rows = [];
      if (d.promptTokens != null && d.cacheReadTokens != null) {
        rows.push({
          icon: ICONS.cache,
          text: `命中 ${formatFull(d.cacheReadTokens)} / ${formatFull(d.promptTokens)} tok`,
        });
        const uncached = Math.max(0, d.promptTokens - d.cacheReadTokens);
        rows.push({
          icon: ICONS.info,
          text: `未缓存输入 ${formatFull(uncached)} tok`,
        });
      }
      return {
        title: `缓存命中 ${d.cacheHit}%`,
        rows,
      };
    }

    if (kind === 'output') {
      const sp = d.speed;
      if (!sp || !(sp.outputTokens > 0)) return null;
      const rows = [];
      if (sp.thinkingTokens > 0) {
        rows.push({ icon: ICONS.spark, text: `含思考 ${formatFull(sp.thinkingTokens)} tok` });
      }
      if (sp.streamingTps != null) {
        rows.push({ icon: ICONS.speed, text: `流式速度 ${sp.streamingTps} tok/s` });
      }
      return {
        title: `本轮输出 ${formatFull(sp.outputTokens)} tok`,
        rows,
      };
    }

    if (kind === 'ctx') {
      const rows = [];
      if (d.remaining != null) {
        const pctPart = d.percent != null ? `（已用 ${d.percent.toFixed(1)}%）` : '';
        rows.push({ icon: ICONS.info, text: `剩余可用 ${formatTokens(d.remaining)} tok${pctPart}` });
      }
      if (d.model) {
        rows.push({ icon: ICONS.spark, text: d.model });
      }
      return {
        title: d.used != null
          ? `上下文 ${formatFull(d.used)}${d.budget ? ` / ${formatFull(d.budget)}` : ''} tok`
          : '上下文占用',
        rows,
      };
    }

    if (kind === 'timing') {
      const sp = d.speed;
      if (!sp || (sp.ttft == null && sp.duration == null)) return null;
      const rows = [];
      if (sp.ttft != null) rows.push({ icon: ICONS.clock, text: `首字延迟 ${sp.ttft}s` });
      if (sp.streamingSec != null) rows.push({ icon: ICONS.speed, text: `流式生成 ${sp.streamingSec}s` });
      return {
        title: sp.duration != null ? `耗时 ${sp.duration}s` : `首字延迟 ${sp.ttft}s`,
        rows,
      };
    }

    return null;
  }

  function positionTooltip(anchor) {
    const tip = el('cm-tooltip');
    if (!tip || !anchor || !anchor.isConnected) return;
    const rect = anchor.getBoundingClientRect();
    const tw = tip.offsetWidth || 200;
    const th = tip.offsetHeight || 68;
    const left = Math.max(8, Math.min(window.innerWidth - tw - 8, rect.left + rect.width / 2 - tw / 2));
    let top = rect.top - th - 8;
    if (top < 8) top = Math.min(window.innerHeight - th - 8, rect.bottom + 8);
    tip.style.left = `${Math.round(left)}px`;
    tip.style.top = `${Math.round(top)}px`;
  }

  function updateTooltipContent(anchor) {
    const tip = el('cm-tooltip');
    if (!tip || !anchor) return false;
    const kind = anchor.getAttribute('data-tip');
    const data = buildTooltipData(kind);
    if (!data) {
      hideTooltip();
      return false;
    }

    el('cm-tip-title').textContent = data.title;
    const rowsEl = el('cm-tip-rows');
    rowsEl.textContent = '';
    rowsEl.hidden = data.rows.length === 0;
    for (const row of data.rows) {
      const div = document.createElement('div');
      div.className = 'cm-tip-row';
      div.innerHTML = `${row.icon}<span></span>`;
      div.querySelector('span').textContent = row.text;
      rowsEl.appendChild(div);
    }

    positionTooltip(anchor);
    return true;
  }

  function showTooltip(anchor) {
    state.hoveredItem = anchor;
    if (updateTooltipContent(anchor)) {
      el('cm-tooltip').setAttribute('data-visible', 'true');
    }
  }

  function hideTooltip() {
    state.hoveredItem = null;
    el('cm-tooltip')?.setAttribute('data-visible', 'false');
  }

  function render() {
    if (state.disposed) return;

    const d = state.latest;
    const shouldShow =
      host.getAttribute('data-dock') === 'composer' &&
      Boolean(state.route) &&
      Boolean(d || state.requestError);

    host.hidden = !shouldShow;
    if (!shouldShow) {
      hideTooltip();
      return;
    }

    const ctxEl = el('cm-ctx');
    const ringEl = el('cm-ring-fill');
    const usedEl = el('cm-used');
    const budgetEl = el('cm-budget');
    const pctEl = el('cm-pct');
    const errEl = el('cm-err');
    const errTextEl = el('cm-err-text');

    if (d) {
      const sp = d.speed;
      const tpsEl = el('cm-tps');
      const primaryTps = sp ? sp.tps ?? sp.streamingTps : null;
      if (primaryTps != null) {
        tpsEl.hidden = false;
        el('cm-tps-val').textContent = `${primaryTps} tok/s`;
      } else {
        tpsEl.hidden = true;
      }

      const cacheEl = el('cm-cache');
      if (d.cacheHit != null) {
        cacheEl.hidden = false;
        el('cm-cache-val').textContent = `${d.cacheHit}%`;
      } else {
        cacheEl.hidden = true;
      }

      const outEl = el('cm-out');
      if (sp && sp.outputTokens > 0) {
        outEl.hidden = false;
        el('cm-out-val').textContent = formatTokens(sp.outputTokens);
      } else {
        outEl.hidden = true;
      }

      const level = d.exceeded
        ? 'danger'
        : d.percent >= 90
          ? 'danger'
          : d.percent >= 75
            ? 'warn'
            : 'normal';
      ctxEl.setAttribute('data-level', level);

      const fillPct = d.exceeded ? 100 : Math.min(100, Math.max(0, d.percent ?? 0));
      ringEl.style.strokeDashoffset = (RING_C * (1 - fillPct / 100)).toFixed(2);

      if (d.exceeded) {
        usedEl.textContent = d.used != null ? formatTokens(d.used) : '超限';
        budgetEl.textContent = d.budget ? `/ ${formatTokens(d.budget)}` : '';
        pctEl.textContent = '';
      } else {
        usedEl.textContent = d.used != null ? formatTokens(d.used) : '—';
        budgetEl.textContent = d.budget ? `/ ${formatTokens(d.budget)}` : '';
        pctEl.textContent = d.percent != null ? `(${d.percent.toFixed(1)}%)` : '';
      }

      const ttftEl = el('cm-ttft');
      if (sp && (sp.ttft != null || sp.duration != null)) {
        ttftEl.hidden = false;
        const parts = [];
        if (sp.ttft != null) parts.push(`首字 <span class="cm-strong">${sp.ttft}s</span>`);
        if (sp.duration != null) parts.push(`<span class="cm-strong">${sp.duration}s</span>`);
        el('cm-ttft-val').innerHTML = parts.join('<span class="cm-sep"> · </span>');
      } else {
        ttftEl.hidden = true;
      }

      if (d.errorInfo && d.errorInfo.kind !== 'none') {
        errEl.hidden = false;
        errTextEl.textContent = d.errorInfo.label;
      } else {
        errEl.hidden = true;
      }
    } else {
      el('cm-tps').hidden = true;
      el('cm-cache').hidden = true;
      el('cm-out').hidden = true;
      el('cm-ttft').hidden = true;

      ctxEl.setAttribute('data-level', 'normal');
      ringEl.style.strokeDashoffset = RING_C.toFixed(2);
      usedEl.textContent = '上下文';
      budgetEl.textContent = '';
      pctEl.textContent = '';

      errEl.hidden = false;
      errTextEl.textContent = state.requestError;
    }

    if (state.hoveredItem) {
      if (state.hoveredItem.hidden) hideTooltip();
      else updateTooltipContent(state.hoveredItem);
    }
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
        dockHost();
        render();
      }
    }
  }

  function tick() {
    if (state.disposed) return;
    if (!host.isConnected || !state.card || !state.card.isConnected) {
      dockHost();
      render();
    }

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
      render();
    }

    if (id && !state.requestBusy && Date.now() >= state.requestNext) {
      void pollCurrentConversation(state.generation, id);
    }
  }

  for (const item of shadow.querySelectorAll('[data-tip]')) {
    item.addEventListener('mouseenter', () => showTooltip(item));
    item.addEventListener('mouseleave', () => {
      if (state.hoveredItem === item) hideTooltip();
    });
  }

  const onResize = () => {
    dockHost();
    if (state.hoveredItem) positionTooltip(state.hoveredItem);
  };
  window.addEventListener('resize', onResize);

  let themeObs = null;
  let domObs = null;
  try {
    themeObs = new MutationObserver(() => syncTheme());
    themeObs.observe(document.documentElement, { attributes: true, attributeFilter: ['style', 'class', 'data-theme'] });
    if (document.body) {
      themeObs.observe(document.body, { attributes: true, attributeFilter: ['style', 'class', 'data-theme'] });
    }
    domObs = new MutationObserver(() => {
      if (!host.isConnected || !state.card || !state.card.isConnected) {
        dockHost();
        render();
      }
    });
    if (document.body) domObs.observe(document.body, { childList: true, subtree: true });
  } catch {}

  const timer = setInterval(tick, 500);

  globalThis.__AGContextMeter = {
    version: '2.1.0',
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
      docked: host.getAttribute('data-dock'),
    }),
    dispose: () => {
      state.disposed = true;
      for (const c of state.controllers) c.abort();
      clearInterval(timer);
      try { themeObs?.disconnect(); } catch {}
      try { domObs?.disconnect(); } catch {}
      try { layoutObserver?.disconnect(); } catch {}
      window.removeEventListener('resize', onResize);
      host.remove();
    },
  };

  syncTheme();
  dockHost();
  render();
  tick();
})();
