'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const core = require('../core');

test('summarize computes usage, cache hit, speed and TTFT', () => {
  const res = core.summarize({
    chatModel: {
      modelDisplayName: 'Gemini 4 Hydrogen',
      timeToFirstToken: '0.8s',
      streamingDuration: '3.2s',
      usage: {
        inputTokens: 2000,
        cacheReadTokens: 18000,
        outputTokens: 400,
        thinkingOutputTokens: 120,
      },
      chatStartMetadata: {
        contextWindowMetadata: {
          estimatedTokensUsed: 19500,
          maxContextTokens: 1000000,
        },
      },
    },
  });

  assert.equal(res.model, 'Gemini 4 Hydrogen');
  assert.equal(res.actual, 20400);
  assert.equal(res.used, 20400);
  assert.equal(res.estimated, false);
  assert.equal(res.budget, 1000000);
  assert.equal(res.remaining, 979600);
  assert.equal(res.percent, 2.0);
  assert.equal(res.cacheHit, 90.0);
  assert.equal(res.speed.ttft, 0.8);
  assert.equal(res.speed.duration, 4.0);
  assert.equal(res.speed.tps, 100.0);
  assert.equal(res.speed.streamingTps, 125.0);
  assert.equal(res.speed.thinkingTokens, 120);
  assert.equal(res.status, 'reported');
});

test('summarize falls back to estimate when usage is not yet returned', () => {
  const res = core.summarize({
    chatModel: {
      model: 'claude-opus-5-5',
      chatStartMetadata: {
        contextWindowMetadata: {
          estimatedTokensUsed: 50000,
          maxContextTokens: 200000,
        },
      },
    },
  });

  assert.equal(res.actual, null);
  assert.equal(res.used, 50000);
  assert.equal(res.estimated, true);
  assert.equal(res.percent, 25.0);
  assert.equal(res.status, 'estimated');
});

test('summarize classifies context overflow and preserves prior context on transient errors', () => {
  const prev = core.summarize({
    chatModel: {
      usage: { inputTokens: 1000, cacheReadTokens: 9000, outputTokens: 100 },
      chatStartMetadata: { contextWindowMetadata: { maxContextTokens: 100000 } },
    },
  });

  const rateLimited = core.summarize(
    { chatModel: { retryInfos: [{ error: '429 Too Many Requests, retry in 12s' }] } },
    { previousValidContext: prev }
  );
  assert.equal(rateLimited.status, 'rate_limited');
  assert.equal(rateLimited.actual, 10100);
  assert.equal(rateLimited.errorInfo.label, '请求限流');

  const overflow = core.summarize(
    { chatModel: { error: 'input token count exceeds maximum context length limit of 1000000' } },
    { previousValidContext: prev }
  );
  assert.equal(overflow.exceeded, true);
  assert.equal(overflow.status, 'context_overflow');
  assert.equal(overflow.errorInfo.serviceLimit, 1000000);
});

test('formatTokens formats compact units cleanly', () => {
  assert.equal(core.formatTokens(null), '—');
  assert.equal(core.formatTokens(850), '850');
  assert.equal(core.formatTokens(1250), '1.3k');
  assert.equal(core.formatTokens(125000), '125k');
  assert.equal(core.formatTokens(1450000), '1.45M');
});

test('renderer and main stay inline and lightweight without history, native titles, or titlebar widgets', () => {
  const rendererSrc = fs.readFileSync(path.join(__dirname, '..', 'renderer.js'), 'utf8');
  const mainSrc = fs.readFileSync(path.join(__dirname, '..', 'main.js'), 'utf8');

  assert.equal(rendererSrc.includes('titlebar'), false);
  assert.equal(rendererSrc.includes('实际统计'), false);
  assert.equal(rendererSrc.includes('历史用量'), false);
  assert.equal(rendererSrc.includes('contextMeterAPI'), false);
  assert.equal(rendererSrc.includes('.title ='), false);
  assert.equal(rendererSrc.includes('justify-content: center'), true);

  const order = ['id="cm-tps"', 'id="cm-cache"', 'id="cm-out"', 'id="cm-ctx"', 'id="cm-ttft"'];
  const indices = order.map((marker) => rendererSrc.indexOf(marker));
  for (let i = 1; i < indices.length; i++) {
    assert.ok(indices[i - 1] >= 0 && indices[i] > indices[i - 1], `expected ${order[i - 1]} before ${order[i]}`);
  }

  assert.equal(mainSrc.includes('ipcMain'), false);
  assert.equal(mainSrc.includes('collector'), false);
});
