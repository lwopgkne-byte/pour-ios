/**
 * 去重（规格 6.3；照网页版 shared/src/dedupe.ts 和 server/src/ai/steps.ts 的 extraFields、againOf、againWith）：
 * 同一件事被重复提到时合并为一条，不能重复计算。
 *
 * AI 会先看到已有的记录并自己判断；这里是兜底的规则，AI 漏判时也不会记两次。
 * 原话明说了「又」「第二次」的是新的一次——AI 判成重复也照新的一次记
 */
import type { Category, ExistingRecord, Metric, RecordData } from './contract.ts'
import type { DateStr } from './dates.ts'
import { BAD_MOOD, GOOD_MOOD, LINK_MIN_OVERLAP, longestOverlap, normalizeForMatch } from './mood.ts'
import type { UpdateItem } from './schemas.ts'
import { logicalDayOf, minutesBetween } from './time.ts'
import { type Updated, applyUpdate } from './update.ts'

type EventData = Extract<RecordData, { kind: 'event' }>
type MoodData = Extract<RecordData, { kind: 'mood' }>
type Fields = UpdateItem['fields']

const normalize = (s: string) => s.replace(/\s+/g, '').toLowerCase()

/** 两个名称说的是不是同一种事：去掉空格以后一样，或者一个包含另一个（「看书」和「去图书馆看书」） */
export function sameActivity(a: string, b: string): boolean {
  const x = normalize(a)
  const y = normalize(b)
  return x === y || x.includes(y) || y.includes(x)
}

/** 两段时间是否重叠（只有一个时刻时按 1 分钟算） */
function overlaps(a: EventData, b: EventData): boolean {
  const range = (x: EventData): [number, number] => {
    const s = minutesBetween('2000-01-01T00:00', (x.start ?? x.end)!)
    const e = x.end ? minutesBetween('2000-01-01T00:00', x.end) : s + 1
    return [s, Math.max(e, s + 1)]
  }
  const [as, ae] = range(a)
  const [bs, be] = range(b)
  return as < be && bs < ae
}

const hasTime = (d: EventData) => Boolean(d.start || d.end)

/** 「又」「再次」「第二次」：明说了是又一次 */
const REPEAT = /又|再次|再一次|第[二两三四五六七八九十\d]+[次回遍趟顿]/
/** 「又说一遍」「再提一下」：是把同一件事再说一遍，不是又做了一次 */
const RESAY = /(又|再)(说|讲|提|重复|发)/

/** 原话明说了是又一次（「又喂了一次奶」「第二次去医院」）：是新的一次，不按重复合并 */
export const isRepeatMention = (span: string | undefined): boolean => !!span && REPEAT.test(span) && !RESAY.test(span)

/** 明说了几次的「又」：「又喂了一次奶」「又给宝宝喂了一顿」「再次」「第二次」 */
const STRONG_REPEAT = /再次|再一次|第[二两三四五六七八九十\d]+[次回遍趟顿]|又[^，。,.！？!?\s]{0,8}?[一两二三][次回遍趟顿]/

/**
 * 明说了又一次（强的「又」）：不管怎样都是新的一次。光一个「又」（「回来吃了晚饭，又去图书馆看了会儿书」「网购又花了147」）
 * 常常只是「接着」「另外」：一段话在把那天的事再说一遍的时候，不算又做了一次（见 understand.ts 的 recapDays）
 */
export const isStrongRepeat = (span: string | undefined): boolean => !!span && STRONG_REPEAT.test(span) && !RESAY.test(span)

/**
 * 原话里这个数说的是约数（「两百多」「三十来块」「八十几」）：这个数到下一个整数位，例如 200 是 200–299；
 * 说得准的返回 null。AI 照约数写的是开头那个整数
 */
function roughRange(value: number, said: string | undefined): [number, number] | null {
  if (!said || !/[\d零〇一二两三四五六七八九十百千万][多几来]/.test(said) || value <= 0) return null
  let step = 1
  while (value % (step * 10) === 0 && step * 10 <= value) step *= 10
  return step === 1 ? null : [value, value + step]
}

const clearlyDiffer = (x: number, y: number) => Math.abs(x - y) > Math.max(x, y) * 0.2

/**
 * 两边都有时长、或者都有同名的数量，并且相差超过两成。b 是新说的这次：原话说的是约数（「看病花了两百多」），
 * a 的数在这个范围里就不算不一样（以前记的 261）
 */
function differentAmounts(a: EventData, b: EventData, said?: string): boolean {
  if (a.durationMin && b.durationMin && clearlyDiffer(a.durationMin, b.durationMin)) return true
  for (const m of a.metrics) {
    const other = b.metrics.find((x) => x.name === m.name)
    if (!other) continue
    const rough = roughRange(other.value, said)
    if (rough ? m.value < rough[0] || m.value >= rough[1] : clearlyDiffer(m.value, other.value)) return true
  }
  return false
}

/** 好坏是不是一边：都是好时刻、都是不好的时刻，或者都是一般 */
const sameSide = (a: number, b: number) => (a >= GOOD_MOOD && b >= GOOD_MOOD) || (a <= BAD_MOOD && b <= BAD_MOOD) || (a === 3 && b === 3)

/**
 * 两条心情是不是同一刻（同一天由调用方保证）：
 * - 两条都有那一刻：好坏一样，而且那一刻相同、互相包含，或者连续 4 个字一样（晚上回顾时又提了下午那次）
 * - 两条都没有那一刻：级别、精力、情绪词都一样才算（同一段话发了两遍；心情一天里可以变）
 * - 一条有、一条没有：两条
 */
export function sameMoodMoment(a: MoodData, b: MoodData): boolean {
  if (a.moment && b.moment) {
    if (!sameSide(a.level, b.level)) return false
    const x = normalizeForMatch(a.moment)
    const y = normalizeForMatch(b.moment)
    return x === y || x.includes(y) || y.includes(x) || longestOverlap(a.moment, b.moment) >= LINK_MIN_OVERLAP
  }
  if (a.moment || b.moment) return false
  const same = (x: string[], y: string[]) => x.length === y.length && x.every((w) => y.includes(w))
  return a.level === b.level && a.energy === b.energy && same(a.emotions, b.emotions)
}

/**
 * 在已有记录里找「其实是同一件事」的那一条，没有返回 null。
 * - 事件：同一天、同一类别、名称相同或互相包含，并且时间重叠或至少一方没说时间；
 *   但两边的时长或数量明显不同时是两次（said 是这次的原话：说的是约数时按范围比）
 * - 感悟：原话片段相同
 * - 待办：内容相同且还没完成
 * - 心情：一天里可以有好几次，按那一刻认是不是同一刻（sameMoodMoment）
 */
export function findDuplicate<T extends { day: DateStr; data: RecordData }>(existing: T[], candidate: { day: DateStr; data: RecordData }, said?: string): T | null {
  const b = candidate.data
  for (const e of existing) {
    const a = e.data
    if (a.kind !== b.kind || e.day !== candidate.day) continue
    if (a.kind === 'event' && b.kind === 'event') {
      if (a.category !== b.category || !sameActivity(a.label, b.label)) continue
      // 两边都说了时长或数量、而且明显不一样：是两次（「又打坐了 10 分钟」不是之前那 15 分钟）
      if (differentAmounts(a, b, said)) continue
      if (!hasTime(a) || !hasTime(b) || overlaps(a, b)) return e
    }
    if (a.kind === 'insight' && b.kind === 'insight' && normalize(a.quote) === normalize(b.quote)) return e
    if (a.kind === 'mood' && b.kind === 'mood' && sameMoodMoment(a, b)) return e
    if (a.kind === 'todo' && b.kind === 'todo' && !a.done && normalize(a.content) === normalize(b.content)) return e
  }
  return null
}

/** 同一个数：名字一样、名目也一样（「花费·菜」和「花费·肉」是两笔） */
const sameMetric = (a: Metric, b: Metric) => a.name === b.name && (a.item ?? '') === (b.item ?? '')

/** 新说的比已有的多出来的信息（时间、时长、数量；心情的好坏、精力）：有的话改那一条，没有就是「之前已记过」 */
export function extraFields(a: RecordData, b: RecordData, boundary: number): Fields | null {
  const fields: Fields = {}
  if (a.kind === 'mood' && b.kind === 'mood') {
    // 同一刻又说了一遍：说得更强或更弱，以新说的为准；新说到了精力就补上
    if (a.level !== b.level) Object.assign(fields, b.tone ? { tone: b.tone, strength: b.strength ?? 'medium' } : { mood: b.level })
    if (a.energy === undefined && b.energy !== undefined) fields.energy = b.energy
    return Object.keys(fields).length ? fields : null
  }
  if (a.kind !== 'event' || b.kind !== 'event') return null
  if (!a.start && b.start) fields.start = b.start.slice(11)
  if (!a.end && b.end) fields.end = b.end.slice(11)
  if (!a.durationMin && b.durationMin) fields.duration_min = b.durationMin
  const newMetrics = b.metrics.filter((m) => !a.metrics.some((x) => sameMetric(x, m)))
  if (newMetrics.length) fields.metrics = newMetrics
  if (b.start && (fields.start || fields.end)) fields.date = logicalDayOf(b.start, boundary)
  return Object.keys(fields).length ? fields : null
}

/**
 * 「又……了一次」：照着上一次记一条新的。做的什么、和谁、东西、地方照抄；
 * 几点、多久、多少是那一次的，不抄（用户没说就是不知道，AI 不编造数字）
 */
export function againOf(d: EventData): EventData {
  const { start: _start, end: _end, durationMin: _duration, metrics: _metrics, note: _note, ...same } = d
  return { ...same, metrics: [] }
}

/**
 * 今天又做了一次（AI 却写成了改以前那条）：做的是什么照那条（名称、类别、和谁），时间、数量照这次说的；日期是今天
 */
export function againWith(record: ExistingRecord & { data: EventData }, fields: Fields, day: DateStr, boundary: number, cats: Category[], confidence: number): Updated {
  const { date: _date, ...said } = fields
  return applyUpdate({ id: record.id, day, data: againOf(record.data) }, { op: 'update', entry_id: 1, fields: said, span: '', confidence, question: undefined }, boundary, cats)
}

/** 这次修改动没动时间、数量（改掉的、加上的都算）；只补人、东西、地方、备注的不算 */
export function changedAmounts(before: ExistingRecord, after: Updated): boolean {
  if (before.data.kind !== 'event' || after.data.kind !== 'event') return false
  const pick = (d: EventData) => JSON.stringify([d.start ?? null, d.end ?? null, d.durationMin ?? null, d.metrics])
  return before.day !== after.day || pick(before.data) !== pick(after.data)
}
