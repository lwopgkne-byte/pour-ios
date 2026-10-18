# Pour（倾）· iOS

你只管倾倒，AI 负责把混沌变成结构。这里是 Pour 的 iOS App：SwiftUI + Liquid Glass。现在只做产品主人的 iPhone 15 + iOS 27（最低系统暂时 iOS 27，ADR A03）。

## 开始

1. 从 App Store 装 Xcode 27.1，打开一次；装 [Homebrew](https://brew.sh)
2. `git clone https://github.com/lwopgkne-byte/pour-ios.git && cd pour-ios`
3. `scripts/bootstrap.sh`：装 XcodeGen、SwiftLint，启用推送前检查，生成 Xcode 工程（可以重复运行）
4. `scripts/check.sh`：日常检查；`scripts/check.sh --full`：全部审计（每个模块自验收前）
5. `open Pour.xcodeproj`

## 里面有什么

| 目录 | 是什么 |
|---|---|
| `App/` | 正式的 App |
| `Gallery/` | 设计画廊（不上架）：设计规范的全部、样张 |
| `Packages/PourKit/` | PourCore（规则和计算）、PourData、PourAI、PourDesign（设计系统）、PourPlatform |
| `scripts/` | 准备环境、一键检查、截图、装到手机、色板 |
| `fixtures/golden/` | 对拍的标准答案：从网页版规则导出的冻结数据 |
| `docs/` | 全部方案、设计规范、模块方案、验收报告、技术决定（ADR） |

方案从 [docs/README.md](docs/README.md) 读起。

网页版（已冻结）在 [lwopgkne-byte/pour](https://github.com/lwopgkne-byte/pour)，和这里没有代码依赖（[ADR A21](docs/ADR/A21-独立仓库.md)）。
