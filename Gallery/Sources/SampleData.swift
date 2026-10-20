import Foundation
import PourDesign

/// 样张用的示例数据（Gallery/Resources/Sample.json：演示数据里真实的一天，冻结的数据，出处写在文件开头）
struct Sample: Decodable {
    struct Goal: Decodable, Identifiable {
        var id: String { name }
        let name: String
        let fraction: Double
        let headline: String
        let behind: Bool
        let domain: String
    }

    struct TimelineItem: Decodable, Identifiable {
        let id = UUID()
        let quote: String
        let kind: String
        let time: String?
        let domain: String?
        let title: String?
        let value: String?
        let person: String?
        let level: Int?
        let feeling: String?
        let moment: String?
        let done: Bool?
        let due: String?

        private enum CodingKeys: String, CodingKey {
            case quote, kind, time, domain, title, value, person, level, feeling, moment, done, due
        }
    }

    struct Today: Decodable {
        let title: String
        let weekday: String
        let summary: String
        let goals: [Goal]
        let timeline: [TimelineItem]
    }

    struct ReceiptLineData: Decodable {
        let domain: String
        let title: String
        let person: String?
        let value: String?
    }

    struct Receipt: Decodable {
        let quote: String
        let lines: [ReceiptLineData]
    }

    struct MoneyDomain: Decodable, Identifiable {
        var id: String { name }
        let name: String
        let domain: String
        let amount: String
    }

    struct Watch: Decodable, Identifiable {
        var id: String { name }
        let name: String
        let amount: String
        let sub: String
    }

    struct Money: Decodable {
        let month: String
        let spent: String
        let count: Int
        let compare: String?
        let firstWeekday: Int
        let today: Int?
        let calendar: [Double?]
        let domains: [MoneyDomain]
        let watch: [Watch]
    }

    struct Tile: Decodable {
        let name: String
        let domain: String
        let notes: Int
    }

    struct Finding: Decodable {
        let sentence: String
        let these: Double
        let others: Double
        let basis: String
    }

    struct MoneyAngle: Decodable {
        let big: String
        let sub: String
        let week: [Double]
    }

    struct About: Decodable {
        let caption: String
        let tiles: [Tile]
        let finding: Finding?
        let moneyAngle: MoneyAngle?
    }

    struct Review: Decodable, Identifiable {
        var id: String { title + summary }
        let title: String
        let summary: String
        let kind: String
    }

    let day: String
    let today: Today
    let receipt: Receipt?
    let money: Money
    let about: About
    let review: [Review]

    static let shared: Sample = {
        guard let url = Bundle.main.url(forResource: "Sample", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let sample = try? JSONDecoder().decode(Sample.self, from: data)
        else { fatalError("Sample.json 读不出来：文件坏了或者没打进画廊 App") }
        return sample
    }()
}

extension String {
    /// 示例数据里的领域名 → 领域色
    var pourDomain: PourDomain { PourDomain(rawValue: self) ?? .stone }
}
