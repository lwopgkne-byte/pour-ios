/** 测试用的背景包：预置类别就是手机建库用的那一份（PourData 的 categories.json） */
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { type BackgroundPackage, Category, type ExistingRecord } from '../src/contract.ts'
import { ROOT } from '../src/env.ts'

export const SEED_CATEGORIES: Category[] = (
  JSON.parse(readFileSync(join(ROOT, '..', 'Packages', 'PourKit', 'Sources', 'PourData', 'Resources', 'categories.json'), 'utf8')) as { categories: unknown[] }
).categories.map((c) => Category.parse(c))

export function backgroundPackage(
  text: string,
  over: { localTime?: string; day?: string; existing?: ExistingRecord[]; id?: string } = {},
): BackgroundPackage {
  const localTime = over.localTime ?? '2026-09-24T09:30'
  return {
    version: 1,
    note: { id: over.id ?? 'note-1', text, localTime, timeZone: 'Asia/Shanghai', day: over.day ?? localTime.slice(0, 10) },
    dayBoundary: 240,
    categories: SEED_CATEGORIES,
    existing: over.existing ?? [],
  }
}

/** 整理的一条跑步（和网页版测试里的一样） */
export const run = {
  op: 'create',
  kind: 'event',
  category: 'run',
  label: '跑步',
  date: 'today',
  start: '08:00',
  end: null,
  duration_min: 60,
  metrics: [],
  note: '',
  span: '8点开始跑步跑了一个小时',
  confidence: 0.95,
  question: null,
}
