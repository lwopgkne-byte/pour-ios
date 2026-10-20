import Foundation
import PourCore
import Testing

/// 对拍：读服务器导出的标准答案（fixtures/golden/，scripts/export-golden.ts 生成），逐份比较。
/// 服务器的规则改了 → 重新导出 → 这里变红 → Swift 跟着改（docs/归档/05-测试方案.md 第 4 节）。
@Suite("对拍：和服务器的标准答案一致")
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
            if !Golden.same(actual, expected) { mismatches.append("jsRound(\(input)) = \(actual)，服务器 = \(expected)") }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) 处不同：\(mismatches.prefix(5))")
    }
}

extension GoldenTests {
    /// 日期的 4 个函数
    @Test func datesMatchWebVersion() throws {
        let cases = try Golden.load("date").cases
        let mismatches =
            Self.addDaysMismatches(cases["addDays"] ?? []) + Self.diffDaysMismatches(cases["diffDays"] ?? [])
            + Self.weekdayMismatches(cases["weekdayMon0"] ?? []) + Self.validMismatches(cases["isValidDateStr"] ?? [])
        let total = ["addDays", "diffDays", "weekdayMon0", "isValidDateStr"].reduce(0) { $0 + (cases[$1]?.count ?? 0) }
        #expect(total >= 130, "标准答案太少，导出脚本是不是坏了")
        #expect(mismatches.isEmpty, "\(mismatches.count) 处不同：\(mismatches.prefix(5))")
    }

    static func addDaysMismatches(_ samples: [GoldenSample]) -> [String] {
        samples.compactMap { sample in
            guard case .string(let day) = sample.input[0], let days = sample.input[1].number,
                case .string(let expected) = sample.output
            else { return "读不懂的样例：\(sample)" }
            let actual = PourDate.addDays(day, Int(days))
            return actual == expected ? nil : "addDays(\(day), \(days)) = \(actual)，服务器 \(expected)"
        }
    }

    static func diffDaysMismatches(_ samples: [GoldenSample]) -> [String] {
        samples.compactMap { sample in
            guard case .string(let lhs) = sample.input[0], case .string(let rhs) = sample.input[1],
                let expected = sample.output.number
            else { return "读不懂的样例：\(sample)" }
            let actual = PourDate.diffDays(lhs, rhs)
            return Double(actual) == expected ? nil : "diffDays(\(lhs), \(rhs)) = \(actual)，服务器 \(expected)"
        }
    }

    static func weekdayMismatches(_ samples: [GoldenSample]) -> [String] {
        samples.compactMap { sample in
            guard case .string(let day) = sample.input[0], let expected = sample.output.number else {
                return "读不懂的样例：\(sample)"
            }
            let actual = PourDate.weekdayMon0(day)
            return Double(actual) == expected ? nil : "weekdayMon0(\(day)) = \(actual)，服务器 \(expected)"
        }
    }

    static func validMismatches(_ samples: [GoldenSample]) -> [String] {
        samples.compactMap { sample in
            guard case .bool(let expected) = sample.output else { return "读不懂的样例：\(sample)" }
            // 服务器也接受不是字符串的（null、数字）：都不是合法的日期，Swift 这边类型上就传不进来
            guard case .string(let day) = sample.input[0] else {
                return expected ? "isValidDateStr(\(sample.input[0])) 服务器说合法" : nil
            }
            return PourDate.isValid(day) == expected ? nil : "isValidDateStr(\(day)) 和服务器不一样"
        }
    }

    /// 钟点：parseTime、formatTime
    @Test func clockMatchesWebVersion() throws {
        let cases = try Golden.load("time").cases
        var mismatches: [String] = []
        for sample in cases["parseTime"] ?? [] {
            let input: String? = if case .string(let text) = sample.input[0] { text } else { nil }
            let actual = input.flatMap(PourDate.parseTime).map(Double.init)
            let expected = sample.output.number
            if actual != expected {
                mismatches.append("parseTime(\(sample.input[0])) = \(String(describing: actual))，服务器 \(sample.output)")
            }
        }
        for sample in cases["formatTime"] ?? [] {
            guard let minutes = sample.input[0].number, case .string(let expected) = sample.output else { continue }
            let actual = PourDate.formatTime(minutes)
            if actual != expected { mismatches.append("formatTime(\(minutes)) = \(actual)，服务器 \(expected)") }
        }
        #expect((cases["parseTime"]?.count ?? 0) + (cases["formatTime"]?.count ?? 0) >= 80)
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

/// 一份样例：参数和服务器的结果
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
