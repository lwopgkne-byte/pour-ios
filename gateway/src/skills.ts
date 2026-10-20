/**
 * Skill 文件：gateway/skills/ 下的 Markdown 提示词，照网页版原样搬来（server/src/ai/skills.ts）。
 * 开头的 front matter 写名字和版本号；_voice.md 是语气和行为准则，自动加在所有其他 Skill 前面。
 */
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { ROOT } from './env.ts'

export interface Skill {
  name: string
  version: string
  body: string
}

export const SKILLS_DIR = join(ROOT, 'skills')

export function parseSkill(name: string, raw: string): Skill {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(raw)
  if (!m) return { name, version: '0', body: raw.trim() }
  const meta = Object.fromEntries(
    m[1]!
      .split(/\r?\n/)
      .map((l) => /^(\w+):\s*(.*)$/.exec(l.trim()))
      .filter((x): x is RegExpExecArray => Boolean(x))
      .map((x) => [x[1], x[2]!.trim()]),
  )
  return { name: meta.name ?? name, version: meta.version ?? '0', body: m[2]!.trim() }
}

export function loadSkill(name: string, dir: string = SKILLS_DIR): Skill {
  const file = join(dir, `${name}.md`)
  if (!existsSync(file)) throw new Error(`找不到 Skill 文件：skills/${name}.md`)
  return parseSkill(name, readFileSync(file, 'utf8'))
}

/** 用 {{变量}} 填充 Skill 正文；没给的变量原样留着（测试会抓出来） */
export function fillTemplate(body: string, vars: Record<string, string>): string {
  return body.replace(/\{\{(\w+)\}\}/g, (_, k: string) => vars[k] ?? `{{${k}}}`)
}

/**
 * Skill 文件里这一行之后是「背景」：每次调用都不一样的内容（现在几点、已有的记录…）。
 * 背景放进用户消息，系统提示词只留不变的规则——每次发送的开头都一样，DeepSeek 的上下文缓存能命中，
 * 这部分的价格只有原来的几十分之一。
 */
export const CONTEXT_MARKER = /^# 背景（每次调用时填入）\s*$/m

/** 系统提示词 = 语气准则 + 这个 Skill 不变的部分；context = 填好变量的背景 */
export function renderSkill(
  name: string,
  vars: Record<string, string>,
  dir?: string,
): { prompt: string; context: string; version: string } {
  const voice = loadSkill('_voice', dir)
  const skill = loadSkill(name, dir)
  const m = CONTEXT_MARKER.exec(skill.body)
  const rules = m ? skill.body.slice(0, m.index).trim() : skill.body
  const context = m ? fillTemplate(skill.body.slice(m.index + m[0].length).trim(), vars) : ''
  return {
    prompt: `${voice.body}\n\n---\n\n${fillTemplate(rules, vars)}`,
    context,
    version: `${skill.name}@${skill.version}+_voice@${voice.version}`,
  }
}
