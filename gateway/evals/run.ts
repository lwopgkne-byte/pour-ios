/**
 * 整理准确率评测（M2c 的尺子）：`npm run eval`
 *
 * 用网页版的 340 条评测用例（evals/parse-cases.json，网页版提交 eeede65 原样搬来），在网关上真实地整理一遍：
 * 每条用例一部「假手机」——已有的记录、前面几句对话都在它的本机数据里，背景包照手机的规矩拼，
 * 改动包照手机的规矩写回去——再按网页版的评分规则（evals/run.ts 的 score）对照期望。
 *
 * 只算网关已经有的能力：意图、类别、时间、数值（钱、时长、人和地方、心情、精力、那一刻……）。
 * 还没搬的能力（目标、问答、学说法、钱的分类、人情、值不值）的检查不算对也不算错，单独数出来——
 * 搬一样，它们就进来一样。
 *
 * 会真的调用大模型（要 gateway/.env 里的密钥），全部跑一遍大约两块钱。
 * 参数：--only=id1,id2 只跑这几条；--tag=钱 只跑带这个标签的；--concurrency=4 同时跑几条；--limit=20 只跑前几条
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import {
  type BackgroundPackage,
  CONTRACT_VERSION,
  type Category,
  type ChangePackage,
  type DialogueTurn,
  type ExistingRecord,
  type RecordData,
} from '../src/contract.ts'
import { diffDays } from '../src/dates.ts'
import { ROOT, loadConfig } from '../src/env.ts'
import { createLlmClient } from '../src/llm.ts'
import { rootCategory } from '../src/rules.ts'
import { logicalDayOf } from '../src/time.ts'
import { understand } from '../src/understand.ts'
import { SEED_CATEGORIES } from '../test/sample.ts'
import { sameAmount } from './match.ts'

// ───────────── 用例的样子（网页版 evals/run.ts） ─────────────

interface ExpectEntry {
  kind: RecordData['kind']
  category?: string
  categoryAny?: string[]
  label?: string
  day?: string
  start?: string
  end?: string
  durationMin?: number
  values?: number[]
  due?: string
  remindAt?: string
  done?: boolean
  mood?: number[]
  status?: 'ok' | 'confirm'
  quoteContains?: string[]
  notCategory?: string
  people?: string[]
  things?: string[]
  places?: string[]
  keeps?: string[]
  domain?: string | string[]
  money?: { spent?: number; earned?: number; for?: string | string[]; flag?: string; flagNot?: string; pack?: number; kind?: string }
  verdict?: unknown
  renqing?: unknown
  absent?: string[]
  momentContains?: string[]
  momentNot?: string[]
  energy?: number[]
  emotionsAny?: string[]
  emotionsNot?: string[]
}

/** 网页版的一条记录（用例里的 existing、history 是这个样子） */
interface WebEntry {
  kind: RecordData['kind']
  category?: string
  day?: string
  status?: 'ok' | 'confirm'
  question?: string
  confidence?: number
  data: Record<string, unknown>
}

interface Case {
  id: string
  tags?: string[]
  text: string
  now?: string
  existing?: WebEntry[]
  dictionary?: unknown[]
  goals?: unknown[]
  history?: { text: string; at: string; entries?: WebEntry[] }[]
  turns?: { text: string; at?: string }[]
  expect: {
    intents: string[]
    entries: ExpectEntry[]
    optional?: ExpectEntry[]
    since?: number
    goals?: unknown[]
    answer?: unknown
    replyNot?: string[]
    replyContains?: string[]
    moodCount?: number
    gone?: ExpectEntry[]
    asks?: boolean
    learns?: unknown[]
    learnsNot?: string[]
  }
}

// ───────────── 假手机：本机数据、背景包、写回改动包（照 PourData、Organizer 的规矩） ─────────────

/** 手机里的一条记录 */
interface Stored {
  id: string
  day: string
  data: RecordData
  question?: string
  /** 说这条的那一刻（排时间轴用） */
  said: string
  deleted?: boolean
  seq: number
}

class Phone {
  readonly records = new Map<string, Stored>()
  readonly turns: (DialogueTurn & { at: string })[] = []
  readonly existingIds = new Set<string>()
  private seq = 0
  constructor(public categories: Category[]) {}

  /** 用例里预先放好的记录（网页版的样子 → 契约的样子） */
  seed(e: WebEntry, day: string, said: string) {
    const id = `seed-${++this.seq}`
    this.records.set(id, { id, day: e.day ?? day, data: fromWeb(e), ...(e.question || e.status === 'confirm' ? { question: e.question ?? '我理解得对吗？' } : {}), said, seq: this.seq })
    this.existingIds.add(id)
  }

  /** 背景包：那一天和前后一天的记录 + 最近 30 条没做完的待办（PourStore.existingEntries）、一小时内最多 4 段对话 */
  background(text: string, localTime: string): BackgroundPackage {
    const day = logicalDayOf(localTime, 240)
    const alive = [...this.records.values()].filter((r) => !r.deleted).sort((a, b) => a.seq - b.seq)
    const near = alive.filter((r) => Math.abs(diffDays(r.day, day)) <= 1).sort((a, b) => a.day.localeCompare(b.day) || a.seq - b.seq)
    const todos = alive
      .filter((r) => r.data.kind === 'todo' && !r.data.done && !near.includes(r))
      .slice(-30)
      .sort((a, b) => a.day.localeCompare(b.day) || a.seq - b.seq)
    const existing: ExistingRecord[] = [...near, ...todos].map((r) => ({ id: r.id, day: r.day, data: r.data, ...(r.question ? { question: r.question } : {}) }))
    const minutes = (t: string) => Date.parse(`${t}:00Z`) / 60_000
    const dialogue = this.turns.filter((t) => minutes(localTime) - minutes(t.at) <= 60 && minutes(t.at) < minutes(localTime)).slice(-4)
    return {
      version: CONTRACT_VERSION,
      note: { id: `note-${++this.seq}`, text, localTime, timeZone: 'Asia/Shanghai', day },
      dayBoundary: 240,
      categories: this.categories,
      existing,
      dialogue: dialogue.map(({ at: _at, ...t }) => t),
    }
  }

  /** 写回改动包（PourStore.apply），记下这一段对话（Organizer.dialogue） */
  apply(bg: BackgroundPackage, change: ChangePackage) {
    // 先建这段话新建的类别（手机 PourStore.apply 也是这样）
    for (const c of change.newCategories) if (!this.categories.some((x) => x.key === c.key)) this.categories = [...this.categories, c]
    const actions: DialogueTurn['actions'] = []
    for (const c of change.creates) {
      const id = `rec-${++this.seq}`
      this.records.set(id, { id, day: c.day, data: c.data, ...(c.question ? { question: c.question } : {}), said: bg.note.localTime, seq: this.seq })
      actions.push({ action: 'created', recordId: id, text: describe(c.data) })
    }
    for (const u of change.updates) {
      const r = this.records.get(u.id)
      if (!r || r.deleted) continue
      this.records.set(u.id, { ...r, day: u.day, data: u.data, ...(u.question ? { question: u.question } : { question: undefined }) })
      actions.push({ action: u.action, recordId: u.id, text: describe(u.data) })
    }
    for (const d of change.deletes) {
      const r = this.records.get(d.id)
      if (!r) continue
      this.records.set(d.id, { ...r, deleted: true })
      actions.push({ action: 'deleted', recordId: d.id, text: describe(r.data) })
    }
    for (const d of change.duplicates) {
      const r = this.records.get(d.id)
      if (r) actions.push({ action: 'duplicate', recordId: d.id, text: describe(r.data) })
    }
    const asking = actions.map((a) => this.records.get(a.recordId)).filter((r) => r && !r.deleted).flatMap((r) => (r!.question ? [r!.question] : []))
    this.turns.push({
      text: bg.note.text,
      localTime: bg.note.localTime,
      at: bg.note.localTime,
      status: 'done',
      actions,
      ...(change.reply ? { reply: change.reply } : {}),
      questions: [...change.questions, ...asking],
      undone: false,
      awaitingDelete: change.awaitingDelete,
    })
  }

  alive(): Stored[] {
    return [...this.records.values()].filter((r) => !r.deleted).sort((a, b) => a.seq - b.seq)
  }
}

/** 网页版的记录内容 → 契约的样子（心情的级别网页版叫 mood） */
function fromWeb(e: WebEntry): RecordData {
  const d = e.data
  const list = (v: unknown) => (Array.isArray(v) ? (v as string[]) : [])
  switch (e.kind) {
    case 'event':
      return {
        kind: 'event',
        category: e.category ?? 'other',
        label: String(d.label ?? ''),
        ...(d.start ? { start: String(d.start) } : {}),
        ...(d.end ? { end: String(d.end) } : {}),
        ...(typeof d.durationMin === 'number' ? { durationMin: d.durationMin } : {}),
        metrics: (Array.isArray(d.metrics) ? d.metrics : []) as Extract<RecordData, { kind: 'event' }>['metrics'],
        ...(d.note ? { note: String(d.note) } : {}),
        people: list(d.people),
        things: list(d.things),
        places: list(d.places),
      }
    case 'insight':
      return { kind: 'insight', title: String(d.title ?? ''), quote: String(d.quote ?? ''), tags: list(d.tags) }
    case 'todo':
      return { kind: 'todo', content: String(d.content ?? ''), ...(d.due ? { due: String(d.due) } : {}), done: Boolean(d.done), people: list(d.people), things: list(d.things), places: list(d.places) }
    case 'mood':
      return {
        kind: 'mood',
        level: Number(d.mood ?? d.level ?? 3),
        ...(typeof d.energy === 'number' ? { energy: d.energy } : {}),
        emotions: list(d.emotions),
        ...(d.moment ? { moment: String(d.moment) } : {}),
      }
  }
}

/** 一条记录的一句话（对话里说给 AI 听） */
function describe(d: RecordData): string {
  switch (d.kind) {
    case 'event':
      return [d.label, ...d.metrics.map((m) => `${m.value}${m.unit}`), d.people.length ? `和${d.people.join('、')}` : ''].filter(Boolean).join(' · ')
    case 'insight':
      return `感悟：${d.title}`
    case 'todo':
      return `待办：${d.content}`
    case 'mood':
      return `心情 ${d.level}`
  }
}

// ───────────── 评分（网页版 evals/run.ts 的 score，只算已经搬了的能力） ─────────────

type Dim = 'intent' | 'category' | 'time' | 'value'
interface Check {
  dim: Dim
  ok: boolean
  what: string
}

let cats: Category[] = SEED_CATEGORIES
/** 期望写成网页版的样子：记录的「类别」，非事件就是种类 */
const categoryOf = (r: Stored) => (r.data.kind === 'event' ? r.data.category : r.data.kind)
/** 子类别算上级；期望「其他」时，程序自动新建的类别（c- 开头）也算对：新活动本来就该有自己的类别（网页版的规矩） */
function sameCategory(want: string, got: string): boolean {
  const root = rootCategory(got, cats)
  if (got === want || root === want) return true
  return want === 'other' && root.startsWith('c-')
}
const domainNames = (exp: ExpectEntry) => (exp.domain === undefined ? [] : Array.isArray(exp.domain) ? exp.domain : [exp.domain])
const domainOf = (r: Stored) => {
  const root = rootCategory(categoryOf(r), cats)
  return cats.find((c) => c.key === root)?.name ?? root
}
const domainOk = (exp: ExpectEntry, r: Stored) => exp.domain === undefined || domainNames(exp).some((n) => n.replace(/\s/g, '') === domainOf(r).replace(/\s/g, ''))
const categoryOk = (exp: ExpectEntry, r: Stored) =>
  (exp.categoryAny ? exp.categoryAny.some((c) => sameCategory(c, categoryOf(r))) : exp.category ? sameCategory(exp.category, categoryOf(r)) : true) && domainOk(exp, r)
const labelOk = (exp: ExpectEntry, r: Stored) => {
  if (!exp.label) return true
  const name = r.data.kind === 'event' ? r.data.label : r.data.kind === 'todo' ? r.data.content : null
  return name === null || name.includes(exp.label) || exp.label.includes(name)
}
const squash = (s: string) => s.replace(/\s/g, '')
const momentOf = (r: Stored | null) => (r?.data.kind === 'mood' ? (r.data.moment ?? '') : '')
const momentOk = (exp: ExpectEntry, r: Stored) => {
  if (!exp.momentContains) return true
  const m = squash(momentOf(r))
  return exp.momentContains.every((w) => m.includes(squash(w))) && !(exp.momentNot ?? []).some((w) => m.includes(squash(w)))
}
const isAbsent = (v: unknown) => v === undefined || v === null || v === '' || (Array.isArray(v) && v.length === 0)

function match(expected: ExpectEntry[], actual: Stored[]): [ExpectEntry, Stored | null][] {
  const used = new Set<string>()
  const pick = (exp: ExpectEntry, strict: boolean) =>
    actual.find((r) => !used.has(r.id) && r.data.kind === exp.kind && categoryOk(exp, r) && (!strict || (labelOk(exp, r) && momentOk(exp, r) && (!exp.day || r.day === exp.day)))) ?? null
  return expected.map((exp) => {
    const found = pick(exp, true) ?? pick(exp, false)
    if (found) used.add(found.id)
    return [exp, found]
  })
}

/** 网页版评测的「当前阶段」：since 比它大的用例网页版也只查意图 */
const WEB_STAGE = 6

/** 还没搬的能力：这些期望不算对也不算错，数出来 */
const NOT_PORTED_FIELDS = ['remindAt', 'verdict', 'renqing'] as const

function score(c: Case, intents: string[], phone: Phone): { checks: Check[]; skipped: string[] } {
  const checks: Check[] = []
  const skipped: string[] = []
  const actual = phone.alive()
  const want = [...new Set(c.expect.intents)].sort().join(',')
  const got = [...new Set(intents)].sort().join(',')
  // 用例带着已有的目标、个人词典（背景里要有它们才答得对）：这两样还没搬，网关看不到——整条不算，检查也不算
  if (c.goals?.length) return { checks: [], skipped: ['目标'] }
  if (c.dictionary?.length) return { checks: [], skipped: ['个人词典'] }
  checks.push({ dim: 'intent', ok: want === got, what: `意图 期望 ${want}，实际 ${got || '（无）'}` })
  // 网页版也还没做好的（since 大于网页版当时的阶段 6）：只查意图，和网页版一样
  if ((c.expect.since ?? 0) > WEB_STAGE) return { checks, skipped }
  if (c.expect.goals !== undefined) skipped.push('目标')
  if (c.expect.answer) skipped.push('问答')
  if (c.expect.learns?.length || c.expect.learnsNot?.length) skipped.push('学说法')

  const pairs = match(c.expect.entries, actual)
  const matched = new Set(pairs.map(([, r]) => r?.id).filter((x): x is string => x !== undefined))
  for (const [exp, r] of pairs) {
    const name = `${exp.kind}${exp.category ? `/${exp.category}` : ''}${exp.domain ? `/${domainNames(exp).join('或')}` : ''}${exp.label ? `「${exp.label}」` : ''}`
    checks.push({ dim: 'category', ok: Boolean(r), what: `${name} ${r ? '找到了' : '没有记下'}` })
    const d = r?.data as Record<string, unknown> | undefined
    const eq = (dim: Dim, field: string, want: unknown, got: unknown) => checks.push({ dim, ok: r !== null && want === got, what: `${name} ${field} 期望 ${want}，实际 ${got ?? '（无）'}` })
    if (exp.day) eq('time', '日期', exp.day, r?.day)
    if (exp.start) eq('time', '开始', exp.start, d?.start)
    if (exp.end) eq('time', '结束', exp.end, d?.end)
    if (exp.due) eq('time', '期限', exp.due, d?.due)
    if (exp.durationMin !== undefined) {
      const gotMin = d?.durationMin as number | undefined
      checks.push({ dim: 'value', ok: gotMin !== undefined && Math.abs(gotMin - exp.durationMin) <= Math.max(2, exp.durationMin * 0.05), what: `${name} 时长 期望 ${exp.durationMin}，实际 ${gotMin ?? '（无）'}` })
    }
    for (const v of exp.values ?? []) {
      const metrics = (d?.metrics as { value: number; unit?: string }[] | undefined) ?? []
      checks.push({ dim: 'value', ok: metrics.some((m) => sameAmount(m.value, m.unit ?? '', v)), what: `${name} 数量 期望有 ${v}，实际 ${metrics.map((m) => m.value).join('、') || '（无）'}` })
    }
    if (exp.done !== undefined) eq('value', '完成', exp.done, d?.done)
    for (const w of exp.quoteContains ?? []) {
      const q = (d?.quote as string | undefined) ?? ''
      checks.push({ dim: 'value', ok: q.includes(w), what: `${name} 摘录里要有「${w}」，实际「${q}」` })
    }
    if (exp.notCategory) checks.push({ dim: 'category', ok: r !== null && categoryOf(r) !== exp.notCategory, what: `${name} 不能归到 ${exp.notCategory}，实际 ${r ? categoryOf(r) : '（无）'}` })
    if (exp.keeps?.length) {
      const said = squash(
        [d?.label, d?.content, d?.title, d?.note, ...((d?.people as string[]) ?? []), ...((d?.things as string[]) ?? []), ...((d?.places as string[]) ?? []), ...((d?.metrics as { item?: string; value: number }[]) ?? []).map((m) => `${m.item ?? ''}${m.value}`)]
          .filter(Boolean)
          .join(' '),
      )
      for (const w of exp.keeps) checks.push({ dim: 'value', ok: said.includes(squash(w)), what: `${name} 要留下「${w}」，实际「${said.slice(0, 60) || '（没找到这条）'}」` })
    }
    for (const [field, label] of [['people', '和谁'], ['things', '东西'], ['places', '地方']] as const) {
      for (const w of exp[field] ?? []) {
        const gotList = (d?.[field] as string[] | undefined) ?? []
        checks.push({ dim: 'value', ok: gotList.some((p) => p.includes(w) || w.includes(p)), what: `${name} ${label} 期望有「${w}」，实际 ${gotList.join('、') || '（无）'}` })
      }
    }
    for (const [key, metric] of [['spent', '花费'], ['earned', '收入']] as const) {
      const wantMoney = exp.money?.[key]
      if (wantMoney === undefined) continue
      const metrics = (d?.metrics as { name: string; value: number; unit: string }[] | undefined) ?? []
      const same = metrics.filter((m) => m.name === metric)
      const total = same.reduce((sum, m) => sum + m.value, 0)
      checks.push({ dim: 'value', ok: same.length > 0 && Math.abs(total - wantMoney) <= Math.max(1, wantMoney * 0.02), what: `${name} ${metric} 期望 ${wantMoney} 元，实际 ${metrics.map((m) => `${m.name} ${m.value}${m.unit}`).join('、') || '（无）'}` })
    }
    if (exp.money?.for !== undefined || exp.money?.flag !== undefined || exp.money?.flagNot !== undefined || exp.money?.pack !== undefined || exp.money?.kind !== undefined) skipped.push('钱的去向和分类')
    for (const f of NOT_PORTED_FIELDS) if (exp[f] !== undefined) skipped.push(f)
    // 要提醒、没说什么时候（问一句「想什么时候提醒你？」）是 M4 提醒的能力（能力对照表 6.6）：这一项不算
    if (exp.status === 'confirm' && exp.kind === 'todo' && c.tags?.includes('提醒')) skipped.push('没说时间的提醒')
    else if (exp.status) {
      const status = r?.question ? 'confirm' : 'ok'
      eq('value', '状态', exp.status, r ? status : undefined)
    }
    if (exp.mood) {
      const level = r?.data.kind === 'mood' ? r.data.level : undefined
      checks.push({ dim: 'value', ok: level !== undefined && exp.mood.includes(level), what: `${name} 心情 期望 ${exp.mood.join('/')}，实际 ${level ?? '（无）'}` })
    }
    for (const field of exp.absent ?? []) {
      const gotValue = d?.[field]
      checks.push({ dim: 'value', ok: r !== null && isAbsent(gotValue), what: `${name} 不能有 ${field}，实际 ${r ? JSON.stringify(gotValue) : '（没找到这条）'}` })
    }
    const moment = momentOf(r)
    for (const w of exp.momentContains ?? []) checks.push({ dim: 'value', ok: squash(moment).includes(squash(w)), what: `${name} 那一刻里要有「${w}」，实际「${moment || '（无）'}」` })
    for (const w of exp.momentNot ?? []) checks.push({ dim: 'value', ok: r !== null && !squash(moment).includes(squash(w)), what: `${name} 那一刻里不能有「${w}」，实际「${moment || '（无）'}」` })
    if (exp.energy) {
      const energy = d?.energy as number | undefined
      checks.push({ dim: 'value', ok: energy !== undefined && exp.energy.includes(energy), what: `${name} 精力 期望 ${exp.energy.join('/')}，实际 ${energy ?? '（无）'}` })
    }
    const emotions = (d?.emotions as string[] | undefined) ?? []
    if (exp.emotionsAny) checks.push({ dim: 'value', ok: exp.emotionsAny.some((w) => emotions.includes(w)), what: `${name} 情绪词 要有「${exp.emotionsAny.join('」或「')}」，实际 ${emotions.join('、') || '（无）'}` })
    for (const w of exp.emotionsNot ?? []) checks.push({ dim: 'value', ok: r !== null && !emotions.includes(w), what: `${name} 情绪词 不能有「${w}」，实际 ${emotions.join('、') || '（无）'}` })
  }
  if (c.expect.moodCount !== undefined) {
    const moods = actual.filter((r) => r.data.kind === 'mood' && !phone.existingIds.has(r.id))
    checks.push({ dim: 'value', ok: moods.length === c.expect.moodCount, what: `心情 期望正好 ${c.expect.moodCount} 条，实际 ${moods.length} 条` })
  }
  for (const g of c.expect.gone ?? []) {
    const still = actual.find((r) => r.data.kind === g.kind && categoryOk(g, r) && labelOk(g, r))
    checks.push({ dim: 'value', ok: !still, what: `应该删掉的 ${g.kind}「${g.label ?? ''}」${still ? '还在' : '删掉了'}` })
  }
  // 多记出来的（心情是推测，不算；可选的、预先放好的不算）
  const optional = c.expect.optional ?? []
  for (const r of actual) {
    if (matched.has(r.id) || r.data.kind === 'mood' || phone.existingIds.has(r.id)) continue
    if (optional.some((o) => o.kind === r.data.kind && categoryOk(o, r))) continue
    const label = r.data.kind === 'event' ? r.data.label : r.data.kind === 'insight' ? r.data.title : r.data.kind === 'todo' ? r.data.content : ''
    checks.push({ dim: 'category', ok: false, what: `多记了 ${r.data.kind}/${categoryOf(r)}「${label}」` })
  }
  return { checks, skipped: [...new Set(skipped)] }
}

// ───────────── 跑 ─────────────

const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, '').split('=') as [string, string]))
const file = JSON.parse(readFileSync(join(ROOT, 'evals', 'parse-cases.json'), 'utf8')) as { defaults: { now: string }; cases: Case[] }
let cases = file.cases
if (args.only) cases = cases.filter((c) => args.only!.split(',').includes(c.id))
if (args.tag) cases = cases.filter((c) => c.tags?.includes(args.tag!))
if (args.limit) cases = cases.slice(0, Number(args.limit))
const concurrency = Number(args.concurrency ?? 4)
const config = loadConfig()
if (!config.apiKey) {
  console.error('还没有密钥：gateway/.env 里要有 DEEPSEEK_API_KEY')
  process.exit(1)
}
const llm = createLlmClient(config)

/** 往回 n 分钟 */
const minus = (local: string, minutes: number) => new Date(Date.parse(`${local}:00Z`) - minutes * 60_000).toISOString().slice(0, 16)

async function runCase(c: Case) {
  const now = c.now ?? file.defaults.now
  const phone = new Phone(SEED_CATEGORIES)
  const today = logicalDayOf(now, 240)
  for (const e of c.existing ?? []) phone.seed(e, today, minus(now, 60))
  for (const h of c.history ?? []) for (const e of h.entries ?? []) phone.seed(e, logicalDayOf(h.at, 240), h.at)
  const turns = c.turns ?? []
  let tokens = { prompt: 0, hit: 0, out: 0 }
  const count = (change: ChangePackage) => {
    for (const s of change.steps) tokens = { prompt: tokens.prompt + (s.promptTokens ?? 0), hit: tokens.hit + (s.cacheHitTokens ?? 0), out: tokens.out + (s.completionTokens ?? 0) }
  }
  for (const [i, t] of turns.entries()) {
    const at = t.at ?? minus(now, turns.length - i)
    const bg = phone.background(t.text, at)
    const change = await understand(bg, { llm })
    count(change)
    phone.apply(bg, change)
  }
  const bg = phone.background(c.text, now)
  const started = Date.now()
  const change = await understand(bg, { llm })
  count(change)
  phone.apply(bg, change)
  // 评分按这部手机现在的类别表认领域（这段话里新建的也在）
  cats = phone.categories
  const { checks, skipped } = score(c, change.intents, phone)
  // 没全对的留下这一句的改动包和手机里最后的记录，看错在哪
  const failed = checks.some((x) => !x.ok)
  const detail = failed
    ? {
        change: { creates: change.creates, updates: change.updates, deletes: change.deletes, duplicates: change.duplicates, questions: change.questions, skipped: change.skipped },
        records: phone.alive().map((r) => ({ day: r.day, ...(r.question ? { question: r.question } : {}), data: r.data })),
      }
    : {}
  return { id: c.id, text: c.text, tags: c.tags ?? [], ms: Date.now() - started, checks, skipped, tokens, reply: change.reply, ...detail }
}

type Result = Awaited<ReturnType<typeof runCase>> | { id: string; text: string; tags: string[]; error: string }
const results: Result[] = []
let next = 0
await Promise.all(
  Array.from({ length: Math.min(concurrency, cases.length) }, async () => {
    while (next < cases.length) {
      const c = cases[next++]!
      try {
        const r = await runCase(c)
        results.push(r)
        const bad = r.checks.filter((x) => !x.ok)
        process.stdout.write(bad.length ? '×' : '.')
      } catch (err) {
        results.push({ id: c.id, text: c.text, tags: c.tags ?? [], error: (err as Error).message })
        process.stdout.write('!')
      }
    }
  }),
)
console.log()

// 汇总：每一项的准确率（检查条数），整条全对的比例，没搬的能力数出来
const ok = results.filter((r): r is Exclude<Result, { error: string }> => !('error' in r))
const dims: Dim[] = ['intent', 'category', 'time', 'value']
const summary = Object.fromEntries(
  dims.map((dim) => {
    const all = ok.flatMap((r) => r.checks.filter((x) => x.dim === dim))
    return [dim, { pass: all.filter((x) => x.ok).length, total: all.length }]
  }),
)
const perfect = ok.filter((r) => r.checks.every((x) => x.ok) && r.skipped.length === 0).length
const scorable = ok.filter((r) => r.skipped.length === 0).length
const skippedCount: Record<string, number> = {}
for (const r of ok) for (const s of r.skipped) skippedCount[s] = (skippedCount[s] ?? 0) + 1
const tokens = ok.reduce((t, r) => ({ prompt: t.prompt + r.tokens.prompt, hit: t.hit + r.tokens.hit, out: t.out + r.tokens.out }), { prompt: 0, hit: 0, out: 0 })
// DeepSeek Flash 的官方价（闲时，美元 / 百万）：命中缓存 0.003、没命中 0.15、输出 0.6（网页版 pricing.ts）
const usd = (tokens.hit * 0.003 + (tokens.prompt - tokens.hit) * 0.15 + tokens.out * 0.6) / 1_000_000

console.log(`用例 ${results.length} 条（出错 ${results.length - ok.length}）；能全算的 ${scorable} 条里全对 ${perfect} 条（${((perfect / Math.max(scorable, 1)) * 100).toFixed(1)}%）`)
for (const dim of dims) {
  const s = summary[dim]!
  console.log(`  ${{ intent: '意图', category: '类别', time: '时间', value: '数值' }[dim]}：${s.pass}/${s.total}（${((s.pass / Math.max(s.total, 1)) * 100).toFixed(1)}%）`)
}
const allChecks = ok.flatMap((r) => r.checks)
// 总体：全部检查项里对了多少（网页版评测报的「全量 99.93%」就是这个数）
console.log(`  总体：${allChecks.filter((x) => x.ok).length}/${allChecks.length}（${((allChecks.filter((x) => x.ok).length / Math.max(allChecks.length, 1)) * 100).toFixed(2)}%）`)
console.log(`  还没搬的能力（这些用例里的对应检查不算）：${Object.entries(skippedCount).map(([k, v]) => `${k} ${v} 条`).join('、') || '没有'}`)
console.log(`  花费约 ¥${(usd * 7.2).toFixed(2)}（输入 ${tokens.prompt}，命中缓存 ${tokens.hit}，输出 ${tokens.out}）`)
const failures = ok.filter((r) => r.checks.some((x) => !x.ok))
for (const r of failures.slice(0, Number(args.show ?? 40))) {
  console.log(`\n✗ ${r.id}「${r.text.slice(0, 40)}」`)
  for (const x of r.checks.filter((y) => !y.ok)) console.log(`    ${x.dim} · ${x.what}`)
}
for (const r of results.filter((x) => 'error' in x)) console.log(`\n! ${r.id}：${(r as { error: string }).error}`)

const dir = join(ROOT, 'evals', 'results')
mkdirSync(dir, { recursive: true })
const out = join(dir, `${new Date().toISOString().replace(/[:.]/g, '-')}.json`)
writeFileSync(out, JSON.stringify({ at: new Date().toISOString(), model: config.model, summary, perfect, scorable, skipped: skippedCount, usd, results }, null, 2))
console.log(`\n结果：${out}`)
