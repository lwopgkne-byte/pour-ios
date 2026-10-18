/**
 * 原话里说没说到某一天、是不是在纠正（照网页版 shared/src/refer.ts）：程序用来核对 AI 的判断（能用程序确定的事，不交给 AI）。
 * AI 要改别的日子记下的事：原话得说到那天，或者明说了是在纠正（「改成」「不是…是」「其实」），
 * 不然多半是今天又做了同样的事（「进货一共1950」被当成改昨天的进货）
 */
import { type DateStr, addDays, weekdayMon0 } from './dates.ts'

/** 相对的说法；长的放前面（「大前天」先于「前天」） */
const RELATIVE: [RegExp, number][] = [
  [/大前天|大前日/g, -3],
  [/前天|前晚|前日|前儿个/g, -2],
  [/昨天|昨晚|昨夜|昨日|昨儿|昨早|昨个/g, -1],
  [/今天|今晚|今早|今夜|今日|今儿/g, 0],
  [/大后天/g, 3],
  [/明天|明晚|明早|明日|明儿/g, 1],
  // 「然后天气」里的「后天」不算
  [/(?<!然)后天/g, 2],
]

const WEEKDAY_CHARS = '一二三四五六日天'
const WEEKDAY_REF = /(上上|上|这|本|下下|下)?(?:周|星期|礼拜)([一二三四五六日天])/g
const MONTH_DAY = /(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]/g
const DAY_ONLY = /(?<![\d月])(\d{1,2})\s*[号日](?![\d子])/g

const pad = (n: number) => String(n).padStart(2, '0')

/**
 * 原话里提到了哪些日子：昨天、前天、明天、周三、上周五、下周一、10月12日、12号。
 * 只说星期几的：做过的事是已经过去的最近那天、要做的事是还没到的那天，两个都算（核对时只问「有没有说到这天」）
 */
export function mentionedDays(text: string, today: DateStr): DateStr[] {
  let rest = text.replace(/\s+/g, '')
  const out = new Set<DateStr>()
  for (const [re, offset] of RELATIVE) {
    if (rest.search(re) >= 0) out.add(addDays(today, offset))
    rest = rest.replace(re, '　')
  }
  const thisMonday = addDays(today, -weekdayMon0(today))
  for (const m of rest.matchAll(WEEKDAY_REF)) {
    const prefix = m[1] ?? ''
    const day = Math.min(WEEKDAY_CHARS.indexOf(m[2]!), 6)
    const week = prefix === '上上' ? -14 : prefix === '上' ? -7 : prefix === '下下' ? 14 : prefix === '下' ? 7 : 0
    const d = addDays(thisMonday, day + week)
    out.add(d)
    // 只说「周五」：可能是过去的那个，也可能是将来的那个
    if (!prefix) out.add(d <= today ? addDays(d, 7) : addDays(d, -7))
  }
  const year = Number(today.slice(0, 4))
  for (const m of rest.matchAll(MONTH_DAY)) out.add(`${year}-${pad(Number(m[1]))}-${pad(Number(m[2]))}`)
  for (const m of rest.replace(MONTH_DAY, '　').matchAll(DAY_ONLY)) {
    const d = Number(m[1])
    if (d >= 1 && d <= 31) out.add(`${today.slice(0, 8)}${pad(d)}`)
  }
  return [...out].sort()
}

/** 原话说到了这一天 */
export const mentionsDay = (text: string, today: DateStr, day: DateStr) => mentionedDays(text, today).includes(day)

/** 明说了是在纠正、改以前说的（「改成」「不是 8 点是 9 点」「是两公里不是三公里」「应该是」「其实」「记错了」） */
const CORRECTION_CUE = /改成|改为|改到|改一下|改下|改了|应该是|其实是|其实|不是.{0,12}是|是.{1,12}不是|记错|说错|弄错|搞错|写错|算错|不对|更正|纠正/

export const isCorrectionCue = (text: string) => CORRECTION_CUE.test(text.replace(/\s+/g, ''))
