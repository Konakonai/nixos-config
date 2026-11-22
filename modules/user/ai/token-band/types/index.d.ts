export type Stats = {
  /** A main-loop response is streaming now. */
  isStreaming: boolean
  /** Request sent → first chunk, ms. */
  ttftMs: number
  /** Output tokens per second, first chunk → stop; while streaming, from a chars/4 estimate. */
  tps: number
  /** Prompt size of the last request: input + cache read + cache write. */
  ctxTokens: number
  /** Share of the prompt served from cache, 0..1. */
  cacheHit: number
  /** When the last main-loop request was sent ($.clock.now() ms): the cache TTL runs from here. */
  lastRequestAt: number
}

declare module 'claude-code' {
  interface PluginState {
    'token-band': { stats: Stats | null; tick: number }
  }
}
