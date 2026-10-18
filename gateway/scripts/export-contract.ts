/**
 * 把接口契约写成文件（`npm run contract`）：gateway/contract/ 下的 JSON Schema 和一对样例。
 * 手机那边的测试解码同一对样例（PourAITests），两边的格式对不上时测试会失败；
 * 网关的测试核对这些文件是最新的（改了契约忘了重新导出会失败）
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { CONTRACT_VERSION } from '../src/contract.ts'
import { ROOT } from '../src/env.ts'
import { contractFiles } from './contract-files.ts'

const dir = join(ROOT, 'contract')
mkdirSync(dir, { recursive: true })
const files = await contractFiles()
for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, name), text)
console.log(`契约 v${CONTRACT_VERSION} → gateway/contract/（${Object.keys(files).length} 个文件）`)
