/**
 * 理解一段话：背景包进、改动包出（docs/03-架构与开发方案.md 第 5.1 节；照网页版 server/src/ai/pipeline.ts、steps.ts）。
 * 意图识别和整理同时开始（整理不等意图识别）；没有要记录的就取消整理、不白花钱。
 *
 * M2a：新建记录的程序把关（日期和时间、类别、心情）。M2b：改、删、确认、做完待办、之前已记过——
 * AI 说的是短编号（#3），这里换回手机的编号，算出改完的样子。
 * 网页版细致的把关（新类别、同义词、领域归类、只说几点起、钱的去向、「又」……M2c）陆续搬来
 */
import { CategoryBook, adoptsFromOther, resolveEventCategory } from './categories.ts'
import { callSkill } from './call-skill.ts'
import {
  type BackgroundPackage,
  CONTRACT_VERSION,
  type ChangePackage,
  type ExistingRecord,
  type NewRecord,
  type RecordData,
  type StepLog,
  type UpdatedRecord,
} from './contract.ts'
import { addDays, type DateStr, weekdayDateIn } from './dates.ts'
import { againOf, againWith, changedAmounts, extraFields, findDuplicate, isRepeatMention, isStrongRepeat, sameActivity } from './dedupe.ts'
import { normalizeEmotions, saidEmotions } from './emotions.ts'
import { notToRecord } from './guards.ts'
import { wakeTimeIn } from './numbers.ts'
import { aliases, backgroundVars } from './describe.ts'
import type { LlmClient } from './llm.ts'
import { DISTRESS_REPLY, cleanMoment, directMoodLevel, isDistress, keepEnergy, levelOf, moodWord, toneOfLevel } from './mood.ts'
import { quickAnswer } from './quick.ts'
import { isCorrectionCue, mentionsDay, upcomingRelativeDayIn, upcomingWeekdayIn } from './refer.ts'
import { CONFIDENCE_THRESHOLD, rootCategory, rootName } from './rules.ts'
import { type CreateItem, ParseOutput, RouterOutput, type UpdateItem } from './schemas.ts'
import { minutesBetween, resolveDateRef, resolveEventTime } from './time.ts'
import { tidyEvent } from './tidy.ts'
import { applyUpdate } from './update.ts'

export interface UnderstandDeps {
  llm: LlmClient
  skillsDir?: string
}

export async function understand(bg: BackgroundPackage, deps: UnderstandDeps): Promise<ChangePackage> {
  // 「对」「删吧」回答上一句问的要不要删、同一句话又发了一遍：程序直接回，不问 AI（quick.ts）
  const quick = quickAnswer(bg)
  if (quick) return quick
  const steps: StepLog[] = []
  const vars = backgroundVars(bg)
  const common = { llm: deps.llm, log: steps, user: bg.note.text, vars, ...(deps.skillsDir ? { skillsDir: deps.skillsDir } : {}) }
  const parseAbort = new AbortController()
  const parsing = callSkill({ ...common, step: 'parse', skill: 'parse-note', schema: ParseOutput, maxTokens: 3000, signal: parseAbort.signal })
  // 用不上时会取消，取消报的错没人等
  parsing.catch(() => {})
  let routed: RouterOutput
  try {
    routed = await callSkill({ ...common, step: 'route', skill: 'router', schema: RouterOutput, maxTokens: 600 })
  } catch (err) {
    parseAbort.abort()
    throw err
  }
  // 一段话里说了好几件要记的事，意图识别会写好几个 record：改动包里每种只写一次
  const intents = [...new Set(routed.intents.map((i) => i.type))]
  const wantsRecords = intents.includes('record') || intents.includes('correction')
  let parsed: ParseOutput = { items: [], learn: [], reply: '' }
  if (wantsRecords) parsed = await parsing
  else parseAbort.abort()

  const questions = routed.intents.filter((i) => i.type === 'question').map((i) => i.text)
  const { distress, repeatedAgain, ...changes } = applyItems(parsed.items, bg, questions, intents.includes('correction'))
  const raw = intents.includes('chat') && !wantsRecords ? routed.reply : parsed.reply
  return {
    version: CONTRACT_VERSION,
    noteId: bg.note.id,
    intents,
    ...changes,
    ...compose({ intents, changes, raw, distress, repeatedAgain }),
    steps,
  }
}

/** 整理时的回复不能替系统做承诺（「5 分钟后提醒你」）：能不能提醒由系统决定，说了这类话的回复不显示（网页版 honest） */
const PROMISE = /提醒你|叫你|喊你|通知你|会提醒|帮你盯|到时候告诉你/
/** 内部编号（#12）只是给 AI 对照记录用的，给你看的话里不能出现 */
const noIds = (t: string) =>
  t
    .replace(/(\p{Script=Han})?\s*#\d+\s*(\p{Script=Han})?/gu, (_m, a = '', b = '') => (a && b ? `${a}${b}` : `${a} ${b}`))
    .replace(/\s{2,}/g, ' ')
    .replace(/ ([，。？、])/g, '$1')
    .trim()

export const NOTHING_TO_RECORD = '这段话里没有新的内容要记（说过的已经记下了）。'
export const WHICH_ONE = '没找到要改的是哪条，能说具体一点吗？比如「跑步那条删掉」。'
export const NO_ANSWER_YET = '问答还没做好，这句话的原话先留着。'

/**
 * 给你的那句话和要问你的话（照网页版 composeStep）：
 * - 有提问时不显示整理顺口的回复（它可能说出没核对过的数字）；问答还没做（以后的模块），只是提问就照实说
 * - 回复里问的话也是追问：和别的追问一样记下，下一句就知道是在回答它
 * - 说了话却什么都没发生，要说明白，不能一声不响（不然以为没发出去，再发一遍）
 * - 很难受的时候：换成程序写的那句，不追问
 */
function compose(o: {
  intents: ChangePackage['intents']
  changes: Pick<ChangePackage, 'creates' | 'updates' | 'deletes' | 'duplicates' | 'questions'>
  raw: string
  distress: boolean
  repeatedAgain: boolean
}): { reply: string; questions: string[] } {
  if (o.distress) return { reply: DISTRESS_REPLY, questions: [] }
  const asking = o.intents.includes('question')
  let reply = asking || PROMISE.test(o.raw) ? '' : noIds(o.raw.trim())
  // 原话说了「又」、程序照新的一次记了：AI 顺口问的「这次和之前那次是同一次吗？」不再问
  if (o.repeatedAgain && /[？?]/.test(reply)) reply = ''
  let questions = [...new Set(o.changes.questions.map(noIds))]
  if (reply && /[？?]/.test(reply) && questions.length === 0) {
    questions = [reply]
    reply = ''
  }
  const { creates, updates, deletes, duplicates } = o.changes
  const happened = creates.length + updates.length + deletes.length + duplicates.length > 0
  if (!happened && !reply && questions.length === 0) {
    if (o.intents.includes('correction')) questions = [WHICH_ONE]
    else if (o.intents.includes('record')) reply = NOTHING_TO_RECORD
    else if (asking) reply = NO_ANSWER_YET
  }
  return { reply, questions }
}

/** 对话里改心情的字段：那一刻要一字不差在原话里、不是只说了心情；原话没说到精力就不改精力 */
function guardedMoodFields(fields: UpdateItem['fields'], noteText: string): UpdateItem['fields'] {
  const { moment, energy, ...rest } = fields
  const keptMoment = moment === undefined || moment.trim() === '' ? moment : cleanMoment(moment, noteText)
  const keptEnergy = typeof energy === 'number' && !keepEnergy(noteText) ? undefined : energy
  return { ...rest, ...(keptMoment !== undefined ? { moment: keptMoment } : {}), ...(keptEnergy !== undefined ? { energy: keptEnergy } : {}) }
}

/** 说的是这次醒来（今天早上起床）：「昨晚」「昨天晚上」说的是那一晚；「今天」「今早」「刚睡醒」（网页版 WOKE_TODAY） */
const WOKE_TODAY = /昨晚|昨天晚上|昨儿(个)?晚上|昨个晚上|昨夜|前一晚|今天|今早|今儿|今个|刚睡醒|刚醒|刚起/

/** 拿不准删哪条（带着追问、或者把握不到 0.6）：先问，不删（网页版的规矩） */
const DELETE_CONFIDENCE = 0.6

/** 多久以内说过的算「刚才对话里正在说的」（分钟） */
const RECENT_TALK_MIN = 30

/** 一条记录的一句话（删之前问你时用） */
export function describeRecord(d: RecordData): string {
  switch (d.kind) {
    case 'event':
      return d.label
    case 'insight':
      return `感悟「${d.title}」`
    case 'todo':
      return `待办「${d.content}」`
    case 'mood':
      return `心情 ${moodWord(d.level)}`
  }
}

/** 整理出的每一项变成改动：新建的把关、去重；改、删、确认、做完、重复的换回手机的编号、算出改完的样子 */
export function applyItems(
  items: ParseOutput['items'],
  bg: BackgroundPackage,
  /** 意图识别认出的问话：从问话里摘出来的不记 */
  asked: string[] = [],
  /** 意图识别认出这段话是在纠正 */
  isCorrection = false,
): Pick<ChangePackage, 'creates' | 'updates' | 'deletes' | 'duplicates' | 'questions' | 'awaitingDelete' | 'newCategories' | 'skipped'> & {
  distress: boolean
  repeatedAgain: boolean
} {
  const { recordOf } = aliases(bg.existing)
  // 这段话里新建的类别加进来：后面的记录接着用得上；最后放进改动包，手机照着建上
  const book = new CategoryBook(bg.categories)
  const creates: NewRecord[] = []
  const updates = new Map<string, UpdatedRecord>()
  const deletes: ChangePackage['deletes'] = []
  const duplicates: ChangePackage['duplicates'] = []
  const questions: string[] = []
  /** 问了要不要删的那几条：下一句回答「对」时照着删 */
  const awaitingDelete: string[] = []
  const skipped: string[] = []
  const text = bg.note.text
  const noteDay = bg.note.day
  // 很难受的认法看这条心情摘的那段；整段话只有一条心情时也看整段原话（网页版 guarded）
  const moodsInNote = items.filter((i) => i.op === 'create' && i.kind === 'mood').length
  let distress = false
  /** 原话说了「又」、AI 却判成重复的，照新的一次记了 */
  let repeatedAgain = false
  const deleted = (id: string) => deletes.some((d) => d.id === id)
  // 同一段话里改了同一条好几次：在改过的样子上接着改
  const current = (record: ExistingRecord): ExistingRecord => {
    const u = updates.get(record.id)
    return u ? { id: u.id, day: u.day, data: u.data, ...(u.question ? { question: u.question } : {}) } : record
  }
  // 同一条在一段话里被提到好几次：留最有信息量的动作（改了的不再算「之前已记过」）
  const put = (u: UpdatedRecord) => {
    const before = updates.get(u.id)
    updates.set(u.id, before && before.action === 'updated' && u.action !== 'updated' ? { ...u, action: 'updated' } : u)
    const i = duplicates.findIndex((d) => d.id === u.id)
    if (i >= 0) duplicates.splice(i, 1)
  }
  const markDuplicate = (id: string, span: string) => {
    if (!updates.has(id) && !duplicates.some((d) => d.id === id)) duplicates.push({ id, span })
  }
  /** 刚才对话里正在说的那条（半小时内的哪段话动过它） */
  const talkedJustNow = (id: string) =>
    bg.dialogue.some((t) => minutesBetween(t.localTime, bg.note.localTime) <= RECENT_TALK_MIN && t.actions.some((a) => a.recordId === id))

  // 一段话在把那天的事再说一遍（别的事已经记过：AI 判成了重复、改了那条，或者那天已经有同名的记录）：这一天里光说一个「又」的
  // （「回来吃了晚饭，又去图书馆看了会儿书」「下午网购又花了147」）是「接着」「另外」，不算又做了一次；
  // 明说了「又…一次」「第二次」的照旧是新的一次（「又喂了一次奶」）。网页版训练场找到的
  const recapDays = new Set<DateStr>()
  for (const item of items) {
    if (isRepeatMention(item.span)) continue
    if (item.op === 'duplicate' || item.op === 'update') {
      const r = recordOf(item.entry_id)
      if (r) recapDays.add(r.day)
    } else if (item.op === 'create' && item.kind === 'event') {
      const day = resolveDateRef(item.date, noteDay)
      if (bg.existing.some((e) => e.day === day && e.data.kind === 'event' && sameActivity(e.data.label, item.label))) recapDays.add(day)
    }
  }
  /** 原话说了「又」，确实是又做了一次：明说了几次的，或者这一天不是在回顾 */
  const againForSure = (span: string | undefined, day: DateStr) => isRepeatMention(span) && (isStrongRepeat(span) || !recapDays.has(day))

  /**
   * 兜底去重：AI 漏判时也不会重复计算（原话说的是约数「两百多」时按范围比）。
   * 已有的记录里有同一件：多说了时间、数量就补上那一条，没多说就是「之前已记过」；这段话前面刚新建过同一件：补进那条
   */
  const merged = (rec: NewRecord, span: string): boolean => {
    const known = bg.existing.filter((r) => r.day === rec.day && !deleted(r.id)).map(current)
    const dup = findDuplicate(known, rec, span)
    if (dup) {
      const extra = extraFields(dup.data, rec.data, bg.dayBoundary)
      if (!extra) markDuplicate(dup.id, span)
      else {
        const confidence = Math.max(rec.confidence, dup.question ? 0 : 1)
        put({ id: dup.id, action: 'updated', span, ...applyUpdate(dup, { op: 'update', entry_id: 1, fields: extra, span, confidence, question: undefined }, bg.dayBoundary, book.all) })
      }
      return true
    }
    const earlier = findDuplicate(creates, rec, span)
    if (!earlier) return false
    const extra = extraFields(earlier.data, rec.data, bg.dayBoundary)
    if (extra) {
      const confidence = Math.max(rec.confidence, earlier.confidence)
      const u = applyUpdate({ id: 'new', day: earlier.day, data: earlier.data }, { op: 'update', entry_id: 1, fields: extra, span, confidence, question: undefined }, bg.dayBoundary, book.all)
      creates[creates.indexOf(earlier)] = { day: u.day, data: u.data, span: earlier.span, confidence: u.confidence, ...(u.question ? { question: u.question } : {}) }
    }
    return true
  }

  for (const item of items) {
    if (item.op === 'create') {
      // 不该记的不记：问的话、说没做的、别人的事（guards.ts）
      const notThis = notToRecord(
        { kind: item.kind, ...('label' in item ? { label: item.label } : {}), span: item.span, people: 'people' in item ? item.people : undefined },
        asked,
        text,
      )
      if (notThis) {
        skipped.push(`${notThis}，不记：${'label' in item ? item.label : 'content' in item ? item.content : 'title' in item ? item.title : ''}（${item.span}）`)
        continue
      }
      let guarded: CreateItem = item
      if (item.kind === 'event') {
        // 做过的事说的是星期几（「周五加班」）：日期由程序照日期表定，不用 AI 推算的
        const weekday = weekdayDateIn(item.span, noteDay)
        if (weekday && item.date !== weekday) guarded = { ...item, date: weekday }
      } else if (item.kind === 'mood') {
        const sad = item.distress === true || isDistress(item.span) || (moodsInNote === 1 && isDistress(text))
        if (sad) distress = true
        // 直接评价心情（「心情很好」）：照原词定级别
        const direct = directMoodLevel(item.span) ?? (moodsInNote === 1 ? directMoodLevel(text) : undefined)
        let mood = item
        if (sad) mood = { ...mood, tone: 'bad', strength: 'strong' }
        else if (direct) mood = { ...mood, ...toneOfLevel(direct) }
        // AI 一个情绪词都没写、原话里却直接说了（「挺开心的」）：程序补上（看这条摘的那段；整段只有一条心情时看整段）
        if (item.emotions.length === 0) mood = { ...mood, emotions: saidEmotions(item.span || (moodsInNote === 1 ? text : '')) }
        guarded = mood
      }
      const rec = newRecord(guarded, bg, book)
      // 原话明说了「又」「第二次」的是新的一次，不合并——除非这段话是在把那天的事再说一遍、这一件又只是光一个「又」
      if (!(rec.data.kind === 'event' && againForSure(item.span, rec.day)) && merged(rec, item.span)) continue
      creates.push(rec)
      continue
    }
    const original = recordOf(item.entry_id)
    // AI 写了不存在的编号：不动任何记录
    if (!original || deleted(original.id)) continue
    const record = current(original)
    switch (item.op) {
      case 'update': {
        // 对话里改心情：那一刻同样要一字不差在这段原话里，没说精力的字就不改精力（清空照样可以）
        const u = applyUpdate(record, record.data.kind === 'mood' ? { ...item, fields: guardedMoodFields(item.fields, text) } : item, bg.dayBoundary, book.all)
        // 要动别的日子记下的事的时间、数量，得有根据：意图是纠正、原话明说了是改（「改成」「不是…是」）、说到了那天、
        // 或者就是刚才对话里正在说的那条。都没有，多半是今天又做了同样的事（「进货一共1950」被当成改昨天的进货）：
        // 照今天新的一次记，以前那条不动
        if (
          record.data.kind === 'event' &&
          record.day !== noteDay &&
          changedAmounts(record, u) &&
          !isCorrection &&
          !isCorrectionCue(text) &&
          !mentionsDay(text, noteDay, record.day) &&
          !talkedJustNow(record.id)
        ) {
          const fresh = againWith({ ...record, data: record.data }, item.fields, noteDay, bg.dayBoundary, book.all, record.question ? item.confidence : 1)
          creates.push({ day: fresh.day, data: fresh.data, span: item.span, confidence: fresh.confidence, ...(fresh.question ? { question: fresh.question } : {}) })
          skipped.push(`没说是改 ${record.day} 那条（不是纠正、没提那天），照今天新的一次记：${describeRecord(record.data)}`)
          break
        }
        put({ id: record.id, action: 'updated', span: item.span, ...u })
        break
      }
      case 'confirm':
        put({ id: record.id, action: 'confirmed', day: record.day, data: record.data, span: item.span, confidence: 1 })
        break
      case 'complete_todo':
        if (record.data.kind !== 'todo') break
        put({ id: record.id, action: 'completed', day: record.day, data: { ...record.data, done: true }, span: item.span, confidence: 1 })
        break
      case 'delete':
        if (item.question || (item.confidence !== undefined && item.confidence < DELETE_CONFIDENCE)) {
          questions.push(item.question ?? `要删的是「${describeRecord(record.data)}」吗？`)
          if (!awaitingDelete.includes(record.id)) awaitingDelete.push(record.id)
          break
        }
        updates.delete(record.id)
        deletes.push({ id: record.id, span: item.span })
        break
      case 'duplicate':
        // 原话明说了「又」「第二次」：是新的一次，AI 判成重复也照新的一次记，不再问「是同一次吗」
        if (record.data.kind === 'event' && againForSure(item.span, record.day)) {
          creates.push({ day: noteDay, data: againOf(record.data), span: item.span, confidence: 1 })
          repeatedAgain = true
          break
        }
        markDuplicate(record.id, item.span)
        break
    }
  }
  // 新建了类别：背景里落在「其他」的旧记录对得上的归进来（网页版 adoptFromOther）
  for (const category of book.created) {
    for (const r of bg.existing) {
      const d = r.data
      if (d.kind !== 'event' || d.category !== 'other' || updates.has(r.id) || deleted(r.id)) continue
      if (!adoptsFromOther(category, [d.label, ...d.people, ...d.things, ...d.places])) continue
      put({ id: r.id, action: 'updated', day: r.day, data: { ...d, category: category.key }, span: '', confidence: 1, ...(r.question ? { question: r.question } : {}) })
    }
  }
  // 同一段话里又说清楚删了的，不再等
  const waiting = awaitingDelete.filter((id) => !deleted(id))
  return { creates, updates: [...updates.values()], deletes, duplicates, questions, awaitingDelete: waiting, newCategories: book.created, skipped, distress, repeatedAgain }
}

/**
 * 一条新建的记录：日期和时间、类别、心情的程序把关（照网页版 buildEntry）。
 * 把握低于门槛才问；心情本来就是推测、卡片上标着「AI 推测」，不问；一天只有 24 小时，时长超过就问一句
 */
export function newRecord(item: CreateItem, bg: BackgroundPackage, book = new CategoryBook(bg.categories)): NewRecord {
  const { day, data } = recordOf(item, bg, book)
  const unsure = item.kind !== 'mood' && item.confidence < CONFIDENCE_THRESHOLD
  const tooLong = data.kind === 'event' && data.durationMin !== undefined && data.durationMin > 24 * 60
  const question =
    data.kind === 'event' && tooLong
      ? `${data.label} ${Math.round(data.durationMin! / 60)} 小时？一天只有 24 小时，是不是说错了？`
      : unsure
        ? (item.question ?? '我理解得对吗？')
        : undefined
  return { day, data, span: item.span, confidence: item.confidence, ...(question ? { question } : {}) }
}

function recordOf(item: CreateItem, bg: BackgroundPackage, book: CategoryBook): { day: DateStr; data: RecordData } {
  const noteDay = bg.note.day
  const mentions = (m: { people?: string[] | undefined; things?: string[] | undefined; places?: string[] | undefined }) => ({
    people: m.people ?? [],
    things: m.things ?? [],
    places: m.places ?? [],
  })
  switch (item.kind) {
    case 'event': {
      // 类别：同义词、生活领域、新活动（categories.ts，照网页版）
      const category = resolveEventCategory(item, book)
      const isSleep = rootCategory(category, book.all) === 'sleep'
      // 只说了几点起（「今天六点半起的」）：起床时刻由程序照原话认——AI 没写就补上，写成了入睡时间就挪回起床
      const wake = isSleep && !item.end ? (wakeTimeIn(item.span) ?? undefined) : undefined
      const startIsWake = wake !== undefined && item.start !== undefined && item.start.replace(/^(\d):/, '0$1:') === wake
      const start = startIsWake ? undefined : item.start
      const end = item.end ?? (start ? undefined : wake)
      // 「昨晚睡到五点半」「刚睡醒，昨晚睡了好久」：「昨晚」说的是那一晚，起床在今天——没说几点睡的，睡觉归到起床那天
      const date =
        isSleep && !start && resolveDateRef(item.date, noteDay) === addDays(noteDay, -1) && WOKE_TODAY.test(item.span ?? '')
          ? 'today'
          : item.date
      const t = resolveEventTime(
        { date: date ?? null, start: start ?? null, end: end ?? null, durationMin: item.duration_min ?? null },
        noteDay,
        bg.dayBoundary,
        { isSleep, now: bg.note.localTime },
      )
      // 钱的名字、合计和拆分、血压、名称里的称呼：程序整理一遍（tidy.ts）
      const data = tidyEvent(
        {
          kind: 'event',
          category,
          label: item.label,
          ...(t.start ? { start: t.start } : {}),
          ...(t.end ? { end: t.end } : {}),
          ...(t.durationMin ? { durationMin: t.durationMin } : {}),
          metrics: (item.metrics ?? []).map((m) => ({
            name: m.name,
            value: m.value,
            unit: m.unit,
            ...(m.item ? { item: m.item } : {}),
            ...(m.for ? { for: m.for } : {}),
            ...(m.from ? { from: m.from } : {}),
          })),
          ...(item.note ? { note: item.note } : {}),
          ...mentions(item),
        },
        { rootName: rootName(category, book.all), span: item.span, noteText: bg.note.text },
      )
      return { day: t.day, data }
    }
    case 'insight':
      return { day: noteDay, data: { kind: 'insight', title: item.title, quote: item.quote, tags: item.tags } }
    case 'todo': {
      // 要做的事的日子由程序往后数（照网页版 buildEntry）：「明天」「大后天」程序数；AI 把星期几写成了已经过去的那天，改回还没到的那天
      const said = item.due ? resolveDateRef(item.due, noteDay) : undefined
      const due = upcomingRelativeDayIn(item.span ?? '', noteDay) ?? (said && said < noteDay ? (upcomingWeekdayIn(item.span ?? '', noteDay) ?? said) : said)
      return { day: noteDay, data: { kind: 'todo', content: item.content, ...(due ? { due } : {}), done: false, ...mentions(item) } }
    }
    case 'mood': {
      // 级别由程序查表；说到很难受的定为很差（M2c 搬网页版的整套说法）；精力只在原话说到时才有；那一刻要一字不差
      const level = item.distress ? 1 : item.tone ? levelOf(item.tone, item.strength) : (item.mood ?? 3)
      const moment = cleanMoment(item.moment, bg.note.text)
      return {
        day: noteDay,
        data: {
          kind: 'mood',
          level,
          ...(item.tone ? { tone: item.tone } : {}),
          ...(item.strength ? { strength: item.strength } : {}),
          ...(item.energy !== undefined && keepEnergy(bg.note.text) ? { energy: item.energy } : {}),
          emotions: normalizeEmotions(item.emotions),
          ...(moment ? { moment } : {}),
        },
      }
    }
  }
}
