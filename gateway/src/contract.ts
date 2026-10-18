/**
 * 接口契约 v1（docs/03-架构与开发方案.md 第 8 节）：手机发「背景包」，网关回「改动包」。
 * 改格式先升版本号；`npm run contract` 把它们写成 JSON Schema（gateway/contract/），手机那边的测试用同一份核对。
 */
import { z } from 'zod'

export const CONTRACT_VERSION = 1

const DateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
/** 本地时刻：说这句话的地方墙上的钟点，YYYY-MM-DDTHH:mm（网关不认时区） */
const LocalDateTime = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/)

/** 类别（手机上的类别表；网页版的基础类别是起点） */
export const Category = z.object({
  key: z.string().min(1),
  name: z.string().min(1),
  emoji: z.string().default(''),
  parent: z.string().nullish(),
  /** duration 时长 / count 次数 / 其他是数量的单位（公里、页） */
  measure: z.string().default('duration'),
  synonyms: z.array(z.string()).default([]),
})
export type Category = z.infer<typeof Category>

/** 一个数：钱、距离、页数……（钱的去向、给谁花的 M2c 起补齐） */
export const Metric = z.object({
  name: z.string().min(1),
  value: z.number(),
  unit: z.string().default(''),
  item: z.string().optional(),
  for: z.string().optional(),
  from: z.string().optional(),
})
export type Metric = z.infer<typeof Metric>

const Mentions = {
  people: z.array(z.string()).default([]),
  things: z.array(z.string()).default([]),
  places: z.array(z.string()).default([]),
}

/** 一条记录的内容（手机存的、发回来给 AI 看的，都是这个样子） */
export const RecordData = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('event'),
    category: z.string(),
    label: z.string().min(1),
    /** 几点开始、几点结束（本地时刻；跨零点的睡眠结束在第二天） */
    start: LocalDateTime.optional(),
    end: LocalDateTime.optional(),
    durationMin: z.number().positive().optional(),
    metrics: z.array(Metric).default([]),
    note: z.string().optional(),
    ...Mentions,
  }),
  z.object({ kind: z.literal('insight'), title: z.string().min(1), quote: z.string().min(1), tags: z.array(z.string()).default([]) }),
  z.object({ kind: z.literal('todo'), content: z.string().min(1), due: DateStr.optional(), done: z.boolean().default(false), ...Mentions }),
  z.object({
    kind: z.literal('mood'),
    /** 1–5：很差、不太好、一般、挺好、很好（由程序查表定，不是 AI 直接给的数） */
    level: z.number().int().min(1).max(5),
    tone: z.enum(['good', 'neutral', 'bad', 'mixed']).optional(),
    strength: z.enum(['weak', 'medium', 'strong']).optional(),
    /** 精力 1–5：只在说到时才有 */
    energy: z.number().int().min(1).max(5).optional(),
    emotions: z.array(z.string()).default([]),
    /** 那一刻：原话里一字不差的一段 */
    moment: z.string().optional(),
  }),
])
export type RecordData = z.infer<typeof RecordData>

/** 已有的一条记录（背景包里给 AI 看，判断是不是同一件事、补充哪一条） */
export const ExistingRecord = z.object({
  id: z.string().min(1),
  day: DateStr,
  data: RecordData,
  /** 还在等你确认的那个问题 */
  question: z.string().optional(),
})
export type ExistingRecord = z.infer<typeof ExistingRecord>

/** 背景包：整理一段话要用的全部背景，手机从本机数据库拼出来 */
export const BackgroundPackage = z.object({
  version: z.literal(CONTRACT_VERSION),
  note: z.object({
    id: z.string().min(1),
    text: z.string().trim().min(1).max(4000),
    /** 说这句话时手机上的本地钟点 YYYY-MM-DDTHH:mm（网关不认时区，只用这个） */
    localTime: LocalDateTime,
    timeZone: z.string().min(1),
    /** 按日界线算的「今天」 */
    day: DateStr,
  }),
  /** 日界线，当日分钟数：240 = 凌晨 4:00 之前算前一天 */
  dayBoundary: z.number().int().min(0).max(720).default(240),
  categories: z.array(Category).min(1),
  /** 今天的记录、前后几天还没做完的待办 */
  existing: z.array(ExistingRecord).default([]),
})
export type BackgroundPackage = z.infer<typeof BackgroundPackage>

/** 改动包里新建的一条记录 */
export const NewRecord = z.object({
  day: DateStr,
  data: RecordData,
  /** 原话里对应的那一段（详情里荧光标出） */
  span: z.string().default(''),
  confidence: z.number().min(0).max(1),
  /** 拿不准时要问你的话：有它就是「待确认」 */
  question: z.string().optional(),
})
export type NewRecord = z.infer<typeof NewRecord>

/** 这一段话处理中的一步（给开发看：多久、用了多少；不含原话） */
export const StepLog = z.object({
  step: z.string(),
  skill: z.string().optional(),
  skillVersion: z.string().optional(),
  durationMs: z.number(),
  promptTokens: z.number().optional(),
  cacheHitTokens: z.number().optional(),
  completionTokens: z.number().optional(),
  error: z.string().optional(),
})
export type StepLog = z.infer<typeof StepLog>

/** 改动包：理解一段话的全部结果，手机在一个事务里整体写入、整体撤销 */
export const ChangePackage = z.object({
  version: z.literal(CONTRACT_VERSION),
  noteId: z.string(),
  /** 这段话是记录、提问、目标、纠正还是聊天 */
  intents: z.array(z.enum(['record', 'question', 'goal', 'correction', 'chat'])),
  /** 新建的记录（收据由手机照这些记录排出来） */
  creates: z.array(NewRecord),
  /** 给你的一句话（聊天的回应、整理顺口说的话） */
  reply: z.string(),
  steps: z.array(StepLog),
})
export type ChangePackage = z.infer<typeof ChangePackage>
