/**
 * 「今天」日子头下面的一句话总结（照网页版 server/src/ai/summary.ts，Skill 是 canvas-summary v3 原样）：
 * 手机发来这一天的记录（待办、待确认的不算），回一句不超过 36 个字的话。
 * 什么时候生成、缓存、防抖由手机管（记录没变就不再问）；网关照旧不存任何东西
 */
import { z } from 'zod'
import { callSkill } from './call-skill.ts'
import { CONTRACT_VERSION, ExistingRecord, type StepLog } from './contract.ts'
import { formatDayTitle } from './dates.ts'
import { describeRecordLine } from './describe.ts'
import type { LlmClient } from './llm.ts'

export const SummaryRequest = z.object({
  version: z.literal(CONTRACT_VERSION),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  records: z.array(ExistingRecord).max(300),
})
export type SummaryRequest = z.infer<typeof SummaryRequest>

const SummaryOutput = z.object({ summary: z.string().trim().min(1).max(80) })

export interface SummaryResult {
  version: number
  day: string
  /** 没有可说的（只有待办、待确认的）时是空的 */
  summary: string
  steps: StepLog[]
}

export async function summarize(req: SummaryRequest, deps: { llm: LlmClient; skillsDir?: string }): Promise<SummaryResult> {
  const steps: StepLog[] = []
  // 待办不进总结：还没到做的时候，说「没完成」不公平；待确认的可能不对，也不说
  const records = req.records.filter((r) => r.data.kind !== 'todo' && !r.question)
  if (records.length === 0) return { version: CONTRACT_VERSION, day: req.day, summary: '', steps }
  const out = await callSkill({
    llm: deps.llm,
    log: steps,
    step: 'summary',
    skill: 'day-summary',
    schema: SummaryOutput,
    maxTokens: 200,
    user: '请总结这一天。',
    vars: { day: formatDayTitle(req.day), entries: records.map((r) => `- ${describeRecordLine(r)}`).join('\n') },
    ...(deps.skillsDir ? { skillsDir: deps.skillsDir } : {}),
  })
  return { version: CONTRACT_VERSION, day: req.day, summary: out.summary.replace(/[。.]$/, ''), steps }
}
