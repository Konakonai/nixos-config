'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const core = require('../core');
const { collectTokenHistoryAsync } = require('../collector');

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

test('collector reads transcripts read-only, deduplicates, and merges archived baseline', async () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ag-cm-test-'));
  try {
    const agDir = path.join(tmp, 'antigravity');
    const agCliDir = path.join(tmp, 'antigravity-cli');
    const deskLogDir = path.join(agDir, 'brain', 'conv-1', '.system_generated', 'logs');
    const cliLogDir = path.join(agCliDir, 'brain', 'conv-2', '.system_generated', 'logs');
    fs.mkdirSync(deskLogDir, { recursive: true });
    fs.mkdirSync(cliLogDir, { recursive: true });

    fs.writeFileSync(
      path.join(deskLogDir, 'transcript.jsonl'),
      [
        JSON.stringify({
          step_index: 1,
          callId: 'c1',
          created_at: '2026-11-14T08:00:00Z',
          input_tokens: 100,
          cache_read_tokens: 900,
          output_tokens: 50,
        }),
        JSON.stringify({
          step_index: 1,
          callId: 'c1', // duplicate should be skipped
          created_at: '2026-11-14T08:00:00Z',
          input_tokens: 100,
          cache_read_tokens: 900,
          output_tokens: 50,
        }),
      ].join('\n')
    );

    fs.writeFileSync(
      path.join(cliLogDir, 'transcript.jsonl'),
      JSON.stringify({
        step_index: 1,
        callId: 'c2',
        created_at: '2026-11-14T09:00:00Z',
        chatModel: { usage: { inputTokens: 200, cacheReadTokens: 0, outputTokens: 100 } },
      })
    );

    // Archived day from an older deleted conversation.
    fs.writeFileSync(
      path.join(agDir, 'token_usage_archive_v2.json'),
      JSON.stringify({
        dailyMapBySource: {
          desktop: { '2026-11-01': { total: 5000, input: 1000, cache: 3500, output: 500, steps: 2 } },
          cli: {},
        },
      })
    );

    const res = await collectTokenHistoryAsync({
      agDir,
      agCliDir,
      now: new Date('2026-11-14T16:00:00+08:00'),
    });

    assert.equal(res.todayKey, '2026-11-14');
    assert.equal(res.sources.desktop.today, 1050);
    assert.equal(res.sources.cli.today, 300);
    assert.equal(res.sources.all.today, 1350);
    assert.equal(res.sources.all.total, 6350);
    assert.equal(res.recentDays.length, 14);
    assert.equal(res.recentDays[13].date, '2026-11-14');
    assert.equal(res.recentDays[13].all.total, 1350);
    // Ensure collector remained purely read-only (did not create v1 archive or ledger).
    assert.equal(fs.existsSync(path.join(agDir, 'pricing_ledger_v1.json')), false);
    assert.equal(fs.existsSync(path.join(agDir, 'token_usage_archive_v1.json')), false);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
