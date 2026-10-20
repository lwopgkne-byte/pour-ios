/**
 * 启动网关：`npm start`（改代码时 `npm run dev` 自动重启）。
 * 默认只听本机 127.0.0.1:5480——模拟器直接连得上，不用令牌。
 * 真机：听局域网（POUR_GATEWAY_HOST=0.0.0.0），启动时显示 6 位配对码，手机在设置里输一次（gateway/.paired.json 记着配好的手机）
 */
import { join } from 'node:path'
import { ROOT, loadConfig } from './env.ts'
import { createLlmClient } from './llm.ts'
import { Pairing } from './pairing.ts'
import { buildServer } from './server.ts'

const config = loadConfig()
const loopback = ['127.0.0.1', '::1', 'localhost'].includes(config.host)
const pairing = loopback ? undefined : new Pairing(join(ROOT, '.paired.json'))

const app = buildServer({ config, llm: createLlmClient(config), ...(pairing ? { pairing } : {}) })
await app.listen({ host: config.host, port: config.port })
console.log(
  `Pour 网关：http://${config.host}:${config.port}（模型 ${config.model}；密钥${config.apiKey ? '已填' : '还没填'}）`,
)
if (pairing) console.log(`真机配对码：${pairing.code}（已经配好 ${pairing.count} 台；配好一台就换一个新的）`)
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => void app.close().then(() => process.exit(0)))
}
