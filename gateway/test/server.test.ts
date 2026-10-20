import { afterEach, describe, expect, it } from 'vitest'
import type { FastifyInstance } from 'fastify'
import { CONTRACT_VERSION } from '../src/contract.ts'
import { type GatewayConfig, parseEnvFile, loadConfig } from '../src/env.ts'
import { LlmError } from '../src/llm.ts'
import { buildServer } from '../src/server.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage, run } from './sample.ts'

const config: GatewayConfig = {
  apiKey: 'sk-test',
  baseUrl: 'https://api.deepseek.com',
  model: 'deepseek-flash',
  thinking: 'disabled',
  host: '127.0.0.1',
  port: 0,
  devToken: null,
}

let app: FastifyInstance
afterEach(async () => app?.close())

const serve = (llm: FakeLlm, over: Partial<GatewayConfig> = {}) => {
  const lines: string[] = []
  app = buildServer({ config: { ...config, ...over }, llm, log: (l) => lines.push(l) })
  return lines
}

describe('网关服务', () => {
  it('健康检查：说有没有密钥，不说密钥是什么', async () => {
    serve(new FakeLlm())
    const res = await app.inject({ method: 'GET', url: '/health' })
    expect(res.json()).toEqual({ ok: true, contract: CONTRACT_VERSION, model: 'deepseek-flash', key: 'set' })
    expect(res.body).not.toContain('sk-test')
  })

  it('深度健康检查：真的问一句，密钥不对就说不对', async () => {
    serve(new FakeLlm().on('health', new LlmError('bad_key', '大模型密钥无效')))
    const res = await app.inject({ method: 'GET', url: '/health?deep=1' })
    expect(res.json()).toMatchObject({ key: 'invalid' })
    serve(new FakeLlm().on('health', '好'))
    expect((await app.inject({ method: 'GET', url: '/health?deep=1' })).json()).toMatchObject({ key: 'valid' })
  })

  it('理解：背景包进、改动包出；日志里没有原话', async () => {
    const lines = serve(new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [run], reply: '记下了。' }))
    const res = await app.inject({ method: 'POST', url: '/v1/understand', payload: backgroundPackage('8点开始跑步跑了一个小时') })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ version: CONTRACT_VERSION, noteId: 'note-1', intents: ['record'], creates: [{ data: { label: '跑步' } }], reply: '记下了。' })
    expect(lines).toHaveLength(1)
    expect(lines[0]).toMatch(/理解 200 .*record 新建 1/)
    expect(lines[0]).not.toContain('跑步')
  })

  it('背景包不对：400，说清楚哪里不对；版本对不上单独说', async () => {
    serve(new FakeLlm())
    const bad = await app.inject({ method: 'POST', url: '/v1/understand', payload: { ...backgroundPackage('x'), categories: [] } })
    expect(bad.statusCode).toBe(400)
    expect(bad.json().error).toMatchObject({ code: 'bad_request', retryable: false })
    expect(bad.json().error.message).toContain('categories')
    const old = await app.inject({ method: 'POST', url: '/v1/understand', payload: { ...backgroundPackage('x'), version: 9 } })
    expect(old.json().error.code).toBe('contract_version')
  })

  it('大模型的错误翻成给手机的错误：要不要过一会儿再试', async () => {
    serve(new FakeLlm().on('router', new LlmError('timeout', '超时')).on('parse-note', { items: [], reply: '' }))
    const res = await app.inject({ method: 'POST', url: '/v1/understand', payload: backgroundPackage('8点开始跑步') })
    expect(res.statusCode).toBe(504)
    expect(res.json().error).toEqual({ code: 'timeout', message: '超时', retryable: true })
    serve(new FakeLlm().on('router', new LlmError('insufficient_balance', '余额不足')).on('parse-note', { items: [], reply: '' }))
    const broke = await app.inject({ method: 'POST', url: '/v1/understand', payload: backgroundPackage('8点开始跑步') })
    expect(broke.json().error).toMatchObject({ code: 'insufficient_balance', retryable: false })
  })

  it('设了开发令牌：没带、带错都不理', async () => {
    serve(new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [], reply: '' }), { devToken: 'abc123' })
    const payload = backgroundPackage('8点开始跑步')
    expect((await app.inject({ method: 'POST', url: '/v1/understand', payload })).statusCode).toBe(401)
    const wrong = { authorization: 'Bearer abc124' }
    expect((await app.inject({ method: 'POST', url: '/v1/understand', payload, headers: wrong })).statusCode).toBe(401)
    const right = { authorization: 'Bearer abc123' }
    expect((await app.inject({ method: 'POST', url: '/v1/understand', payload, headers: right })).statusCode).toBe(200)
  })
})

describe('配置', () => {
  it('读 .env：注释、空行、引号', () => {
    expect(parseEnvFile('# 注释\n\nDEEPSEEK_API_KEY="sk-1"\nLLM_MODEL = deepseek-pro \nbad line')).toEqual({ DEEPSEEK_API_KEY: 'sk-1', LLM_MODEL: 'deepseek-pro' })
  })

  it('默认：Flash、只听本机、DeepSeek 关掉深度思考；别的服务不发这个参数', () => {
    const c = loadConfig({}, '/不存在的文件')
    expect(c).toMatchObject({ apiKey: null, model: 'deepseek-flash', host: '127.0.0.1', port: 5480, thinking: 'disabled', devToken: null })
    expect(loadConfig({ LLM_BASE_URL: 'https://example.com/v1/' }, '/不存在的文件')).toMatchObject({ baseUrl: 'https://example.com/v1', thinking: null })
  })
})

describe('真机配对', () => {
  it('配对码换令牌；令牌能用；配好一台就换配对码；输错 5 次也换', async () => {
    const { Pairing } = await import('../src/pairing.ts')
    const pairing = new Pairing(null)
    app = buildServer({ config, llm: new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [], reply: '' }), pairing, log: () => {} })
    const payload = backgroundPackage('8点开始跑步')
    // 从这台 Mac 自己来的（模拟器）不用令牌；局域网里别的设备要
    expect((await app.inject({ method: 'POST', url: '/v1/understand', payload })).statusCode).toBe(200)
    const phone = { remoteAddress: '192.168.1.23' }
    expect((await app.inject({ method: 'POST', url: '/v1/understand', payload, ...phone })).statusCode).toBe(401)
    const wrong = await app.inject({ method: 'POST', url: '/v1/pair', payload: { code: '000000x', device: 'iPhone 15' } })
    expect(wrong.statusCode).toBe(403)
    const code = pairing.code
    const paired = await app.inject({ method: 'POST', url: '/v1/pair', payload: { code, device: 'iPhone 15' } })
    const token = paired.json().token as string
    expect(token.length).toBeGreaterThan(30)
    expect(pairing.code).not.toBe(code)
    const ok = await app.inject({ method: 'POST', url: '/v1/understand', payload, ...phone, headers: { authorization: `Bearer ${token}` } })
    expect(ok.statusCode).toBe(200)
    const before = pairing.code
    for (let i = 0; i < 5; i++) pairing.pair('xxxxxx', 'x')
    expect(pairing.code).not.toBe(before)
  })
})
