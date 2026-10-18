/** 契约文件的内容：两份 JSON Schema、一对样例（一段话的背景包和它的改动包，用假大模型算出来，每次都一样） */
import { z } from 'zod'
import { BackgroundPackage, CONTRACT_VERSION, ChangePackage } from '../src/contract.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from '../test/fake-llm.ts'
import { backgroundPackage } from '../test/sample.ts'

const json = (value: unknown) => `${JSON.stringify(value, null, 2)}\n`

export const EXAMPLE_TEXT = '早上跑了五公里 中午和小王吃面三十二 房租交了'

export async function contractFiles(): Promise<Record<string, string>> {
  const bg = BackgroundPackage.parse({
    ...backgroundPackage(EXAMPLE_TEXT, { id: '0B6F3C2E-6B1D-4C8A-9E55-3A7D2F1C9B10', localTime: '2026-10-18T12:40', day: '2026-10-18' }),
    existing: [
      {
        id: '5A0E1D7C-2B44-4F0B-8C1E-9D3B6A2F4E01',
        day: '2026-10-18',
        data: { kind: 'event', category: 'sleep', label: '睡眠', start: '2026-10-17T23:30', end: '2026-10-18T07:10', durationMin: 460, metrics: [], people: [], things: [], places: [] },
      },
      {
        id: '7C2D9E4B-1A3F-4E6D-8B5C-0F9A2D7E3C02',
        day: '2026-10-17',
        data: { kind: 'todo', content: '交房租', due: '2026-10-19', done: false, people: [], things: [], places: [] },
        question: '是这个月的房租吗？',
      },
    ],
    dialogue: [
      {
        text: '明天交房租',
        localTime: '2026-10-17T21:05',
        status: 'done',
        actions: [{ action: 'created', recordId: '7C2D9E4B-1A3F-4E6D-8B5C-0F9A2D7E3C02', text: '待办：交房租' }],
        questions: ['是这个月的房租吗？'],
        undone: false,
      },
    ],
  })
  const llm = new FakeLlm().on('router', recordIntent(EXAMPLE_TEXT)).on('parse-note', {
    items: [
      { op: 'create', kind: 'event', category: 'run', label: '跑步', date: 'today', start: null, end: null, duration_min: null, metrics: [{ name: '距离', value: 5, unit: '公里' }], span: '早上跑了五公里', confidence: 0.95 },
      { op: 'create', kind: 'event', category: 'diet', label: '吃面', date: 'today', start: '12:00', metrics: [{ name: '花费', value: 32, unit: '元', item: '面' }], people: ['小王'], span: '中午和小王吃面三十二', confidence: 0.9 },
      { op: 'create', kind: 'mood', tone: 'good', strength: 'weak', emotions: ['满足'], span: '', confidence: 0.5 },
      { op: 'create', kind: 'todo', content: '还小王饭钱', due: 'tomorrow', people: ['小王'], span: '', confidence: 0.6, question: '要记一条还小王饭钱的待办吗？' },
      { op: 'complete_todo', entry_id: 2, span: '房租交了' },
    ],
    reply: '',
  })
  const raw = ChangePackage.parse(await understand(bg, { llm }))
  // 每一步用了多久、谁先回来每次不一样：样例里定成 0、按步骤排好
  const change = { ...raw, steps: raw.steps.map((s) => ({ ...s, durationMs: 0 })).sort((a, b) => a.step.localeCompare(b.step)) }
  return {
    [`background-package.v${CONTRACT_VERSION}.schema.json`]: json(z.toJSONSchema(BackgroundPackage, { io: 'input' })),
    [`change-package.v${CONTRACT_VERSION}.schema.json`]: json(z.toJSONSchema(ChangePackage, { io: 'output' })),
    'example-background-package.json': json(bg),
    'example-change-package.json': json(change),
  }
}
