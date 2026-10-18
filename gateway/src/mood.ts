/**
 * 心情的说法和程序把关（照网页版 shared/src/mood.ts）：级别查表、直接评价心情照原词、很难受的说法、
 * 那一刻要一字不差（省略补全、只说了心情的不算）、精力只在说到时才记
 */
import { EMOTIONS, ENERGY_ONLY } from './emotions.ts'

export const MOOD_WORDS = ['很差', '不太好', '一般', '挺好', '很好'] as const
export const ENERGY_WORDS = ['很累', '有点累', '一般', '有精神', '精力充沛'] as const
/** 那一刻最多几个字（去掉空白） */
export const MOMENT_MAX_CHARS = 60

export type MoodTone = 'good' | 'neutral' | 'bad' | 'mixed'
export type MoodStrength = 'weak' | 'medium' | 'strong'

const clamp = (n: number) => Math.min(5, Math.max(1, Math.round(n)))

/** 1–5 → 心情的说法 */
export const moodWord = (n: number): string => MOOD_WORDS[clamp(n) - 1]!
/** 1–5 → 精力的说法 */
export const energyWord = (n: number): string => ENERGY_WORDS[clamp(n) - 1]!

/** 精力的说法 → 1–5；对不上就没有 */
export function energyLevel(word: string): number | undefined {
  const i = (ENERGY_WORDS as readonly string[]).indexOf(word.trim())
  return i < 0 ? undefined : i + 1
}

/**
 * 「好不好 × 强不强」查表得出是哪一级。同一句话每次都是同一级，「很开心」是挺好，「开心死了」才是很好：
 *
 * | 好不好 \ 强不强 | 弱 | 中 | 强 |
 * |---|---|---|---|
 * | 好 | 4 | 4 | 5 |
 * | 一般 | 3 | 3 | 3 |
 * | 不好 | 2 | 2 | 1 |
 * | 又好又不好 | 3 | 3 | 3 |
 */
export function levelOf(tone: MoodTone, strength: MoodStrength = 'medium'): number {
  if (tone === 'good') return strength === 'strong' ? 5 : 4
  if (tone === 'bad') return strength === 'strong' ? 1 : 2
  return 3
}

/** 原话里说到精力的字：没有这些字，AI 写了精力也不要（开心不等于有精神，不能替你推） */
export const ENERGY_CUES = ['累', '困', '乏', '疲', '劲', '精神', '精力', '力气', '神清气爽', '提不起']

export const keepEnergy = (noteText: string): boolean => {
  const t = noteText.replace(/\s/g, '')
  return ENERGY_CUES.some((w) => t.includes(w))
}

/** 好时刻：心情 4 级以上 */
export const GOOD_MOOD = 4
/** 不好的时刻：心情 2 级以下 */
export const BAD_MOOD = 2
/** 那一刻和另一刻连续几个字一样才算对得上 */
export const LINK_MIN_OVERLAP = 4

/** 比较两段话用：去掉空白、标点、符号，转小写 */
export const normalizeForMatch = (s: string): string => s.replace(/[\s\p{P}\p{S}]/gu, '').toLowerCase()

/** 两段话最长的连续相同的一段有几个字（比之前先各自 normalizeForMatch） */
export function longestOverlap(a: string, b: string): number {
  const x = normalizeForMatch(a)
  const y = normalizeForMatch(b)
  let best = 0
  // 动态规划：prev[j] 是以 x[i-1]、y[j-1] 结尾的相同段长度
  let prev = new Array<number>(y.length + 1).fill(0)
  for (let i = 1; i <= x.length; i++) {
    const cur = new Array<number>(y.length + 1).fill(0)
    for (let j = 1; j <= y.length; j++) {
      if (x[i - 1] === y[j - 1]) {
        cur[j] = prev[j - 1]! + 1
        if (cur[j]! > best) best = cur[j]!
      }
    }
    prev = cur
  }
  return best
}

/**
 * 不是情境的那些字：时间、程度、「心情」「整个人」这类、心情和精力的说法、语气词。
 * 一段话去掉这些什么都不剩，就是只说了心情（「下午有点烦」「心里特别舒服」），没说是什么情境
 */
const NOT_SITUATION = [
  ...['今天', '昨天', '前天', '今早', '今晚', '昨晚', '刚才', '刚刚', '早上', '早晨', '上午', '中午', '下午', '傍晚', '晚上', '夜里', '半夜', '凌晨', '白天', '一早', '这会儿', '现在', '一整天', '一天'],
  ...['有点儿', '有点', '有些', '一点', '很', '挺', '特别', '非常', '太', '超级', '超', '好', '真的', '真', '蛮', '比较', '更', '最', '还', '又', '都', '也', '就', '一下子', '一下', '起来', '多了', '死了', '坏了', '极了'],
  ...['我', '心里', '心情', '状态', '情绪', '整个人', '感觉', '觉得', '人', '不'],
  ...EMOTIONS.flatMap((e) => [e.word, ...e.also]),
  ...ENERGY_ONLY,
  ...['烦', '累', '困', '舒服', '舒坦', '爽', '难受', '不开心', '开心', '高兴', '郁闷', '心累', '闷', '慌', '急', '气', '堵', '暖', '乐', '美滋滋'],
  ...['了', '的', '啊', '呀', '呢', '吧', '哦', '嘛', '得', '着'],
].sort((a, b) => b.length - a.length)
const NOT_SITUATION_RE = new RegExp(NOT_SITUATION.map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'g')

/** 那一刻只说了时间和心情、没说是什么情境（去掉时间、程度、心情说法和语气词，什么都不剩） */
export const onlyFeeling = (moment: string): boolean => normalizeForMatch(moment).replace(NOT_SITUATION_RE, '') === ''

/**
 * 那一刻要一字不差在这段原话里（比的时候不算空白和标点）、去掉空白不超过 60 个字，否则不记那一刻（心情照记）。
 * AI 改写过的、总结过的都不要：那一刻是你自己的话。
 * 只说了时间和心情的（「下午」「下午有点烦」「心里特别舒服」）也不要：那是什么时候、什么感觉，不是什么情境
 */
export function cleanMoment(moment: string | undefined, noteText: string): string | undefined {
  const m = moment?.trim()
  if (!m) return undefined
  const plain = normalizeForMatch(m)
  if (!plain || onlyFeeling(m)) return undefined
  const fit = (s: string) => (s.replace(/\s/g, '').length > MOMENT_MAX_CHARS ? undefined : s)
  if (normalizeForMatch(noteText).includes(plain)) return fit(m)
  return fit(coveringSpan(m, noteText) ?? '') || undefined
}

/**
 * AI 把中间一段省掉了（原话「A B C」，它摘成「A，C」）：几段都按顺序一字不差在原话里时，取原话里从第一段到最后一段的那一整段。
 * 摘出来的还是原话（一字不差），只是不让 AI 的省略把那一刻整个丢掉；对不上就是没有
 */
function coveringSpan(moment: string, noteText: string): string | undefined {
  const parts = moment.split(/[\s，,。、；;：:！!？?]+/).filter(Boolean)
  if (parts.length < 2) return undefined
  let from = -1
  let at = 0
  for (const p of parts) {
    const i = noteText.indexOf(p, at)
    if (i < 0) return undefined
    if (from < 0) from = i
    at = i + p.length
  }
  return noteText.slice(from, at).trim()
}

/**
 * 直接评价心情、状态时照原词（网页版 directMoodLevel，docs/prd-mood.md 5.1）：「心情很好」就是很好，不能显示成「挺好」。
 * 一句里有好几种时按先认出的那种；不是在评价心情（「很开心」「挺好的一天」）的不管
 */
const DIRECT_MOOD: [RegExp, number][] = [
  [/(心情|状态)(很|特别|非常|超级?)差|(心情|状态)(糟透|糟糕透|差透|烂透|差到极点)/, 1],
  [/(心情|状态)(不太好|不怎么样|不大好)/, 2],
  [/(心情|状态)(一般|还行|马马虎虎|凑合)/, 3],
  [/(心情|状态)(不错|挺好|还不错|还挺好|蛮好)/, 4],
  [/(心情|状态)(很好|特别好|超级?好|非常好|好极了)/, 5],
]

export function directMoodLevel(text: string): number | undefined {
  const t = text.replace(/\s/g, '')
  let best: { at: number; level: number } | undefined
  for (const [re, level] of DIRECT_MOOD) {
    const m = re.exec(t)
    if (m && (!best || m.index < best.at)) best = { at: m.index, level }
  }
  return best?.level
}

/** 级别 → 好不好、强不强（程序定了级别时，两个判断跟着写对） */
export function toneOfLevel(level: number): { tone: MoodTone; strength: MoodStrength } {
  if (level >= 5) return { tone: 'good', strength: 'strong' }
  if (level === 4) return { tone: 'good', strength: 'medium' }
  if (level === 3) return { tone: 'neutral', strength: 'medium' }
  if (level === 2) return { tone: 'bad', strength: 'medium' }
  return { tone: 'bad', strength: 'strong' }
}

/**
 * 很难受的说法（网页版 DISTRESS_PATTERNS，docs/prd-mood.md 5.6）：去掉空白后对得上任一个就算。由程序认全，不靠 AI 自己标。
 * 口头禅不算：「不想活动」「想死你了」「热得想死」「累死了」「这个项目撑不下去了」
 */
export const DISTRESS_PATTERNS = [
  /不想.{0,2}活(了|下去|着)/,
  /活不下去/,
  /活着.{0,2}没意思/,
  /自杀|轻生|了结自己|结束自己|结束生命|伤害自己|不想醒来/,
  /活着.{0,3}(累|难|苦|没劲|没有?意义)/,
  /活着.{0,6}什么意义|人生.{0,3}没有?意义/,
  /(?<!得)想死(?![你我他她它])/,
  /死了算了|不如死了|还不如死|一死了之/,
  /想消失|消失算了|不想存在/,
  /我.{0,4}(撑|熬)不下去/,
  /没有?活下去的(意义|理由|勇气|动力|希望)/,
]

export const isDistress = (text: string): boolean => {
  const t = text.replace(/\s/g, '')
  return DISTRESS_PATTERNS.some((p) => p.test(t))
}

/**
 * 很难受时的固定回复（网页版原样，docs/prd-mood.md 5.6）：程序写的，不让 AI 自由发挥。
 * 12356 是国家卫生健康委设置的全国统一心理援助热线（国卫医政函〔2024〕259 号；网页版 2026-10-03 查证）
 */
export const DISTRESS_REPLY =
  '听起来你现在真的很难受。你说的都记下了。如果有伤害自己的念头，请马上告诉身边信任的人，或者拨打全国心理援助热线 12356、拨打急救电话。'
