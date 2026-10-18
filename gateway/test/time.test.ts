// 网页版 shared/src/timeinfer.test.ts 原样搬来（待办提醒那一段 M2b 搬 resolveReminder 时一起搬），外加和网页版对拍 parseTime。
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { ROOT } from '../src/env.ts'
import { clockOnLogicalDay, parseTime, resolveDateRef, resolveEventTime } from '../src/time.ts'

const B = 240 // 日界线 04:00

describe('相对日期', () => {
  it('今天、昨天、明天都相对这段话所属的那一天', () => {
    expect(resolveDateRef('today', '2026-09-24')).toBe('2026-09-24')
    expect(resolveDateRef('yesterday', '2026-09-01')).toBe('2026-08-31')
    expect(resolveDateRef('tomorrow', '2026-12-31')).toBe('2027-01-01')
    expect(resolveDateRef(null, '2026-09-24')).toBe('2026-09-24')
    expect(resolveDateRef('2026-09-20', '2026-09-24')).toBe('2026-09-20')
    expect(resolveDateRef('胡说', '2026-09-24')).toBe('2026-09-24')
  })

  it('早于日界线的钟点落在日历上的第二天', () => {
    expect(clockOnLogicalDay('2026-09-23', 60, B)).toBe('2026-09-24T01:00')
    expect(clockOnLogicalDay('2026-09-23', 23 * 60, B)).toBe('2026-09-23T23:00')
    expect(clockOnLogicalDay('2026-09-23', 4 * 60, B)).toBe('2026-09-23T04:00')
  })
})

describe('事件时间', () => {
  it('开始 + 时长：8 点开始跑了一个小时', () => {
    expect(resolveEventTime({ start: '08:00', durationMin: 60 }, '2026-09-24', B)).toEqual({
      day: '2026-09-24',
      start: '2026-09-24T08:00',
      end: '2026-09-24T09:00',
      durationMin: 60,
    })
  })

  it('开始 + 结束会算出时长', () => {
    expect(resolveEventTime({ start: '14:00', end: '15:30' }, '2026-09-24', B).durationMin).toBe(90)
  })

  it('结束 + 时长会倒推开始', () => {
    expect(resolveEventTime({ end: '21:00', durationMin: 30 }, '2026-09-24', B).start).toBe('2026-09-24T20:30')
  })

  it('说不出时间的事件只记日期', () => {
    expect(resolveEventTime({ durationMin: 60 }, '2026-09-24', B)).toEqual({ day: '2026-09-24', durationMin: 60 })
    expect(resolveEventTime({ date: 'yesterday' }, '2026-09-24', B)).toEqual({ day: '2026-09-23' })
  })

  it('跨零点：23:30 到 00:30 是一个小时', () => {
    const r = resolveEventTime({ start: '23:30', end: '00:30' }, '2026-09-24', B)
    expect(r.end).toBe('2026-09-25T00:30')
    expect(r.durationMin).toBe(60)
    expect(r.day).toBe('2026-09-24')
  })

  it('深夜 1 点做的事归到前一个逻辑日', () => {
    // 9/24 的话里说「凌晨 1 点还在写代码」，指 9/24 夜里的 1 点，即日历 9/25 01:00
    const r = resolveEventTime({ start: '01:00', durationMin: 30 }, '2026-09-24', B)
    expect(r.start).toBe('2026-09-25T01:00')
    expect(r.day).toBe('2026-09-24')
  })
})

describe('睡眠归属到起床那一天', () => {
  it('昨晚 11 点睡，早上 7 点半起', () => {
    const r = resolveEventTime({ date: 'yesterday', start: '23:00', end: '07:30' }, '2026-09-24', B, { isSleep: true })
    expect(r).toEqual({ day: '2026-09-24', start: '2026-09-23T23:00', end: '2026-09-24T07:30', durationMin: 510 })
  })

  it('昨晚凌晨 1 点才睡，8 点起', () => {
    const r = resolveEventTime({ date: 'yesterday', start: '01:00', end: '08:00' }, '2026-09-24', B, { isSleep: true })
    expect(r.start).toBe('2026-09-24T01:00')
    expect(r.durationMin).toBe(420)
    expect(r.day).toBe('2026-09-24')
  })

  it('只说了睡了 8 个小时，归到这一天', () => {
    expect(resolveEventTime({ durationMin: 480 }, '2026-09-24', B, { isSleep: true })).toEqual({
      day: '2026-09-24',
      durationMin: 480,
    })
  })

  it('午睡不跨夜，也归到当天', () => {
    const r = resolveEventTime({ start: '13:00', end: '13:40' }, '2026-09-24', B, { isSleep: true })
    expect(r.day).toBe('2026-09-24')
    expect(r.durationMin).toBe(40)
  })
})

describe('做过的事不会在说话以后：凌晨的钟点说的是刚过去的那个凌晨（训练场找到的）', () => {
  const B = 240
  it('早上 7 点半说「今天凌晨两点多起来喂夜奶」：是今天凌晨（归前一天），不是今晚深夜', () => {
    const t = resolveEventTime({ date: 'today', start: '02:00', durationMin: 25 }, '2026-10-03', B, { now: '2026-10-03T07:33' })
    expect(t).toMatchObject({ start: '2026-10-03T02:00', end: '2026-10-03T02:25', day: '2026-10-02' })
  })

  it('零点以后说「今天凌晨一点五十才睡，睡到十点」：睡觉归到起床那天', () => {
    const t = resolveEventTime({ date: 'today', start: '01:50', end: '10:00' }, '2026-10-03', B, { isSleep: true, now: '2026-10-04T00:05' })
    expect(t).toMatchObject({ start: '2026-10-03T01:50', end: '2026-10-03T10:00', day: '2026-10-03' })
  })

  it('晚上说「凌晨一点才睡」是今早一点；「今晚 11 点睡」「半夜一点喂奶」说在前面的照旧', () => {
    expect(resolveEventTime({ start: '01:00' }, '2026-10-03', B, { now: '2026-10-03T22:00' }).start).toBe('2026-10-03T01:00')
    expect(resolveEventTime({ start: '23:00' }, '2026-10-03', B, { now: '2026-10-03T22:00' }).start).toBe('2026-10-03T23:00')
    // 凌晨三点说一点喂的：已经过去了，不动
    expect(resolveEventTime({ start: '01:00' }, '2026-10-03', B, { now: '2026-10-04T03:00' }).start).toBe('2026-10-04T01:00')
    // 不知道说话的时刻就照旧
    expect(resolveEventTime({ start: '02:00' }, '2026-10-03', B).start).toBe('2026-10-04T02:00')
  })
})

describe('和网页版对拍（fixtures/golden/time.json）', () => {
  const golden = JSON.parse(readFileSync(join(ROOT, '..', 'fixtures', 'golden', 'time.json'), 'utf8')) as {
    cases: { parseTime: { in: [string | null]; out: number | null }[] }
  }
  it('parseTime 每一个样例都一样', () => {
    expect(golden.cases.parseTime.length).toBeGreaterThan(10)
    for (const c of golden.cases.parseTime) expect(parseTime(c.in[0]), JSON.stringify(c.in)).toBe(c.out)
  })
})
