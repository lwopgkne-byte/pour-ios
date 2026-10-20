/**
 * 网关的 HTTP 服务（ADR A08）：
 * - GET /health：活着没有、用哪个模型、密钥填了没有；?deep=1 再真的问大模型一句，看密钥能不能用（密钥本身永远不出现）
 * - POST /v1/understand：背景包进、改动包出（docs/03 第 8 节）
 * - POST /v1/summary：这一天的记录进、一句话总结出
 *
 * 网关不存任何东西：原话只在这一次请求里用，日志里只有多久、用了多少，没有原话。
 * 设了开发令牌（POUR_DEV_TOKEN）就要带着它来；听局域网时必须设（见 main.ts）。上架前换成设备证明
 */
import { timingSafeEqual } from 'node:crypto'
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify'
import { InvalidOutputError } from './call-skill.ts'
import { BackgroundPackage, CONTRACT_VERSION, type ChangePackage } from './contract.ts'
import type { GatewayConfig } from './env.ts'
import { type LlmClient, LlmError, type LlmErrorCode } from './llm.ts'
import type { Pairing } from './pairing.ts'
import { describeZodError } from './schemas.ts'
import { SummaryRequest, summarize } from './summary.ts'
import { understand } from './understand.ts'

export interface ServerDeps {
  config: GatewayConfig
  llm: LlmClient
  /** 听局域网时有：真机用配对码换来的令牌 */
  pairing?: Pairing
  skillsDir?: string
  /** 每个请求一行日志（测试里收起来看） */
  log?: (line: string) => void
}

/** 出错时回给手机的样子：code 给程序判断，message 是给人看的一句话，retryable 是过一会儿再试有没有用 */
export interface GatewayError {
  error: { code: string; message: string; retryable: boolean }
}

/** 大模型的错误 → HTTP 状态和要不要过一会儿再试（余额、密钥要人去处理，自动重试没用） */
const LLM_ERRORS: Record<LlmErrorCode, { status: number; retryable: boolean }> = {
  not_configured: { status: 503, retryable: false },
  bad_key: { status: 502, retryable: false },
  insufficient_balance: { status: 502, retryable: false },
  rate_limited: { status: 429, retryable: true },
  upstream: { status: 502, retryable: true },
  bad_request: { status: 502, retryable: false },
  timeout: { status: 504, retryable: true },
  network: { status: 502, retryable: true },
  cancelled: { status: 503, retryable: true },
  empty_response: { status: 502, retryable: true },
}

export function buildServer(deps: ServerDeps): FastifyInstance {
  const { config } = deps
  const log = deps.log ?? ((line: string) => console.log(line))
  // 背景包里有今天的记录和前后几天的待办，几百条也不过几十 KB
  const app = Fastify({ logger: false, bodyLimit: 512 * 1024 })

  const fail = (reply: FastifyReply, status: number, code: string, message: string, retryable: boolean) =>
    reply.code(status).send({ error: { code, message, retryable } } satisfies GatewayError)

  /** 只听本机、也没设开发令牌：不用令牌（模拟器）；从这台 Mac 自己来的也不用；别的要带开发令牌或者配对换来的令牌 */
  const authorized = (req: FastifyRequest): boolean => {
    if (!config.devToken && !deps.pairing) return true
    if (!config.devToken && ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(req.ip)) return true
    const token = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1] ?? ''
    if (deps.pairing?.accepts(token)) return true
    if (!config.devToken) return false
    const given = Buffer.from(token)
    const expected = Buffer.from(config.devToken)
    return given.length === expected.length && timingSafeEqual(given, expected)
  }

  app.get('/health', async (req, reply) => {
    const deep = (req.query as Record<string, string | undefined>).deep === '1'
    const base = { ok: true, contract: CONTRACT_VERSION, model: config.model, key: config.apiKey ? 'set' : 'missing' }
    if (!deep) return base
    if (!authorized(req)) return fail(reply, 401, 'unauthorized', '开发令牌不对。', false)
    if (!config.apiKey) return base
    try {
      await deps.llm.complete({ feature: 'health', messages: [{ role: 'user', content: '回一个字：好' }], maxTokens: 2, temperature: 0 })
      return { ...base, key: 'valid' }
    } catch (err) {
      const code = err instanceof LlmError ? err.code : 'unknown'
      return { ...base, key: code === 'bad_key' ? 'invalid' : 'unchecked', problem: (err as Error).message }
    }
  })

  app.post('/v1/pair', async (req, reply) => {
    if (!deps.pairing) return fail(reply, 404, 'not_pairing', '网关只听本机，不用配对。', false)
    const body = (req.body ?? {}) as { code?: unknown; device?: unknown }
    const token = deps.pairing.pair(String(body.code ?? ''), String(body.device ?? ''))
    if (!token) return fail(reply, 403, 'wrong_code', '配对码不对。看一下 Mac 上网关显示的 6 位数字。', false)
    log(`${new Date().toISOString()} 配对了一台：${String(body.device ?? 'iPhone').slice(0, 60)}`)
    return { token }
  })

  app.post('/v1/understand', async (req, reply) => {
    const started = Date.now()
    if (!authorized(req)) return fail(reply, 401, 'unauthorized', '开发令牌不对。', false)
    const version = (req.body as { version?: unknown } | null)?.version
    if (typeof version === 'number' && version !== CONTRACT_VERSION) {
      return fail(reply, 400, 'contract_version', `手机和网关的接口版本对不上（手机 ${version}，网关 ${CONTRACT_VERSION}）。`, false)
    }
    const parsed = BackgroundPackage.safeParse(req.body)
    if (!parsed.success) return fail(reply, 400, 'bad_request', `背景包的格式不对：${describeZodError(parsed.error)}`, false)
    try {
      const result: ChangePackage = await understand(parsed.data, { llm: deps.llm, ...(deps.skillsDir ? { skillsDir: deps.skillsDir } : {}) })
      log(requestLine(started, 200, result))
      return result
    } catch (err) {
      if (err instanceof LlmError) {
        const { status, retryable } = LLM_ERRORS[err.code]
        log(requestLine(started, status, undefined, err.code))
        return fail(reply, status, err.code, err.message, retryable)
      }
      if (err instanceof InvalidOutputError) {
        log(requestLine(started, 502, undefined, 'invalid_output'))
        return fail(reply, 502, 'invalid_output', err.message, true)
      }
      log(requestLine(started, 500, undefined, 'internal'))
      return fail(reply, 500, 'internal', `网关出错了：${(err as Error).message}`, true)
    }
  })

  app.post('/v1/summary', async (req, reply) => {
    const started = Date.now()
    if (!authorized(req)) return fail(reply, 401, 'unauthorized', '开发令牌不对。', false)
    const parsed = SummaryRequest.safeParse(req.body)
    if (!parsed.success) return fail(reply, 400, 'bad_request', `总结的请求格式不对：${describeZodError(parsed.error)}`, false)
    try {
      const result = await summarize(parsed.data, { llm: deps.llm, ...(deps.skillsDir ? { skillsDir: deps.skillsDir } : {}) })
      log(`${new Date().toISOString()} 总结 200 ${Date.now() - started}ms ${parsed.data.records.length} 条`)
      return result
    } catch (err) {
      if (err instanceof LlmError) {
        const { status, retryable } = LLM_ERRORS[err.code]
        return fail(reply, status, err.code, err.message, retryable)
      }
      return fail(reply, 502, 'invalid_output', (err as Error).message, true)
    }
  })

  return app
}

/** 一个请求一行：多久、几步、用了多少（命中缓存多少）、出了什么错。没有原话 */
function requestLine(started: number, status: number, result?: ChangePackage, error?: string): string {
  const steps = result?.steps ?? []
  const sum = (key: 'promptTokens' | 'cacheHitTokens' | 'completionTokens') => steps.reduce((n, s) => n + (s[key] ?? 0), 0)
  const detail = steps.map((s) => `${s.step} ${s.durationMs}ms${s.error ? '（出错）' : ''}`).join('，')
  const usage = result ? ` 输入 ${sum('promptTokens')}（缓存 ${sum('cacheHitTokens')}）输出 ${sum('completionTokens')}` : ''
  const counts = result ? ` ${result.intents.join('+')} 新建 ${result.creates.length}` : ''
  return `${new Date().toISOString()} 理解 ${status} ${Date.now() - started}ms${counts}${usage}${detail ? ` [${detail}]` : ''}${error ? ` ${error}` : ''}`
}
