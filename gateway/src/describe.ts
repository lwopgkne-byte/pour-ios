/**
 * 把背景包写成 Skill 要的那几段背景（照网页版 server/src/ai/steps.ts 的 describeExisting、describeCategories 等）。
 * 空的时候和网页版一样写「（没有）」「（还没有）」：AI 习惯这种写法，缓存也一样
 */
import type { BackgroundPackage, Category, ExistingRecord, RecordData } from './contract.ts'
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
  const line = (r: ExistingRecord, alias: number): string => {
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
        return `- #${alias} ${when(r.day)} 事件 [${d.category}] ${d.label}${time ? `（${time}）` : ''}${metrics ? ` ${metrics}` : ''}${tail}`
      }
      case 'insight':
        return `- #${alias} ${when(r.day)} 感悟「${d.title}」：${d.quote}${tail}`
      case 'todo':
        return `- #${alias} ${when(r.day)} 待办${d.done ? '（已完成）' : '（未完成）'}：${d.content}${d.due ? `，期限 ${d.due}` : ''}${tail}`
      case 'mood':
        return `- #${alias} ${when(r.day)} ${describeMoodForAi(d)}${tail}`
    }
  }
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

/** 类别表：上级在前、子类别缩进；带量法和同义词 */
export function describeCategories(cats: Category[]): string {
  const measure = (m: string) => (m === 'duration' ? '时长' : m === 'count' ? '次数' : m)
  const line = (c: Category, indent: string) =>
    `${indent}- \`${c.key}\` ${c.emoji} ${c.name}（${measure(c.measure)}${c.synonyms.length ? `；同义：${c.synonyms.join('、')}` : ''}）`
  const out: string[] = []
  for (const top of cats.filter((c) => !c.parent)) {
    out.push(line(top, ''))
    for (const child of cats.filter((c) => c.parent === top.key)) out.push(line(child, '  '))
  }
  return out.join('\n')
}

/** 两份 Skill 的全部背景变量 */
export function backgroundVars(bg: BackgroundPackage): Record<string, string> {
  const [date, clock] = bg.note.localTime.split('T') as [string, string]
  return {
    now: `${formatDayTitle(date)} ${clock}（${date}）`,
    today: `${bg.note.day}（${formatDayTitle(bg.note.day)}）`,
    recent_days: recentDaysTable(bg.note.day),
    boundary: hhmm(bg.dayBoundary),
    existing: describeExisting(bg.existing, bg.note.day),
    categories: describeCategories(bg.categories),
    // M2b 起手机会带上：对话、追问、个人词典、目标；「Pour 认识的你」更晚
    dialogue: '（没有）',
    pending_questions: '（没有）',
    dictionary: '（还没有）',
    about_me: '（还不知道）',
    goals: '（还没有目标）',
  }
}
