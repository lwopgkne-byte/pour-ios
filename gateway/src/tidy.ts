/**
 * 存事件之前程序整理一遍（照网页版 shared/src/tidy.ts、health.ts；docs/prd-daily.md 8.3）：不交给 AI 每次写对。
 * - 钱：AI 写成「人均」「流水」「稿费」「金额」……统一认成「花费」或「收入」，单位写「元」，原来的名目留在 item
 * - 合计和拆分只算合计（「营业额2350 微信1800 现金550」是 2350）；清单里一行一个价钱、AI 加成了总数的拆回每一样
 * - 血压统一成「收缩压」「舒张压」（mmHg）
 * - 名称里提到、AI 漏写的常见称呼补进「和谁」
 * 钱的去向（报销、借出、退款……）、值不值、人情往来以后搬
 */
import type { Metric, RecordData } from './contract.ts'
import { spokenNumbers } from './numbers.ts'

type EventData = Extract<RecordData, { kind: 'event' }>

const squash = (s: string) => s.replace(/[#＃\s]/g, '')
const has = (s: string, words: string[]) => words.some((w) => s.includes(w))

/* ───────────── 人 ───────────── */

/**
 * 常见的称呼（家人、朋友、工作上的人）：名称里出现、AI 漏写进「和谁」时由程序补上（「跟供应商吵架」常常漏掉供应商）。
 * 只收两个字以上的：「妈」「娃」单字容易误认。长的在前，「老同学」先于「同学」认
 */
const PEOPLE_WORDS = [
  '老同学', '老朋友', '老板娘', '大学室友', '供应商', '合作方', '小舅子',
  '老公', '老婆', '爱人', '丈夫', '妻子', '媳妇', '对象', '男友', '女友', '男朋友', '女朋友',
  '儿子', '女儿', '孩子', '宝宝', '大宝', '小宝', '二宝',
  '爸爸', '妈妈', '爸妈', '父母', '爷爷', '奶奶', '外公', '外婆', '姥姥', '姥爷', '公公', '婆婆', '岳父', '岳母', '老伴',
  '孙子', '孙女', '外孙', '外孙女', '哥哥', '姐姐', '弟弟', '妹妹', '表哥', '表姐', '表弟', '表妹', '堂哥', '堂姐',
  '朋友', '同学', '室友', '闺蜜', '兄弟', '邻居', '同事', '领导', '老板', '上司', '下属', '客户', '甲方', '员工', '房东', '老师', '医生',
].sort((a, b) => b.length - a.length)

/** 名称里提到的常见称呼（「跟供应商吵架」→ 供应商；「陪老同学吃饭」→ 老同学，不再另算同学） */
export function peopleInText(text: string): string[] {
  const out: string[] = []
  let rest = text
  for (const w of PEOPLE_WORDS) {
    if (!rest.includes(w)) continue
    out.push(w)
    rest = rest.split(w).join('　')
  }
  return out
}

/** 和谁：AI 写的照留，名称里提到、AI 漏写的常见称呼补上（已经写了更具体的就不补：写了「同事小王」不再补「同事」） */
export function withPeopleFromLabel(people: string[], label: string): string[] {
  const add = peopleInText(label).filter((w) => !people.some((p) => p.includes(w) || w.includes(p)))
  return [...people, ...add]
}

/* ───────────── 钱 ───────────── */

/** 一定是钱的单位 */
const MONEY_UNITS = ['元', '块钱', '¥', '￥', '人民币', 'rmb', 'RMB']
/** 「块」既是钱（二十块）也是量词（两块鸡胸肉）：名字也说的是钱才算 */
const MAYBE_MONEY_UNITS = ['块']
/** 说的是钱、但分不出进出的名字 */
const MONEY_NAMES = ['金额', '钱', '价', '账']
const INCOME_NAMES = ['收入', '进账', '到账', '入账', '稿费', '工资', '薪水', '薪资', '奖金', '提成', '分红', '流水', '营业额', '营收', '销售额', '收款', '赚了', '赚', '佣金', '打赏', '回款', '返现', '利息', '报销', '退款']
const SPEND_NAMES = ['花费', '花了', '花销', '消费', '支出', '开销', '人均', '费用', '价格', '价钱', '房租', '租金', '门票', '罚款', '押金', '定金', '订金', '首付', '月供', '房贷', '车贷']
/** 名字说不清进出（「金额」）时，看这条记录的名称 */
const INCOME_LABEL = ['到账', '打款', '收到', '收入', '进账', '卖', '赚', '工资', '稿费', '奖金', '营业额', '流水']
const SPEND_LABEL = ['买', '花', '交', '付', '缴', '充', '租', '费', '拿货', '进货']
/** 这些领域里的钱，说不清的都是花出去的 */
const SPEND_ROOTS = ['饮食', '购物', '出行', '宠物', '育儿', '健康', '办事', '娱乐', '兴趣', '家务']

export interface MoneyContext {
  label: string
  /** 顶级类别的名称 */
  rootName?: string
}

/** 一个数量是进还是出：收入、花费，认不出就 null（宁可少算，不能算错） */
function moneyKind(m: Metric, ctx: MoneyContext): '收入' | '花费' | null {
  const name = squash(m.name)
  if (has(name, INCOME_NAMES)) return '收入'
  if (has(name, SPEND_NAMES) || name.endsWith('费')) return '花费'
  if (has(ctx.label, INCOME_LABEL)) return '收入'
  if ((ctx.rootName && SPEND_ROOTS.includes(ctx.rootName)) || has(ctx.label, SPEND_LABEL)) return '花费'
  return null
}

/** 这个数量是不是钱 */
export function isMoney(m: Metric): boolean {
  const unit = m.unit.trim()
  if (MONEY_UNITS.includes(unit)) return true
  if (!MAYBE_MONEY_UNITS.includes(unit)) return false
  const name = squash(m.name)
  return has(name, INCOME_NAMES) || has(name, SPEND_NAMES) || name.endsWith('费') || has(name, MONEY_NAMES)
}

/** 本来就只是说钱、说不出名目的名字（「人均」「单价」说的是怎么算的，也不是名目） */
const GENERIC_MONEY = /^(花费|花了|花销|消费|支出|开销|费用|金额|钱|价格|价钱|价|收入|进账|到账|入账|收款|赚了|赚|账|总额|总计|合计|一共|共|总共|人均|每人|单价|均价)$/

/** 名目：「菜钱」→ 菜，「打赏收入」→ 打赏；本来就是泛称的、和记录名称一样的，没有名目 */
function itemOf(name: string, label: string): string | undefined {
  const n = squash(name)
  if (GENERIC_MONEY.test(n)) return undefined
  const item = n.replace(/(的)?(钱|收入|花费|支出|金额)$/, '') || n
  return label.includes(item) ? undefined : item
}

/**
 * 统一钱的名字：单位是钱的数量，单位写「元」，名字认成「花费」或「收入」，原来的名目留在 item；认不出的名字不动。
 * 不是钱的数量原样返回。再统一一遍结果不变；给谁、谁给的照样留着
 */
export function normalizeMoney(metrics: Metric[], ctx: MoneyContext): Metric[] {
  return metrics.map((m) => {
    if (!isMoney(m)) return m
    const extra = { ...(m.for?.trim() ? { for: m.for.trim() } : {}), ...(m.from?.trim() ? { from: m.from.trim() } : {}) }
    const kind = moneyKind(m, ctx)
    if (!kind) return { name: m.name, value: m.value, unit: '元', ...(m.item ? { item: m.item } : {}), ...extra }
    const item = m.item ?? itemOf(m.name, ctx.label)
    return { name: kind, value: m.value, unit: '元', ...(item ? { item } : {}), ...extra }
  })
}

const sum = (xs: Metric[]) => xs.reduce((s, m) => s + m.value, 0)

/** 说的是一笔钱怎么拆开的（「微信1800 现金550」「其中」「一共」） */
const BREAKDOWN = /其中|微信|支付宝|现金|刷卡|扫码|银行卡|分别|一共|总共|合计|共计|总计|总额/

/**
 * 合计和拆分只算合计（「营业额2350 微信1800 现金550」是 2350，不是 4700）：同一条记录里同是收入（或同是花费）的钱，
 * 有一笔正好等于另外几笔加起来、原话又说了是拆分，另外几笔就是拆分，不再算一遍。
 * 没说是拆分的照算（「菜钱1000 肉1000 米2000」就是 4000）。parts 是拆出来的，写进备注
 */
export function foldBreakdown(metrics: Metric[], text: string): { metrics: Metric[]; parts: Metric[] } {
  if (!BREAKDOWN.test(squash(text))) return { metrics, parts: [] }
  let kept = metrics
  const parts: Metric[] = []
  for (const kind of ['收入', '花费']) {
    const same = kept.filter((m) => m.name === kind && m.unit === '元')
    if (same.length < 3) continue
    const total = same.find((t) => Math.abs(t.value - sum(same.filter((x) => x !== t))) < 0.005)
    if (!total) continue
    const split = same.filter((x) => x !== total)
    parts.push(...split)
    kept = kept.filter((m) => !split.includes(m))
  }
  return { metrics: kept, parts }
}

/** ¥8,000 · ¥12.5（千位分隔，最多两位小数） */
export const formatYuan = (n: number) => `¥${n.toLocaleString('en-US', { maximumFractionDigits: 2 })}`

/** 一个数量怎么写（备注里「其中 微信 ¥1,800」）：钱写名目和 ¥，别的「5 公里」 */
export function formatMetric(m: Metric): string {
  if (isMoney(m)) return `${m.item ? `${m.item} ` : ''}${formatYuan(m.value)}`
  return `${Number.isInteger(m.value) ? m.value : Math.round(m.value * 100) / 100} ${m.unit}`.trim()
}

/** 清单里的一行：开头是名称，结尾是价钱（「奶瓶 贝亲 55」「• 奶瓶：贝亲玻璃160ml｜48元」） */
const LISTED_LINE = /^\s*(?:[•·\-*]|\d+[.、)])?\s*([^\s：:｜|，,\d][^\s：:｜|，,]*?)[\s：:｜|，,].*?(\d+(?:\.\d+)?)\s*(?:元|块|￥|¥)?\s*$/

/** 一行一个价钱的清单（两行以上才算）：每行的名称和价钱 */
export function listedPrices(text: string): { item: string; value: number }[] {
  const out: { item: string; value: number }[] = []
  for (const line of text.split(/\r?\n/)) {
    const m = LISTED_LINE.exec(line)
    if (m) out.push({ item: m[1]!, value: Number(m[2]) })
  }
  return out.length >= 2 ? out : []
}

/**
 * 清单里一行一个价钱，AI 却加成了一个（或几个）总数：每一样的名目就丢了。
 * 程序照原话按行拆回来——只在 AI 记的钱加起来正好等于每行加起来时拆，对不上就不动
 */
export function splitListed(metrics: Metric[], text: string): Metric[] {
  const listed = listedPrices(text)
  const money = metrics.filter((m) => m.unit === '元' && (m.name === '花费' || m.name === '收入'))
  if (listed.length < 2 || money.length === 0 || money.length >= listed.length) return metrics
  const kind = money[0]!.name
  if (money.some((m) => m.name !== kind) || Math.abs(sum(money) - listed.reduce((s, l) => s + l.value, 0)) > 0.005) return metrics
  return [...metrics.filter((m) => !money.includes(m)), ...listed.map((l) => ({ name: kind, value: l.value, unit: '元', item: l.item }))]
}

/* ───────────── 血压 ───────────── */

const plausible = (hi: number, lo: number) => hi >= 60 && hi <= 260 && lo >= 30 && lo <= 180 && hi > lo

/** 原话里说的血压：「血压135/88」「量血压一百三十五八十八」「高压135低压88」「收缩压 135 舒张压 88」 */
export function bloodPressureIn(text: string): { systolic: number; diastolic: number } | null {
  const t = text.replace(/\s/g, '')
  const hi = /(?:高压|收缩压)[:：是有]?([\d零〇一二两三四五六七八九十百]+)/.exec(t)
  const lo = /(?:低压|舒张压)[:：是有]?([\d零〇一二两三四五六七八九十百]+)/.exec(t)
  if (hi && lo) {
    const [a] = spokenNumbers(hi[1]!)
    const [b] = spokenNumbers(lo[1]!)
    if (a !== undefined && b !== undefined && plausible(a, b)) return { systolic: a, diastolic: b }
  }
  const at = t.indexOf('血压')
  if (at < 0) return null
  const [a, b] = spokenNumbers(t.slice(at + 2, at + 2 + 24))
  return a !== undefined && b !== undefined && plausible(a, b) ? { systolic: a, diastolic: b } : null
}

/** 说的是血压的数（名字或单位） */
const isPressure = (m: Metric) => /血压|收缩压|舒张压|高压|低压/.test(m.name) || /mmHg|毫米汞柱/i.test(m.unit)

/**
 * 血压统一写成「收缩压」「舒张压」（mmHg）：原话里认得出两个数就照原话（AI 漏了、写错了都改过来）；
 * 认不出时只统一 AI 写的名字（高压 → 收缩压，低压 → 舒张压，和舒张压一起出现的「血压」→ 收缩压）
 */
export function normalizeHealth(metrics: Metric[], text = ''): Metric[] {
  const said = bloodPressureIn(text)
  if (said) {
    return [
      ...metrics.filter((m) => !isPressure(m)),
      { name: '收缩压', value: said.systolic, unit: 'mmHg' },
      { name: '舒张压', value: said.diastolic, unit: 'mmHg' },
    ]
  }
  const paired = metrics.some((m) => /舒张压|低压/.test(m.name))
  return metrics.map((m) => {
    if (!isPressure(m)) return m
    const name = /低压|舒张压/.test(m.name) ? '舒张压' : /高压|收缩压/.test(m.name) || (paired && /血压/.test(m.name)) ? '收缩压' : m.name
    return { ...m, name, unit: 'mmHg' }
  })
}

/* ───────────── 一条事件 ───────────── */

/**
 * 存事件之前整理一遍（网页版 tidyEvent）：身体的数字、钱的名字、清单拆回每一样、合计和拆分只算合计（拆分写进备注）、
 * 名称里的称呼补进「和谁」
 */
export function tidyEvent(data: EventData, opts: { rootName?: string; span?: string; noteText?: string }): EventData {
  const normalized = normalizeMoney(normalizeHealth(data.metrics, opts.span ?? ''), { label: data.label, ...(opts.rootName ? { rootName: opts.rootName } : {}) })
  const listed = opts.noteText ? splitListed(normalized, opts.noteText) : normalized
  const { metrics, parts } = opts.span ? foldBreakdown(listed, opts.span) : { metrics: listed, parts: [] }
  const note = parts.length ? [data.note, `其中 ${parts.map(formatMetric).join('、')}`].filter(Boolean).join('；') : data.note
  const { note: _note, ...rest } = data
  return { ...rest, metrics, ...(note ? { note } : {}), people: withPeopleFromLabel(data.people, data.label) }
}
