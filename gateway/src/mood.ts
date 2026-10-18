/**
 * 心情的说法和程序把关（照网页版 shared/src/mood.ts）。
 * M2a 搬了最要紧的几条；其余（直接评价心情照原词定级、很难受的说法、那一刻的省略补全、情绪词归并……）
 * M2c 起陆续搬来，每条和网页版对拍
 */
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

/** 比较两段话用：去掉空白、标点、符号，转小写 */
export const normalizeForMatch = (s: string): string => s.replace(/[\s\p{P}\p{S}]/gu, '').toLowerCase()

/**
 * 那一刻要一字不差在这段原话里（比的时候不算空白和标点）、去掉空白不超过 60 个字，否则不记那一刻（心情照记）。
 * AI 改写过的、总结过的都不要：那一刻是你自己的话
 */
export function cleanMoment(moment: string | undefined, noteText: string): string | undefined {
  const m = moment?.trim()
  if (!m) return undefined
  const plain = normalizeForMatch(m)
  if (!plain || !normalizeForMatch(noteText).includes(plain)) return undefined
  return m.replace(/\s/g, '').length > MOMENT_MAX_CHARS ? undefined : m
}
