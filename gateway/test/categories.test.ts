import { describe, expect, it } from 'vitest'
import { CategoryBook, findSimilarCategory, isCookingLabel, lifeDomainOf, resolveEventCategory } from '../src/categories.ts'
import type { ExistingRecord } from '../src/contract.ts'
import { describeCategories } from '../src/describe.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { SEED_CATEGORIES, backgroundPackage } from './sample.ts'

const event = (over: object) => ({ op: 'create', kind: 'event', category: 'other', label: '', date: 'today', span: '', confidence: 0.95, ...over })

async function organize(items: object[], existing: ExistingRecord[] = []) {
  const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', { items, reply: '' })
  return understand(backgroundPackage('一段话', { existing }), { llm })
}

describe('类别和生活领域（照网页版 categories.ts）', () => {
  it('同义词：「慢跑」找到跑步，「走路」找到运动', () => {
    expect(findSimilarCategory('慢跑', SEED_CATEGORIES)?.key).toBe('run')
    expect(findSimilarCategory('走路', SEED_CATEGORIES)?.key).toBe('exercise')
    expect(lifeDomainOf(['陪孩子']))?.toMatchObject({ name: '育儿' })
    expect(isCookingLabel('做午饭')).toBe(true)
    expect(isCookingLabel('吃自己做的饭')).toBe(false)
  })

  it('AI 放进了「其他」：按名称认出生活领域，没有就建上（带上颜色），记录用新类别', async () => {
    const out = await organize([event({ label: '带娃去公园' })])
    expect(out.newCategories).toHaveLength(1)
    expect(out.newCategories[0]).toMatchObject({ name: '育儿', color: 'pink', parent: null })
    expect(out.creates[0]!.data).toMatchObject({ category: out.newCategories[0]!.key })
  })

  it('AI 直接选了还没用过的领域（domain:健康）：由程序建上；同一段话里第二次用到不再建', async () => {
    const out = await organize([event({ category: 'domain:健康', label: '吃降压药' }), event({ category: 'domain:健康', label: '量血压' })])
    expect(out.newCategories.map((c) => c.name)).toEqual(['健康'])
    expect(out.creates.map((c) => (c.data.kind === 'event' ? c.data.category : ''))).toEqual([out.newCategories[0]!.key, out.newCategories[0]!.key])
  })

  it('AI 提议新活动：和已有类别相近就用它；认得出领域就用领域；都不是才新建（颜色是网页版的九种标签色）', async () => {
    const similar = await organize([event({ label: '晨跑', new_category: { name: '晨跑', emoji: '🏃', color: 'green' } })])
    expect(similar.newCategories).toEqual([])
    expect(similar.creates[0]!.data).toMatchObject({ category: 'run' })
    const fresh = await organize([event({ label: '冥想', new_category: { name: '冥想', emoji: '🧘', color: 'purple', measure: 'duration', synonyms: ['打坐'] } })])
    expect(fresh.newCategories[0]).toMatchObject({ name: '冥想', color: 'purple', synonyms: ['打坐'] })
    expect(fresh.newCategories[0]!.key).toMatch(/^c-[0-9a-f]{8}$/)
  })

  it('买的东西看用途：买奶粉是育儿（不留一个空的购物）；买补光灯是购物；做饭是家务', async () => {
    const milk = await organize([event({ label: '买奶粉', new_category: { name: '购物', emoji: '🛒', color: 'orange' } })])
    expect(milk.newCategories.map((c) => c.name)).toEqual(['育儿'])
    const lamp = await organize([event({ label: '买补光灯' })])
    expect(lamp.newCategories.map((c) => c.name)).toEqual(['购物'])
    const cook = await organize([event({ category: 'diet', label: '做午饭' })])
    expect(cook.newCategories.map((c) => c.name)).toEqual(['家务'])
  })

  it('新建了领域：背景里落在「其他」的旧记录对得上的归进来', async () => {
    const dog: ExistingRecord = { id: 'dog', day: '2026-09-24', data: { kind: 'event', category: 'other', label: '遛狗', metrics: [], people: [], things: [], places: [] } }
    const out = await organize([event({ category: 'domain:宠物', label: '喂猫' })], [dog])
    const pets = out.newCategories[0]!
    expect(pets.name).toBe('宠物')
    expect(out.updates).toEqual([expect.objectContaining({ id: 'dog', action: 'updated', data: expect.objectContaining({ category: pets.key }) })])
  })

  it('背景里给 AI 列出还没用过的常见领域（key 写成 domain:育儿）', () => {
    const text = describeCategories(SEED_CATEGORIES)
    expect(text).toContain('`domain:育儿` 🍼 育儿（次数；同义：带娃、带孩子、陪孩子、陪娃……）')
    const book = new CategoryBook(SEED_CATEGORIES)
    resolveEventCategory({ category: 'domain:育儿', label: '哄睡' }, book)
    expect(describeCategories(book.all)).not.toContain('`domain:育儿`')
  })
})
