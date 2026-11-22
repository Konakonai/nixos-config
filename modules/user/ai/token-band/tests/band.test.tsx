import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 10,
    bodyColumns: 200,
    scroll: { offset: 0, bodyRows: 10 },
    view: {},
  },
} as const

const USAGE = {
  model: 'claude-opus-5-5',
  input_tokens: 100,
  output_tokens: 200,
  cache_read_input_tokens: 900,
  cache_creation_input_tokens: 0,
}

test('reports speed, TTFT and cache from a streamed response', async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  // Stand-in for the API: first chunk after 500ms, stop 2s later with 200 tokens.
  on('turn.step', async function* () {
    await clock.sleep(500)
    yield { kind: 'text', index: 0, text: 'hello world' }
    await clock.sleep(2000)
    yield {
      kind: 'stop',
      stopReason: 'end_turn',
      usage: USAGE,
    }
    return { turnId: 't1', index: 0, answer: 'hello world', toolUses: [], stopReason: 'end_turn', usage: USAGE }
  })

  const run = (async () => {
    for await (const _ of $.turn.step({ turnId: 't1', index: 0, model: 'claude-opus-5-5', messageCount: 1 })) {
      // drain
    }
  })()
  await clock.advance(500)
  await clock.advance(2000)
  await run

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'token-band', surface, ...BAND })
    expect(await ui.find({ type: 'Text', text: /^100 tok\/s  ·  TTFT 0\.5s$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^1\.0k tok  ·  hit 90\.0%$/ })).toBeDefined()
    await ui.unmount()
  }
})

test('counts hidden thinking time in the speed', async ($, on) => {
  const clock = mock.clock(on, { now: 0 })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  // First chunk at 500ms (a test cannot mint the engine's envelope), 1.9s of unseen thinking, text at 2.4s, stop at 2.5s.
  on('turn.step', async function* () {
    await clock.sleep(500)
    yield { kind: 'thinking', index: 0, text: '' }
    await clock.sleep(1900)
    yield { kind: 'text', index: 0, text: 'hi' }
    await clock.sleep(100)
    yield { kind: 'stop', stopReason: 'end_turn', usage: USAGE }
    return { turnId: 't1', index: 0, answer: 'hi', toolUses: [], stopReason: 'end_turn', usage: USAGE }
  })

  const run = (async () => {
    for await (const _ of $.turn.step({ turnId: 't1', index: 0, model: 'claude-opus-5-5', messageCount: 1 })) {
      // drain
    }
  })()
  await clock.advance(500)
  await clock.advance(1900)
  await clock.advance(100)
  await run

  const ui = await $.ui.mount({ plugin: 'token-band', surface: 'desktop', ...BAND })
  expect(await ui.find({ type: 'Text', text: /^100 tok\/s/ })).toBeDefined()
  await ui.unmount()
})

for (const [ttl, coldAt] of [
  ['1h', 3_600_000],
  ['5m', 300_000],
] as const) {
  test(`counts the ${ttl} cache down from the last request`, { options: { cacheTtl: ttl } }, async ($, on) => {
    // The request goes out at 1s: 0 reads as "no request yet".
    const clock = mock.clock(on, { now: 1000 })
    on('ui.render', ($, e) => {
      const { Text } = $.ui.resolve(e)
      return <Text>engine</Text>
    })
    on('turn.step', async function* (_$, e) {
      yield { kind: 'stop', stopReason: 'end_turn', usage: USAGE }
      return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: USAGE }
    })
    for await (const _ of $.turn.step({ turnId: 't1', index: 0, model: 'claude-opus-5-5', messageCount: 1 })) {
      // drain
    }

    const at = async (ms: number, text: RegExp) => {
      await clock.set(1000 + ms)
      const ui = await $.ui.mount({ plugin: 'token-band', surface: 'desktop', ...BAND })
      expect(await ui.find({ type: 'Text', text })).toBeDefined()
      await ui.unmount()
    }
    await at(coldAt - 125_000, /^cold in 3m$/)
    await at(coldAt - 30_000, /^cold in 30s$/)
    await at(coldAt, /^cache cold$/)
  })
}

test('draws nothing before the first response', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'token-band', surface, ...BAND })
    expect(await ui.find({ type: 'Text', text: /tok\/s/ })).toBeUndefined()
    await ui.unmount()
  }
})
