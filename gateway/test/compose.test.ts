import { describe, expect, it } from 'vitest'
import { DISTRESS_REPLY } from '../src/mood.ts'
import { NOTHING_TO_RECORD, NO_ANSWER_YET, WHICH_ONE, understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage, run } from './sample.ts'

/** 意图是 intents，整理出 items、顺口回 reply */
async function say(text: string, intents: { type: string; text: string }[], items: object[], reply = '') {
  const llm = new FakeLlm().on('router', { intents, reply: '' }).on('parse-note', { items, reply })
  return understand(backgroundPackage(text), { llm })
}

describe('给你的那句话（照网页版 composeStep）', () => {
  it('回复里不出现内部编号；替系统做承诺的回复不显示', async () => {
    const ai = await say('跑步', recordIntent('跑步').intents, [run], '跑步记在 #3 下面了。')
    expect(ai.reply).toBe('跑步记在下面了。')
    expect(ai.replyByProgram).toBe(false)
    expect((await say('跑步', recordIntent('跑步').intents, [run], '到时候会提醒你')).reply).toBe('')
  })

  it('回复里问的话变成追问（下一句就知道是在回答它）', async () => {
    const out = await say('删掉', [{ type: 'correction', text: '删掉' }], [], '要删哪条？说个内容。')
    expect(out.reply).toBe('')
    expect(out.questions).toEqual(['要删哪条？说个内容。'])
  })

  it('什么都没发生要说明白：要改却没找到是哪条就问；要记的都记过了就说一声；只是提问照实说问答还没做', async () => {
    expect((await say('删掉那条', [{ type: 'correction', text: '删掉那条' }], [])).questions).toEqual([WHICH_ONE])
    const nothing = await say('跑步', recordIntent('跑步').intents, [])
    expect(nothing.reply).toBe(NOTHING_TO_RECORD)
    // 程序写的话手机不标「AI」
    expect(nothing.replyByProgram).toBe(true)
    expect((await say('这周跑了几次', [{ type: 'question', text: '这周跑了几次' }], [])).reply).toBe(NO_ANSWER_YET)
  })

  it('很难受的时候：程序写的那句，不追问', async () => {
    const mood = { op: 'create', kind: 'mood', tone: 'bad', strength: 'strong', distress: true, emotions: [], span: '', confidence: 0.9 }
    const out = await say('不想活了', recordIntent('不想活了').intents, [mood], '要不要说说？')
    expect(out.reply).toBe(DISTRESS_REPLY)
    expect(out.replyByProgram).toBe(true)
    expect(out.questions).toEqual([])
  })
})
