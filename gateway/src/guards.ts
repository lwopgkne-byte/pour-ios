/**
 * 不该记的不记（网页版 server/src/ai/guards.ts 原样，训练场找到的，docs/prd-arena.md 15.5）：
 * AI 整理时偶尔会把这几种话记成一条，规则里早就写了还是时对时错，改成程序把关——
 * - 问的话：「这周一共洗碗了几次」记了一条洗碗，「这周午睡次数」记成一条感悟
 * - 说没做的：「今天没网购」记了一条网购
 * - 别人的事：「老伴感冒了」「小周要离职了」「老公今天加班」记成用户的事件
 */

/** 新建的一条（AI 整理出来的，心情不归这里管） */
export interface NewItem {
  kind: string
  label?: string
  title?: string
  content?: string
  span?: string
  people?: string[] | undefined
}

const squash = (s: string) => s.replace(/[\s，。！？、,.!?；;：:~～]/g, '')

/** 问的说法（几、多少、多久、什么时候……） */
const ASKING = /几|多少|多久|多长|哪天|哪一天|什么时候|有没有|是不是|吗|呢/

/** 摘的字在不在问话里：意图识别写问话时会顺手改掉语音的错字，差的字不超过两个、也不超过一成半就算在里面 */
function nearlyIn(s: string, q: string): boolean {
  if (q.includes(s)) return true
  const allowed = Math.min(2, Math.floor(s.length * 0.15))
  for (let i = 0; i + s.length <= q.length; i++) {
    let diff = 0
    for (let j = 0; j < s.length && diff <= allowed; j++) if (s[j] !== q[i + j]) diff++
    if (diff <= allowed) return true
  }
  return false
}

/** 这一条是不是从问话里摘出来的：摘的字整个在意图识别认出的问话里，而且本身就是在问 */
export function fromQuestion(span: string | undefined, questions: string[]): boolean {
  const s = squash(span ?? '')
  return s.length > 0 && ASKING.test(s) && questions.some((q) => nearlyIn(s, squash(q)))
}

/** 说的是没做（「今天没网购」「还没吃午饭」）：叫法前面紧挨着「没」「没有」「还没」，中间最多隔一个字 */
export function saidNotDone(label: string | undefined, span: string | undefined, noteText = ''): boolean {
  const l = (label ?? '').trim()
  if (!l) return false
  const escaped = l.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const negated = new RegExp(`(?:没有?|还没|没再|没能)[^，。,.；;！!？?\\s没]?${escaped}`, 'g')
  const s = span ?? ''
  if (s.includes(l) && squash(s) !== squash(l)) return negated.test(s)
  const all = noteText.split(l).length - 1
  return all > 0 && (noteText.match(negated) ?? []).length === all
}

/** 用户自己也在里面的说法：我、陪、带、跟、和、给、一起…… */
const INVOLVED = /我|咱|俺|陪|带|跟|和|与|给|帮|替|一起|一块|送|接|辅导|教|喂|哄|照顾|看望|探望|打电话|视频/
/** 别人自己的状况、自己的事：病了、加班、出差、离职、考试、装修…… */
const THEIR_OWN = /感冒|发烧|生病|病了|住院|咳嗽|拉肚子|过敏|加班|出差|离职|辞职|请假|值班|上班|下班|考试|考了|上岸|升职|装修|搬家|结婚|离婚|怀孕|上兴趣班|上课|放学|开学/

/** 别人的事：摘的话以这个人开头，后面没有用户自己，说的是他自己的状况。「老公做的晚饭」「带孙子去上兴趣班」不算 */
export function othersEvent(item: NewItem): boolean {
  if (item.kind !== 'event') return false
  const span = (item.span ?? '').trim()
  const who = (item.people ?? []).find((p) => p && span.startsWith(p))
  if (!who) return false
  if (INVOLVED.test(span.slice(who.length))) return false
  return THEIR_OWN.test(item.label ?? '') || THEIR_OWN.test(span)
}

/** 这一条不该记的话，说清楚为什么；该记的返回 null */
export function notToRecord(item: NewItem, questions: string[], noteText = ''): string | null {
  if (item.kind === 'mood') return null
  if (fromQuestion(item.span, questions)) return '这是问的话，不是记录'
  if (item.kind !== 'event') return null
  if (saidNotDone(item.label, item.span, noteText)) return '原话说的是没做'
  if (othersEvent(item)) return '是别人的事，只是提到'
  return null
}
