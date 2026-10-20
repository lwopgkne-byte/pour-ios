import { describe, expect, it } from 'vitest'
import type { DialogueTurn, ExistingRecord } from '../src/contract.ts'
import { aliases, describeDialogue } from '../src/describe.ts'
import { RESENT_REPLY } from '../src/quick.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage } from './sample.ts'

const scolded = (id: string): ExistingRecord => ({
  id,
  day: '2026-09-29',
  data: { kind: 'event', category: 'work', label: '被老板骂', metrics: [], people: [], things: [], places: [] },
})
const asked: DialogueTurn = {
  text: '删除被老板骂这个卡片',
  localTime: '2026-09-29T19:00',
  status: 'done',
  actions: [],
  questions: ['要删的是这两条「被老板骂」吗？'],
  undone: false,
  awaitingDelete: ['a', 'b'],
}

/** 这一句之前的对话是 dialogue；AI 没被问到时 llm.calls 是空的 */
async function reply(text: string, dialogue: DialogueTurn[], existing: ExistingRecord[] = [scolded('a'), scolded('b')], localTime = '2026-09-29T19:01') {
  const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items: [], reply: '' })
  const out = await understand(backgroundPackage(text, { existing, dialogue, localTime }), { llm })
  return { out, asked: llm.calls.length > 0 }
}

describe('上一句问了要不要删：简单的「对」「算了」由程序直接处理（网页版 answerAwaiting）', () => {
  it('「对」「删吧」：删问过的那几条，不问 AI', async () => {
    for (const text of ['对', '是的。', '删吧', '都删了吧']) {
      const { out, asked: ai } = await reply(text, [asked])
      expect(ai).toBe(false)
      expect(out.deletes.map((d) => d.id)).toEqual(['a', 'b'])
    }
  })

  it('「算了」「先别删」：不删', async () => {
    const { out, asked: ai } = await reply('算了', [asked])
    expect(ai).toBe(false)
    expect(out.deletes).toEqual([])
    expect(out.reply).toBe('好，不删了。')
  })

  it('问过之后已经没了的不再删；都没了就说一声', async () => {
    expect((await reply('对', [asked], [scolded('b')])).out.deletes.map((d) => d.id)).toEqual(['b'])
    expect((await reply('对', [asked], [])).out.reply).toBe('这几条已经不在了。')
  })

  it('别的回答（「不是，是看电影那个」）、问话不是最后一段、那段撤销了：照常问 AI', async () => {
    expect((await reply('不是，是看电影那个', [asked])).asked).toBe(true)
    const later: DialogueTurn = { ...asked, text: '跑了五公里', awaitingDelete: [], questions: [] }
    expect((await reply('对', [asked, later])).asked).toBe(true)
    expect((await reply('对', [{ ...asked, undone: true }])).asked).toBe(true)
  })

  it('AI 拿不准删哪条时先问：问的那几条放进改动包，对话里写给 AI 看「在等确认」', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', {
      items: [{ op: 'delete', entry_id: 1, span: '删除被老板骂', confidence: 0.5, question: '要删的是哪一条？' }],
      reply: '',
    })
    const out = await understand(backgroundPackage('删除被老板骂', { existing: [scolded('a'), scolded('b')] }), { llm })
    expect(out.deletes).toEqual([])
    expect(out.awaitingDelete).toEqual(['a'])
    const { aliasOf } = aliases([scolded('a'), scolded('b')])
    expect(describeDialogue([asked], aliasOf)).toContain('（在等用户确认要不要删：#1 #2）')
  })
})

describe('同一句话几分钟内又发了一遍（网页版 sameAsRecent）', () => {
  const sent: DialogueTurn = {
    text: '帮我增加几个待办 晚上先去见朋友',
    localTime: '2026-09-29T18:09',
    status: 'done',
    actions: [{ action: 'created', recordId: 'x', text: '待办：见朋友' }],
    questions: [],
    undone: false,
    awaitingDelete: [],
  }
  it('上一次记下了东西：不再整理一遍，说刚才已经记过（标点、空格不一样也算）', async () => {
    const { out, asked: ai } = await reply('帮我增加几个待办，晚上先去见朋友。', [sent], [], '2026-09-29T18:10')
    expect(ai).toBe(false)
    expect(out.intents).toEqual([])
    expect(out.reply).toBe(RESENT_REPLY)
    expect(out.replyByProgram).toBe(true)
  })

  it('过了 5 分钟、上一次撤销了、上一次没记下东西（删、改、问可以反复说）：照常整理', async () => {
    expect((await reply(sent.text, [sent], [], '2026-09-29T18:15')).asked).toBe(true)
    expect((await reply(sent.text, [{ ...sent, undone: true }], [], '2026-09-29T18:10')).asked).toBe(true)
    expect((await reply(sent.text, [{ ...sent, actions: [{ action: 'deleted', recordId: 'x', text: '' }] }], [], '2026-09-29T18:10')).asked).toBe(true)
  })
})
