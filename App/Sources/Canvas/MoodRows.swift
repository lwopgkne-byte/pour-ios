import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情：一条一行（五个小圆点 + 说法 + 情绪词 + 说到时的精力），下面一行是那一刻；按说的先后排；
/// 一天有好几条、说的时间不一样时，每条前面写几点说的（网页版 MoodBody）
struct MoodRows: View {
    let items: [API.Entry]
    let quotes: [String]

    var body: some View {
        let moods = items.sorted { (said($0) ?? "", $0.id) < (said($1) ?? "", $1.id) }
        let times = moods.map { said($0).map(Self.clock) }
        let showTimes = Set(times.compactMap { $0 }).count > 1
        ForEach(Array(moods.enumerated()), id: \.element.id) { index, entry in
            if case .mood(let mood) = entry.data {
                DayRow(entry: entry) {
                    MoodLine(mood: mood, quotes: quotes, time: showTimes ? times[index] : nil)
                }
            }
        }
    }

    /// 建这条心情的那段话是什么时候说的
    private func said(_ entry: API.Entry) -> String? {
        (entry.sources.first { $0.action == "created" } ?? entry.sources.first)?.createdAt
    }

    /// 「16:16」「9:05」：按这台手机的时区
    static func clock(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

struct MoodLine: View {
    let mood: API.MoodData
    let quotes: [String]
    let time: String?

    var body: some View {
        let level = min(5, max(1, Int(mood.mood.rounded())))
        // 那一刻已经整句在当天某条感悟的摘录里：不再写一遍
        let squash = { (text: String) in text.filter { !$0.isWhitespace && !$0.isPunctuation } }
        let moment = mood.moment.flatMap { moment in
            quotes.contains { squash($0).contains(squash(moment)) } ? nil : moment
        }
        VStack(alignment: .leading, spacing: Web.space1) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                if let time {
                    Text(time).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                        .frame(minWidth: Web.space8 + Web.space2, alignment: .leading)
                }
                HStack(spacing: Web.space1) {
                    ForEach(1...5, id: \.self) { dot in
                        Circle().fill(dot <= level ? Web.tag("pink").solid : Web.lineStrong)
                            .frame(width: Web.space1 * 1.5, height: Web.space1 * 1.5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("心情：\(Show.moodWords[level - 1])，五级里的第\(level)级"))
                Text(words(level)).font(Web.body)
            }
            if let moment {
                QuoteText(text: moment).padding(.leading, time == nil ? 0 : Web.space8 + Web.space2 + Web.space2)
            }
        }
    }

    private func words(_ level: Int) -> AttributedString {
        var text = AttributedString(Show.moodWords[level - 1])
        text.font = Web.bodyMedium
        text.foregroundColor = Web.fg
        if !mood.emotions.isEmpty {
            var emotions = AttributedString("  · \(mood.emotions.joined(separator: "、"))")
            emotions.foregroundColor = Web.fgSecondary
            text += emotions
        }
        if let energy = mood.energy {
            var line = AttributedString("  精力\(Show.energyWord(energy))")
            line.foregroundColor = Web.fgTertiary
            text += line
        }
        return text
    }
}
