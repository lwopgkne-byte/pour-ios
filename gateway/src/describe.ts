/**
 * 把背景包写成 Skill 要的那几段背景（照网页版 server/src/ai/steps.ts 的 describeExisting、describeCategories 等）。
 * 空的时候和网页版一样写「（没有）」「（还没有）」：AI 习惯这种写法，缓存也一样
 */
import { DOMAIN_KEY_PREFIX, unusedDomains } from './categories.ts'
import type { BackgroundPackage, Category, DialogueTurn, ExistingRecord, RecordData } from './contract.ts'
import { type DateStr, diffDays, formatDayTitle, hhmm, recentDaysTable } from './dates.ts'
import { energyWord, moodWord } from './mood.ts'

const TONE_WORDS = { good: '好', neutral: '一般', bad: '不好', mixed: '又好又不好' } as const
const STRENGTH_WORDS = { weak: '弱', medium: '中', strong: '强' } as const

/** 给 AI 看的心情一行：「心情 挺好（好·中），精力 有点累，开心、放松（那一刻：…）」；没说精力就不写精力 */
export function describeMoodForAi(d: Extract<RecordData, { kind: 'mood' }>): string {
  const judged = d.tone ? `（${TONE_WORDS[d.tone]}·${STRENGTH_WORDS[d.strength ?? 'medium']}）` : ''
  return (
    [`心情 ${moodWord(d.level)}${judged}`, d.energy !== undefined ? `精力 ${energyWord(d.energy)}` : '', d.emotions.join('、')]
      .filter(Boolean)
      .join('，') + (d.moment ? `（那一刻：${d.moment}）` : '')
  )
}

/**
 * 已有的记录写成给 AI 看的简短列表，分成「今天的」和「前后几天的」：只有今天的才可能是同一件事又说了一遍。
 * 记录在手机上用很长的编号；给 AI 看的是从 1 开始的短编号（AI 回 entry_id 时用它，网关换回手机的编号）
 */
export function describeExisting(records: ExistingRecord[], today: DateStr): string {
  if (records.length === 0) return '（还没有记录）'
  const RELATIVE: Record<number, string> = { 0: '今天', [-1]: '昨天', [-2]: '前天', 1: '明天' }
  const when = (day: DateStr) => {
    const word = RELATIVE[diffDays(day, today)]
    return word ? `${day}（${word}）` : day
  }
  const line = (r: ExistingRecord, alias: number) => `- #${alias} ${when(r.day)} ${describeRecordLine(r)}`
  const numbered = records.map((r, i) => ({ r, alias: i + 1 }))
  const todays = numbered.filter(({ r }) => r.day === today)
  const others = numbered.filter(({ r }) => r.day !== today)
  return [
    `今天（${today}）的：`,
    ...(todays.length ? todays.map(({ r, alias }) => line(r, alias)) : ['（还没有）']),
    '',
    '前后几天的、还没做完的待办（不是今天的事：改、删、补充它们时用；今天又做了同类的事，照常新建）：',
    ...(others.length ? others.map(({ r, alias }) => line(r, alias)) : ['（没有）']),
  ].join('\n')
}

/** 一条记录写给 AI 看的一行（不带编号和日子）：「事件 [diet] 吃面（开始 2026-10-18 12:00） 花费 32元【待确认：…】」 */
export function describeRecordLine(r: ExistingRecord): string {
  const tail = r.question ? `【待确认：${r.question}】` : ''
  const d = r.data
  switch (d.kind) {
    case 'event': {
      const time = [
        d.start ? `开始 ${d.start.replace('T', ' ')}` : '',
        d.end ? `结束 ${d.end.replace('T', ' ')}` : '',
        d.durationMin ? `时长 ${d.durationMin} 分钟` : '',
      ]
        .filter(Boolean)
        .join('，')
      const metrics = d.metrics.map((m) => `${m.name} ${m.value}${m.unit}`).join('，')
      return `事件 [${d.category}] ${d.label}${time ? `（${time}）` : ''}${metrics ? ` ${metrics}` : ''}${tail}`
    }
    case 'insight':
      return `感悟「${d.title}」：${d.quote}${tail}`
    case 'todo':
      return `待办${d.done ? '（已完成）' : '（未完成）'}：${d.content}${d.due ? `，期限 ${d.due}` : ''}${tail}`
    case 'mood':
      return `${describeMoodForAi(d)}${tail}`
  }
}

/** 还没用过的领域在类别表里列几个说法就够（全列出来很长，又每次都要发） */
const UNUSED_DOMAIN_SYNONYMS = 4

/**
 * 类别表：上级在前、子类别缩进；带量法和同义词。再列出还没用过的常见领域（key 是 `domain:育儿`，网页版 describeCategories）：
 * AI 只能从表里挑，不列出来它就把带孩子的事塞进沾边的已有类别
 */
export function describeCategories(cats: Category[]): string {
  const measure = (m: string) => (m === 'duration' ? '时长' : m === 'count' ? '次数' : m)
  const line = (c: Category, indent: string) =>
    `${indent}- \`${c.key}\` ${c.emoji} ${c.name}（${measure(c.measure)}${c.synonyms.length ? `；同义：${c.synonyms.join('、')}` : ''}）`
  const out: string[] = []
  for (const top of cats.filter((c) => !c.parent)) {
    out.push(line(top, ''))
    for (const child of cats.filter((c) => c.parent === top.key)) out.push(line(child, '  '))
  }
  const unused = unusedDomains(cats)
  if (unused.length) {
    out.push('', '还没用过的常见领域（属于哪个就直接用它的 key，程序会自动建上，不用写 new_category）：')
    for (const d of unused) {
      const words = (d.synonyms ?? []).slice(0, UNUSED_DOMAIN_SYNONYMS)
      out.push(`- \`${DOMAIN_KEY_PREFIX}${d.name}\` ${d.emoji} ${d.name}（${measure(d.measure ?? 'count')}${words.length ? `；同义：${words.join('、')}……` : ''}）`)
    }
  }
  return out.join('\n')
}

const ACTION_WORDS = {
  created: '记下',
  updated: '修改',
  duplicate: '之前已记过',
  completed: '标为完成',
  confirmed: '确认',
  deleted: '删掉',
} as const

/**
 * 最近的对话写给 AI 看（照网页版 dialogue.ts）：刚才你说了什么、Pour 记下了哪几条（带短编号）、问了什么还在等回答。
 * 回答「是的」「刚才那个」「改成明天」时，AI 才知道指的是哪条
 */
export function describeDialogue(turns: DialogueTurn[], aliasOf: (id: string) => number | undefined): string {
  if (turns.length === 0) return '（没有）'
  const lines: string[] = []
  turns.forEach((t, i) => {
    lines.push(`- 用户（${t.localTime.slice(11)}）：${t.text}`)
    if (t.status !== 'done') {
      lines.push(`  Pour：${t.status === 'pending' ? '（还没整理）' : '（没有结果）'}`)
      return
    }
    if (t.undone) lines.push('  Pour：（这段话整理出的记录已经被撤销）')
    for (const a of t.actions) {
      const alias = aliasOf(a.recordId)
      lines.push(`  Pour：${ACTION_WORDS[a.action]}${alias ? ` #${alias}` : ''} ${a.text}`)
    }
    if (t.reply) lines.push(`  Pour：${t.reply}`)
    for (const q of t.questions) lines.push(`  Pour 问：${q}`)
    // 最近一段里 Pour 问了问题：你这一句多半是在回答它
    if (i === turns.length - 1 && t.questions.length > 0) lines.push('  （Pour 在等用户回答上面这个问题：用户这一句多半就是回答）')
  })
  return lines.join('\n')
}

/** 还在等你回答的追问：今天的记录里拿不准的那几条（照网页版 describePendingQuestions） */
export function describePendingQuestions(records: ExistingRecord[], today: DateStr, aliasOf: (id: string) => number | undefined): string {
  const waiting = records.filter((r) => r.day === today && r.question)
  if (waiting.length === 0) return '（没有）'
  return waiting.map((r) => `- 关于记录 #${aliasOf(r.id) ?? '?'}：${r.question}`).join('\n')
}

/** 已有记录的短编号：背景包里的顺序，从 1 开始（describeExisting 用同一套） */
export function aliases(records: ExistingRecord[]): { aliasOf: (id: string) => number | undefined; recordOf: (alias: number) => ExistingRecord | undefined } {
  const byId = new Map(records.map((r, i) => [r.id, i + 1]))
  return { aliasOf: (id) => byId.get(id), recordOf: (alias) => records[alias - 1] }
}

/** 两份 Skill 的全部背景变量 */
export function backgroundVars(bg: BackgroundPackage): Record<string, string> {
  const [date, clock] = bg.note.localTime.split('T') as [string, string]
  const { aliasOf } = aliases(bg.existing)
  return {
    now: `${formatDayTitle(date)} ${clock}（${date}）`,
    today: `${bg.note.day}（${formatDayTitle(bg.note.day)}）`,
    recent_days: recentDaysTable(bg.note.day),
    boundary: hhmm(bg.dayBoundary),
    existing: describeExisting(bg.existing, bg.note.day),
    categories: describeCategories(bg.categories),
    dialogue: describeDialogue(bg.dialogue, aliasOf),
    pending_questions: describePendingQuestions(bg.existing, bg.note.day, aliasOf),
    // 个人词典、目标、「Pour 认识的你」以后再带上
    dictionary: '（还没有）',
    about_me: '（还不知道）',
    goals: '（还没有目标）',
  }
}
