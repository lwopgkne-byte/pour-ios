# 技术决定记录（ADR）

> 每条写清：选了什么、为什么、没选什么、后果和什么时候要重新看。来源：[03 架构与开发方案](../03-架构与开发方案.md) 第 8 节。M0 写成（2026-10-17）。改决定：先改这里，再改代码。

| # | 决定 | 状态 |
|---|---|---|
| [A01](A01-语言.md) | Swift 6（严格并发） | 已定 |
| [A02](A02-界面.md) | SwiftUI 为主，倾倒栏输入区用 UIKit 包一层 | 已定 |
| [A03](A03-最低系统.md) | 最低系统 iOS 26；先用 Xcode 26.6（iOS 26.5 SDK）构建 | 已定（2026-10-17 产品主人改过） |
| [A04](A04-架构.md) | 分层 + 单向数据流；@Observable + swift-dependencies | 已定 |
| [A05](A05-数据库.md) | SQLite + GRDB；界面观察和同步用 SQLiteData | 已定 |
| [A06](A06-同步.md) | CloudKit 私有库（SQLiteData 同步引擎），同步层可替换 | 已定 |
| [A07](A07-规则和计算.md) | PourCore 纯 Swift 包，iOS 和 macOS 都能跑 | 已定 |
| [A08](A08-AI 网关.md) | TypeScript（Node + Fastify），国内云 | 已定 |
| [A09](A09-身份.md) | 不注册登录，App Attest 设备证明 + 短期令牌 | 已定 |
| [A10](A10-通知.md) | 本地通知为主，时间表在手机上算 | 已定 |
| [A11](A11-语音.md) | SpeechAnalyzer（端侧中文），不达标退回系统听写 | 已定 |
| [A12](A12-按意思搜索.md) | bge-small-zh 转端侧模型（Core ML），向量只在本机 | 已定 |
| [A13](A13-全文搜索.md) | FTS5 三字切分 + 1–2 个字直接扫描原话 | 已定 |
| [A14](A14-图表.md) | Swift Charts + Canvas 自绘 | 已定 |
| [A15](A15-工程生成.md) | XcodeGen（ios/project.yml） | 已定 |
| [A16](A16-代码风格.md) | SwiftLint + swift-format；令牌检查是自定义规则 | 已定 |
| [A17](A17-观测.md) | MetricKit + 系统日志标记 + Xcode Organizer | 已定 |
| [A18](A18-依赖政策.md) | 能用系统的不用第三方；每个第三方库先写 ADR | 已定 |
| [A19](A19-多语言.md) | 界面文字全进 String Catalog，简体中文为基准 | 已定 |
| [A20](A20-隐私清单.md) | 从 M0 起就有 PrivacyInfo.xcprivacy | 已定 |
