/**
 * 配对（真机连这台 Mac 上的网关，ADR A08；上架前换成设备证明）：
 * 网关听局域网时，启动就生成一个 6 位配对码、显示在终端里；手机在设置里输一次，换回一个令牌，存在手机的钥匙串里。
 * 令牌只存在这台 Mac 的 gateway/.paired.json（不进仓库）；App 里不放任何令牌——「密钥不进 App」。
 * 配对码输错 5 次就换一个，防止被一个一个试出来
 */
import { randomBytes, randomInt, timingSafeEqual } from 'node:crypto'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'

export interface PairedDevice {
  token: string
  device: string
  pairedAt: string
}

export class Pairing {
  code: string
  private wrong = 0
  private readonly devices: PairedDevice[]

  constructor(private readonly file: string | null) {
    this.code = Pairing.newCode()
    this.devices = file && existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as PairedDevice[]) : []
  }

  static newCode(): string {
    return String(randomInt(0, 1_000_000)).padStart(6, '0')
  }

  /** 用配对码换令牌；配对码不对返回 null（输错 5 次换一个新的配对码） */
  pair(code: string, device: string): string | null {
    if (!same(code.trim(), this.code)) {
      this.wrong += 1
      if (this.wrong >= 5) {
        this.code = Pairing.newCode()
        this.wrong = 0
      }
      return null
    }
    const token = randomBytes(32).toString('base64url')
    this.devices.push({ token, device: device.slice(0, 60) || 'iPhone', pairedAt: new Date().toISOString() })
    if (this.file) writeFileSync(this.file, JSON.stringify(this.devices, null, 2), { mode: 0o600 })
    // 配好一台就换配对码：同一个码不能再配第二台
    this.code = Pairing.newCode()
    this.wrong = 0
    return token
  }

  accepts(token: string): boolean {
    return this.devices.some((d) => same(token, d.token))
  }

  get count(): number {
    return this.devices.length
  }
}

/** 比较两段字，用的时间和哪里不一样无关（不让人从响应快慢猜） */
function same(a: string, b: string): boolean {
  const x = Buffer.from(a)
  const y = Buffer.from(b)
  return x.length === y.length && timingSafeEqual(x, y)
}
