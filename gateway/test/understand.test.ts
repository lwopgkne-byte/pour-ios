import { describe, expect, it } from 'vitest'
import { ChangePackage } from '../src/contract.ts'
import { LlmError } from '../src/llm.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, later, recordIntent } from './fake-llm.ts'
import { backgroundPackage, run } from './sample.ts'

describe('理解一段话：背景包进、改动包出', () => {
  it('规格验收用例：跑步、168 饮食、感悟、睡眠（和网页版 pipeline.test.ts 同一段话）', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', {
      items: [
        run,
        { op: 'create', kind: 'event', category: 'diet', label: '16:8 轻断食', date: 'today', start: null, end: null, duration_min: null, metrics: [], note: '', span: '今天是168饮食', confidence: 0.6, question: '168 是指 16:8 轻断食吗？' },
        { op: 'create', kind: 'insight', title: '运动很重要', quote: '跑完神清气爽', tags: ['运动'], span: '跑完神清气爽', confidence: 0.9, question: null },
        { op: 'create', kind: 'event', category: 'sleep', label: '睡眠', date: 'yesterday', start: '23:00', end: '07:30', duration_min: null, metrics: [], note: '', span: '昨晚11点睡今早7点半起', confidence: 0.95, question: null },
      ],
      reply: '记下了。',
    })
    const out = await understand(backgroundPackage('8点开始跑步跑了一个小时，今天是168饮食，跑完神清气爽，昨晚11点睡今早7点半起'), { llm })

    expect(ChangePackage.parse(out)).toEqual(out)
    expect(out.intents).toEqual(['record'])
    expect(out.reply).toBe('记下了。')
    expect(out.creates).toHaveLength(4)
    const [running, diet, insight, sleep] = out.creates
    expect(running).toMatchObject({ day: '2026-09-24', data: { kind: 'event', category: 'run', start: '2026-09-24T08:00', end: '2026-09-24T09:00', durationMin: 60 } })
    expect(running!.question).toBeUndefined()
    // 把握不够：要你确认，带着 AI 的追问
    expect(diet!.question).toBe('168 是指 16:8 轻断食吗？')
    expect(insight!.data).toEqual({ kind: 'insight', title: '运动很重要', quote: '跑完神清气爽', tags: ['运动'] })
    // 睡眠归到起床那一天，跨零点算出时长
    expect(sleep).toMatchObject({ day: '2026-09-24', data: { start: '2026-09-23T23:00', end: '2026-09-24T07:30', durationMin: 510 } })
  })

  it('意图识别和整理同时开始：两个请求都发出去了，整理不等意图识别', async () => {
    const llm = new FakeLlm().on('router', later(recordIntent(), 40)).on('parse-note', { items: [run], reply: '' })
    const started = Date.now()
    await understand(backgroundPackage('8点开始跑步跑了一个小时'), { llm })
    expect(llm.calls.map((c) => c.feature)).toEqual(['parse-note', 'router'])
    expect(Date.now() - started).toBeLessThan(400)
  })

  it('只是聊天：取消整理、不白花钱，回的是意图识别那句话', async () => {
    const llm = new FakeLlm()
      .on('router', { intents: [{ type: 'chat', text: '你好' }], reply: '你好呀。' })
      .on('parse-note', later({ items: [run], reply: '' }, 200))
    const out = await understand(backgroundPackage('你好'), { llm })
    expect(out.creates).toEqual([])
    expect(out.reply).toBe('你好呀。')
    expect(out.steps.map((s) => s.step)).toEqual(['route'])
  })

  it('处理记录：每一步的 Skill 版本、用量；没有原话', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [run], reply: '' })
    const out = await understand(backgroundPackage('8点开始跑步跑了一个小时'), { llm })
    const route = out.steps.find((s) => s.step === 'route')!
    expect(route.skillVersion).toMatch(/^router@\d+\+_voice@\d+$/)
    expect(route.cacheHitTokens).toBe(80)
    expect(JSON.stringify(out.steps)).not.toContain('跑步')
  })

  it('不变的规则在系统提示词里，背景和原话在用户消息里：两段不同的话系统提示词一字不差（缓存才命中）', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [], reply: '' })
    await understand(backgroundPackage('8点开始跑步', { localTime: '2026-09-24T09:30' }), { llm })
    await understand(backgroundPackage('中午吃了面', { localTime: '2026-10-02T21:05' }), { llm })
    for (const skill of ['router', 'parse-note']) {
      const [a, b] = llm.calls.filter((c) => c.feature === skill)
      expect(a!.messages[0]!.content).toBe(b!.messages[0]!.content)
      expect(a!.messages[0]!.content).not.toMatch(/\{\{\w+\}\}/)
      expect(a!.messages[1]!.content).not.toMatch(/\{\{\w+\}\}/)
      expect(b!.messages[1]!.content).toContain('中午吃了面')
    }
    // 意图识别不用知道今天几号；整理要
    expect(llm.calls.filter((c) => c.feature === 'parse-note')[1]!.messages[1]!.content).toContain('2026-10-02')
  })

  it('整理的格式不对：带着原因重试一次', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', '这不是 JSON', { items: [run], reply: '' })
    const out = await understand(backgroundPackage('8点开始跑步跑了一个小时'), { llm })
    expect(out.creates).toHaveLength(1)
    expect(llm.count('parse-note')).toBe(2)
    expect(out.steps.filter((s) => s.step === 'parse').map((s) => Boolean(s.error))).toEqual([true, false])
  })

  it('大模型出错：原样报出来（网关翻成给手机的错误）', async () => {
    const llm = new FakeLlm().on('router', new LlmError('bad_key', '密钥无效')).on('parse-note', later({ items: [], reply: '' }, 200))
    await expect(understand(backgroundPackage('8点开始跑步'), { llm })).rejects.toMatchObject({ code: 'bad_key' })
  })
})

describe('新建记录的程序把关', () => {
  const parseOne = async (item: object, text = '随便一段话', localTime?: string) => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [item], reply: '' })
    const out = await understand(backgroundPackage(text, localTime ? { localTime } : {}), { llm })
    return out.creates[0]!
  }

  it('类别表里没有的类别先归「其他」', async () => {
    const r = await parseOne({ ...run, category: 'knitting', label: '织毛衣' })
    expect(r.data).toMatchObject({ category: 'other', label: '织毛衣' })
  })

  it('子类别的睡眠也归到起床那天：午睡不跨夜', async () => {
    const r = await parseOne({ ...run, category: 'sleep', label: '午睡', start: '13:00', end: '13:40', duration_min: null })
    expect(r).toMatchObject({ day: '2026-09-24', data: { durationMin: 40 } })
  })

  it('凌晨的钟点说的是刚过去的那个凌晨：早上 7 点半说「今天凌晨两点起来喂夜奶」归前一天', async () => {
    const r = await parseOne({ ...run, category: 'other', label: '喂夜奶', start: '02:00', duration_min: 25 }, '今天凌晨两点起来喂夜奶', '2026-10-03T07:33')
    expect(r).toMatchObject({ day: '2026-10-02', data: { start: '2026-10-03T02:00' } })
  })

  it('时长超过一天：问一句是不是说错了', async () => {
    const r = await parseOne({ ...run, label: '学习', category: 'study', start: null, duration_min: 3000 })
    expect(r.question).toBe('学习 50 小时？一天只有 24 小时，是不是说错了？')
  })

  it('把握低、AI 没写追问：问「我理解得对吗？」；把握够了，AI 写了追问也不问', async () => {
    expect((await parseOne({ ...run, confidence: 0.5 })).question).toBe('我理解得对吗？')
    expect((await parseOne({ ...run, confidence: 0.9, question: '是跑步吗？' })).question).toBeUndefined()
  })

  it('心情：级别由程序查表；心情不追问；精力只在原话说到时才有；那一刻要一字不差', async () => {
    const mood = { op: 'create', kind: 'mood', tone: 'good', strength: 'strong', energy: '有精神', emotions: ['开心'], moment: '开心死了', span: '开心死了', confidence: 0.4 }
    const r = await parseOne(mood, '今天升职了 开心死了')
    expect(r.data).toEqual({ kind: 'mood', level: 5, tone: 'good', strength: 'strong', emotions: ['开心'], moment: '开心死了' })
    expect(r.question).toBeUndefined()
    const tired = await parseOne({ ...mood, tone: 'bad', strength: 'medium', energy: '有点累', moment: '改写过的话' }, '加班到十点，有点累')
    expect(tired.data).toMatchObject({ level: 2, energy: 2 })
    expect(tired.data).not.toHaveProperty('moment')
  })

  it('说到很难受的定为很差', async () => {
    const r = await parseOne({ op: 'create', kind: 'mood', tone: 'bad', strength: 'weak', distress: true, emotions: [], span: '', confidence: 0.9 }, '不想活了')
    expect(r.data).toMatchObject({ level: 1 })
  })

  it('待办的期限相对这段话的那一天；钱和人原样带上', async () => {
    const todo = await parseOne({ op: 'create', kind: 'todo', content: '交房租', due: 'tomorrow', people: ['房东'], span: '明天交房租', confidence: 0.95 })
    expect(todo).toMatchObject({ day: '2026-09-24', data: { kind: 'todo', content: '交房租', due: '2026-09-25', done: false, people: ['房东'] } })
    const lunch = await parseOne({
      op: 'create', kind: 'event', category: 'diet', label: '吃面', start: '12:00', metrics: [{ name: '花费', value: '32', unit: '元', item: '面' }],
      people: ['小王'], span: '中午和小王吃面三十二', confidence: 0.9,
    })
    expect(lunch.data).toMatchObject({ category: 'diet', metrics: [{ name: '花费', value: 32, unit: '元', item: '面' }], people: ['小王'] })
  })
})
