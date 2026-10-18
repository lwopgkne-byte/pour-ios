/**
 * 评测里检查回答和数量用的比对（网页版 evals/match.ts 原样搬来，网页版提交 eeede65；docs/prd-qa.md Q4「把尺子做准」）。
 * 以前按字符串包含：「12980」里有「1980」也算答对，错的回答被判成对，准确率虚高。
 */

/** 文字里的数（阿拉伯数字，可以带千位逗号、小数，后面可以跟「万」「千」） */
const NUMBER = /(?<![\d.])(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?\s*(万|千)?/g
const PURE_NUMBER = /^\s*(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?\s*(万|千)?\s*$/

const valueOf = (int: string, frac: string | undefined, unit: string | undefined) =>
  Number(`${int.replace(/,/g, '')}${frac ? `.${frac}` : ''}`) * (unit === '万' ? 10000 : unit === '千' ? 1000 : 1)

/** 一段文字里提到的所有数：「合计 12,980 元，约 1.3 万」→ [12980, 13000] */
export function numbersIn(text: string): number[] {
  return [...text.matchAll(NUMBER)].map((m) => valueOf(m[1]!, m[2], m[3]))
}

const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/**
 * 回答里有没有说到 expected：
 * - 纯数字按数值比：「1980」对不上「12980」；「1,980」「1980」是同一个数；「1.1万」等于 11000
 * - 数字开头或结尾的说法（「9:25」「9 点 25」）前后不能紧挨着别的数字：「19:25」不算说到了「9:25」
 * - 别的照字面找
 */
export function mentions(text: string, expected: string): boolean {
  const pure = expected.match(PURE_NUMBER)
  if (pure) {
    const want = valueOf(pure[1]!, pure[2], pure[3])
    return numbersIn(text).some((n) => Math.abs(n - want) < 1e-9)
  }
  const head = /^\d/.test(expected) ? '(?<![\\d.])' : ''
  const tail = /\d$/.test(expected) ? '(?![\\d])' : ''
  return new RegExp(`${head}${escape(expected)}${tail}`).test(text)
}

/** 同一种量的单位换算成最小的那个（「1 公里」= 1000 米，「2 小时」= 120 分钟，「1 公斤」= 2 斤） */
const TO_BASE: Record<string, number> = {
  公里: 1000, 千米: 1000, km: 1000, 米: 1, m: 1,
  小时: 60, 分钟: 1, 分: 1,
  公斤: 1000, 千克: 1000, kg: 1000, 斤: 500, 克: 1, g: 1,
}

/**
 * 记下的数量和期望的数一样吗：一样就对；不一样时，看换个等价的单位是不是对得上
 * （「游泳一千米」期望 1000，记成「1 公里」也对）
 */
export function sameAmount(value: number, unit: string, expected: number): boolean {
  if (value === expected) return true
  const base = TO_BASE[unit.trim()]
  if (!base) return false
  return Object.values(TO_BASE).some((other) => Math.abs((value * base) / other - expected) < 1e-9)
}

/** 同一句话说了两遍（「这周一共 93 元。这周一共 93 元。」）：按句号、问号、换行切开，有一模一样的两句（6 个字以上）就是重复 */
export function repeatedSentence(text: string): string | null {
  const seen = new Set<string>()
  for (const raw of text.split(/[。！？!?\n]+/)) {
    const s = raw.replace(/\s+/g, '').replace(/\[#\d+\]/g, '')
    if (s.length < 6) continue
    if (seen.has(s)) return s
    seen.add(s)
  }
  return null
}
