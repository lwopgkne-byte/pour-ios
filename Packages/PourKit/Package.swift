// swift-tools-version: 6.2
// Pour 的分层代码包（docs/03-架构与开发方案.md 第 6.1 节）。
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
        .library(name: "PourData", targets: ["PourData"]),
        .library(name: "PourAI", targets: ["PourAI"]),
        .library(name: "PourDesign", targets: ["PourDesign"]),
        .library(name: "PourPlatform", targets: ["PourPlatform"]),
    ],
    // 第三方库：每一个都先写进 ADR（A18），scripts/check-deps.py 核对
    dependencies: [
        // 本机数据库（ADR A05）：MIT 许可证；钉在一个版本上，升级先看更新说明、跑全部数据测试
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")
    ],
    targets: [
        // 领域：规则和计算、格式化。只用 Foundation
        .target(name: "PourCore", swiftSettings: swiftSettings),
        // 数据：表结构、迁移、仓储、同步（M2 起）。预置类别放在 Resources/categories.json（网关的测试也读它）
        .target(
            name: "PourData",
            dependencies: ["PourCore", .product(name: "GRDB", package: "GRDB.swift")],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings),
        // AI：网关客户端、理解服务、问答、端侧语音和向量（M2 起）
        .target(name: "PourAI", dependencies: ["PourCore", "PourData"], swiftSettings: swiftSettings),
        // 设计系统：令牌、组件。只用 SwiftUI，不认识业务
        .target(name: "PourDesign", swiftSettings: swiftSettings),
        // 系统能力：通知、后台任务、钥匙串、Face ID（以后）
        .target(name: "PourPlatform", dependencies: ["PourCore", "PourData"], swiftSettings: swiftSettings),

        .testTarget(name: "PourCoreTests", dependencies: ["PourCore"], swiftSettings: swiftSettings),
        .testTarget(name: "PourDataTests", dependencies: ["PourData", "PourCore"], swiftSettings: swiftSettings),
        .testTarget(
            name: "PourAITests", dependencies: ["PourAI", "PourData", "PourCore"], swiftSettings: swiftSettings),
        .testTarget(name: "PourDesignTests", dependencies: ["PourDesign"], swiftSettings: swiftSettings),
        .testTarget(
            name: "PourPlatformTests", dependencies: ["PourPlatform", "PourData"], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
