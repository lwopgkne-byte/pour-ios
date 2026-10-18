/**
 * 用一个 Skill 调用大模型并校验输出（照网页版 server/src/ai/call-skill.ts）：
 * 输出不合法时带着错误原因自动重试一次，仍然不合法就抛 InvalidOutputError。每次尝试都写进这段话的处理记录。
 */
import type { z } from 'zod'
import type { StepLog } from './contract.ts'
import { type LlmClient, LlmError, type LlmMessage } from './llm.ts'
import { describeZodError } from './schemas.ts'
import { renderSkill } from './skills.ts'

export class InvalidOutputError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'InvalidOutputError'
  }
}


export interface CallSkillOptions<T extends z.ZodTypeAny> {
  llm: LlmClient
  log: StepLog[]
  step: string
  skill: string
  vars: Record<string, string>
  /** 用户消息：通常就是原话 */
  user: string
  schema: T
  maxTokens?: number
  skillsDir?: string
  signal?: AbortSignal
}

export async function callSkill<T extends z.ZodTypeAny>(opts: CallSkillOptions<T>): Promise<z.infer<T>> {
  const { prompt, context, version } = renderSkill(opts.skill, opts.vars, opts.skillsDir)
  const messages: LlmMessage[] = [
    { role: 'system', content: prompt },
    { role: 'user', content: context ? `# 背景\n\n${context}\n\n# 用户这段话\n\n${opts.user}` : opts.user },
  ]
  for (let attempt = 1; attempt <= 2; attempt++) {
    const started = Date.now()
    try {
      const res = await opts.llm.complete({
        feature: opts.skill,
        messages,
        json: true,
        maxTokens: opts.maxTokens ?? 2000,
        temperature: 0.2,
        ...(opts.signal ? { signal: opts.signal } : {}),
      })
      const usage = { promptTokens: res.promptTokens, cacheHitTokens: res.cacheHitTokens, completionTokens: res.completionTokens }
      const checked = validate(res.content, opts.schema)
      if (checked.ok) {
        opts.log.push({ step: opts.step, skill: opts.skill, skillVersion: version, durationMs: Date.now() - started, ...usage })
        return checked.value
      }
      opts.log.push({
        step: opts.step,
        skill: opts.skill,
        skillVersion: version,
        durationMs: Date.now() - started,
        ...usage,
        error: `第 ${attempt} 次输出不合格：${checked.error}`,
      })
      if (attempt === 2) throw new InvalidOutputError(`整理结果的格式不对：${checked.error}`)
      messages.push(
        { role: 'assistant', content: res.content },
        { role: 'user', content: `上面的输出不符合要求：${checked.error}。请重新输出，只输出符合格式的 JSON。` },
      )
    } catch (err) {
      if (err instanceof InvalidOutputError) throw err
      if (err instanceof LlmError && err.code === 'cancelled') throw err
      opts.log.push({ step: opts.step, skill: opts.skill, skillVersion: version, durationMs: Date.now() - started, error: (err as Error).message })
      // 空内容当作输出不合格，重试一次
      if (err instanceof LlmError && err.code === 'empty_response' && attempt === 1) continue
      if (err instanceof LlmError && err.code === 'empty_response') throw new InvalidOutputError('大模型两次都返回了空内容。')
      throw err
    }
  }
  throw new InvalidOutputError('整理没有得到结果。')
}

function validate<T extends z.ZodTypeAny>(content: string, schema: T): { ok: true; value: z.infer<T> } | { ok: false; error: string } {
  let json: unknown
  try {
    // 有些模型会把 JSON 包在 ```json 代码块里
    json = JSON.parse(content.replace(/^\s*```(?:json)?\s*/i, '').replace(/\s*```\s*$/, ''))
  } catch {
    return { ok: false, error: '不是合法的 JSON' }
  }
  const parsed = schema.safeParse(json)
  return parsed.success ? { ok: true, value: parsed.data } : { ok: false, error: describeZodError(parsed.error) }
}
