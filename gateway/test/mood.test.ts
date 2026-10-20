import { describe, expect, it } from 'vitest'
import { EMOTIONS, normalizeEmotions, saidEmotions } from '../src/emotions.ts'
import { cleanMoment, longestOverlap, normalizeForMatch, onlyFeeling } from '../src/mood.ts'

describe('一套常用的情绪说法（照网页版 emotions.test.ts）', () => {
  it('能对上「说法」或「也算」的换成说法，对不上的照留；去掉说精力的；去重，最多 3 个', () => {
    expect(normalizeEmotions(['高兴'])).toEqual(['开心'])
    expect(normalizeEmotions(['憋屈', '火大'])).toEqual(['委屈', '生气'])
    expect(normalizeEmotions(['松弛感'])).toEqual(['松弛感'])
    expect(normalizeEmotions([' 开心 ', '累', '困', '没精神'])).toEqual(['开心'])
    expect(normalizeEmotions(['开心', '放松', '温暖', '感动'])).toEqual(['开心', '放松', '温暖'])
  })

  it('每个说法、也算的词只出现一次', () => {
    const all = EMOTIONS.flatMap((e) => [e.word, ...e.also])
    expect(new Set(all).size).toBe(all.length)
  })

  it('原话里直接说出来的情绪词：说成一种感受的样子才算', () => {
    expect(saidEmotions('今天挺开心的')).toEqual(['开心'])
    expect(saidEmotions('烦死了')).toEqual(['烦躁'])
    expect(saidEmotions('又紧张又期待')).toEqual(['紧张', '期待'])
    expect(saidEmotions('今天不开心')).toEqual([])
    expect(saidEmotions('怎么也开心不起来')).toEqual([])
    expect(saidEmotions('今天心情很好')).toEqual([])
    expect(saidEmotions('下午吃了开心果')).toEqual([])
    expect(saidEmotions('这事挺麻烦')).toEqual([])
  })
})

describe('那一刻（照网页版 mood.test.ts）', () => {
  it('一字不差在原话里（不算空格和标点）才留；改写过的、空的、超过 60 字的不要', () => {
    const note = '中午在公司楼下 买到了最后一个肉夹馍！心里美滋滋'
    expect(cleanMoment('买到了最后一个肉夹馍', note)).toBe('买到了最后一个肉夹馍')
    expect(cleanMoment(' 公司楼下，买到了最后一个肉夹馍 ', note)).toBe('公司楼下，买到了最后一个肉夹馍')
    expect(cleanMoment('抢到了最后一个肉夹馍', note)).toBeUndefined()
    expect(cleanMoment('  ', note)).toBeUndefined()
    const long = '沿着河边慢慢走'.repeat(9)
    expect(cleanMoment(long, `${long} 很放松`)).toBeUndefined()
  })

  it('只说了时间和心情的不要；带着做的事、看到的东西的照留', () => {
    const note = '下午有点闷 晚上散了会儿步 心里特别舒服 一下就好了'
    expect(cleanMoment('下午', note)).toBeUndefined()
    expect(cleanMoment('下午有点闷', note)).toBeUndefined()
    expect(cleanMoment('心里特别舒服', note)).toBeUndefined()
    expect(cleanMoment('一下就好了', note)).toBeUndefined()
    expect(cleanMoment('晚上散了会儿步', note)).toBe('晚上散了会儿步')
    expect(onlyFeeling('看他笑成那样')).toBe(false)
    expect(onlyFeeling('今天不开心')).toBe(true)
  })

  it('AI 把中间省掉了一段：几段按顺序都在原话里，取原话里的那一整段；顺序不对、有一段不在的不要', () => {
    const note = '陪闺女在楼下骑滑板车 顺手录了一段 看她骑得那么稳 我也挺高兴'
    expect(cleanMoment('陪闺女在楼下骑滑板车，看她骑得那么稳', note)).toBe('陪闺女在楼下骑滑板车 顺手录了一段 看她骑得那么稳')
    expect(cleanMoment('看她骑得那么稳，陪闺女在楼下骑滑板车', note)).toBeUndefined()
    expect(cleanMoment('陪闺女骑车，看她骑得那么稳', note)).toBeUndefined()
  })

  it('比较用的写法和最长的连续相同的一段', () => {
    expect(normalizeForMatch('早上，看到 Moon！')).toBe('早上看到moon')
    expect(longestOverlap('陪女儿荡秋千 她一直在笑', '下午和女儿荡秋千')).toBe(5)
    expect(longestOverlap('看晚霞', '吃火锅')).toBe(0)
  })
})
