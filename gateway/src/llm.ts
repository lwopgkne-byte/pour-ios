/**
 * 大模型客户端（OpenAI 兼容格式，照网页版 server/src/llm/client.ts）：请求、超时、取消、把失败翻译成平实的话。
 * 测试时用假的实现代替，不发真实请求。
 */
import type { GatewayConfig } from './env.ts'

export interface LlmMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface LlmRequest {
  /** 用途：router / parse-note …（记用量用） */
  feature: string
  messages: LlmMessage[]
  json?: boolean
  maxTokens?: number
  temperature?: number
  signal?: AbortSignal
}

export interface LlmResponse {
  content: string
  model: string
  promptTokens: number
  /** 输入里命中上下文缓存的部分：价格只有几十分之一 */
  cacheHitTokens: number
  completionTokens: number
  durationMs: number
}

export interface LlmClient {
  complete(req: LlmRequest): Promise<LlmResponse>
}

export type LlmErrorCode =
  | 'not_configured'
  | 'bad_key'
  | 'insufficient_balance'
  | 'rate_limited'
  | 'upstream'
  | 'bad_request'
  | 'timeout'
  | 'network'
  | 'cancelled'
  | 'empty_response'

export class LlmError extends Error {
  constructor(
    readonly code: LlmErrorCode,
    message: string,
  ) {
    super(message)
    this.name = 'LlmError'
  }
}

const TIMEOUT_MS = 90_000

/** 把接口错误翻译成平实的中文（密钥本身永远不出现在这里） */
export function translateStatus(status: number, body: string): LlmError {
  if (status === 401) return new LlmError('bad_key', '大模型密钥无效：检查 gateway/.env 里的 DEEPSEEK_API_KEY。')
  if (status === 402) return new LlmError('insufficient_balance', '大模型账户余额不足。充值后会自动继续整理。')
  if (status === 429) return new LlmError('rate_limited', '大模型那边请求太多，暂时被限流。稍后会自动重试。')
  if (status >= 500) return new LlmError('upstream', '大模型服务暂时出错。稍后会自动重试。')
  return new LlmError('bad_request', `大模型拒绝了这次请求（${status}）：${body.slice(0, 200)}`)
}

export function createLlmClient(config: GatewayConfig, fetchImpl: typeof fetch = fetch): LlmClient {
  return {
    async complete(req) {
      if (!config.apiKey) throw new LlmError('not_configured', '还没有填写大模型密钥：在 gateway/.env 里写 DEEPSEEK_API_KEY。')
      if (req.signal?.aborted) throw new LlmError('cancelled', '结果用不上了，取消了这次请求。')
      const started = Date.now()
      const controller = new AbortController()
      const cancel = () => controller.abort()
      req.signal?.addEventListener('abort', cancel, { once: true })
      const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
      try {
        let res: Response
        try {
          res = await fetchImpl(`${config.baseUrl}/chat/completions`, {
            method: 'POST',
            signal: controller.signal,
            headers: { 'content-type': 'application/json', authorization: `Bearer ${config.apiKey}` },
            body: JSON.stringify({
              model: config.model,
              ...(config.thinking ? { thinking: { type: config.thinking } } : {}),
              messages: req.messages,
              stream: false,
              ...(req.json ? { response_format: { type: 'json_object' } } : {}),
              ...(req.maxTokens ? { max_tokens: req.maxTokens } : {}),
              ...(req.temperature !== undefined ? { temperature: req.temperature } : {}),
            }),
          })
        } catch (err) {
          if (req.signal?.aborted) throw new LlmError('cancelled', '结果用不上了，取消了这次请求。')
          if ((err as Error).name === 'AbortError') throw new LlmError('timeout', '大模型超过 90 秒没有回应。稍后会自动重试。')
          throw new LlmError('network', '连不上大模型服务，可能是网络断了。')
        }
        if (!res.ok) throw translateStatus(res.status, await res.text().catch(() => ''))
        const json = (await res.json().catch(() => null)) as {
          choices?: { message?: { content?: string } }[]
          usage?: { prompt_tokens?: number; completion_tokens?: number; prompt_cache_hit_tokens?: number }
          model?: string
        } | null
        const content = json?.choices?.[0]?.message?.content ?? ''
        // 官方文档提到 JSON 模式偶尔返回空内容：当作输出不合格，由调用方重试
        if (!content.trim()) throw new LlmError('empty_response', '大模型返回了空内容。')
        return {
          content,
          model: json?.model ?? config.model,
          promptTokens: json?.usage?.prompt_tokens ?? 0,
          cacheHitTokens: json?.usage?.prompt_cache_hit_tokens ?? 0,
          completionTokens: json?.usage?.completion_tokens ?? 0,
          durationMs: Date.now() - started,
        }
      } finally {
        clearTimeout(timer)
        req.signal?.removeEventListener('abort', cancel)
      }
    },
  }
}
