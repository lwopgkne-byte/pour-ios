import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { ROOT } from '../src/env.ts'
import { contractFiles } from '../scripts/contract-files.ts'

describe('接口契约的文件', () => {
  it('gateway/contract/ 是最新的（改了契约要跑 npm run contract，手机那边的测试用同一份样例）', async () => {
    for (const [name, text] of Object.entries(await contractFiles())) {
      expect(readFileSync(join(ROOT, 'contract', name), 'utf8'), `contract/${name}`).toBe(text)
    }
  })

  it('样例：低把握的待办要确认，心情不问，吃面认出人和钱', async () => {
    const change = JSON.parse((await contractFiles())['example-change-package.json']!)
    expect(change.creates.map((c: { question?: string }) => c.question ?? null)).toEqual([null, null, null, '要记一条还小王饭钱的待办吗？'])
    expect(change.creates[1].data).toMatchObject({ people: ['小王'], metrics: [{ value: 32 }], start: '2026-10-18T12:00' })
  })
})
