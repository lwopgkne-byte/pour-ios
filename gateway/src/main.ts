/**
 * 启动网关：`npm start`（改代码时 `npm run dev` 自动重启）。
 * 默认只听本机 127.0.0.1:5480——模拟器直接连得上。真机要听局域网（POUR_GATEWAY_HOST=0.0.0.0），这时必须设开发令牌
 */
import { createLlmClient } from './llm.ts'
import { loadConfig } from './env.ts'
import { buildServer } from './server.ts'

const config = loadConfig()
const loopback = ['127.0.0.1', '::1', 'localhost'].includes(config.host)
if (!loopback && !config.devToken) {
  console.error(`要听 ${config.host}（局域网里的手机都能连）就必须在 gateway/.env 里设 POUR_DEV_TOKEN。`)
  process.exit(1)
}

const app = buildServer({ config, llm: createLlmClient(config) })
await app.listen({ host: config.host, port: config.port })
console.log(
  `Pour 网关：http://${config.host}:${config.port}（模型 ${config.model}；密钥${config.apiKey ? '已填' : '还没填'}` +
    `${config.devToken ? '；要开发令牌' : ''}）`,
)
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => void app.close().then(() => process.exit(0)))
}
