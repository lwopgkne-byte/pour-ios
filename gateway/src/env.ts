/**
 * 网关的配置：读 gateway/.env（密钥只在这台电脑上，不进仓库）和环境变量。
 * 密钥不打印、不写日志；健康检查只说「有没有、能不能用」。
 */
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

/** gateway/ 目录 */
export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

/** 读 KEY=VALUE 一行一个的文件；# 开头是注释、空行跳过。值两边的引号去掉 */
export function parseEnvFile(text: string): Record<string, string> {
  const out: Record<string, string> = {}
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const m = /^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$/.exec(line)
    if (!m) continue
    out[m[1]!] = m[2]!.replace(/^(['"])(.*)\1$/, '$2').trim()
  }
  return out
}

export interface GatewayConfig {
  apiKey: string | null
  baseUrl: string
  model: string
  /**
   * 深度思考：DeepSeek 默认开启，整理会慢好几倍、多花不少钱——关掉（网页版的经验）。
   * 其他兼容服务不认这个参数，不发
   */
  thinking: 'disabled' | 'enabled' | null
  host: string
  port: number
  /** 局域网里的手机要带着它来（没加入苹果开发者计划前，代替设备证明）；只听本机时不用 */
  devToken: string | null
}

/** 整理用 DeepSeek 的 Flash（docs/04 第 4 节：网页版评测 99.7%–100%，花费约 Pro 的三成、快一倍） */
export const DEFAULT_MODEL = 'deepseek-flash'
export const DEFAULT_BASE_URL = 'https://api.deepseek.com'

export function loadConfig(env: NodeJS.ProcessEnv = process.env, file = join(ROOT, '.env')): GatewayConfig {
  const fromFile = existsSync(file) ? parseEnvFile(readFileSync(file, 'utf8')) : {}
  const get = (key: string) => (env[key]?.trim() || fromFile[key]?.trim() || undefined)
  const baseUrl = (get('LLM_BASE_URL') ?? DEFAULT_BASE_URL).replace(/\/+$/, '')
  const host = get('POUR_GATEWAY_HOST') ?? '127.0.0.1'
  return {
    apiKey: get('DEEPSEEK_API_KEY') ?? null,
    baseUrl,
    model: get('LLM_MODEL') ?? DEFAULT_MODEL,
    thinking: /deepseek\.com/.test(baseUrl) ? 'disabled' : null,
    host,
    port: Number(get('POUR_GATEWAY_PORT') ?? 5480),
    devToken: get('POUR_DEV_TOKEN') ?? null,
  }
}
