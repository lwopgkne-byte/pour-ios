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
