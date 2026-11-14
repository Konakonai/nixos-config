'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const SKIP_DIRS = new Set(['steps', 'scratch', 'media', 'artifacts', 'node_modules', '.git', '__pycache__']);
const CACHE_TTL_MS = 15_000;
const MAX_FILE_CACHE = 1000;

const transcriptFileCache = new Map();
let cachedResult = null;
let cachedAt = 0;
let inflight = null;

function formatLocalDateKey(dateObj) {
  const y = dateObj.getFullYear();
  const m = String(dateObj.getMonth() + 1).padStart(2, '0');
  const d = String(dateObj.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function emptyDay() {
  return { total: 0, input: 0, output: 0, cache: 0, steps: 0 };
}

function readJsonSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf8');
    if (!raw.trim()) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function collectTranscriptFiles(rootDir, sourceName) {
  const jobs = [];
  const visited = new Set();

  function walk(dir, depth = 0) {
    if (depth > 4) return;
    try {
      if (!fs.existsSync(dir)) return;
      const real = fs.realpathSync(dir);
      if (visited.has(real)) return;
      visited.add(real);

      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (SKIP_DIRS.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isSymbolicLink()) {
          try {
            const target = fs.realpathSync(full);
            const st = fs.statSync(target);
            if (st.isDirectory()) walk(target, depth + 1);
            else if (entry.name === 'transcript.jsonl') jobs.push({ path: target, source: sourceName });
          } catch {}
        } else if (entry.isDirectory()) {
          if (depth === 0) {
            const stdLog = path.join(full, '.system_generated', 'logs', 'transcript.jsonl');
            const directLog = path.join(full, 'transcript.jsonl');
            let matched = false;
            if (fs.existsSync(stdLog)) {
              jobs.push({ path: stdLog, source: sourceName });
              matched = true;
            }
            if (fs.existsSync(directLog)) {
              jobs.push({ path: directLog, source: sourceName });
              matched = true;
            }
            if (matched) continue;
          }
          walk(full, depth + 1);
        } else if (entry.name === 'transcript.jsonl') {
          jobs.push({ path: full, source: sourceName });
        }
      }
    } catch {}
  }

  walk(rootDir);
  return jobs;
}

function parseTranscriptFile(filePath) {
  const st = fs.statSync(filePath);
  const hit = transcriptFileCache.get(filePath);
  if (hit && hit.size === st.size && hit.mtimeMs === st.mtimeMs) {
    return hit.records;
  }

  const records = [];
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line || !line.trim()) continue;
    let ev;
    try {
      ev = JSON.parse(line);
    } catch {
      continue;
    }

    let dateKey = null;
    if (ev.created_at) {
      const dt = new Date(ev.created_at);
      if (!Number.isNaN(dt.getTime())) dateKey = formatLocalDateKey(dt);
    }
    if (!dateKey) continue;

    let inp = 0;
    let outp = 0;
    let cap = 0;
    if (ev.input_tokens != null || ev.output_tokens != null || ev.cache_read_tokens != null) {
      inp = Number(ev.input_tokens || 0);
      outp = Number(ev.output_tokens || 0);
      cap = Number(ev.cache_read_tokens || 0);
    } else if (ev.chatModel?.usage) {
      const u = ev.chatModel.usage;
      inp = Number(u.inputTokens || 0);
      outp = Number(u.outputTokens || 0);
      cap = Number(u.cacheReadTokens || 0);
    }

    const tot = inp + outp + cap;
    if (tot <= 0) continue;

    const eventId =
      ev.callId ||
      ev.responseId ||
      ev.chatModel?.usage?.responseId ||
      `${filePath}#${ev.step_index ?? i}`;
    records.push({ eventId, dateKey, inp, outp, cap, tot });
  }

  if (transcriptFileCache.size >= MAX_FILE_CACHE) {
    const oldest = transcriptFileCache.keys().next().value;
    if (oldest) transcriptFileCache.delete(oldest);
  }
  transcriptFileCache.set(filePath, { size: st.size, mtimeMs: st.mtimeMs, records });
  return records;
}

function mergeDayMap(scanned, archived) {
  const out = {};
  const keys = new Set([...Object.keys(scanned || {}), ...Object.keys(archived || {})]);
  for (const k of keys) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(k)) continue;
    const s = scanned?.[k];
    const a = archived?.[k];
    if (s && (!a || (s.total || 0) >= (a.total || 0))) {
      out[k] = {
        total: s.total || 0,
        input: s.input || 0,
        output: s.output || 0,
        cache: s.cache || 0,
        steps: s.steps || 0,
      };
    } else if (a) {
      out[k] = {
        total: a.total || 0,
        input: a.input || 0,
        output: a.output || 0,
        cache: a.cache || 0,
        steps: a.steps || 0,
      };
    }
  }
  return out;
}

function summarizeSourceMap(dayMap, todayKey, monthPrefix) {
  let today = 0;
  let month = 0;
  let total = 0;
  let input = 0;
  let cache = 0;
  let output = 0;
  let steps = 0;

  for (const [k, v] of Object.entries(dayMap)) {
    if (!v) continue;
    const t = v.total || 0;
    total += t;
    input += v.input || 0;
    cache += v.cache || 0;
    output += v.output || 0;
    steps += v.steps || 0;
    if (k === todayKey) today += t;
    if (k.startsWith(monthPrefix)) month += t;
  }

  return { today, month, total, input, cache, output, steps };
}

async function collectTokenHistoryAsync(options = {}) {
  const hasCustomDirs = Boolean(options.agDir || options.agCliDir);
  if (!hasCustomDirs && !options.force && cachedResult && Date.now() - cachedAt < CACHE_TTL_MS) {
    return cachedResult;
  }
  if (!hasCustomDirs && inflight) {
    return inflight;
  }

  const run = (async () => {
    const home = process.env.USERPROFILE || os.homedir();
    const agDir = options.agDir || process.env.AG_DIR || path.join(home, '.gemini', 'antigravity');
    const agCliDir = options.agCliDir || process.env.AG_CLI_DIR || path.join(home, '.gemini', 'antigravity-cli');

    const jobs = [
      ...collectTranscriptFiles(path.join(agDir, 'brain'), 'desktop'),
      ...collectTranscriptFiles(path.join(agCliDir, 'brain'), 'cli'),
    ];

    const scanned = { desktop: {}, cli: {} };
    const seen = new Set();

    for (let i = 0; i < jobs.length; i++) {
      if (i > 0 && i % 20 === 0) {
        await new Promise((resolve) => setImmediate(resolve));
      }
      const job = jobs[i];
      try {
        const records = parseTranscriptFile(job.path);
        const bucket = scanned[job.source];
        for (const rec of records) {
          if (seen.has(rec.eventId)) continue;
          seen.add(rec.eventId);
          if (!bucket[rec.dateKey]) bucket[rec.dateKey] = emptyDay();
          const d = bucket[rec.dateKey];
          d.total += rec.tot;
          d.input += rec.inp;
          d.output += rec.outp;
          d.cache += rec.cap;
          d.steps += 1;
        }
      } catch {}
    }

    // Read-only fallback to existing archives so deleted transcripts keep historical totals.
    const v2 = readJsonSafe(path.join(agDir, 'token_usage_archive_v2.json'));
    const v1 = readJsonSafe(path.join(agDir, 'token_usage_archive_v1.json'));
    const desktopMap = mergeDayMap(scanned.desktop, v2?.dailyMapBySource?.desktop);
    const cliMap = mergeDayMap(scanned.cli, v2?.dailyMapBySource?.cli);
    const legacyMap = v2?.dailyMapBySource?.legacyUnallocated || v1?.dailyMap || {};

    const allMap = {};
    const allKeys = new Set([...Object.keys(desktopMap), ...Object.keys(cliMap), ...Object.keys(legacyMap)]);
    for (const k of Array.from(allKeys).sort()) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(k)) continue;
      const d = desktopMap[k] || emptyDay();
      const c = cliMap[k] || emptyDay();
      const l = legacyMap[k] || emptyDay();
      // v1 legacyMap stores total across sources when v2 didn't exist; only top up if desktop+cli is lower.
      const combined = {
        total: (d.total || 0) + (c.total || 0),
        input: (d.input || 0) + (c.input || 0),
        output: (d.output || 0) + (c.output || 0),
        cache: (d.cache || 0) + (c.cache || 0),
        steps: (d.steps || 0) + (c.steps || 0),
      };
      if (!v2?.dailyMapBySource?.desktop && (l.total || 0) > combined.total) {
        allMap[k] = {
          total: l.total || 0,
          input: l.input || 0,
          output: l.output || 0,
          cache: l.cache || 0,
          steps: l.steps || 0,
        };
      } else {
        allMap[k] = combined;
      }
    }

    const now = options.now ? new Date(options.now) : new Date();
    const todayKey = formatLocalDateKey(now);
    const monthPrefix = todayKey.slice(0, 7);

    const recentDays = [];
    for (let offset = 13; offset >= 0; offset--) {
      const dt = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset);
      const key = formatLocalDateKey(dt);
      const pick = (m) => {
        const v = m[key];
        return v ? { total: v.total || 0, input: v.input || 0, cache: v.cache || 0, output: v.output || 0 } : { total: 0, input: 0, cache: 0, output: 0 };
      };
      recentDays.push({
        date: key,
        all: pick(allMap),
        desktop: pick(desktopMap),
        cli: pick(cliMap),
      });
    }

    const result = {
      updatedAt: Date.now(),
      todayKey,
      sources: {
        all: summarizeSourceMap(allMap, todayKey, monthPrefix),
        desktop: summarizeSourceMap(desktopMap, todayKey, monthPrefix),
        cli: summarizeSourceMap(cliMap, todayKey, monthPrefix),
      },
      recentDays,
    };

    if (!hasCustomDirs) {
      cachedResult = result;
      cachedAt = Date.now();
    }
    return result;
  })();

  if (hasCustomDirs) return run;

  inflight = run.finally(() => {
    inflight = null;
  });
  return inflight;
}

module.exports = {
  collectTokenHistoryAsync,
  formatLocalDateKey,
  parseTranscriptFile,
};
