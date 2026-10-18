import { describe, expect, it } from 'vitest'
import { bloodPressureIn, foldBreakdown, formatMetric, formatYuan, listedPrices, normalizeHealth, normalizeMoney, peopleInText, splitListed, withPeopleFromLabel } from '../src/tidy.ts'
import { understand } from '../src/understand.ts'
import { FakeLlm, recordIntent } from './fake-llm.ts'
import { backgroundPackage } from './sample.ts'

const yuan = (name: string, value: number, unit = '元') => ({ name, value, unit })

describe('钱的名字由程序统一（照网页版 tidy.test.ts）', () => {
  it('不是钱的数量不动；「块」是量词时不是钱（「两块鸡胸肉」）', () => {
    expect(normalizeMoney([yuan('距离', 5, '公里')], { label: '跑步' })).toEqual([yuan('距离', 5, '公里')])
    const meat = [yuan('鸡胸肉', 2, '块'), yuan('鸡蛋', 3, '个')]
    expect(normalizeMoney(meat, { label: '吃鸡蛋和鸡胸肉', rootName: '饮食' })).toEqual(meat)
  })

  it('「块」的名字说的是钱才算钱；单位统一写「元」', () => {
    expect(normalizeMoney([yuan('花费', 20, '块')], { label: '午饭' })).toEqual([yuan('花费', 20)])
    expect(normalizeMoney([yuan('金额', 50, '块')], { label: '买菜' })).toEqual([yuan('花费', 50)])
    expect(normalizeMoney([yuan('花费', 28, '块钱'), yuan('花费', 3, '¥')], { label: '午饭' }).map((m) => m.unit)).toEqual(['元', '元'])
  })

  it('「人均」「门票」、以「费」结尾的算花费；「流水」「稿费」「工资」算收入', () => {
    expect(normalizeMoney([yuan('人均', 120), yuan('门票', 60), yuan('车费', 15)], { label: '周末' }).map((m) => m.name)).toEqual(['花费', '花费', '花费'])
    expect(normalizeMoney([yuan('流水', 3200), yuan('稿费', 8000), yuan('工资', 1)], { label: '今天' }).map((m) => m.name)).toEqual(['收入', '收入', '收入'])
  })

  it('「金额」看名称和领域；认不出进出就不动', () => {
    expect(normalizeMoney([yuan('金额', 50)], { label: '卖二手书' })[0]!.name).toBe('收入')
    expect(normalizeMoney([yuan('金额', 50)], { label: '买猫砂' })[0]!.name).toBe('花费')
    expect(normalizeMoney([yuan('金额', 80)], { label: '洗澡美容', rootName: '宠物' })[0]!.name).toBe('花费')
    expect(normalizeMoney([yuan('金额', 500)], { label: '和客户谈合作', rootName: '工作' })).toEqual([yuan('金额', 500)])
  })

  it('原来的名目留下（「菜钱」→ 菜、「打赏收入」→ 打赏）；再统一一遍不变', () => {
    expect(normalizeMoney([yuan('菜钱', 860), yuan('肉', 1200)], { label: '进货' })).toEqual([
      { name: '花费', value: 860, unit: '元', item: '菜' },
      { name: '花费', value: 1200, unit: '元', item: '肉' },
    ])
    expect(normalizeMoney([yuan('打赏收入', 860)], { label: '直播' })).toEqual([{ name: '收入', value: 860, unit: '元', item: '打赏' }])
    expect(normalizeMoney([yuan('午饭', 23)], { label: '午饭', rootName: '饮食' })).toEqual([yuan('花费', 23)])
    const once = normalizeMoney([yuan('菜钱', 860)], { label: '进货' })
    expect(normalizeMoney(once, { label: '进货' })).toEqual(once)
  })

  it('合计和拆分只算合计（「营业额2350 微信1800 现金550」不是 4700）；没说是拆分的照算', () => {
    const noon = normalizeMoney([yuan('营业额', 2350), yuan('微信', 1800), yuan('现金', 550)], { label: '营业额' })
    expect(foldBreakdown(noon, '中午营业额2350 微信1800 现金550')).toEqual({
      metrics: [{ name: '收入', value: 2350, unit: '元' }],
      parts: [
        { name: '收入', value: 1800, unit: '元', item: '微信' },
        { name: '收入', value: 550, unit: '元', item: '现金' },
      ],
    })
    const buy = normalizeMoney([yuan('菜钱', 1000), yuan('肉', 1000), yuan('米', 2000)], { label: '进货' })
    expect(foldBreakdown(buy, '进货 菜钱1000 肉1000 米2000').metrics).toHaveLength(3)
  })

  it('¥ 千位分隔，最多两位小数；钱写名目', () => {
    expect(formatYuan(8600)).toBe('¥8,600')
    expect(formatYuan(12.5)).toBe('¥12.5')
    expect(formatMetric({ name: '花费', value: 860, unit: '元', item: '菜' })).toBe('菜 ¥860')
    expect(formatMetric(yuan('距离', 5, '公里'))).toBe('5 公里')
  })
})

describe('名称里提到的人补进和谁', () => {
  it.each([
    ['跟供应商吵架', ['供应商']],
    ['陪老同学吃饭', ['老同学']],
    ['给妈妈打视频电话', ['妈妈']],
    ['跑步', []],
  ])('「%s」', (label, expected) => {
    expect(peopleInText(label)).toEqual(expected)
  })

  it('AI 写了的照留；写了更具体的不再补', () => {
    expect(withPeopleFromLabel([], '跟供应商吵架')).toEqual(['供应商'])
    expect(withPeopleFromLabel(['同事小王'], '和同事吃饭')).toEqual(['同事小王'])
    expect(withPeopleFromLabel(['老公'], '晚饭')).toEqual(['老公'])
  })
})

describe('清单里一行一个价钱：AI 加成一个总数时照原话拆回每一样', () => {
  it('每行「名称 … 价钱」读出来；不是一行一个价钱的不认', () => {
    expect(listedPrices('宝宝用品\n奶瓶 贝亲 55\n纸尿裤 花王 L码 129\n湿巾 全棉时代 39\n已经下单了')).toEqual([
      { item: '奶瓶', value: 55 },
      { item: '纸尿裤', value: 129 },
      { item: '湿巾', value: 39 },
    ])
    expect(listedPrices('中午吃牛肉面花了10元')).toEqual([])
  })

  it('总数正好等于每行加起来才拆', () => {
    const text = '宝宝用品\n奶瓶 贝亲 55\n纸尿裤 花王 L码 129\n湿巾 全棉时代 39'
    expect(splitListed([{ name: '花费', value: 223, unit: '元' }], text)).toHaveLength(3)
    expect(splitListed([{ name: '花费', value: 200, unit: '元' }], text)).toEqual([{ name: '花费', value: 200, unit: '元' }])
  })
})

describe('血压由程序认（照网页版 health.test.ts）', () => {
  it('各种说法都认得出；统一写成收缩压、舒张压', () => {
    expect(bloodPressureIn('早上量血压一百三十五八十八 吃了降压药')).toEqual({ systolic: 135, diastolic: 88 })
    expect(bloodPressureIn('高压138 低压86')).toEqual({ systolic: 138, diastolic: 86 })
    expect(bloodPressureIn('今天跑了5公里 用了30分钟')).toBeNull()
    expect(normalizeHealth([], '早上量血压一百三十五八十八')).toEqual([
      { name: '收缩压', value: 135, unit: 'mmHg' },
      { name: '舒张压', value: 88, unit: 'mmHg' },
    ])
    expect(normalizeHealth([{ name: '血压', value: 135, unit: 'mmHg' }, { name: '舒张压', value: 88, unit: 'mmHg' }])[0]!.name).toBe('收缩压')
  })
})

describe('新建的事件存之前整理一遍', () => {
  it('「中午营业额2350 微信1800 现金550」：收入只算 2350，拆分写进备注', async () => {
    const llm = new FakeLlm().on('router', recordIntent()).on('parse-note', {
      items: [
        {
          op: 'create', kind: 'event', category: 'work', label: '营业额', date: 'today',
          metrics: [yuan('营业额', 2350), yuan('微信', 1800), yuan('现金', 550)],
          span: '中午营业额2350 微信1800 现金550', confidence: 0.9,
        },
      ],
      reply: '',
    })
    const out = await understand(backgroundPackage('中午营业额2350 微信1800 现金550'), { llm })
    expect(out.creates[0]!.data).toMatchObject({ metrics: [{ name: '收入', value: 2350, unit: '元' }], note: '其中 微信 ¥1,800、现金 ¥550' })
  })
})
