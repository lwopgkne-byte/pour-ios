/**
 * 一套常用的情绪说法（照网页版 shared/src/emotions.ts；docs/prd-mood.md 5.5）：AI 从这里挑，程序按「也算」归并。
 * 只有一个用处：同一种感受只有一个名字，以后才能数、能比。显示时只写字，不上颜色
 */

export type EmotionGroup = 'good' | 'bad' | 'unclear'

export interface Emotion {
  word: string
  group: EmotionGroup
  /** 也算这个说法的（程序归并） */
  also: string[]
}

const e = (group: EmotionGroup, word: string, also: string[]): Emotion => ({ word, group, also })

export const EMOTIONS: Emotion[] = [
  e('good', '开心', ['高兴', '快乐', '愉快', '开森', '乐', '好笑']),
  e('good', '幸福', ['甜蜜', '美好']),
  e('good', '放松', ['轻松', '舒服', '惬意', '自在', '舒坦']),
  e('good', '平静', ['安静', '宁静', '淡定']),
  e('good', '满足', ['充实', '有成就感', '成就感', '过瘾', '值了']),
  e('good', '踏实', ['安心', '安稳', '放心']),
  e('good', '温暖', ['暖心', '温馨']),
  e('good', '感动', ['触动', '泪目', '动容']),
  e('good', '期待', ['盼着', '憧憬', '向往']),
  e('good', '骄傲', ['自豪', '得意']),
  e('good', '感激', ['感恩', '感谢']),
  e('good', '兴奋', ['激动', '振奋']),
  e('bad', '难过', ['伤心', '心酸', '想哭']),
  e('bad', '失落', ['低落', '沮丧', '郁闷', '丧']),
  e('bad', '委屈', ['憋屈']),
  e('bad', '生气', ['火大', '恼火', '愤怒', '窝火']),
  e('bad', '烦躁', ['烦', '心烦', '闹心', '不耐烦']),
  e('bad', '焦虑', ['担心', '不安', '发愁', '着急', '心慌']),
  e('bad', '紧张', ['忐忑']),
  e('bad', '害怕', ['恐惧', '后怕']),
  e('bad', '孤单', ['孤独', '寂寞']),
  e('bad', '失望', ['灰心', '扫兴']),
  e('bad', '内疚', ['后悔', '自责', '愧疚']),
  e('bad', '无聊', ['没意思', '空虚']),
  e('bad', '压力大', ['压抑', '喘不过气']),
  e('unclear', '想念', ['惦记', '思念', '想家']),
  e('unclear', '怀念', ['怀旧']),
  e('unclear', '感慨', ['唏嘘', '五味杂陈', '百感交集']),
]

/** 说的是精力，不是情绪词（精力另外记） */
export const ENERGY_ONLY = ['累', '疲惫', '困', '乏', '没精神', '有劲', '精神好']

/**
 * 口语里也算说了这种感受：「跑完特别痛快」「心里暖暖的」「忍不住笑了」。
 * **只用在核对和清理**（这条心情的情绪词是不是原话里有的），不用在整理时自动补——
 * 「笑话」「开心果」这种也会撞上，自动补会补错（docs/prd-mood.md 第 18 节）
 */
export const SPOKEN_ALSO: Record<string, string[]> = { 开心: ['痛快', '笑'], 温暖: ['暖暖'], 生气: ['火'], 难过: ['哭'] }

/** 这个情绪词在原话里出现过吗（它本身、它的「也算」、口语说法；去掉空白后按字面找） */
export function emotionAppears(text: string, word: string): boolean {
  const t = text.replace(/\s/g, '')
  const e = EMOTIONS.find((x) => x.word === word)
  return [word, ...(e?.also ?? []), ...(SPOKEN_ALSO[word] ?? [])].some((w) => t.includes(w))
}

const BY_WORD = new Map<string, Emotion>(EMOTIONS.flatMap((x) => [[x.word, x] as const, ...x.also.map((a) => [a, x] as const)]))

/** 这个说法属于哪一组（好的 / 不好的 / 说不清的）；不在这套说法里是 null */
export const emotionGroup = (word: string): EmotionGroup | null => BY_WORD.get(word.trim())?.group ?? null

/**
 * 情绪词归并：去掉空白、去掉说精力的、能对上的换成这套说法（「高兴」→ 开心，「憋屈」→ 委屈），
 * 对不上的照原样留着；去重，最多 3 个
 */
export function normalizeEmotions(words: string[]): string[] {
  const out: string[] = []
  for (const raw of words) {
    const w = raw.trim()
    if (!w || ENERGY_ONLY.includes(w)) continue
    const word = BY_WORD.get(w)?.word ?? w
    if (!out.includes(word)) out.push(word)
    if (out.length === 3) break
  }
  return out
}

/** 说成一种感受的样子：前面是程度词、「我」「心里」「觉得」，或者后面是「死了」「坏了」「极了」 */
const FEELING_BEFORE = ['很', '挺', '好', '真', '太', '超', '蛮', '更', '又', '特别', '非常', '有点', '有点儿', '有些', '比较', '十分', '格外', '我', '心里', '觉得', '感到', '感觉']
const FEELING_AFTER = ['死了', '坏了', '极了', '透了', '得很', '得不行', '得要命', '得不得了']
/** 前面三个字里有这些，说的是没有这种感受（「不开心」「没那么开心」「一点也不放松」）；后面跟着「不起来」也是（「开心不起来」） */
const NEGATION = /[不没未别无]/
const NEGATED_AFTER = ['不起来', '不了']

/**
 * 原话里直接说出来的情绪词（docs/prd-mood.md 第 18 节）：这套说法和它的「也算」，说成一种感受的样子才算——
 * 「今天挺开心的」「我有点紧张」「开心得不得了」「烦死了」。「天气温暖」「吃了开心果」「音乐」「麻烦」这种不是在说感受的不认，
 * 「不开心」「开心不起来」不认。
 * 用处：AI 一个情绪词都没写、原话里却直接说了时，程序补上（规则改成「没说就不写」以后，AI 偶尔把「挺开心的」也当成只评价了心情）
 */
export function saidEmotions(text: string): string[] {
  const t = text.replace(/\s/g, '')
  const found: { at: number; word: string }[] = []
  for (const [said, emotion] of BY_WORD) {
    for (let at = t.indexOf(said); at >= 0; at = t.indexOf(said, at + 1)) {
      const before = t.slice(Math.max(0, at - 3), at)
      const after = t.slice(at + said.length)
      if (NEGATION.test(before) || NEGATED_AFTER.some((w) => after.startsWith(w))) continue
      if (FEELING_BEFORE.some((w) => before.endsWith(w)) || FEELING_AFTER.some((w) => after.startsWith(w))) found.push({ at, word: emotion.word })
    }
  }
  return normalizeEmotions(found.sort((a, b) => a.at - b.at).map((f) => f.word))
}
