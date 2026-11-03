// swift-tools-version: 6.2
// Pour 的分层代码包（docs/归档/03-架构与开发方案.md 第 6.1 节）。
// 每一层只能依赖下面「dependencies」里写明的层：没写的，import 了也编译不过——依赖方向靠编译器守住。
// scripts/check-deps.py 再核对一遍这张表和 6.1 节一致（功能包之间不许互相依赖、不许有没写进 ADR 的第三方库）。

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // A1：Swift 6 严格并发；以后的 Swift 新规则提前打开，升级时不用大改
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "PourKit",
    defaultLocalization: "zh-Hans",
    // macOS 只为了在 Mac 命令行上直接跑规则的测试和对拍（A7），App 只上 iPhone
    platforms: [.iOS("27.0"), .macOS(.v26)],  // iOS 跟 App 一样（ADR A03）；macOS 是这台 Mac 跑规则测试用的
    products: [
        .library(name: "PourCore", targets: ["PourCore"]),
        .library(name: "PourDesign", targets: ["PourDesign"]),
        .library(name: "PourPlatform", targets: ["PourPlatform"]),
        .library(name: "PourAPI", targets: ["PourAPI"]),
    ],
    // 第三方库：每一个都先写进 ADR（A18），scripts/check-deps.py 核对。现在一个都没有
    // （3.0 第 0 步删掉了第一阶段手机上的本机数据库和它用的第三方库：数据都在服务器上，ADR A22）
    dependencies: [],
    targets: [
        // 领域：规则和计算、格式化。只用 Foundation
        .target(name: "PourCore", swiftSettings: swiftSettings),
        // 设计系统：令牌、组件。只用 SwiftUI，不认识业务
        .target(name: "PourDesign", swiftSettings: swiftSettings),
        // 系统能力：通知、后台任务、钥匙串、健康、日历、语音
        .target(name: "PourPlatform", dependencies: ["PourCore"], swiftSettings: swiftSettings),
        // 服务器的接口（产品主人 2026-10-19 选 B：业务规则和 AI 用 Pour 服务器，手机只做界面）：只用系统框架
        .target(name: "PourAPI", dependencies: ["PourCore"], swiftSettings: swiftSettings),

        .testTarget(name: "PourCoreTests", dependencies: ["PourCore"], swiftSettings: swiftSettings),
        .testTarget(name: "PourDesignTests", dependencies: ["PourDesign"], swiftSettings: swiftSettings),
        .testTarget(
            name: "PourAPITests", dependencies: ["PourAPI"], resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings),
        .testTarget(name: "PourPlatformTests", dependencies: ["PourPlatform"], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
