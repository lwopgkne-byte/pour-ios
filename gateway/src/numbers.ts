/**
 * 原话里的数和钟点（照网页版 shared/src/health.ts 的 spokenNumbers、wakeTimeIn）：能用程序确定的事，不交给 AI
 */
const CN_DIGIT: Record<string, number> = { 零: 0, 〇: 0, 一: 1, 二: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9 }
const CN_CHARS = /[零〇一二两三四五六七八九十百]/

/** 从 i 开始读一个中文数（一千以内）：返回数值和读到哪 */
function readCn(s: string, i: number): [number, number] | null {
  const d = (k: number) => CN_DIGIT[s[k] ?? '']
  let v = 0
  let j = i
  let any = false
  if (d(j) !== undefined && s[j + 1] === '百') {
    v += d(j)! * 100
    j += 2
    any = true
    if (s[j] === '零' || s[j] === '〇') {
      j++
    } else if (d(j) !== undefined && s[j + 1] !== '十' && s[j + 1] !== '百') {
      // 「一百二」「一百五」：百后面直接跟一个数，是口语的 120、150
      return [v + d(j)! * 10, j + 1]
    }
  }
  if (d(j) !== undefined && s[j + 1] === '十') {
    v += d(j)! * 10
    j += 2
    any = true
  } else if (s[j] === '十') {
    v += 10
    j += 1
    any = true
  }
  if (d(j) !== undefined && s[j + 1] !== '十' && s[j + 1] !== '百') {
    v += d(j)!
    j += 1
    any = true
  }
  return any ? [v, j] : null
}

/** 按顺序读出一段话里的数：阿拉伯数字和中文数都认（「一百三十五八十八」→ 135、88） */
export function spokenNumbers(text: string): number[] {
  const s = text.replace(/\s/g, '')
  const out: number[] = []
  let i = 0
  while (i < s.length) {
    const arabic = /^\d+(?:\.\d+)?/.exec(s.slice(i))
    if (arabic) {
      out.push(Number(arabic[0]))
      i += arabic[0].length
      continue
    }
    if (CN_CHARS.test(s[i]!)) {
      const r = readCn(s, i)
      if (r && r[1] > i) {
        out.push(r[0])
        i = r[1]
        continue
      }
    }
    i++
  }
  return out
}

const CN_HOUR: Record<string, number> = { 一: 1, 二: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9, 十: 10, 十一: 11, 十二: 12 }
const WAKE = /(\d{1,2}|十[一二]?|[一二两三四五六七八九])点(半|一刻|三刻|(\d{1,2}|[一二三四五]十[一二三四五六七八九]?)分?)?(?:多)?(?:才|就)?(?:起床|起来|起的|起了|起|醒)/

/** 只说了几点起（「今天六点半起的」「五点四十就醒了」）：起床的时刻由程序照原话认，按早上算（12 点以内） */
export function wakeTimeIn(text: string): string | null {
  const m = WAKE.exec(text.replace(/\s/g, ''))
  if (!m) return null
  const hour = /^\d+$/.test(m[1]!) ? Number(m[1]) : CN_HOUR[m[1]!]
  if (hour === undefined || hour < 3 || hour > 12) return null
  const minText = m[2]
  const min = !minText ? 0 : minText === '半' ? 30 : minText === '一刻' ? 15 : minText === '三刻' ? 45 : (spokenNumbers(m[3] ?? '')[0] ?? 0)
  if (min > 59) return null
  return `${String(hour).padStart(2, '0')}:${String(min).padStart(2, '0')}`
}
