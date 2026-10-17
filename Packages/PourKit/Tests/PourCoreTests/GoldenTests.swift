import Foundation
import PourCore
import Testing

/// 对拍：读网页版导出的标准答案（fixtures/golden/，scripts/export-golden.ts 生成），逐份比较。
/// 网页版的规则改了 → 重新导出 → 这里变红 → Swift 跟着改（docs/05-测试方案.md 第 4 节）。
@Suite("对拍：和网页版的标准答案一致")
struct GoldenTests {
    @Test func mathRoundMatchesWebVersion() throws {
        let cases = try Golden.load("math").cases["Math.round"] ?? []
        #expect(cases.count >= 300, "标准答案太少，导出脚本是不是坏了")
        var mismatches: [String] = []
        for sample in cases {
            guard let input = sample.input.first?.number, let expected = sample.output.number else {
                Issue.record("读不懂的样例：\(sample)")
                continue
            }
            let actual = jsRound(input)
            if !Golden.same(actual, expected) { mismatches.append("jsRound(\(input)) = \(actual)，网页版 = \(expected)") }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) 处不同：\(mismatches.prefix(5))")
    }
}

/// 标准答案文件的格式：{ cases: { 函数名: [{ in: [参数…], out: 结果 }] } }
enum Golden {
    struct File: Decodable { let cases: [String: [GoldenSample]] }

    /// 仓库根目录下的 fixtures/golden/<name>.json
    static func load(_ name: String) throws -> File {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PourCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // PourKit
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // 仓库根目录
        let url = root.appendingPathComponent("fixtures/golden/\(name).json")
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
    }

    /// 数一样：NaN 等于 NaN；0 和 -0 要区分（JavaScript 里看得出来）
    static func same(_ lhs: Double, _ rhs: Double) -> Bool {
        if lhs.isNaN || rhs.isNaN { return lhs.isNaN && rhs.isNaN }
        return lhs == rhs && lhs.sign == rhs.sign
    }
}

/// 一份样例：参数和网页版的结果
struct GoldenSample: Decodable, CustomStringConvertible {
    let input: [GoldenValue]
    let output: GoldenValue
    enum CodingKeys: String, CodingKey {
        case input = "in"
        case output = "out"
    }
    var description: String { "\(input) → \(output)" }
}

/// 一个值；JSON 表示不了的数写成字符串："-0"、"NaN"、"Infinity"、"-Infinity"
enum GoldenValue: Decodable, CustomStringConvertible {
    case number(Double)
    case string(String)
    case bool(Bool)
    case null
    case other

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .other
        }
    }

    /// 数（包括写成字符串的特殊数）
    var number: Double? {
        switch self {
        case .number(let value): value
        case .string("-0"): -0.0
        case .string("NaN"): .nan
        case .string("Infinity"): .infinity
        case .string("-Infinity"): -.infinity
        default: nil
        }
    }

    var description: String {
        switch self {
        case .number(let value): "\(value)"
        case .string(let value): "\"\(value)\""
        case .bool(let value): "\(value)"
        case .null: "null"
        case .other: "…"
        }
    }
}
