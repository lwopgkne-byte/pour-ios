// 网页版截图（对照用）：用 iPhone 15 的尺寸打开这台 Mac 上的网页版演示数据（端口 5199），整页截下来。
// 用法：node scripts/web-shot.mjs /day/2026-10-15 web-1015   → build/web-shots/web-1015.png、web-1015-full.png
// 先点一下某个按钮再截（比如打开对话）：node scripts/web-shot.mjs / web-chat http://127.0.0.1:5199 展开对话
// 要先在网页版仓库装好 playwright（~/Developer/pour/node_modules）和它的 Chromium（~/Library/Caches/ms-playwright）
import { existsSync, mkdirSync, readdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

const { chromium } = await import(join(homedir(), 'Developer/pour/node_modules/playwright/index.mjs'))
const cache = join(homedir(), 'Library/Caches/ms-playwright')
const chrome = readdirSync(cache)
  .filter((d) => d.startsWith('chromium-'))
  .map((d) => join(cache, d, 'chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'))
  .find(existsSync)
const out = join(import.meta.dirname, '..', 'build', 'web-shots')
mkdirSync(out, { recursive: true })
const [path = '/', name = 'web', base = 'http://127.0.0.1:5199', click] = process.argv.slice(2)
const browser = await chromium.launch(chrome ? { executablePath: chrome } : {})
const page = await browser.newPage({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'zh-CN' })
await page.goto(base + path, { waitUntil: 'networkidle' })
await page.waitForTimeout(1500)
if (click) {
  await page.getByRole('button', { name: click }).first().click()
  await page.waitForTimeout(1500)
}
await page.screenshot({ path: join(out, `${name}.png`) })
await page.screenshot({ path: join(out, `${name}-full.png`), fullPage: true })
await browser.close()
console.log(join(out, `${name}-full.png`))
