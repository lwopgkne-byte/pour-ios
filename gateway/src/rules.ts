/** 几处共用的规矩（照网页版） */
import type { Category } from './contract.ts'

/** 把握低于这个数的记录要你确认（网页版设置里的默认值） */
export const CONFIDENCE_THRESHOLD = 0.8

/** 顶级类别：一直往上找（「跑步」的顶级是「运动」） */
export function rootCategory(key: string, cats: Category[]): string {
  let current = key
  for (let hops = 0; hops < 8; hops++) {
    const parent = cats.find((c) => c.key === current)?.parent
    if (!parent) return current
    current = parent
  }
  return current
}
