'use strict';

const fs = require('fs');
const path = require('path');
const { ipcMain, app } = require('electron');
const { collectTokenHistoryAsync } = require('./collector');

let registered = false;
const boundWindows = new WeakSet();
const boundWebContents = new WeakSet();
const injectionTimers = new WeakMap();

function isLocalMainFrameSender(event) {
  try {
    const rawUrl = event?.senderFrame?.url || event?.sender?.getURL?.() || '';
    const url = new URL(rawUrl);
    if (url.protocol !== 'https:' || url.hostname !== '127.0.0.1') return null;
    if (event.senderFrame && event.sender?.mainFrame && event.senderFrame !== event.sender.mainFrame) {
      return null;
    }
    return url;
  } catch {
    return null;
  }
}

function getMeterSource() {
  try {
    const coreCode = fs.readFileSync(path.join(__dirname, 'core.js'), 'utf8');
    const rendererCode = fs.readFileSync(path.join(__dirname, 'renderer.js'), 'utf8');
    return `${coreCode}\n${rendererCode}\ntrue;`;
  } catch {
    return '';
  }
}

function registerIpcOnce() {
  if (registered) return;
  registered = true;

  ipcMain.handle('context-meter:token-history', async (event, force) => {
    if (!isLocalMainFrameSender(event)) {
      throw new Error('Only allowed from local main frame');
    }
    try {
      return { ok: true, data: await collectTokenHistoryAsync({ force: force === true }) };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  });
}

function scheduleRetry(win, options, delays) {
  const attempt = Number(options.attempt || 0);
  if (attempt >= delays.length || !win || win.isDestroyed?.()) return;
  const prev = injectionTimers.get(win);
  if (prev) clearTimeout(prev);
  const timer = setTimeout(() => {
    injectionTimers.delete(win);
    void ensureMeterInjected(win, { ...options, attempt: attempt + 1 });
  }, delays[attempt]);
  injectionTimers.set(win, timer);
}

async function ensureMeterInjected(win, options = {}) {
  try {
    if (!win || win.isDestroyed?.()) return false;
    const wc = win.webContents;
    if (!wc || wc.isDestroyed?.()) return false;
    const url = wc.getURL?.() || '';
    if (!/^https:\/\/127\.0\.0\.1:\d+\//.test(url)) {
      scheduleRetry(win, options, [300, 600, 1000, 1500, 2500]);
      return false;
    }

    if (!options.force) {
      try {
        const alive = await wc.executeJavaScript(
          'Boolean(window.__AGContextMeter && document.getElementById("ag-context-meter") && window.__AGContextMeter.ensureAlive())'
        );
        if (alive === true) return true;
      } catch {}
    }

    const src = getMeterSource();
    if (!src) return false;
    await wc.executeJavaScript(src);
    return true;
  } catch (err) {
    scheduleRetry(win, options, [350, 1000, 2500]);
    if (Number(options.attempt || 0) >= 3) {
      console.warn('[Context Meter]', err?.message || String(err));
    }
    return false;
  }
}

function installContextMeter(win) {
  registerIpcOnce();
  if (!win || win.isDestroyed?.()) return;

  if (!boundWindows.has(win)) {
    boundWindows.add(win);
    const onActive = () => void ensureMeterInjected(win, { force: false });
    win.on?.('show', onActive);
    win.on?.('restore', onActive);
    win.on?.('focus', onActive);
  }

  const wc = win.webContents;
  if (wc && !boundWebContents.has(wc)) {
    boundWebContents.add(wc);
    wc.on('did-finish-load', () => void ensureMeterInjected(win, { force: true }));
    wc.on('dom-ready', () => void ensureMeterInjected(win, { force: false }));
    wc.on('did-navigate', () => void ensureMeterInjected(win, { force: false }));
    wc.on('did-navigate-in-page', () => void ensureMeterInjected(win, { force: false }));
  }
}

try {
  if (app && typeof app.on === 'function') {
    app.on('browser-window-created', (_event, win) => {
      try {
        installContextMeter(win);
        void ensureMeterInjected(win, { force: false });
      } catch {}
    });
    app.on('activate', () => {
      try {
        const utils = require('../utils');
        const wins = typeof utils.getLocalHubWindows === 'function'
          ? utils.getLocalHubWindows()
          : (typeof utils.getHubWindows === 'function' ? utils.getHubWindows() : []);
        for (const w of wins) {
          installContextMeter(w);
          void ensureMeterInjected(w, { force: true });
        }
      } catch {}
    });
  }
} catch {}

module.exports = {
  installContextMeter,
  ensureMeterInjected,
};
