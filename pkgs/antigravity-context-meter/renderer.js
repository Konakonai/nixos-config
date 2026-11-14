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

      --cm-fg: var(--foreground, #ececef);
      --cm-muted: var(--muted-foreground, var(--secondary-foreground, color-mix(in srgb, var(--cm-fg) 58%, transparent)));
      --cm-border: var(--border, color-mix(in srgb, var(--cm-fg) 12%, transparent));
      --cm-track: color-mix(in srgb, var(--cm-fg) 15%, transparent);
      --cm-primary: var(--primary, #7c5cfa);
      --cm-warn: #f59e0b;
      --cm-danger: var(--destructive, #ef4444);

      color: var(--cm-muted);
      color-scheme: dark;
    }

    :host([hidden]) {
      display: none !important;
    }

    :host([data-tone="light"]) {
      --cm-fg: var(--foreground, #18181b);
      --cm-warn: #d97706;
      --cm-danger: var(--destructive, #dc2626);
      color-scheme: light;
    }

    * { box-sizing: border-box; }

    .cm-strip {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 4px 12px;
      padding: 0 6px;
      min-height: 20px;
      font-variant-numeric: tabular-nums;
    }

    .cm-group {
      display: inline-flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 4px 10px;
      min-width: 0;
    }

    .cm-item {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      white-space: nowrap;
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
      padding: 1px 6px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 500;
      color: var(--cm-danger);
      background: color-mix(in srgb, var(--cm-danger) 12%, transparent);
      border: 1px solid color-mix(in srgb, var(--cm-danger) 28%, transparent);
    }

    .cm-err[hidden] {
      display: none !important;
    }

    :host([data-width="compact"]) .cm-hide-compact,
    :host([data-width="tight"]) .cm-hide-compact {
      display: none !important;
    }

    :host([data-width="tight"]) .cm-hide-tight {
      display: none !important;
    }
  `;

  const TEMPLATE = `
    <div class="cm-strip">
      <div class="cm-group">
        <span id="cm-ctx" class="cm-item cm-ctx" data-level="normal">
          <svg class="cm-ring" width="14" height="14" viewBox="0 0 14 14" aria-hidden="true">
            <circle class="cm-ring-track" cx="7" cy="7" r="${RING_R}" fill="none" stroke-width="1.8"></circle>
            <circle id="cm-ring-fill" class="cm-ring-fill" cx="7" cy="7" r="${RING_R}" fill="none" stroke-width="1.8" stroke-linecap="round" transform="rotate(-90 7 7)" stroke-dasharray="${RING_C.toFixed(2)}" stroke-dashoffset="${RING_C.toFixed(2)}"></circle>
          </svg>
          <span id="cm-used" class="cm-strong">—</span>
          <span id="cm-budget"></span>
          <span id="cm-pct" class="cm-pct"></span>
        </span>
        <span id="cm-err" class="cm-err" hidden>${ICONS.alert}<span id="cm-err-text"></span></span>
      </div>

      <div class="cm-group">
        <span id="cm-cache" class="cm-item" hidden>
          ${ICONS.cache}
          <span>缓存 <span id="cm-cache-val" class="cm-strong">—</span></span>
        </span>
        <span id="cm-tps" class="cm-item" hidden>
          ${ICONS.speed}
          <span id="cm-tps-val" class="cm-strong">—</span>
        </span>
        <span id="cm-ttft" class="cm-item cm-hide-tight" hidden>
          ${ICONS.clock}
          <span id="cm-ttft-val">—</span>
        </span>
        <span id="cm-out" class="cm-item cm-hide-compact" hidden>
          ${ICONS.output}
          <span>输出 <span id="cm-out-val" class="cm-strong">—</span></span>
        </span>
      </div>
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

      // Walk up from the active chat editor to the outer rounded composer container
      // without climbing into the tall conversation scroll pane.
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

    const w = cardRect.width;
    host.setAttribute('data-width', w < 360 ? 'tight' : w < 490 ? 'compact' : 'full');
  }

  function dockHost() {
    if (state.disposed) return;
    const card = findComposerCard();
    if (!card) {
      state.card = null;
      host.removeAttribute('data-dock');
      if (host.isConnected) host.hidden = true;
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
          }
        });
        layoutObserver.observe(card);
        layoutObserver.observe(parent);
      } catch {}
    }

    alignToCard(parent, card);
  }

  function render() {
    if (state.disposed) return;

    const d = state.latest;
    const shouldShow =
      host.getAttribute('data-dock') === 'composer' &&
      Boolean(state.route) &&
      Boolean(d || state.requestError);

    host.hidden = !shouldShow;
    if (!shouldShow) return;

    const ctxEl = el('cm-ctx');
    const ringEl = el('cm-ring-fill');
    const usedEl = el('cm-used');
    const budgetEl = el('cm-budget');
    const pctEl = el('cm-pct');
    const errEl = el('cm-err');
    const errTextEl = el('cm-err-text');

    if (d) {
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

      const ctxTipParts = [];
      if (d.used != null) ctxTipParts.push(`精确 ${formatFull(d.used)} tok`);
      if (d.budget) ctxTipParts.push(`上限 ${formatFull(d.budget)} tok`);
      if (d.remaining != null) ctxTipParts.push(`剩余 ${formatTokens(d.remaining)}`);
      ctxEl.title = ctxTipParts.join(' · ');

      if (d.errorInfo && d.errorInfo.kind !== 'none') {
        errEl.hidden = false;
        errTextEl.textContent = d.errorInfo.label;
        errEl.title = d.errorInfo.detail || d.errorInfo.label;
      } else {
        errEl.hidden = true;
        errEl.title = '';
      }

      const cacheEl = el('cm-cache');
      if (d.cacheHit != null) {
        cacheEl.hidden = false;
        el('cm-cache-val').textContent = `${d.cacheHit}%`;
        cacheEl.title =
          d.promptTokens != null && d.cacheReadTokens != null
            ? `缓存命中 ${formatTokens(d.cacheReadTokens)} / ${formatTokens(d.promptTokens)}`
            : '';
      } else {
        cacheEl.hidden = true;
      }

      const sp = d.speed;
      const tpsEl = el('cm-tps');
      const primaryTps = sp ? sp.tps ?? sp.streamingTps : null;
      if (primaryTps != null) {
        tpsEl.hidden = false;
        el('cm-tps-val').textContent = `${primaryTps} tok/s`;
        const speedTips = [];
        if (sp.tps != null) speedTips.push(`平均 ${sp.tps} tok/s`);
        if (sp.streamingTps != null) speedTips.push(`流式 ${sp.streamingTps} tok/s`);
        tpsEl.title = speedTips.join(' · ');
      } else {
        tpsEl.hidden = true;
      }

      const ttftEl = el('cm-ttft');
      if (sp && (sp.ttft != null || sp.duration != null)) {
        ttftEl.hidden = false;
        const parts = [];
        if (sp.ttft != null) parts.push(`首字 <span class="cm-strong">${sp.ttft}s</span>`);
        if (sp.duration != null) parts.push(`<span class="cm-strong">${sp.duration}s</span>`);
        el('cm-ttft-val').innerHTML = parts.join('<span class="cm-sep"> · </span>');
        ttftEl.title = [
          sp.ttft != null ? `首字延迟 ${sp.ttft}s` : '',
          sp.duration != null ? `总耗时 ${sp.duration}s` : '',
        ]
          .filter(Boolean)
          .join(' · ');
      } else {
        ttftEl.hidden = true;
      }

      const outEl = el('cm-out');
      if (sp && sp.outputTokens > 0) {
        outEl.hidden = false;
        el('cm-out-val').textContent = formatTokens(sp.outputTokens);
        outEl.title =
          sp.thinkingTokens > 0
            ? `本轮输出 ${formatFull(sp.outputTokens)} tok（含思考 ${formatFull(sp.thinkingTokens)}）`
            : `本轮输出 ${formatFull(sp.outputTokens)} tok`;
      } else {
        outEl.hidden = true;
      }
    } else {
      ctxEl.setAttribute('data-level', 'normal');
      ringEl.style.strokeDashoffset = RING_C.toFixed(2);
      usedEl.textContent = '上下文';
      budgetEl.textContent = '';
      pctEl.textContent = '';
      ctxEl.title = '';

      errEl.hidden = false;
      errTextEl.textContent = state.requestError;
      errEl.title = state.requestError;

      el('cm-cache').hidden = true;
      el('cm-tps').hidden = true;
      el('cm-ttft').hidden = true;
      el('cm-out').hidden = true;
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

  const onResize = () => dockHost();
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
    version: '2.0.0',
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
