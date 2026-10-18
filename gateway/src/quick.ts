/**
 * 不用问 AI 的几种话（照网页版 server/src/ai/pipeline.ts 的 answerAwaiting、dialogue.ts 的 awaitingAnswer、sameAsRecent）：
 * - 上一句问了「要删这几条吗？」，这一句是简单的「对」「删吧」「算了」：程序直接删或者不删（确定的事不交给 AI 猜）；
 *   别的回答（「不是，是看电影那个」）照常交给 AI，AI 在对话里看得到在等哪几条
 * - 同一句话几分钟内又发了一遍（以为没发出去又点了一次）：上一次记下了东西的话，不再整理一遍
 */
import { type BackgroundPackage, CONTRACT_VERSION, type ChangePackage } from './contract.ts'
import { minutesBetween } from './time.ts'

/** 「是的」「对，删吧」「都删」：确认 */
const YES = /^(是|是的|是啊|对|对的|对呀|嗯|嗯嗯|好|好的|行|可以|确认|没错|删|删吧|删掉|删掉吧|删了吧|都删|都删了吧|全删|全部删掉|是的删掉|对删掉|对删吧|是删吧|是的删吧|好删吧|都删掉)$/
/** 「不」「算了」「先别删」：不删 */
const NO = /^(不|不是|不对|不用|不要|别删|先别删|算了|取消|不删|先不删|不用了)$/

/** 去掉句末的标点和语气：「是的。」「好的～」 */
const bare = (s: string) =>
  s
    .trim()
    .replace(/[。.!！~～，,、\s]+$/u, '')
    .replace(/[，,\s]+/gu, '')

/** 几分钟以内又发了同一句算重复发送 */
const RESEND_WITHIN_MIN = 5

export const RESENT_REPLY = '这句话刚才已经说过了，记录都在，没有重复记。'

/** 什么都不改的改动包：只回一句话（或者只删问过的那几条） */
function only(bg: BackgroundPackage, part: Partial<ChangePackage>): ChangePackage {
  return {
    version: CONTRACT_VERSION,
    noteId: bg.note.id,
    intents: [],
    creates: [],
    updates: [],
    deletes: [],
    duplicates: [],
    questions: [],
    awaitingDelete: [],
    newCategories: [],
    skipped: [],
    reply: '',
    steps: [],
    ...part,
  }
}

/** 上一句问了要不要删、这一句是简单的确认或拒绝：照着删或者不删 */
function answerAwaiting(bg: BackgroundPackage): ChangePackage | null {
  const last = bg.dialogue.at(-1)
  if (!last || last.status !== 'done' || last.undone || last.awaitingDelete.length === 0) return null
  const said = bare(bg.note.text)
  if (NO.test(said)) return only(bg, { reply: '好，不删了。' })
  if (!YES.test(said)) return null
  // 问过之后可能已经删了、撤销了：只删还在的
  const alive = last.awaitingDelete.filter((id) => bg.existing.some((r) => r.id === id))
  return only(bg, { deletes: alive.map((id) => ({ id, span: bg.note.text })), reply: alive.length ? '' : '这几条已经不在了。' })
}

/**
 * 同一句话几分钟内又发了一遍：上一次记下了东西（记下、之前已记过）的话，直接说刚才已经记过。
 * 只认「记下了东西」的：删、改、问可以反复说（「删除这些」→「算了」→「还是删吧」）
 */
export function sameAsRecent(bg: BackgroundPackage): boolean {
  const norm = (s: string) => s.replace(/[\s，,。.!！?？、～~]/gu, '')
  return bg.dialogue.some(
    (t) =>
      minutesBetween(t.localTime, bg.note.localTime) <= RESEND_WITHIN_MIN &&
      t.status === 'done' &&
      !t.undone &&
      t.actions.some((a) => a.action === 'created' || a.action === 'duplicate') &&
      norm(t.text) === norm(bg.note.text),
  )
}

/** 不用问 AI 就能回答的：回改动包；要问 AI 的回 null */
export function quickAnswer(bg: BackgroundPackage): ChangePackage | null {
  const answered = answerAwaiting(bg)
  if (answered) return answered
  if (sameAsRecent(bg)) return only(bg, { reply: RESENT_REPLY, skipped: ['同一句话刚才已经发过、记下了：不再整理一遍'] })
  return null
}
