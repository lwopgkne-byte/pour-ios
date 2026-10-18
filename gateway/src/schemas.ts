/**
 * 大模型输出的结构（zod），照网页版 server/src/ai/schemas.ts 原样搬来（意图识别和整理两部分；目标的 M2b 起再搬）。
 * 字段用下划线命名，和 Skill 文件里的示例一致。对可有可无的字段放宽（null / 缺省都接受），对关键字段严格。
 */
import { z } from 'zod'
import { energyLevel } from './mood.ts'

export const IntentType = z.enum(['record', 'question', 'goal', 'correction', 'chat'])
export type IntentType = z.infer<typeof IntentType>

export const RouterOutput = z.object({
  intents: z.array(z.object({ type: IntentType, text: z.string().default('') })).min(1),
  reply: z.string().nullish().transform((v) => v ?? ''),
})
export type RouterOutput = z.infer<typeof RouterOutput>

const opt = <T extends z.ZodTypeAny>(t: T) => t.nullish().transform((v) => v ?? undefined)
const clock = opt(z.string().regex(/^\d{1,2}:\d{2}$/))
const dateRef = opt(z.string())
const confidence = z.coerce.number().min(0).max(1).catch(0.5)
const question = opt(z.string())
const span = z.string().default('')

/**
 * 数量：没给数的（null、空、「好几」这种写不成数的）、是 0 的不要——没说就是没有，绝不写 0（docs/prd-mood.md 7.2）。
 * 以前 `z.coerce.number()` 把 AI 写的 null 变成了 0
 */
const Metric = z.object({
  name: z.string(),
  value: z.union([z.number(), z.string()]).nullish(),
  unit: z.string().nullish().transform((v) => v ?? ''),
  /** 钱的名目（详情里改某一笔时带回来，分得清改的是哪一笔） */
  item: z.string().nullish().transform((v) => v || undefined),
  /** 钱是给谁花的（docs/prd-money.md 5.1）：没说就没有 */
  for: z.string().nullish().catch(undefined).transform((v) => v?.trim() || undefined),
  /** 收进来的钱是谁给的（人情往来，docs/prd-money.md 第 17 节）：没说就没有 */
  from: z.string().nullish().catch(undefined).transform((v) => v?.trim() || undefined),
  /** 能报销、借出去，或者回来的钱；写错了当没写 */
  flag: z.enum(['reimburse', 'lend', 'repay', 'reimbursed', 'refund']).nullish().catch(undefined).transform((v) => v ?? undefined),
  /** 能报销的报了、借出去的还了（详情里点「标记为已报销」） */
  settled: z.boolean().nullish().catch(undefined),
  /** 一次买了几节、几次（课时、次卡）；不是 2 到 500 之间的整数当没写（docs/prd-money.md 5.5） */
  pack: z
    .union([z.number(), z.string()])
    .nullish()
    .catch(undefined)
    .transform((v) => {
      const n = Number(v ?? Number.NaN)
      return Number.isInteger(n) && n > 1 && n <= 500 ? n : undefined
    }),
  /** 不再算固定的（详情里点的，AI 不写） */
  ended: z.boolean().nullish().catch(undefined),
  /** 原话说了每月扣（程序照原话认，AI 不写）：详情里改这一笔时原样带回来 */
  monthly: z.boolean().nullish().catch(undefined),
  /** 后来回来了多少（退款、AA 转回来；程序对上时记下，AI 不写）：详情里改这一笔时原样带回来 */
  returned: z.object({ amount: z.number().positive(), why: z.enum(['refund', 'aa']) }).nullish().catch(undefined),
})
const metricList = z.array(Metric).transform((list) =>
  list.flatMap((m) => {
    const v = typeof m.value === 'number' ? m.value : typeof m.value === 'string' && m.value.trim() ? Number(m.value) : Number.NaN
    return Number.isFinite(v) && v !== 0
      ? [
          {
            name: m.name,
            value: v,
            unit: m.unit,
            ...(m.item ? { item: m.item } : {}),
            ...(m.for ? { for: m.for } : {}),
            ...(m.from ? { from: m.from } : {}),
            ...(m.flag ? { flag: m.flag } : {}),
            ...(m.settled ? { settled: true as const } : {}),
            ...(m.pack ? { pack: m.pack } : {}),
            ...(m.ended ? { ended: true as const } : {}),
            ...(m.monthly ? { monthly: true as const } : {}),
            ...(m.returned ? { returned: m.returned } : {}),
          },
        ]
      : []
  }),
)

/** 你说的值不值（docs/prd-money.md 5.8）：原话里一字不差的一段，程序核对；写错了当没写 */
const Verdict = z.object({ tone: z.enum(['good', 'regret']), quote: z.string().trim().min(1) })

/** 时长：没给、0、写不成数的都是没有 */
const duration = z.coerce
  .number()
  .nullish()
  .catch(undefined)
  .transform((v) => (v !== null && v !== undefined && Number.isFinite(v) && v > 0 ? v : undefined))

/** AI 遇到新活动时提出的新类别；服务器先查同义词，确实没有才新建 */
const NewCategory = z.object({
  name: z.string().trim().min(1),
  emoji: z.string().trim().default('📌'),
  color: z.string().default('gray'),
  parent: opt(z.string()),
  measure: opt(z.string()),
  synonyms: z.array(z.string()).default([]),
})

/** 人、物、地方：事件和待办都有 */
const Mentions = {
  /** 和谁有关（关系或名字） */
  people: opt(z.array(z.string().trim().min(1)).max(6)),
  /** 提到的东西 */
  things: opt(z.array(z.string().trim().min(1)).max(6)),
  /** 在哪儿 */
  places: opt(z.array(z.string().trim().min(1)).max(4)),
}

const EventFields = {
  /** 类别表里已有的 key；新活动写 other 并给出 new_category */
  category: z.string().trim().default('other'),
  new_category: opt(NewCategory),
  label: z.string().min(1),
  date: dateRef,
  start: clock,
  end: clock,
  duration_min: duration,
  metrics: opt(metricList),
  note: opt(z.string()),
  ...Mentions,
  /** 话题（人、物、地方以外的关键词） */
  tags: opt(z.array(z.string().trim().min(1)).max(4)),
  /** 花钱买的东西、做的事，你说了值不值 */
  verdict: opt(Verdict).catch(undefined),
  /** 人情往来（随礼、红包、送礼、请客）：AI 听出来的方向；是不是人情、事由由程序照原话认（docs/prd-money.md 第 17 节） */
  renqing: opt(z.object({ dir: z.enum(['out', 'in']) })).catch(undefined),
}

const clampScore = (v: number) => Math.min(5, Math.max(1, Math.round(v)))
const moodScore = z.coerce.number().transform(clampScore)

/** AI 听出来的好不好、强不强（docs/prd-mood.md 5.1）：级别由程序查表；写错了当没写 */
const tone = z.enum(['good', 'neutral', 'bad', 'mixed']).nullish().catch(undefined).transform((v) => v ?? undefined)
const strength = z.enum(['weak', 'medium', 'strong']).nullish().catch(undefined).transform((v) => v ?? undefined)

/** 精力的说法（「有点累」）或 1–5 → 1–5；对不上就没有 */
const toEnergy = (v: string | number): number | undefined => {
  if (typeof v === 'number') return Number.isFinite(v) ? clampScore(v) : undefined
  const word = energyLevel(v)
  if (word) return word
  const n = Number(v.trim())
  return v.trim() && Number.isFinite(n) ? clampScore(n) : undefined
}

/** 精力：只在说到时才有；null、没写、对不上都是没有，不再补成 1 */
const energy = z
  .union([z.string(), z.number()])
  .nullish()
  .catch(undefined)
  .transform((v) => (v === null || v === undefined ? undefined : toEnergy(v)))

/** 改精力：null 是清空（详情里点「没说」），没写是不改 */
const energyChange = z
  .union([z.string(), z.number(), z.null()])
  .optional()
  .catch(undefined)
  .transform((v) => (v === null ? null : v === undefined ? undefined : (toEnergy(v) ?? undefined)))

const boolish = z.union([z.boolean(), z.enum(['true', 'false']).transform((v) => v === 'true')])

const Create = z.discriminatedUnion('kind', [
  z.object({ op: z.literal('create'), kind: z.literal('event'), ...EventFields, span, confidence, question }),
  z.object({
    op: z.literal('create'),
    kind: z.literal('insight'),
    title: z.string().min(1),
    quote: z.string().min(1),
    tags: z.array(z.string()).default([]),
    span,
    confidence,
    question,
  }),
  z.object({
    op: z.literal('create'),
    kind: z.literal('todo'),
    content: z.string().min(1),
    due: dateRef,
    /** 「5 分钟后提醒我」：几分钟后 */
    remind_in_min: opt(z.coerce.number().positive().max(60 * 24 * 30)),
    /** 「8 点提醒我」：几点（HH:mm），日期看 due */
    remind_at: clock,
    /** 用户要到时候提醒（「提醒我…」、写在「提醒」标题下面）。没说时间时只有它：由程序问什么时候提醒，AI 不定时间 */
    remind: opt(z.union([z.boolean(), z.enum(['true', 'false']).transform((v) => v === 'true')])),
    ...Mentions,
    span,
    confidence,
    question,
  }),
  z.object({
    op: z.literal('create'),
    kind: z.literal('mood'),
    tone,
    strength,
    /** 后备：AI 照老习惯写了 1–5、没写 tone 时才用 */
    mood: opt(moodScore).catch(undefined),
    energy,
    emotions: z.array(z.string()).default([]),
    /** 那一刻：原话里一字不差的一段，程序核对 */
    moment: opt(z.string()),
    /** 说到不想活、伤害自己这类话 */
    distress: opt(boolish).catch(undefined),
    span,
    confidence,
    question,
  }),
])

/** update 的字段：各类记录字段的任意子集（卡片上的原地修改也用它） */
export const UpdateFields = z
  .object({
    category: opt(z.string()),
    label: opt(z.string().min(1)),
    date: dateRef,
    start: clock,
    end: clock,
    duration_min: EventFields.duration_min,
    metrics: EventFields.metrics,
    note: opt(z.string()),
    people: opt(z.array(z.string())),
    things: opt(z.array(z.string())),
    places: opt(z.array(z.string())),
    title: opt(z.string()),
    quote: opt(z.string()),
    tags: opt(z.array(z.string())),
    content: opt(z.string()),
    due: dateRef,
    remind_in_min: opt(z.coerce.number().positive().max(60 * 24 * 30)),
    remind_at: clock,
    /** 直接给级别（详情里点的）：用它，去掉 tone / strength（以你为准） */
    mood: opt(moodScore),
    /** 对话里说「其实没那么开心」：改好不好、强不强，程序重算级别 */
    tone,
    strength,
    /** 精力：null 是清空（详情里点「没说」） */
    energy: energyChange,
    emotions: opt(z.array(z.string())),
    /** 那一刻：空字符串是清空 */
    moment: opt(z.string()),
    /** 值不值：null 是清空 */
    verdict: z.union([Verdict, z.null()]).optional().catch(undefined),
    /** 人情往来：null 是「不算人情」（详情里点的）；别的不认 */
    renqing: z.null().optional().catch(undefined),
  })
  .partial()

const entryId = z.coerce.number().int().positive()

export const ParseItem = z.union([
  Create,
  z.object({ op: z.literal('update'), entry_id: entryId, fields: UpdateFields, span, confidence, question }),
  z.object({ op: z.literal('duplicate'), entry_id: entryId, span }),
  z.object({ op: z.literal('complete_todo'), entry_id: entryId, span }),
  z.object({ op: z.literal('confirm'), entry_id: entryId, span }),
  // 删除：没写把握程度就当作说清楚了；拿不准删哪条时带着追问
  z.object({ op: z.literal('delete'), entry_id: entryId, span, confidence: opt(z.coerce.number().min(0).max(1)).catch(undefined), question }),
])
export type ParseItem = z.infer<typeof ParseItem>
export type CreateItem = z.infer<typeof Create>
export type UpdateItem = Extract<ParseItem, { op: 'update' }>

export const ParseOutput = z
  .object({
    items: z.array(ParseItem).default([]),
    /** 学会的说法（个人词典）：只在用户确认过意思之后才写 */
    learn: z.array(z.object({ phrase: z.string().trim().min(1), meaning: z.string().trim().min(1) })).default([]),
    reply: z.string().nullish().transform((v) => v ?? ''),
  })
  // 心情的级别由程序查表：tone 和后备的 mood 都没写，就是输出不合格（重试一次）
  .superRefine((out, ctx) => {
    out.items.forEach((item, i) => {
      if (item.op === 'create' && item.kind === 'mood' && !item.tone && item.mood === undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['items', i, 'tone'], message: '心情要写 tone（good / neutral / bad / mixed）' })
      }
    })
  })
export type ParseOutput = z.infer<typeof ParseOutput>

/** zod 错误压成一两句话，放进日志和重试提示里 */
export function describeZodError(err: z.ZodError): string {
  return err.issues
    .slice(0, 5)
    .map((i) => `${i.path.join('.') || '（根）'}：${i.message}`)
    .join('；')
}
