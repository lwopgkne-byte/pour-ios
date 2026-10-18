// 网页版的测试原样搬来（server/src/ai/guards.test.ts、shared/src/health.test.ts、format.test.ts、mood.test.ts 里对应的几段）
import { describe, expect, it } from 'vitest'
import { weekdayDateIn } from '../src/dates.ts'
import { fromQuestion, notToRecord, othersEvent, saidNotDone } from '../src/guards.ts'
import { DISTRESS_REPLY, directMoodLevel, isDistress, toneOfLevel } from '../src/mood.ts'
import { wakeTimeIn } from '../src/numbers.ts'

const ev = (label: string, span: string, people: string[] = []) => ({ kind: 'event', label, span, people })

describe('问的话不记成一条（训练场找到的）', () => {
  it('摘的字整个在问话里、本身就在问：不记（事件、感悟、待办都一样）', () => {
    const q = ['这周一共洗碗了几次哦']
    expect(fromQuestion('这周一共洗碗了几次', q)).toBe(true)
    // 意图识别写问话时顺手改掉了语音的错字（原话「铲毛砂」）：差一两个字也算
    expect(fromQuestion('这周一共铲毛砂了几次啊', ['这周一共铲猫砂了几次啊'])).toBe(true)
    // 差得多就不是
    expect(fromQuestion('上周去了几次健身房', ['这周一共铲猫砂了几次啊'])).toBe(false)
    expect(notToRecord(ev('洗碗', '这周一共洗碗了几次'), q)).toBe('这是问的话，不是记录')
    expect(notToRecord({ kind: 'insight', title: '这周午睡次数', span: '这周一共午睡了几次哦' }, ['这周一共午睡了几次哦？'])).toBe('这是问的话，不是记录')
  })

  it('问话前面说的记录照记（「跑了五公里，这周跑了几次」）；没被认成问话的不动（「问问老板几点开会」是待办）', () => {
    expect(fromQuestion('跑了五公里', ['这周一共跑了几次'])).toBe(false)
    expect(notToRecord({ kind: 'todo', content: '问老板几点开会', span: '问问老板几点开会' }, [])).toBeNull()
    // 摘的字在问话里、本身不是在问的（问话被认得太宽）：照记
    expect(fromQuestion('早上跑了五公里', ['早上跑了五公里，这周跑了几次'])).toBe(false)
  })
})

describe('说没做的不记', () => {
  it('「今天没网购」「还没吃午饭」「没去跑步」', () => {
    expect(saidNotDone('网购', '今天没网购')).toBe(true)
    expect(saidNotDone('午饭', '还没吃午饭')).toBe(true)
    expect(saidNotDone('跑步', '今天没去跑步')).toBe(true)
    expect(notToRecord(ev('网购', '今天没网购'), [])).toBe('原话说的是没做')
  })

  it('只摘了叫法本身：看原话里每一次是不是都说的没做', () => {
    expect(saidNotDone('网购', '网购', '下午买菜花了86块，今天没网购，大后天交房租')).toBe(true)
    expect(saidNotDone('网购', '网购', '今天没网购，昨天网购了一双鞋')).toBe(false)
  })

  it('不是在说没做的不算：「跑步没带耳机」「没想到跑步这么累」', () => {
    expect(saidNotDone('跑步', '跑步没带耳机')).toBe(false)
    expect(saidNotDone('跑步', '没想到跑步这么累')).toBe(false)
  })
})

describe('别人的事不记成用户的', () => {
  it('以这个人开头、说的是他自己的状况：「老伴感冒了」「小周要离职了」「老公今天加班」「老刘家正装修呢」「孙子今天去上兴趣班了」', () => {
    expect(othersEvent(ev('感冒', '老伴感冒了', ['老伴']))).toBe(true)
    expect(othersEvent(ev('小周离职', '小周要离职了', ['小周']))).toBe(true)
    expect(othersEvent(ev('加班', '老公今天加班', ['老公']))).toBe(true)
    expect(othersEvent(ev('老刘家装修', '老刘家正装修呢', ['老刘']))).toBe(true)
    expect(othersEvent(ev('孙子去上兴趣班', '孙子今天去上兴趣班了', ['孙子']))).toBe(true)
    expect(notToRecord(ev('感冒', '老伴感冒了', ['老伴']), [])).toBe('是别人的事，只是提到')
  })

  it('用户自己也在里面的照记：「老公感冒了，我带他去看病」「带孙子去上兴趣班」「老公做的晚饭」「宝宝今天打了疫苗」', () => {
    expect(othersEvent(ev('带老公看病', '老公感冒了，我带他去看病', ['老公']))).toBe(false)
    expect(othersEvent(ev('送孙子上兴趣班', '带孙子去上兴趣班', ['孙子']))).toBe(false)
    expect(othersEvent(ev('晚饭', '老公做的晚饭', ['老公']))).toBe(false)
    expect(othersEvent(ev('宝宝打疫苗', '宝宝今天打了疫苗', ['宝宝']))).toBe(false)
    // 用户自己的事
    expect(othersEvent(ev('感冒', '我感冒了'))).toBe(false)
    expect(othersEvent(ev('加班', '今天加班到九点'))).toBe(false)
  })

  it('心情不归这里管', () => {
    expect(notToRecord({ kind: 'mood', span: '老伴感冒了，我挺担心' }, [])).toBeNull()
  })
})

describe('只说了几点起：起床时刻由程序照原话认', () => {
  it('六点半起的、7点起床、五点四十就醒了、八点多才起；不是起床的钟点不认', () => {
    expect(wakeTimeIn('今天六点半起的')).toBe('06:30')
    expect(wakeTimeIn('今天早起了 六点半起的 去操场跑了3公里')).toBe('06:30')
    expect(wakeTimeIn('7点起床')).toBe('07:00')
    expect(wakeTimeIn('五点四十就醒了')).toBe('05:40')
    expect(wakeTimeIn('八点多才起来')).toBe('08:00')
    expect(wakeTimeIn('晚上9点给妈妈打电话')).toBeNull()
    expect(wakeTimeIn('昨晚两点才睡')).toBeNull()
  })
})

describe('原话里的星期几是哪天（docs/prd-daily.md 10.3，今天 2026-10-14 周三）', () => {
  it.each([
    ['周五在公司加班加到快十一点', '2026-10-09'],
    ['周三在公司加班', '2026-10-14'],
    ['周一陪客户吃饭', '2026-10-12'],
    ['上周三晚上看话剧', '2026-10-07'],
    ['上上周五发烧', '2026-10-02'],
    ['周日去爬山', '2026-10-11'],
    ['星期天在家', '2026-10-11'],
    ['礼拜四去银行', '2026-10-08'],
    ['这周一开了个会', '2026-10-12'],
  ])('「%s」→ %s', (text, expected) => {
    expect(weekdayDateIn(text, '2026-10-14')).toBe(expected)
  })

  it.each([['这周五去体检'], ['下周二开会'], ['周一加班 周二拔牙'], ['今天跑步了']])('「%s」不管', (text) => {
    expect(weekdayDateIn(text, '2026-10-14')).toBeNull()
  })
})

describe('心情（mood.test.ts）', () => {
  it('直接评价心情时照原词，由程序认（5.1 那张表）；不是在评价心情的不管', () => {
    expect(directMoodLevel('今天心情 很好')).toBe(5)
    expect(directMoodLevel('心情特别好')).toBe(5)
    expect(directMoodLevel('心情还不错')).toBe(4)
    expect(directMoodLevel('状态挺好')).toBe(4)
    expect(directMoodLevel('心情一般吧')).toBe(3)
    expect(directMoodLevel('状态马马虎虎')).toBe(3)
    expect(directMoodLevel('心情不太好')).toBe(2)
    expect(directMoodLevel('心情不怎么样')).toBe(2)
    expect(directMoodLevel('心情很差')).toBe(1)
    expect(directMoodLevel('今天心情糟透了')).toBe(1)
    expect(directMoodLevel('今天很开心')).toBeUndefined()
    expect(directMoodLevel('挺好的一天')).toBeUndefined()
    // 一句里两种说法：按先说的那种
    expect(directMoodLevel('早上心情很差 晚上心情不错')).toBe(1)
    expect(toneOfLevel(5)).toEqual({ tone: 'good', strength: 'strong' })
    expect(toneOfLevel(2)).toEqual({ tone: 'bad', strength: 'medium' })
  })
})

describe('心情（mood.test.ts）', () => {
  it('很难受的认法：写好的几条说法，中间可以夹一两个字；不算的不认', () => {
    for (const t of ['不想活了', '真的不想再活了', '我不想活下去', '活不下去了', '活着没意思', '活着真没意思', '想过自杀', '有轻生的念头', '想了结自己', '想结束生命', '想伤害自己', '不想醒来']) {
      expect(isDistress(t), t).toBe(true)
    }
    for (const t of ['不想活动', '想死你了', '今天累死了', '被老板气死了', '烦死了', '活动没意思', '今天不想动']) {
      expect(isDistress(t), t).toBe(false)
    }
    expect(isDistress('活着 真 没意思')).toBe(true) // 去掉空白再认
  })
})

describe('心情（mood.test.ts）', () => {
  it('很难受时的固定回复：有「身边信任的人」和查到的官方热线', () => {
    expect(DISTRESS_REPLY).toContain('身边信任的人')
    expect(DISTRESS_REPLY).toContain('12356')
  })
})

describe('很难受的说法要认全（一类：同一个意思换个说法就认不出）', () => {
  it('活着好累、活着没意义、想死、死了算了、想消失、撑不下去：都认得出', () => {
    for (const t of [
      '我觉得活着好累',
      '活着太难了',
      '活着真的好苦',
      '不知道活着有什么意义',
      '人生没有意义',
      '好想死',
      '有时候真想死',
      '死了算了',
      '还不如死了',
      '想消失',
      '我真的撑不下去了',
      '我快熬不下去了',
      '没有活下去的勇气',
    ]) {
      expect(isDistress(t), t).toBe(true)
    }
  })

  it('口头禅不算：累死了、笑死、想死你了、热得想死、项目撑不下去了', () => {
    for (const t of ['累死了', '笑死我了', '想死你了', '想死我了', '热得想死', '困得想死', '这个项目撑不下去了', '饿死了', '活着回来了', '活着的鱼']) {
      expect(isDistress(t), t).toBe(false)
    }
  })
})

