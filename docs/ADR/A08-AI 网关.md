# A08 AI 网关：TypeScript（Node + Fastify），国内云

- **状态**：已定
- **日期**：2026-10-17

## 决定

网关沿用网页版的整理流水线、Skill、把关和评测。

## 为什么

准确率原样继承；改提示词不用等苹果审核。

## 没选的

用 Swift 重写流水线：要重新赚回 99.9%，没收益。

## 后果和什么时候重新看

M2 建网关时定 Node 版本（写进 `gateway/.nvmrc`；网页版当时用 24）。

**建网关的记录（M2a，2026-10-18）**：
- Node 24（`gateway/.nvmrc`、`package.json` 的 engines 写 `>=24`；这台 Mac 现在装的是 25，也能跑）
- 依赖（`package-lock.json` 进仓库）：fastify 5.12.7、zod 4.6.7（MIT）；开发用 typescript 5.9.3、tsx 4.23.15、vitest 5.0.5（MIT）、@types/node 24
- 开发阶段网关跑在这台 Mac 上（`npm run dev`，默认只听 127.0.0.1:5480，模拟器直接连）；真机要听局域网时必须设开发令牌。上架前搬到国内云、加设备证明（到时候花钱的事先问产品主人）
- 接口契约 v1 写成 JSON Schema 和一对样例（`gateway/contract/`，`npm run contract` 生成），网关和手机的测试都拿它核对
