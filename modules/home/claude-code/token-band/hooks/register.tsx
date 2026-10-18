import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Stats } from '../types'

const stats = atom({ plugin: 'token-band', key: 'stats' } as const, null)
// Bumped on a timer so the cache countdown redraws between responses.
const tick = atom({ plugin: 'token-band', key: 'tick' } as const, 0)

// Live redraws while streaming are throttled to this interval.
const LIVE_MS = 250
const TICK_MS = 15_000
const TTL_MS: Record<string, number> = { '1h': 3_600_000, '5m': 300_000 }

const fmt = (n: number) =>
  n >= 1000 ? `${(n / 1000).toFixed(n >= 100_000 ? 0 : 1)}k` : `${Math.round(n)}`

const remaining = (ms: number) => {
  const s = Math.ceil(ms / 1000)
  return s >= 60 ? `${Math.ceil(s / 60)}m` : `${s}s`
}

// The user's system palette (Catppuccin, lavender accent, light): the same
// values assets/noctalia/palettes/catppuccin-lavender-light.json feeds niri,
// GTK and kitty. The terminal keeps its own theme keys instead.
const LATTE = {
  accent: '#7c5cfa',
  muted: '#685d82',
  green: '#16a34a',
  yellow: '#df8e1d',
  red: '#e5484d',
}

const ICON = {
  // Lucide "gauge", "database" and "timer", 24-unit grid.
  speed: '<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>',
  cache:
    '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>',
  timer: '<line x1="10" x2="14" y1="2" y2="2"/><line x1="12" x2="15" y1="14" y2="11"/><circle cx="12" cy="14" r="8"/>',
}

const svg = (body: string, color: string) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`

// Clawd, Claude Code's mascot, on an 11×7 pixel grid. While a response
// streams he bobs (SMIL, which needs the sandboxed frame to run).
const CLAWD_BODY = '#d97757'
const CLAWD_EYES = '#2c243e'
const clawd = (isBobbing: boolean) => {
  const px = (x: number, y: number, w: number, h: number, fill: string) =>
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"/>`
  const bob = isBobbing
    ? '<animateTransform attributeName="transform" type="translate" values="0 0;0 -0.7;0 0" dur="0.5s" repeatCount="indefinite"/>'
    : ''
  return (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -1 11 8" shape-rendering="crispEdges"><g>' +
    bob +
    px(1, 0, 9, 4, CLAWD_BODY) +
    px(0, 1, 1, 2, CLAWD_BODY) +
    px(10, 1, 1, 2, CLAWD_BODY) +
    px(3, 1, 1, 1, CLAWD_EYES) +
    px(7, 1, 1, 1, CLAWD_EYES) +
    [2, 4, 6, 8].map(x => px(x, 4, 1, 2, CLAWD_BODY)).join('') +
    '</g></svg>'
  )
}

const blank: Stats = { isStreaming: false, ttftMs: 0, tps: 0, ctxTokens: 0, cacheHit: 0, lastRequestAt: 0 }

// The state outlives a hot reload, so a value saved by an older version may
// lack later fields or hold a NaN: each number that is not finite starts
// over at its blank value.
const restore = (saved: Stats | null): Stats => {
  const s: Stats = { ...blank, ...saved }
  for (const k of ['ttftMs', 'tps', 'ctxTokens', 'cacheHit', 'lastRequestAt'] as const) {
    if (!Number.isFinite(s[k])) {
      s[k] = blank[k]
    }
  }
  return s
}

export const register: Register = (on, options) => {
  const ttlMs = TTL_MS[String(options.cacheTtl)] ?? TTL_MS['1h']!

  on('session.start', async ($, e, next) => {
    $.clock.every(TICK_MS, () => void update($, tick, n => n + 1))
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    // Subagents stream in parallel with the main loop and cache their own
    // prefix; only the main loop is measured.
    if (e.agentId) {
      return yield* next(e)
    }

    const sentAt = await $.clock.now()
    let firstAt = 0
    let lastPush = 0
    let chars = 0

    await update($, stats, s => ({ ...restore(s), isStreaming: true, tps: 0, ttftMs: 0, lastRequestAt: sentAt }))

    for await (const c of next(e)) {
      yield c

      // The clock starts at the first chunk of any kind, the envelope included:
      // thinking is generated (and billed in output_tokens) before any visible
      // text, so starting at the first text chunk inflated tok/s tenfold.
      const now = await $.clock.now()
      if (firstAt === 0) {
        firstAt = now
      }

      if (c.kind === 'engine') {
        continue
      }

      if (c.kind === 'text' || c.kind === 'thinking') {
        chars += c.text.length
      } else if (c.kind === 'input') {
        chars += c.json.length
      }

      if (c.kind === 'stop') {
        const u = c.usage
        const genMs = now - firstAt
        await update($, stats, s => {
          const base = restore(s)
          if (!u) {
            return { ...base, isStreaming: false }
          }
          const ctx = u.input_tokens + u.cache_read_input_tokens + u.cache_creation_input_tokens
          return {
            ...base,
            isStreaming: false,
            ttftMs: firstAt - sentAt,
            tps: genMs > 0 ? (u.output_tokens * 1000) / genMs : 0,
            ctxTokens: ctx,
            cacheHit: ctx > 0 ? u.cache_read_input_tokens / ctx : 0,
          }
        })
      } else if (now - lastPush >= LIVE_MS) {
        lastPush = now
        const genMs = now - firstAt
        await update($, stats, s => ({
          ...restore(s),
          ttftMs: firstAt - sentAt,
          tps: genMs > 0 ? (chars * 250) / genMs : 0,
        }))
      }
    }

    // A stream cut short (interrupt, error) has no stop chunk.
    await update($, stats, s => (s && s.isStreaming ? { ...s, isStreaming: false } : s))
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const saved = await read($, stats)
    if (e.props.hasSurvey || saved === null) {
      return next(e)
    }
    const s = restore(saved)
    await read($, tick)
    const now = await $.clock.now()

    const els = $.ui.resolve(e)
    const { Box, Text } = els
    const isTerminal = e.surface === 'terminal'
    const live = s.isStreaming

    const cache = s.cacheHit * 100
    const tps = s.tps >= 100 ? Math.round(s.tps).toString() : s.tps.toFixed(1)
    const left = s.lastRequestAt > 0 ? s.lastRequestAt + ttlMs - now : -1

    // Latte hex on the remote surfaces; theme keys on the terminal, whose
    // background the person's terminal theme decides.
    const c = isTerminal
      ? { accent: 'claude', muted: 'subtle', green: 'success', yellow: 'warning', red: 'error' }
      : LATTE
    const cacheColor = cache >= 90 ? c.green : cache >= 50 ? c.yellow : c.red
    // Yellow for the last tenth of the TTL: time to send something or lose it.
    const ttlColor = live ? c.green : left <= 0 ? c.red : left <= ttlMs / 10 ? c.yellow : c.green

    const hasSvg = 'Svg' in els && !isTerminal
    const icon = (key: string, source: string, alt: string) =>
      hasSvg ? <els.Svg key={key} source={source} alt={alt} width={14} height={14} /> : null

    const dot = <Text color={c.muted}>{'  ·  '}</Text>

    return (
      <Box flexDirection="row" justifyContent="center" alignItems="center" columnGap={4} width="100%">
        {hasSvg && <els.Svg key="clawd" source={clawd(live)} alt="Clawd" width={22} height={16} isInteractive={live} />}
        <Box key="speed" flexDirection="row" alignItems="center" columnGap={1}>
          {icon('speed-icon', svg(ICON.speed, live ? c.accent : c.muted), 'speed')}
          <Text size="footnote" tabular wrap="truncate" color={c.muted}>
            <Text color={live ? c.accent : undefined} weight="medium">
              {live ? '~' : ''}
              {tps}
            </Text>
            {' tok/s'}
            {dot}
            {'TTFT '}
            <Text weight="medium">{(s.ttftMs / 1000).toFixed(1)}s</Text>
          </Text>
        </Box>
        {s.ctxTokens > 0 && (
          <Box key="cache" flexDirection="row" alignItems="center" columnGap={1}>
            {icon('cache-icon', svg(ICON.cache, c.muted), 'cache')}
            <Text size="footnote" tabular wrap="truncate" color={c.muted}>
              <Text weight="medium">{fmt(s.ctxTokens)}</Text>
              {' tok'}
              {dot}
              {'hit '}
              <Text weight="medium" color={cacheColor}>
                {cache.toFixed(1)}%
              </Text>
            </Text>
          </Box>
        )}
        {s.lastRequestAt > 0 && (
          <Box key="ttl" flexDirection="row" alignItems="center" columnGap={1}>
            {icon('ttl-icon', svg(ICON.timer, ttlColor), 'cache expiry')}
            <Text size="footnote" tabular wrap="truncate" color={c.muted}>
              {live ? (
                <Text weight="medium" color={ttlColor}>
                  warm
                </Text>
              ) : left > 0 ? (
                <Text>
                  {'cold in '}
                  <Text weight="medium" color={ttlColor}>
                    {remaining(left)}
                  </Text>
                </Text>
              ) : (
                <Text weight="medium" color={ttlColor}>
                  cache cold
                </Text>
              )}
            </Text>
          </Box>
        )}
      </Box>
    )
  })
}
