import { describe, expect, it } from 'vitest'
import type { ExistingRecord } from '../src/contract.ts'
import { resolveReminder } from '../src/time.ts'
import { REMIND_QUESTION, understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage } from './sample.ts'

/** 在 localTime 说了 text，AI 整理出一条待办 */
async function todo(text: string, fields: object, localTime = '2026-10-19T10:30') {
  const llm = new FakeLlm().on('router', recordIntent(text)).on('parse-note', {
    items: [{ op: 'create', kind: 'todo', span: text, confidence: 0.9, ...fields }],
    reply: '',
  })
  return (await understand(backgroundPackage(text, { localTime }), { llm })).creates[0]!
}

describe('提醒的时刻由程序算（照网页版 resolveReminder）', () => {
  it('「5 分钟后」从说话的时刻往后数；「8 点」没说哪天、今天已经过了就是明天', () => {
    expect(resolveReminder({ inMin: 5 }, '2026-10-19', '2026-10-19T10:30', 240)).toBe('2026-10-19T10:35')
    expect(resolveReminder({ at: '08:00' }, '2026-10-19', '2026-10-19T10:30', 240)).toBe('2026-10-20T08:00')
    expect(resolveReminder({ at: '15:00' }, '2026-10-19', '2026-10-19T10:30', 240)).toBe('2026-10-19T15:00')
    expect(resolveReminder({ at: '15:00', due: '2026-10-21' }, '2026-10-19', '2026-10-19T10:30', 240)).toBe('2026-10-21T15:00')
    expect(resolveReminder({}, '2026-10-19', '2026-10-19T10:30', 240)).toBeNull()
  })
})

describe('待办的提醒', () => {
  it('「5 分钟之后叫我开会」：10:35 提醒，不追问', async () => {
    const r = await todo('5分钟之后叫我开会', { content: '开会', remind_in_min: 5, remind: true })
    expect(r.data).toMatchObject({ kind: 'todo', content: '开会', remindAt: '2026-10-19T10:35', due: '2026-10-19' })
    expect(r.question).toBeUndefined()
  })

  it('晚上说「早上七点提醒我吃药」：是明天早上，不用 AI 写的「今天」', async () => {
    const r = await todo('早上七点提醒我吃药', { content: '吃药', due: 'today', remind_at: '07:00', remind: true }, '2026-10-19T21:00')
    expect(r.data).toMatchObject({ remindAt: '2026-10-20T07:00', due: '2026-10-20' })
  })

  it('「明天下午三点提醒我交房租」：明天 15:00', async () => {
    const r = await todo('明天下午三点提醒我交房租', { content: '交房租', due: 'tomorrow', remind_at: '15:00', remind: true })
    expect(r.data).toMatchObject({ remindAt: '2026-10-20T15:00', due: '2026-10-20' })
  })

  it('说了哪天、没说几点：那天早上 7:30 提醒', async () => {
    const r = await todo('下周三要打疫苗 记得提醒我', { content: '打疫苗', due: '2026-10-28', remind: true })
    expect(r.data).toMatchObject({ remindAt: '2026-10-28T07:30', due: '2026-10-28' })
    expect(r.question).toBeUndefined()
  })

  it('要提醒、没说什么时候：照样记下，问一句；说了今天的钟点却已经过了：问改到什么时候', async () => {
    const r = await todo('提醒我给车续交强险', { content: '续交强险', remind: true })
    expect(r.data).not.toHaveProperty('remindAt')
    expect(r.question).toBe(REMIND_QUESTION)
    const late = await todo('今天早上八点提醒我交表', { content: '交表', due: 'today', remind_at: '08:00', remind: true })
    expect(late.data).not.toHaveProperty('remindAt')
    expect(late.question).toBe('08:00 已经过了，改到什么时候提醒你？')
  })

  it('回答「晚上 9 点」：补上提醒，不再问', async () => {
    const waiting: ExistingRecord = {
      id: 'tax',
      day: '2026-10-19',
      data: { kind: 'todo', content: '续交强险', done: false, people: [], things: [], places: [] },
      question: REMIND_QUESTION,
    }
    const llm = new FakeLlm().on('router', recordIntent('晚上9点')).on('parse-note', {
      items: [{ op: 'update', entry_id: 1, fields: { remind_at: '21:00' }, span: '晚上9点', confidence: 0.95 }],
      reply: '',
    })
    const out = await understand(backgroundPackage('晚上9点', { existing: [waiting], localTime: '2026-10-19T10:40' }), { llm })
    expect(out.updates[0]).toMatchObject({ id: 'tax', data: { remindAt: '2026-10-19T21:00' } })
    expect(out.updates[0]!.question).toBeUndefined()
  })
})
