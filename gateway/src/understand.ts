/**
 * 理解一段话：背景包进、改动包出（docs/03-架构与开发方案.md 第 5.1 节；照网页版 server/src/ai/pipeline.ts、steps.ts）。
 * 意图识别和整理同时开始（整理不等意图识别）；没有要记录的就取消整理、不白花钱。
 *
 * M2a 搬了主干：意图识别 → 整理 → 新建记录的程序把关（日期和时间、类别、心情）。
 * 改、删、确认、补完待办（M2b）和网页版细致的把关（新类别、同义词、领域归类、只说几点起、钱的去向……M2c）陆续搬来
 */
import { callSkill } from './call-skill.ts'
import { type BackgroundPackage, CONTRACT_VERSION, type Category, type ChangePackage, type NewRecord, type RecordData, type StepLog } from './contract.ts'
import type { DateStr } from './dates.ts'
import { backgroundVars } from './describe.ts'
import type { LlmClient } from './llm.ts'
import { cleanMoment, keepEnergy, levelOf } from './mood.ts'
import { type CreateItem, ParseOutput, RouterOutput } from './schemas.ts'
import { resolveDateRef, resolveEventTime } from './time.ts'

export interface UnderstandDeps {
  llm: LlmClient
  skillsDir?: string
}

/** 把握低于这个数的记录要你确认（网页版设置里的默认值） */
export const CONFIDENCE_THRESHOLD = 0.8

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

  const creates = parsed.items.flatMap((item) => (item.op === 'create' ? [newRecord(item, bg)] : []))
  return {
    version: CONTRACT_VERSION,
    noteId: bg.note.id,
    intents,
    creates,
    reply: intents.includes('chat') && !wantsRecords ? routed.reply : parsed.reply,
    steps,
  }
}

/** 顶级类别：一直往上找（「跑步」的顶级是「运动」） */
export function rootCategory(key: string, cats: Category[]): string {
  let current = key
  for (let hops = 0; hops < 8; hops++) {
    const parent = cats.find((c) => c.key === current)?.parent
    if (!parent) return current
    current = parent
  }
  return current
}

/**
 * 一条新建的记录：日期和时间、类别、心情的程序把关（照网页版 buildEntry）。
 * 把握低于门槛才问；心情本来就是推测、卡片上标着「AI 推测」，不问；一天只有 24 小时，时长超过就问一句
 */
export function newRecord(item: CreateItem, bg: BackgroundPackage): NewRecord {
  const { day, data } = recordOf(item, bg)
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

function recordOf(item: CreateItem, bg: BackgroundPackage): { day: DateStr; data: RecordData } {
  const noteDay = bg.note.day
  const mentions = (m: { people?: string[] | undefined; things?: string[] | undefined; places?: string[] | undefined }) => ({
    people: m.people ?? [],
    things: m.things ?? [],
    places: m.places ?? [],
  })
  switch (item.kind) {
    case 'event': {
      // 类别表里有的才用；没有的先归「其他」（新类别、同义词、领域归类 M2c 照网页版搬）
      const category = bg.categories.some((c) => c.key === item.category) ? item.category : 'other'
      const isSleep = rootCategory(category, bg.categories) === 'sleep'
      const t = resolveEventTime(
        { date: item.date ?? null, start: item.start ?? null, end: item.end ?? null, durationMin: item.duration_min ?? null },
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
