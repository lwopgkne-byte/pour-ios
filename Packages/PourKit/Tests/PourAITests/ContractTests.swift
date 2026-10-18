import Foundation
import PourAI
import PourCore
import Testing

/// 接口契约：手机和网关拿同一对样例核对（网关 `npm run contract` 导出到 gateway/contract/）。
/// 任何一边改了格式，另一边的测试就会失败
@Suite("接口契约 v1")
struct ContractTests {
    static func example(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PourAITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // PourKit
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // 仓库根目录
        return try Data(contentsOf: root.appendingPathComponent("gateway/contract/\(name)"))
    }

    static func withoutNulls(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.filter { !($0.value is NSNull) }.mapValues(withoutNulls)
        }
        if let array = value as? [Any] { return array.map(withoutNulls) }
        return value
    }

    @Test func decodesTheGatewaysChangePackage() throws {
        let change = try JSONDecoder().decode(ChangePackage.self, from: Self.example("example-change-package.json"))
        #expect(change.version == 1)
        #expect(change.intents == ["record"])
        #expect(change.creates.count == 4)
        guard case .event(let lunch) = change.creates[1].data else {
            Issue.record("第二条应该是吃面")
            return
        }
        #expect(lunch.label == "吃面")
        #expect(lunch.start == "2026-10-18T12:00")
        #expect(lunch.people == ["小王"])
        #expect(lunch.metrics.first?.isMoney == true)
        #expect(lunch.metrics.first?.display == "面 ¥32")
        guard case .mood(let mood) = change.creates[2].data else {
            Issue.record("第三条应该是心情")
            return
        }
        #expect(mood.level == 4)
        #expect(change.creates[3].question == "要记一条还小王饭钱的待办吗？")
    }

    /// 手机拼出来的背景包，和网关样例里的一模一样（同样的原话、类别、已有记录）
    @Test func encodesTheSameBackgroundPackageAsTheGateway() throws {
        let example = try Self.example("example-background-package.json")
        let decoded = try JSONDecoder().decode(BackgroundPackage.self, from: example)
        let reencoded = try JSONEncoder().encode(decoded)
        // 两边都把「null」和「没有这个字段」当成一回事（zod 的 nullish、Swift 的可选值）：比之前去掉 null
        let lhs = Self.withoutNulls(try JSONSerialization.jsonObject(with: reencoded)) as? NSDictionary
        let rhs = Self.withoutNulls(try JSONSerialization.jsonObject(with: example)) as? NSDictionary
        #expect(lhs == rhs, "手机写出来的背景包和网关的样例不一样")
        #expect(decoded.note.text == "早上跑了五公里 中午和小王吃面三十二")
        #expect(decoded.existing.count == 2)
    }
}
