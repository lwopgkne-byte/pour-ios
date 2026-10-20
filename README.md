# Pour（倾）· iOS

你只管倾倒，AI 负责把混沌变成结构。这里是 Pour 的 iPhone App（SwiftUI）。它连电脑上的 **Pour 服务器**（仓库 [lwopgkne-byte/pour](https://github.com/lwopgkne-byte/pour)）：数据、业务规则和 AI 都在服务器上，App 是它的界面。现在只做产品主人的 iPhone 15 + iOS 27（最低系统暂时 iOS 27，ADR A03）。

## 开始

1. 从 App Store 装 Xcode 27.1，打开一次；装 [Homebrew](https://brew.sh)
2. `git clone https://github.com/lwopgkne-byte/pour-ios.git && cd pour-ios`
3. `scripts/bootstrap.sh`：装 XcodeGen、SwiftLint，启用推送前检查，生成 Xcode 工程（可以重复运行）
4. `scripts/check.sh`：日常检查；`scripts/check.sh --full`：全部审计（每一块自验收前）
5. `open Pour.xcodeproj`；要连真的数据，先在电脑上把 Pour 服务器起来（见服务器仓库的 README）

## 里面有什么

| 目录 | 是什么 |
|---|---|
| `App/` | 正式的 App：八页、对话、搜索和问答、设置；界面测试用的假服务器 |
| `Packages/PourKit/` | PourAPI（服务器的接口和写法）、PourDesign（设计系统）、PourCore（日期时间的规则）、PourPlatform（系统通知、钥匙串）；PourData、PourAI 是第一阶段的，不用了 |
| `AppUITests/` | 每一页的界面测试和无障碍审计 |
| `Gallery/` | 第一阶段的设计画廊（不上架） |
| `gateway/` | 第一阶段手机自己的 AI 网关，不用了 |
| `scripts/` | 准备环境、一键检查、装到手机、模拟器、色板 |
| `fixtures/golden/` | 对拍的标准答案：服务器的规则导出的数据 |
| `docs/` | 总提示词、现在的 App、技术决定（ADR）、每一块的方案和验收报告、第一阶段的归档 |

从 [docs/README.md](docs/README.md) 读起。
