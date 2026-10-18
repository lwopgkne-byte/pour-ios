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
import { notToRecord } from './guards.ts'
import { wakeTimeIn } from './numbers.ts'
import { aliases, backgroundVars } from './describe.ts'
import type { LlmClient } from './llm.ts'
import { DISTRESS_REPLY, cleanMoment, directMoodLevel, isDistress, keepEnergy, levelOf, moodWord, toneOfLevel } from './mood.ts'
import { CONFIDENCE_THRESHOLD, rootCategory } from './rules.ts'
import { type CreateItem, ParseOutput, RouterOutput } from './schemas.ts'
import { resolveDateRef, resolveEventTime } from './time.ts'
import { applyUpdate } from './update.ts'

export interface UnderstandDeps {
  llm: LlmClient
  skillsDir?: string
}

export async function understand(bg: BackgroundPackage, deps: UnderstandDeps): Promise<ChangePackage> {
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
  const { distress, ...changes } = applyItems(parsed.items, bg, questions)
  return {
    version: CONTRACT_VERSION,
    noteId: bg.note.id,
    intents,
    ...changes,
    // 很难受：固定的回复（带心理援助热线），不让 AI 自由发挥
    reply: distress ? DISTRESS_REPLY : intents.includes('chat') && !wantsRecords ? routed.reply : parsed.reply,
    steps,
  }
}

/** 说的是这次醒来（今天早上起床）：「昨晚」「昨天晚上」说的是那一晚；「今天」「今早」「刚睡醒」（网页版 WOKE_TODAY） */
const WOKE_TODAY = /昨晚|昨天晚上|昨儿(个)?晚上|昨个晚上|昨夜|前一晚|今天|今早|今儿|今个|刚睡醒|刚醒|刚起/

/** 拿不准删哪条（带着追问、或者把握不到 0.6）：先问，不删（网页版的规矩） */
const DELETE_CONFIDENCE = 0.6

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

/** 整理出的每一项变成改动：新建的把关；改、删、确认、做完、重复的换回手机的编号、算出改完的样子 */
export function applyItems(
  items: ParseOutput['items'],
  bg: BackgroundPackage,
  /** 意图识别认出的问话：从问话里摘出来的不记 */
  asked: string[] = [],
): Pick<ChangePackage, 'creates' | 'updates' | 'deletes' | 'duplicates' | 'questions' | 'newCategories' | 'skipped'> & {
  distress: boolean
} {
  const { recordOf } = aliases(bg.existing)
  // 这段话里新建的类别加进来：后面的记录接着用得上；最后放进改动包，手机照着建上
  const book = new CategoryBook(bg.categories)
  const creates: NewRecord[] = []
  const updates = new Map<string, UpdatedRecord>()
  const deletes: ChangePackage['deletes'] = []
  const duplicates: ChangePackage['duplicates'] = []
  const questions: string[] = []
  const skipped: string[] = []
  const text = bg.note.text
  // 很难受的认法看这条心情摘的那段；整段话只有一条心情时也看整段原话（网页版 guarded）
  const moodsInNote = items.filter((i) => i.op === 'create' && i.kind === 'mood').length
  let distress = false
  // 同一段话里改了同一条好几次：在改过的样子上接着改
  const current = (record: ExistingRecord): ExistingRecord => {
    const u = updates.get(record.id)
    return u ? { id: u.id, day: u.day, data: u.data, ...(u.question ? { question: u.question } : {}) } : record
  }
  const put = (u: UpdatedRecord) => {
    const before = updates.get(u.id)
    updates.set(u.id, before && before.action === 'updated' && u.action !== 'updated' ? { ...u, action: 'updated' } : u)
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
        const weekday = weekdayDateIn(item.span, bg.note.day)
        if (weekday && item.date !== weekday) guarded = { ...item, date: weekday }
      } else if (item.kind === 'mood') {
        const sad = item.distress === true || isDistress(item.span) || (moodsInNote === 1 && isDistress(text))
        if (sad) distress = true
        // 直接评价心情（「心情很好」）：照原词定级别
        const direct = directMoodLevel(item.span) ?? (moodsInNote === 1 ? directMoodLevel(text) : undefined)
        if (sad) guarded = { ...item, tone: 'bad', strength: 'strong' }
        else if (direct) guarded = { ...item, ...toneOfLevel(direct) }
      }
      creates.push(newRecord(guarded, bg, book))
      continue
    }
    const original = recordOf(item.entry_id)
    // AI 写了不存在的编号：不动任何记录
    if (!original || deletes.some((d) => d.id === original.id)) continue
    const record = current(original)
    switch (item.op) {
      case 'update': {
        const u = applyUpdate(record, item, bg.dayBoundary, book.all)
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
          break
        }
        updates.delete(record.id)
        deletes.push({ id: record.id, span: item.span })
        break
      case 'duplicate':
        duplicates.push({ id: record.id, span: item.span })
        break
    }
  }
  // 新建了类别：背景里落在「其他」的旧记录对得上的归进来（网页版 adoptFromOther）
  for (const category of book.created) {
    for (const r of bg.existing) {
      const d = r.data
      if (d.kind !== 'event' || d.category !== 'other' || updates.has(r.id) || deletes.some((x) => x.id === r.id)) continue
      if (!adoptsFromOther(category, [d.label, ...d.people, ...d.things, ...d.places])) continue
      put({ id: r.id, action: 'updated', day: r.day, data: { ...d, category: category.key }, span: '', confidence: 1, ...(r.question ? { question: r.question } : {}) })
    }
  }
  return { creates, updates: [...updates.values()], deletes, duplicates, questions, newCategories: book.created, skipped, distress }
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
      const data: RecordData = {
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
      }
      return { day: t.day, data }
    }
    case 'insight':
      return { day: noteDay, data: { kind: 'insight', title: item.title, quote: item.quote, tags: item.tags } }
    case 'todo':
      return {
        day: noteDay,
        data: { kind: 'todo', content: item.content, ...(item.due ? { due: resolveDateRef(item.due, noteDay) } : {}), done: false, ...mentions(item) },
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
          emotions: item.emotions,
          ...(moment ? { moment } : {}),
        },
      }
    }
  }
}
