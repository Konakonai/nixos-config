(function (root) {
  'use strict';

  const toNum = (v) =>
    v !== undefined && v !== null && Number.isFinite(Number(v)) && Number(v) >= 0 ? Number(v) : null;

  function parseDurationSec(value) {
    if (value === undefined || value === null) return null;
    if (typeof value === 'number') return Number.isFinite(value) && value >= 0 ? value : null;
    const match = String(value).trim().match(/^([\d.]+)\s*s?$/i);
    if (!match) return null;
    const num = parseFloat(match[1]);
    return Number.isFinite(num) && num >= 0 ? num : null;
  }

  function formatTokens(n) {
    if (n === null || n === undefined || !Number.isFinite(n)) return '—';
    if (n >= 1e9) return `${parseFloat((n / 1e9).toFixed(2))}B`;
    if (n >= 1e6) return `${parseFloat((n / 1e6).toFixed(2))}M`;
    if (n >= 1000) {
      const k = n / 1000;
      return k >= 100 ? `${Math.round(k)}k` : `${parseFloat(k.toFixed(1))}k`;
    }
    return String(Math.round(n));
  }

  function formatFull(n) {
    if (n === null || n === undefined || !Number.isFinite(n)) return '—';
    return Math.round(n).toLocaleString('en-US');
  }

  function classifyError(rawError) {
    const error = typeof rawError === 'string' ? rawError : String(rawError?.error || rawError?.message || '');
    if (!error) return { kind: 'none', label: '正常', detail: '', serviceLimit: null };

    let diagnostic = error.replace(/https?:\/\/[^\s"']+/g, '<URL>').trim();
    if (diagnostic.length > 120) diagnostic = diagnostic.slice(0, 117) + '...';

    const isDeadlineTimeout = /context deadline exceeded|deadline exceeded|stream idle timeout/i.test(error);
    if (
      !isDeadlineTimeout &&
      /input token count exceeds|context\s*(?:window|length|tokens?|limit|size|capacity)?.{0,35}(?:exceed|too long)|maximum context length|prompt exceeds maximum context length|max_tokens exceeded/i.test(
        error
      )
    ) {
      const limitStr = error.match(/(?:allowed|limit(?:\s+of)?|length(?:\s+is|\s+of)?)\s*[:=]?\s*([\d,]+)/i)?.[1];
      const serviceLimit = limitStr ? toNum(limitStr.replaceAll(',', '')) : null;
      return {
        kind: 'context_overflow',
        label: '上下文超限',
        detail: `输入超出模型容量上限${serviceLimit ? ` (${formatFull(serviceLimit)})` : ''}`,
        serviceLimit,
      };
    }

    if (
      /(?:quota\s*(?:exceeded|reached|limit|exhausted)|out\s+of\s+quota|exhausted.*(?:capacity|quota)|resource_exhausted.*(?:quota|capacity|billing)|free\s+tier\s+quota|daily\s+quota|weekly\s+quota)/i.test(
        error
      )
    ) {
      return { kind: 'quota_exhausted', label: '额度耗尽', detail: '当前模型配额已用尽，可切换其他模型', serviceLimit: null };
    }

    if (/(?:rate\s*limit|too\s*many\s*requests|\b429\b|RateLimitError|RESOURCE_EXHAUSTED.*rate)/i.test(error)) {
      const sec = error.match(/(?:retry\s+in|retry-after|wait)\s*[:=]?\s*([\d.]+)\s*(?:s|sec|seconds)?/i)?.[1];
      return {
        kind: 'rate_limited',
        label: '请求限流',
        detail: sec ? `触发 429 限流，建议 ${sec}s 后重试` : '触发 429 频率限制，请稍后重试',
        serviceLimit: null,
      };
    }

    if (/(?:context canceled by user|user cancelled|request was aborted|AbortError)/i.test(error)) {
      return { kind: 'canceled', label: '已取消', detail: '请求已取消', serviceLimit: null };
    }

    if (/(?:UNAUTHENTICATED|PERMISSION_DENIED|\b401\b|\b403\b|invalid api key|credentials expired|permission denied)/i.test(error)) {
      return { kind: 'auth_error', label: '认证异常', detail: '身份认证或权限校验失败', serviceLimit: null };
    }

    if (/(?:UNAVAILABLE|\b503\b|\b502\b|\b504\b|server overloaded|high demand|Bad Gateway|Service Unavailable)/i.test(error)) {
      return { kind: 'service_unavailable', label: '服务受限', detail: '服务端暂时过载或不可用', serviceLimit: null };
    }

    if (/(?:\bEOF\b|idle timeout|deadline exceeded|ECONNRESET|ECONNREFUSED|ETIMEDOUT|ENOTFOUND|socket hang up|fetch failed|Failed to fetch|NetworkError)/i.test(error)) {
      return { kind: 'network_error', label: '网络异常', detail: `连接异常：${diagnostic}`, serviceLimit: null };
    }

    return { kind: 'unknown', label: '请求失败', detail: diagnostic, serviceLimit: null };
  }

  function summarize(metadata, options = {}) {
    const m = metadata?.chatModel;
    if (!m) return null;

    const lastRetry = (m.retryInfos || []).at(-1);
    const error = String(lastRetry?.error || m.error || '');
    const model = m.modelDisplayName || m.responseModel || m.model || options.currentModel || '';
    const errInfo = classifyError(error);
    const exceeded = errInfo.kind === 'context_overflow';

    const usage = lastRetry ? lastRetry.usage : m.usage;
    const input = toNum(usage?.inputTokens) ?? 0;
    const cached = toNum(usage?.cacheReadTokens) ?? 0;
    const output = toNum(usage?.outputTokens);
    const thinking = toNum(usage?.thinkingOutputTokens) ?? 0;
    const hasInput = input + cached > 0;

    const prev = error ? options.previousValidContext || null : null;
    let actual = hasInput && !error ? input + cached + (output ?? 0) : null;
    if (actual === null && prev?.actual != null && !exceeded) {
      actual = prev.actual;
    }

    const ctxMeta = m.chatStartMetadata?.contextWindowMetadata;
    const estimate = toNum(ctxMeta?.estimatedTokensUsed) || prev?.estimate || null;
    const budget = toNum(ctxMeta?.maxContextTokens) || prev?.budget || null;

    const promptTokens = hasInput && !error ? input + cached : prev?.promptTokens ?? null;
    const cacheReadTokens = hasInput && !error ? cached : prev?.cacheReadTokens ?? null;
    const cacheHit =
      promptTokens != null && promptTokens > 0 && cacheReadTokens != null
        ? Number(((cacheReadTokens / promptTokens) * 100).toFixed(1))
        : null;

    const ttft = parseDurationSec(m.timeToFirstToken);
    const streamingSec = parseDurationSec(m.streamingDuration);
    const duration = ttft !== null && streamingSec !== null ? ttft + streamingSec : ttft ?? streamingSec ?? null;
    const tps = output && duration && duration > 0 ? Number((output / duration).toFixed(1)) : null;
    const streamingTps = output && streamingSec && streamingSec > 0.05 ? Number((output / streamingSec).toFixed(1)) : null;

    const speed =
      tps !== null || duration !== null || output !== null
        ? {
            tps,
            streamingTps,
            duration: duration !== null ? Number(duration.toFixed(2)) : null,
            ttft: ttft !== null ? Number(ttft.toFixed(2)) : null,
            streamingSec: streamingSec !== null ? Number(streamingSec.toFixed(2)) : null,
            outputTokens: output ?? 0,
            thinkingTokens: thinking,
          }
        : null;

    const used = actual ?? (estimate && estimate > 0 ? estimate : null);
    const estimated = actual === null && used !== null;
    const percent = used !== null && budget && budget > 0 && !exceeded ? Number(((used / budget) * 100).toFixed(1)) : null;

    let status = 'pending';
    if (errInfo.kind !== 'none') status = errInfo.kind;
    else if (actual !== null) status = 'reported';
    else if (estimate && estimate > 0) status = 'estimated';

    return {
      model,
      used,
      actual,
      estimate: estimate && estimate > 0 ? estimate : null,
      budget: budget && budget > 0 ? budget : null,
      remaining: used !== null && budget && budget > 0 ? Math.max(0, budget - used) : null,
      percent,
      estimated,
      exceeded,
      inputTokens: hasInput && !error ? input : prev?.inputTokens ?? null,
      promptTokens,
      cacheReadTokens,
      cacheHit,
      outputTokens: output ?? prev?.outputTokens ?? null,
      status,
      error,
      errorInfo: errInfo,
      speed,
    };
  }

  const api = {
    parseDurationSec,
    formatTokens,
    formatFull,
    classifyError,
    summarize,
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.__AGContextMeterCore = api;
})(globalThis);
