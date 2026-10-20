/**
 * 把一次「改」合并进已有的记录（照网页版 server/src/ai/steps.ts 的 applyUpdate，纯函数）。
 * 改了开始或时长：保持另一个不变，结束跟着移动；只改了结束：以结束为准重算时长。
 * 钱和别的数按「名字 + 名目」认是哪一笔；心情的级别照「好不好 × 强不强」重新查表。
 * M2b 搬了主干；钱的去向、值不值、人情往来、提醒时刻（M2c 和以后）陆续搬来
 */
import type { Category, ExistingRecord, Metric, RecordData } from './contract.ts'
import type { DateStr } from './dates.ts'
import { levelOf } from './mood.ts'
import type { UpdateItem } from './schemas.ts'
import { type LocalDateTime, type TimeExpr, logicalDayOf, resolveDateRef, resolveEventTime, resolveReminder } from './time.ts'
import { CONFIDENCE_THRESHOLD, rootCategory, rootName } from './rules.ts'
import { normalizeMoney } from './tidy.ts'

/** 改完的样子：哪天、内容、把握、还要不要问 */
export interface Updated {
  day: DateStr
  data: RecordData
  confidence: number
  question?: string
}

/** 同一个数：名字一样、名目也一样（「花费·菜」和「花费·肉」是两笔） */
const sameMetric = (a: Metric, b: Metric) => a.name === b.name && (a.item ?? '') === (b.item ?? '')

/** 「2026-10-18T07:05」→「07:05」 */
const clockOf = (s: string | undefined) => s?.slice(11)

/** 人、物、地方：去重，空的不要 */
const clean = (xs: string[] | undefined) => [...new Set((xs ?? []).map((x) => x.trim()).filter(Boolean))]

export function applyUpdate(
  record: ExistingRecord,
  item: UpdateItem,
  boundary: number,
  cats: Category[],
  /** 说这句话的本地时刻：「5 分钟后提醒我」从这里算 */
  now?: LocalDateTime,
): Updated {
  const f = item.fields
  let day: DateStr = record.day
  let data: RecordData
  const d = record.data
  switch (d.kind) {
    case 'event': {
      const category = f.category && cats.some((c) => c.key === f.category) ? f.category : d.category
      // 有开始时间就以它所在的那一天为准；只有起床时间的睡眠，起床时刻就在归属日
      const base: TimeExpr = {
        date: d.start ? logicalDayOf(d.start, boundary) : record.day,
        start: clockOf(d.start) ?? null,
        end: clockOf(d.end) ?? null,
        durationMin: d.durationMin ?? null,
      }
      const t = resolveEventTime(
        {
          date: f.date ?? base.date,
          start: f.start ?? base.start,
          end: f.end ?? (f.duration_min || f.start ? null : base.end),
          durationMin: f.duration_min ?? (f.end ? null : base.durationMin),
        },
        record.day,
        boundary,
        { isSleep: rootCategory(category, cats) === 'sleep' },
      )
      // 钱的名字先统一（「人均」「流水」→ 花费、收入），才认得出改的是哪一笔
      const money = { label: f.label ?? d.label, ...(rootName(category, cats) ? { rootName: rootName(category, cats)! } : {}) }
      const metrics = normalizeMoney(d.metrics, money)
      const said = (f.metrics ?? []).map((m): Metric => ({ name: m.name, value: m.value, unit: m.unit, ...(m.item ? { item: m.item } : {}), ...(m.for ? { for: m.for } : {}), ...(m.from ? { from: m.from } : {}) }))
      for (const next of normalizeMoney(said, money)) {
        let i = metrics.findIndex((x) => sameMetric(x, next))
        // 没说改的是哪一笔、原来又只有这一笔同名的：就是改它（名目留着）
        const same = metrics.filter((x) => x.name === next.name)
        if (i < 0 && !next.item && same.length === 1) i = metrics.indexOf(same[0]!)
        if (i >= 0) metrics[i] = { ...next, ...(metrics[i]!.item && !next.item ? { item: metrics[i]!.item } : {}) }
        else metrics.push(next)
      }
      const note = f.note ?? d.note
      day = t.day
      data = {
        kind: 'event',
        category,
        label: f.label ?? d.label,
        ...(t.start ? { start: t.start } : {}),
        ...(t.end ? { end: t.end } : {}),
        ...(t.durationMin ? { durationMin: t.durationMin } : {}),
        metrics,
        ...(note ? { note } : {}),
        people: clean(f.people ?? d.people),
        things: clean(f.things ?? d.things),
        places: clean(f.places ?? d.places),
      }
      break
    }
    case 'insight':
      data = { kind: 'insight', title: f.title ?? d.title, quote: f.quote ?? d.quote, tags: f.tags ?? d.tags }
      break
    case 'todo': {
      const due = f.due ? resolveDateRef(f.due, record.day) : d.due
      // 说了提醒的时间（回答「想什么时候提醒你？」、「改到 9 点提醒」）：照网页版 resolveReminder 算
      const remindAt =
        (f.remind_in_min || f.remind_at) && now
          ? resolveReminder({ inMin: f.remind_in_min, at: f.remind_at, due: f.due ? due : d.due }, record.day, now, boundary)
          : undefined
      const at = remindAt ?? d.remindAt
      data = {
        kind: 'todo',
        content: f.content ?? d.content,
        ...(due ? { due } : {}),
        ...(at ? { remindAt: at } : {}),
        done: d.done,
        people: clean(f.people ?? d.people),
        things: clean(f.things ?? d.things),
        places: clean(f.places ?? d.places),
      }
      break
    }
    case 'mood': {
      // 直接给了级别（详情里点的）：以你为准，去掉 AI 听出来的好不好、强不强；改了好不好、强不强：程序重算
      const manual = f.mood !== undefined
      const tone = manual ? undefined : (f.tone ?? d.tone)
      const strength = manual ? undefined : (f.strength ?? d.strength)
      const level = manual ? f.mood! : (f.tone || f.strength) && tone ? levelOf(tone, strength ?? 'medium') : d.level
      // 精力：null 是清空（点了「没说」）；那一刻：空字符串是清空
      const energy = f.energy === null ? undefined : (f.energy ?? d.energy)
      const moment = f.moment === undefined ? d.moment : f.moment.trim() || undefined
      data = {
        kind: 'mood',
        level,
        ...(tone ? { tone, strength: strength ?? 'medium' } : {}),
        ...(energy !== undefined ? { energy } : {}),
        emotions: f.emotions ?? d.emotions,
        ...(moment ? { moment } : {}),
      }
      break
    }
  }
  // 心情本来就是推测，不问；别的把握够了就不问，不够就问（AI 的追问，或者「我理解得对吗？」）
  const ok = d.kind === 'mood' || item.confidence >= CONFIDENCE_THRESHOLD
  return { day, data, confidence: item.confidence, ...(ok ? {} : { question: item.question ?? '我理解得对吗？' }) }
}
