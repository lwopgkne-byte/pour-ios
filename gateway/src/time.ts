/**
 * 钟点和时间推断（照网页版 shared/src/time.ts、timeinfer.ts，规格 6.2）：
 * AI 只负责听懂说法（「昨晚 11 点」→ 日期=昨天、时间=23:00），日界线、跨零点、睡眠归属由这里的纯函数统一处理。
 *
 * 网关不认时区：本地时刻写成「YYYY-MM-DDTHH:mm」，当作墙上的钟点直接加减（不经过任何时区，也就没有夏令时的坑）
 */
import { type DateStr, addDays, isValidDateStr } from './dates.ts'

/** 本地时刻 YYYY-MM-DDTHH:mm */
export type LocalDateTime = string

const pad = (n: number) => String(n).padStart(2, '0')

/** "HH:mm" 或 "H:mm" → 当日分钟数；不合法返回 null（和网页版 parseTime 对拍：fixtures/golden/time.json） */
export function parseTime(value: string | null | undefined): number | null {
  if (typeof value !== 'string') return null
  const m = /^(\d{1,2}):(\d{2})$/.exec(value.trim())
  if (!m) return null
  const h = Number(m[1])
  const min = Number(m[2])
  if (!Number.isInteger(h) || !Number.isInteger(min)) return null
  if (h < 0 || h > 23 || min < 0 || min > 59) return null
  return h * 60 + min
}

function toUtcMs(s: LocalDateTime): number {
  const [date, time] = s.split('T') as [string, string]
  const [y, m, d] = date.split('-').map(Number)
  const [hh, mm] = time.split(':').map(Number)
  return Date.UTC(y!, m! - 1, d!, hh!, mm!)
}

function fromUtcMs(t: number): LocalDateTime {
  const d = new Date(t)
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`
}

export const isLocalDateTime = (s: unknown): s is LocalDateTime =>
  typeof s === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(s) && fromUtcMs(toUtcMs(s)) === s

export const addMinutes = (s: LocalDateTime, minutes: number): LocalDateTime => fromUtcMs(toUtcMs(s) + minutes * 60_000)

/** b - a，单位分钟 */
export const minutesBetween = (a: LocalDateTime, b: LocalDateTime): number => Math.round((toUtcMs(b) - toUtcMs(a)) / 60_000)

/** 一个本地时刻属于哪一天：早于日界线的算前一天 */
export function logicalDayOf(s: LocalDateTime, boundary: number): DateStr {
  const date = s.slice(0, 10)
  const clock = Number(s.slice(11, 13)) * 60 + Number(s.slice(14, 16))
  return clock < boundary ? addDays(date, -1) : date
}

/** AI 写的日期：today / yesterday / tomorrow，或 YYYY-MM-DD（相对这段话属于的那一天）；对不上就是那一天 */
export function resolveDateRef(ref: string | null | undefined, noteDay: DateStr): DateStr {
  if (!ref || ref === 'today') return noteDay
  if (ref === 'yesterday') return addDays(noteDay, -1)
  if (ref === 'tomorrow') return addDays(noteDay, 1)
  return isValidDateStr(ref) ? ref : noteDay
}

/**
 * 某一天里的某个钟点落在哪个时刻：早于日界线的钟点属于「这一天的深夜」，也就是日历上的第二天。
 * 例：9/23、日界线 04:00，「01:00」是 9/24 01:00
 */
export function clockOnLogicalDay(day: DateStr, clock: number, boundary: number): LocalDateTime {
  const date = clock < boundary ? addDays(day, 1) : day
  return `${date}T${pad(Math.floor(clock / 60))}:${pad(clock % 60)}`
}

/**
 * 提醒的时刻（照网页版 resolveReminder）：「5 分钟后」从说这句话的时刻往后数；「8 点」在 due 那天（没说哪天就是这段话那天），
 * 没说哪天、那个钟点今天已经过了，就是明天的这个钟点
 */
export function resolveReminder(r: { inMin?: number | undefined; at?: string | undefined; due?: DateStr | undefined }, noteDay: DateStr, now: LocalDateTime, boundary: number): LocalDateTime | null {
  if (r.inMin && r.inMin > 0) return addMinutes(now, Math.round(r.inMin))
  const clock = parseTime(r.at ?? null)
  if (clock === null) return null
  const at = clockOnLogicalDay(r.due ?? noteDay, clock, boundary)
  return !r.due && at <= now ? addMinutes(at, 24 * 60) : at
}

/** 提醒时刻写给人看：同一天只写钟点，别的日子带上几月几日（「10月20日 08:00」） */
export const formatRemindAt = (at: LocalDateTime, day?: DateStr) =>
  `${day !== undefined && at.slice(0, 10) === day ? '' : `${Number(at.slice(5, 7))}月${Number(at.slice(8, 10))}日 `}${at.slice(11, 16)}`

export interface TimeExpr {
  date?: string | null
  start?: string | null
  end?: string | null
  durationMin?: number | null
}

export interface ResolvedTime {
  day: DateStr
  start?: LocalDateTime
  end?: LocalDateTime
  durationMin?: number
}

/**
 * 推断一个事件的时间（网页版 resolveEventTime 原样）：
 * - 开始、结束、时长知道其中两个就补出第三个
 * - 结束早于或等于开始视为跨零点，结束在第二天
 * - 睡眠归到起床那一天，其他事件归到开始那一天（都按日界线）
 * - 说不出时间的事件只记日期
 */
export function resolveEventTime(
  expr: TimeExpr,
  noteDay: DateStr,
  boundary: number,
  opts: { isSleep?: boolean; now?: LocalDateTime } = {},
): ResolvedTime {
  const baseDay = resolveDateRef(expr.date, noteDay)
  const startClock = parseTime(expr.start ?? null)
  const endClock = parseTime(expr.end ?? null)
  let durationMin = expr.durationMin && expr.durationMin > 0 ? Math.round(expr.durationMin) : undefined

  let start: LocalDateTime | undefined
  let end: LocalDateTime | undefined

  if (startClock !== null) {
    start = clockOnLogicalDay(baseDay, startClock, boundary)
    if (endClock !== null) {
      end = `${start.slice(0, 10)}T${pad(Math.floor(endClock / 60))}:${pad(endClock % 60)}`
      if (minutesBetween(start, end) <= 0) end = addMinutes(end, 24 * 60)
      durationMin = minutesBetween(start, end)
    } else if (durationMin) {
      end = addMinutes(start, durationMin)
    }
  } else if (endClock !== null) {
    end = clockOnLogicalDay(baseDay, endClock, boundary)
    if (durationMin) start = addMinutes(end, -durationMin)
  }

  // 做过的事不会在说话以后：凌晨的钟点照日界线算到了「这一天的深夜」，可它说的是刚过去的那个凌晨
  // （早上 7 点说「今天凌晨两点多起来喂夜奶」）——往前挪一天。只挪日界线以前的钟点：「今晚 11 点睡」说的就是今晚
  const first = start ?? end
  const firstClock = startClock ?? endClock
  if (opts.now && first && firstClock !== null && firstClock < boundary && first > opts.now && addMinutes(first, -24 * 60) <= opts.now) {
    if (start) start = addMinutes(start, -24 * 60)
    if (end) end = addMinutes(end, -24 * 60)
  }

  let day = baseDay
  if (opts.isSleep && end) day = logicalDayOf(end, boundary)
  else if (start) day = logicalDayOf(start, boundary)

  return { day, ...(start ? { start } : {}), ...(end ? { end } : {}), ...(durationMin ? { durationMin } : {}) }
}
