import { describe, expect, it } from 'vitest'
import type { ExistingRecord } from '../src/contract.ts'
import { describeDialogue, describePendingQuestions, aliases } from '../src/describe.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage } from './sample.ts'

const lunch: ExistingRecord = {
  id: 'lunch-uuid',
  day: '2026-09-24',
  data: { kind: 'event', category: 'diet', label: '吃面', start: '2026-09-24T12:00', metrics: [{ name: '花费', value: 28, unit: '元', item: '面' }], people: ['小王'], things: [], places: [] },
  question: '二十八是花了 28 块吗？',
}
const run: ExistingRecord = {
  id: 'run-uuid',
  day: '2026-09-24',
  data: { kind: 'event', category: 'run', label: '跑步', start: '2026-09-24T07:00', end: '2026-09-24T07:40', durationMin: 40, metrics: [], people: [], things: [], places: [] },
}
const rent: ExistingRecord = {
  id: 'rent-uuid',
  day: '2026-09-23',
  data: { kind: 'todo', content: '交房租', due: '2026-09-25', done: false, people: [], things: [], places: [] },
}
const mood: ExistingRecord = { id: 'mood-uuid', day: '2026-09-24', data: { kind: 'mood', level: 4, tone: 'good', strength: 'medium', emotions: ['开心'] } }

/** 已有 #1 吃面、#2 跑步、#3 交房租、#4 心情，AI 整理出 items */
async function change(text: string, items: object[]) {
  const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items, reply: '' })
  return understand(backgroundPackage(text, { existing: [lunch, run, rent, mood] }), { llm })
}

describe('改、删、确认、做完、之前已记过（M2b）', () => {
  it('「刚才那个是 38 不是 28」：改的是那一笔钱，名目留着；把握够了不再问', async () => {
    const out = await change('刚才那个是 38 不是 28', [
      { op: 'update', entry_id: 1, fields: { metrics: [{ name: '花费', value: 38, unit: '元' }] }, span: '是 38 不是 28', confidence: 0.95 },
    ])
    expect(out.creates).toEqual([])
    expect(out.updates).toHaveLength(1)
    const u = out.updates[0]!
    expect(u).toMatchObject({ id: 'lunch-uuid', action: 'updated', day: '2026-09-24' })
    expect(u.data).toMatchObject({ label: '吃面', metrics: [{ name: '花费', value: 38, unit: '元', item: '面' }], people: ['小王'] })
    expect(u.question).toBeUndefined()
  })

  it('改了开始时间：时长不变，结束跟着挪', async () => {
    const out = await change('跑步其实是七点半开始的', [{ op: 'update', entry_id: 2, fields: { start: '07:30' }, span: '七点半开始', confidence: 0.9 }])
    expect(out.updates[0]!.data).toMatchObject({ start: '2026-09-24T07:30', end: '2026-09-24T08:10', durationMin: 40 })
  })

  it('回答追问「对」：确认，不再待确认', async () => {
    const out = await change('对', [{ op: 'confirm', entry_id: 1, span: '对' }])
    expect(out.updates[0]).toMatchObject({ id: 'lunch-uuid', action: 'confirmed', confidence: 1 })
    expect(out.updates[0]!.question).toBeUndefined()
    expect(out.updates[0]!.data).toEqual(lunch.data)
  })

  it('「房租交了」：待办做完；不是待办的不动', async () => {
    const out = await change('房租交了', [
      { op: 'complete_todo', entry_id: 3, span: '房租交了' },
      { op: 'complete_todo', entry_id: 2, span: '' },
    ])
    expect(out.updates).toHaveLength(1)
    expect(out.updates[0]).toMatchObject({ id: 'rent-uuid', action: 'completed', data: { done: true, content: '交房租' } })
  })

  it('删除不靠猜：拿不准删哪条先问，不删；说清楚了才删', async () => {
    const unsure = await change('把那个删了', [{ op: 'delete', entry_id: 2, span: '那个', confidence: 0.4 }])
    expect(unsure.deletes).toEqual([])
    expect(unsure.questions).toEqual(['要删的是「跑步」吗？'])
    const sure = await change('跑步那条删掉', [{ op: 'delete', entry_id: 2, span: '跑步那条删掉' }])
    expect(sure.deletes).toEqual([{ id: 'run-uuid', span: '跑步那条删掉' }])
  })

  it('又说了一遍：之前已记过，不新建', async () => {
    const out = await change('早上跑步了', [{ op: 'duplicate', entry_id: 2, span: '早上跑步了' }])
    expect(out.duplicates).toEqual([{ id: 'run-uuid', span: '早上跑步了' }])
    expect(out.creates).toEqual([])
  })

  it('「其实没那么开心」：心情的级别照好不好、强不强重新查表', async () => {
    const out = await change('其实没那么开心', [{ op: 'update', entry_id: 4, fields: { tone: 'neutral' }, span: '没那么开心', confidence: 0.9 }])
    expect(out.updates[0]!.data).toMatchObject({ kind: 'mood', level: 3, tone: 'neutral' })
  })

  it('同一段话里先改再确认同一条：合成一次「修改」', async () => {
    const out = await change('是 38，对', [
      { op: 'update', entry_id: 1, fields: { metrics: [{ name: '花费', value: 38, unit: '元' }] }, span: '是 38', confidence: 0.95 },
      { op: 'confirm', entry_id: 1, span: '对' },
    ])
    expect(out.updates).toHaveLength(1)
    expect(out.updates[0]).toMatchObject({ action: 'updated', confidence: 1, data: { metrics: [{ value: 38 }] } })
  })

  it('编号不存在：什么都不动', async () => {
    const out = await change('改一下', [{ op: 'update', entry_id: 9, fields: { label: 'x' }, span: '', confidence: 0.9 }])
    expect(out.updates).toEqual([])
  })
})

describe('最近的对话和在等回答的追问（写给 AI 看）', () => {
  const { aliasOf } = aliases([lunch, run])

  it('带着短编号说刚才记下了什么、问了什么；最后一段问了问题，提醒 AI 这一句多半是回答', () => {
    const text = describeDialogue(
      [
        { text: '中午和小王吃面二十八', localTime: '2026-09-24T12:40', status: 'done', actions: [{ action: 'created', recordId: 'lunch-uuid', text: '吃面 ¥28 · 和小王' }], questions: ['二十八是花了 28 块吗？'], undone: false },
      ],
      aliasOf,
    )
    expect(text).toBe(
      ['- 用户（12:40）：中午和小王吃面二十八', '  Pour：记下 #1 吃面 ¥28 · 和小王', '  Pour 问：二十八是花了 28 块吗？', '  （Pour 在等用户回答上面这个问题：用户这一句多半就是回答）'].join('\n'),
    )
    expect(describeDialogue([], aliasOf)).toBe('（没有）')
  })

  it('还在等回答的：今天拿不准的那几条', () => {
    expect(describePendingQuestions([lunch, run], '2026-09-24', aliasOf)).toBe('- 关于记录 #1：二十八是花了 28 块吗？')
    expect(describePendingQuestions([run], '2026-09-24', aliasOf)).toBe('（没有）')
  })

  it('对话和追问进了两份 Skill 的背景', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [], reply: '' })
    await understand(
      backgroundPackage('对', {
        existing: [lunch],
        dialogue: [{ text: '中午吃面二十八', localTime: '2026-09-24T12:40', status: 'done', actions: [], questions: ['二十八是花了 28 块吗？'], undone: false }],
      }),
      { llm },
    )
    for (const call of llm.calls) {
      expect(call.messages[1]!.content).toContain('Pour 问：二十八是花了 28 块吗？')
      expect(call.messages[1]!.content).toContain('关于记录 #1：二十八是花了 28 块吗？')
    }
  })
})

describe('一句话总结', () => {
  it('只说做了什么：待办、待确认的不进总结；去掉句末的句号', async () => {
    const { summarize } = await import('../src/summary.ts')
    const llm = new FakeLlm().on('day-summary', { summary: '早上跑了步，中午和小王吃面。' })
    const out = await summarize({ version: 3, day: '2026-09-24', records: [run, lunch, rent, mood] }, { llm })
    expect(out.summary).toBe('早上跑了步，中午和小王吃面')
    const sent = llm.calls[0]!.messages[1]!.content
    expect(sent).toContain('事件 [run] 跑步')
    expect(sent).not.toContain('吃面')
    expect(sent).not.toContain('交房租')
    expect(sent).toContain('9月24日 周四')
  })

  it('没有可说的：不问 AI，回空的', async () => {
    const { summarize } = await import('../src/summary.ts')
    const llm = new FakeLlm()
    const out = await summarize({ version: 3, day: '2026-09-24', records: [rent, lunch] }, { llm })
    expect(out.summary).toBe('')
    expect(llm.calls).toHaveLength(0)
  })
})
