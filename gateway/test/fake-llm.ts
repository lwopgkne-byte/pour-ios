/**
 * 测试用的假大模型（照网页版 server/src/ai/fake-llm.ts）：按调用的 Skill 返回预先写好的内容，记录收到的请求。
 * 测试从不发真实请求、不花钱、不用密钥
 */
import { type LlmClient, LlmError, type LlmRequest, type LlmResponse } from '../src/llm.ts'

/** 回复可以是函数：按请求现写；返回 Promise 的是慢慢回答的大模型（请求被取消时和真的客户端一样报 cancelled） */
type Reply = string | object | LlmError | ((req: LlmRequest) => string | object | Promise<string | object>)

export class FakeLlm implements LlmClient {
  readonly calls: LlmRequest[] = []
  private readonly queues = new Map<string, Reply[]>()

  /** 给某个 Skill 排队准备回复；排空后重复最后一个 */
  on(feature: string, ...replies: Reply[]): this {
    this.queues.set(feature, [...(this.queues.get(feature) ?? []), ...replies])
    return this
  }

  async complete(req: LlmRequest): Promise<LlmResponse> {
    this.calls.push(req)
    const queue = this.queues.get(req.feature)
    if (!queue || queue.length === 0) throw new Error(`假大模型没有为 ${req.feature} 准备回复`)
    const next = queue.length > 1 ? queue.shift()! : queue[0]!
    if (next instanceof LlmError) throw next
    const value = await untilAborted(typeof next === 'function' ? next(req) : next, req.signal)
    return {
      content: typeof value === 'string' ? value : JSON.stringify(value),
      model: 'fake-model',
      promptTokens: 100,
      cacheHitTokens: 80,
      completionTokens: 50,
      durationMs: 5,
    }
  }

  count(feature: string): number {
    return this.calls.filter((c) => c.feature === feature).length
  }
}

/** 请求被取消了（结果用不上）：和真的客户端一样马上报 cancelled，不再等回答 */
function untilAborted<T>(value: T | Promise<T>, signal?: AbortSignal): Promise<T> {
  const cancelled = () => new LlmError('cancelled', '结果用不上了，没等它回答。')
  if (signal?.aborted) return Promise.reject(cancelled())
  if (!signal) return Promise.resolve(value)
  return new Promise<T>((resolve, reject) => {
    signal.addEventListener('abort', () => reject(cancelled()), { once: true })
    Promise.resolve(value).then(resolve, reject)
  })
}

export const recordIntent = (text = '') => ({ intents: [{ type: 'record', text }], reply: '' })

/** 一段时间以后才回答（意图识别先回来、整理还在路上） */
export const later = <T>(value: T, ms = 30) => () => new Promise<T>((resolve) => setTimeout(() => resolve(value), ms))
