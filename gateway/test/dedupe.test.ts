import { describe, expect, it } from 'vitest'
import type { ExistingRecord, RecordData } from '../src/contract.ts'
import { findDuplicate, isRepeatMention, isStrongRepeat } from '../src/dedupe.ts'
import { isCorrectionCue, mentionedDays } from '../src/refer.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { SEED_CATEGORIES, backgroundPackage } from './sample.ts'

const event = (label: string, over: Partial<Extract<RecordData, { kind: 'event' }>> = {}): Extract<RecordData, { kind: 'event' }> => ({
  kind: 'event',
  category: 'diet',
  label,
  metrics: [],
  people: [],
  things: [],
  places: [],
  ...over,
})
const spent = (value: number) => [{ name: '花费', value, unit: '元' }]

describe('原话明说了又一次（照网页版 dedupe.test.ts）', () => {
  it.each([
    ['又喂了一次奶', true],
    ['晚上又遛了一次狗', true],
    ['再次去医院复查', true],
    ['第二次去健身房', true],
    ['第3次打卡', true],
    ['喂了一次奶', false],
    ['今天跑步了', false],
    ['我再说一遍 今天跑了五公里', false],
    ['又说了一次刚才那件事', false],
    [undefined, false],
  ])('「%s」：%s', (span, expected) => {
    expect(isRepeatMention(span)).toBe(expected)
  })

  it.each([
    ['又喂了一次奶', true],
    ['又给宝宝喂了一顿', true],
    ['再次去医院复查', true],
    ['第二次去健身房', true],
    ['又去图书馆看了会儿书', false],
    ['下午网购又花了147', false],
    [undefined, false],
  ])('强的「又」：「%s」：%s', (span, expected) => {
    expect(isStrongRepeat(span)).toBe(expected)
  })
})

describe('约数（「两百多」）：和已经记的数在这个范围里就是同一件事（训练场：看病 261 又说成「两百多」记了两条）', () => {
  const visit = (spentValue: number) => ({ id: 'a', day: '2026-10-02', data: event('看病', { category: 'health', metrics: spent(spentValue) }) })
  const said = (spentValue: number) => ({ day: '2026-10-02', data: event('看病', { category: 'health', metrics: spent(spentValue) }) })
  it('261 在 200–299 里，是同一次；没说约数的 200 和 261 差两成以上，照旧是两次', () => {
    expect(findDuplicate([visit(261)], said(200), '今天下午看病花了两百多')?.id).toBe('a')
    expect(findDuplicate([visit(261)], said(200), '下午看病花了200')).toBeNull()
    expect(findDuplicate([visit(261)], said(200), '看病花了200多')?.id).toBe('a')
  })
  it('「三十多」不包括 45；「一千二百多」是 1200–1299', () => {
    expect(findDuplicate([visit(45)], said(30), '看病花了三十多')).toBeNull()
    expect(findDuplicate([visit(1260)], said(1200), '看病花了一千二百多')?.id).toBe('a')
    expect(findDuplicate([visit(2100)], said(1200), '看病花了一千二百多')).toBeNull()
  })
  it('时间对不上（一个早上、一个晚上）是两次；一方没说时间就是同一次', () => {
    const morning = { id: 'm', day: '2026-10-02', data: event('跑步', { category: 'run', start: '2026-10-02T07:00', end: '2026-10-02T07:40' }) }
    expect(findDuplicate([morning], { day: '2026-10-02', data: event('跑步', { category: 'run', start: '2026-10-02T19:00' }) })).toBeNull()
    expect(findDuplicate([morning], { day: '2026-10-02', data: event('跑步', { category: 'run' }) })?.id).toBe('m')
  })
})

describe('别的日子的事要改得有根据（mentionedDays、isCorrectionCue）', () => {
  it('说到了哪天：昨天、周五（过去的和将来的都算）、10月12日、12号', () => {
    expect(mentionedDays('昨天跑的是 8 公里', '2026-10-14')).toEqual(['2026-10-13'])
    expect(mentionedDays('周五加班', '2026-10-14')).toEqual(['2026-10-09', '2026-10-16'])
    expect(mentionedDays('10月12日的进货', '2026-10-14')).toEqual(['2026-10-12'])
    expect(mentionedDays('然后天气不错', '2026-10-14')).toEqual([])
  })
  it('明说了在纠正', () => {
    expect(isCorrectionCue('不是 8 点 是 9 点')).toBe(true)
    expect(isCorrectionCue('其实是 8 公里')).toBe(true)
    expect(isCorrectionCue('进货一共1950')).toBe(false)
  })
})

/** 之前说看病时建上的「健康」 */
const health = { key: 'c-health', name: '健康', emoji: '🩺', parent: null, measure: 'count', synonyms: ['看病'], color: 'brick', order: 500 }

/** 背景里已有这些记录，AI 整理出 items */
async function say(text: string, existing: ExistingRecord[], items: object[], localTime = '2026-10-02T22:25') {
  const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items, reply: '是同一次吗？' })
  const bg = backgroundPackage(text, { existing, localTime })
  return understand({ ...bg, categories: [...SEED_CATEGORIES, health] }, { llm })
}
const create = (label: string, category: string, over: object = {}) => ({
  op: 'create',
  kind: 'event',
  category,
  label,
  date: 'today',
  span: label,
  confidence: 0.95,
  ...over,
})

describe('兜底去重：AI 漏判时也不会记两次（M2c）', () => {
  const doctor: ExistingRecord = { id: 'doctor', day: '2026-10-02', data: event('看病', { category: 'c-health', start: '2026-10-02T15:00', metrics: spent(261) }) }

  it('「今天下午看病花了两百多」：之前记过 261 的那次，不新建', async () => {
    const out = await say('今天下午看病花了两百多', [doctor], [create('看病', 'c-health', { metrics: [{ name: '花费', value: 200, unit: '元' }], span: '今天下午看病花了两百多' })])
    expect(out.creates).toEqual([])
    expect(out.duplicates).toEqual([{ id: 'doctor', span: '今天下午看病花了两百多' }])
  })

  it('多说了时长：补到那一条上（修改），不新建', async () => {
    const out = await say('下午看病看了一个小时', [doctor], [create('看病', 'c-health', { start: '15:00', duration_min: 60, span: '下午看病看了一个小时' })])
    expect(out.creates).toEqual([])
    expect(out.updates).toHaveLength(1)
    expect(out.updates[0]).toMatchObject({ id: 'doctor', action: 'updated', data: { durationMin: 60, metrics: spent(261) } })
  })

  it('同一段话里 AI 把一件事写了两遍：只记一条，多说的补上', async () => {
    const out = await say('跑了五公里 跑步四十分钟', [], [
      create('跑步', 'run', { metrics: [{ name: '距离', value: 5, unit: '公里' }] }),
      create('跑步', 'run', { duration_min: 40 }),
    ])
    expect(out.creates).toHaveLength(1)
    expect(out.creates[0]!.data).toMatchObject({ label: '跑步', durationMin: 40, metrics: [{ name: '距离', value: 5, unit: '公里' }] })
  })

  it('「又喂了一次奶」：新的一次，AI 判成重复也照新的一次记（几点、多少不抄），不再问「是同一次吗」', async () => {
    const feed: ExistingRecord = { id: 'feed', day: '2026-10-02', data: event('喂奶', { category: 'other', start: '2026-10-02T14:00', metrics: [{ name: '奶量', value: 120, unit: '毫升' }] }) }
    const out = await say('又喂了一次奶', [feed], [{ op: 'duplicate', entry_id: 1, span: '又喂了一次奶' }])
    expect(out.duplicates).toEqual([])
    expect(out.creates).toHaveLength(1)
    expect(out.creates[0]).toMatchObject({ day: '2026-10-02', data: { label: '喂奶', metrics: [] } })
    expect(out.creates[0]!.data).not.toHaveProperty('start')
    expect(out.reply).toBe('')
  })

  it('把昨天的事再说一遍：光一个「又」（「下午网购又花了147」）是接着说，不是又买了一次', async () => {
    const lunch: ExistingRecord = { id: 'lunch', day: '2026-10-03', data: event('下馆子', { start: '2026-10-03T12:00', metrics: spent(216) }) }
    const shop: ExistingRecord = { id: 'shop', day: '2026-10-03', data: event('网购', { category: 'other', start: '2026-10-03T15:00', metrics: spent(147) }) }
    const out = await say(
      '昨天中午下馆子花了216 下午网购又花了147',
      [lunch, shop],
      [
        { op: 'duplicate', entry_id: 1, span: '昨天中午下馆子花了216' },
        { op: 'duplicate', entry_id: 2, span: '下午网购又花了147' },
      ],
      '2026-10-04T19:09',
    )
    expect(out.creates).toEqual([])
    expect(out.duplicates.map((d) => d.id)).toEqual(['lunch', 'shop'])
  })

  it('AI 把今天又做的事写成了改昨天那条（没说是改、没提那天）：照今天新的一次记，昨天那条不动', async () => {
    const stock: ExistingRecord = { id: 'stock', day: '2026-10-01', data: event('进货', { category: 'work', start: '2026-10-01T05:00', metrics: spent(1800) }) }
    const out = await say('进货一共1950', [stock], [{ op: 'update', entry_id: 1, fields: { metrics: [{ name: '花费', value: 1950, unit: '元' }] }, span: '进货一共1950', confidence: 0.9 }])
    expect(out.updates).toEqual([])
    expect(out.creates).toHaveLength(1)
    expect(out.creates[0]).toMatchObject({ day: '2026-10-02', data: { label: '进货', category: 'work', metrics: spent(1950) } })
    expect(out.skipped[0]).toContain('照今天新的一次记')
  })

  it('说到了那天、或者明说是改：照改昨天那条', async () => {
    const stock: ExistingRecord = { id: 'stock', day: '2026-10-01', data: event('进货', { category: 'work', start: '2026-10-01T05:00', metrics: spent(1800) }) }
    const item = { op: 'update', entry_id: 1, fields: { metrics: [{ name: '花费', value: 1950, unit: '元' }] }, span: '进货', confidence: 0.9 }
    for (const text of ['昨天进货一共1950', '进货其实是1950']) {
      const out = await say(text, [stock], [item])
      expect(out.creates).toEqual([])
      expect(out.updates[0]).toMatchObject({ id: 'stock', day: '2026-10-01', data: { metrics: spent(1950) } })
    }
  })

  it('心情：同一刻又说了一遍不新建，说得更强以新说的为准；不同的时刻各是一条', async () => {
    const jasmine: ExistingRecord = { id: 'jasmine', day: '2026-10-02', data: { kind: 'mood', level: 4, tone: 'good', strength: 'medium', emotions: ['开心'], moment: '早上看到茉莉开了' } }
    const again = { op: 'create', kind: 'mood', tone: 'good', strength: 'strong', emotions: ['开心'], moment: '看到茉莉开了', span: '早上看到茉莉开了特别开心', confidence: 0.9 }
    const out = await say('早上看到茉莉开了特别开心', [jasmine], [again])
    expect(out.creates).toEqual([])
    expect(out.updates[0]).toMatchObject({ id: 'jasmine', data: { level: 5, strength: 'strong', moment: '早上看到茉莉开了' } })
    const sunset = { ...again, moment: '晚上看到晚霞', span: '晚上看到晚霞特别开心' }
    expect((await say('晚上看到晚霞特别开心', [jasmine], [sunset])).creates).toHaveLength(1)
  })

  it('待办：还没做的同一件不再建；做完了的再说一遍是新的', async () => {
    const rent: ExistingRecord = { id: 'rent', day: '2026-10-02', data: { kind: 'todo', content: '交房租', done: false, people: [], things: [], places: [] } }
    const todo = { op: 'create', kind: 'todo', content: '交房租', span: '记得交房租', confidence: 0.9 }
    expect((await say('记得交房租', [rent], [todo])).duplicates).toEqual([{ id: 'rent', span: '记得交房租' }])
    const paid: ExistingRecord = { ...rent, data: { ...rent.data, done: true } as RecordData }
    expect((await say('记得交房租', [paid], [todo])).creates).toHaveLength(1)
  })
})

describe('要做的事的日子由程序往后数（照网页版 refer.test.ts）', () => {
  it('星期几是还没到的那天；今天就是那天就是今天；「下周三」是下一周；「上周」不管', async () => {
    const { upcomingWeekdayIn, upcomingRelativeDayIn } = await import('../src/refer.ts')
    expect(upcomingWeekdayIn('周五下午三点提醒我交论文', '2026-10-12')).toBe('2026-10-16')
    expect(upcomingWeekdayIn('周三开会', '2026-10-14')).toBe('2026-10-14')
    expect(upcomingWeekdayIn('周一要交报告', '2026-10-14')).toBe('2026-10-19')
    expect(upcomingWeekdayIn('下周三要打疫苗', '2026-10-12')).toBe('2026-10-21')
    expect(upcomingWeekdayIn('上周五开的会', '2026-10-12')).toBeNull()
    expect(upcomingRelativeDayIn('大后天要去交房租', '2026-10-12')).toBe('2026-10-15')
    expect(upcomingRelativeDayIn('明天提醒我后天交房租', '2026-10-12')).toBeNull()
  })

  it('AI 把「周五」写成了已经过去的那个周五：改回这个周五', async () => {
    const todo = { op: 'create', kind: 'todo', content: '交论文', due: '2026-10-09', span: '周五交论文', confidence: 0.9 }
    const out = await say('周五交论文', [], [todo], '2026-10-12T09:00')
    expect(out.creates[0]!.data).toMatchObject({ due: '2026-10-16' })
  })
})
