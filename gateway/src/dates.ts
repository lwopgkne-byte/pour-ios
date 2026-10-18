/**
 * 日历上的加减和中文排版（照网页版 shared/src/date.ts、format.ts）。
 * 网关是纯函数、不认电脑的时区：一律用 UTC 零点表示一个日期，只做日历换算；「现在几点、属于哪一天」由手机给。
 */

/** 日期字符串，格式 YYYY-MM-DD */
export type DateStr = string

export const WEEKDAY_CN = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'] as const

const pad = (n: number) => String(n).padStart(2, '0')

function toUtc(s: DateStr): number {
  const [y, m, d] = s.split('-').map(Number)
  return Date.UTC(y!, (m ?? 1) - 1, d ?? 1)
}

function fromUtc(t: number): DateStr {
  const d = new Date(t)
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`
}

export function isValidDateStr(s: unknown): s is DateStr {
  return typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && fromUtc(toUtc(s)) === s
}

export function addDays(s: DateStr, n: number): DateStr {
  return fromUtc(toUtc(s) + n * 86_400_000)
}

/** a - b，单位天 */
export function diffDays(a: DateStr, b: DateStr): number {
  return Math.round((toUtc(a) - toUtc(b)) / 86_400_000)
}

/** 0=周一 ... 6=周日 */
export function weekdayMon0(s: DateStr): number {
  return (new Date(toUtc(s)).getUTCDay() + 6) % 7
}

/** "2026-09-23" -> "9月23日 周三"；不在今年的日期带上年份 */
export function formatDayTitle(date: DateStr, today?: DateStr): string {
  const year = today && today.slice(0, 4) !== date.slice(0, 4) ? `${Number(date.slice(0, 4))}年` : ''
  return `${year}${Number(date.slice(5, 7))}月${Number(date.slice(8, 10))}日 ${WEEKDAY_CN[weekdayMon0(date)]}`
}

/** 240 → "04:00" */
export const hhmm = (min: number) => `${pad(Math.floor(min / 60))}:${pad(min % 60)}`

/**
 * 最近两周每一天是星期几、是「本周」还是「上周」（网页版 recentDaysTable）：
 * 「周一」「上周三」对应哪天由程序算好交给 AI，AI 只管对照，不自己推算日期
 */
export function recentDaysTable(today: DateStr, days = 14): string {
  const thisMonday = addDays(today, -weekdayMon0(today))
  const lines: string[] = []
  for (let i = 0; i < days; i++) {
    const d = addDays(today, -i)
    const w = WEEKDAY_CN[weekdayMon0(d)]!
    const weeksBack = Math.ceil(diffDays(thisMonday, d) / 7)
    const week = `${'上'.repeat(Math.max(0, weeksBack))}${w}`
    const near = ['今天', '昨天', '前天'][i]
    lines.push(`- ${d}：${week}${near ? `，${near}` : ''}`)
  }
  return lines.join('\n')
}

const WEEKDAY_CHARS = '一二三四五六日天'
/** 「周五」「上周三」「这星期一」：前缀、星期几 */
const WEEKDAY_REF = /(上上|上|这|本|下)?(?:周|星期|礼拜)([一二三四五六日天])/g

/**
 * 原话里说的星期几是哪天（网页版 weekdayDateIn，和最近两周日期表同一套规则）：
 * 「上周三」是上一周的周三；「这周一」是这一周的周一；只说「周五」是已经过去的最近那个周五（今天是周五就是今天）。
 * 「下周……」是将来的事，不管；一段话里说了好几个不一样的星期几，也不管
 */
export function weekdayDateIn(text: string, today: DateStr): DateStr | null {
  const refs = [...text.matchAll(WEEKDAY_REF)].map((m) => ({ prefix: m[1] ?? '', day: Math.min(WEEKDAY_CHARS.indexOf(m[2]!), 6) }))
  if (refs.length === 0) return null
  const keys = new Set(refs.map((r) => `${r.prefix}${r.day}`))
  if (keys.size > 1) return null
  const { prefix, day } = refs[0]!
  if (prefix === '下') return null
  const thisMonday = addDays(today, -weekdayMon0(today))
  if (prefix === '上上') return addDays(thisMonday, day - 14)
  if (prefix === '上') return addDays(thisMonday, day - 7)
  const thisWeek = addDays(thisMonday, day)
  if (prefix === '这' || prefix === '本') return thisWeek <= today ? thisWeek : null
  return thisWeek <= today ? thisWeek : addDays(thisWeek, -7)
}
