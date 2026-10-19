import PourCore
import PourDesign
import SwiftUI

/// 心情：一条一行（五个小圆点 + 说法 + 情绪词 + 说到时的精力），下面一行是那一刻；
/// 一天有好几条、说的时间不一样时，每条前面写几点说的
struct MoodRows: View {
    let items: [Entry]
    let notes: [Note]
    let quotes: [String]

    var body: some View {
        let said = Dictionary(notes.map { ($0.id, $0.localTime) }, uniquingKeysWith: { first, _ in first })
        let moods = items.sorted { (said[$0.noteId] ?? "") < (said[$1.noteId] ?? "") }
        let times = moods.map { said[$0.noteId].map(WebText.clock) }
        let showTimes = Set(times.compactMap { $0 }).count > 1
        ForEach(Array(moods.enumerated()), id: \.element.id) { index, entry in
            if case .mood(let mood) = entry.data {
                DayRow(entry: entry) {
                    MoodLine(mood: mood, quotes: quotes, time: showTimes ? times[index] : nil)
                }
            }
        }
    }
}

struct MoodLine: View {
    let mood: RecordData.Mood
    let quotes: [String]
    let time: String?

    var body: some View {
        let level = min(5, max(1, mood.level))
        let moment = mood.moment.flatMap { moment in
            quotes.contains {
                $0.replacingOccurrences(of: " ", with: "").contains(moment.replacingOccurrences(of: " ", with: ""))
            }
                ? nil : moment
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
                .accessibilityLabel(Text("心情：\(PourFormat.moodWord(level))，五级里的第\(level)级"))
                Text(moodText(level)).font(Web.body)
            }
            if let moment {
                QuoteText(text: moment).padding(.leading, time == nil ? 0 : Web.space8 + Web.space2 + Web.space2)
            }
        }
    }

    private func moodText(_ level: Int) -> AttributedString {
        var text = AttributedString(PourFormat.moodWord(level))
        text.font = Web.bodyMedium
        text.foregroundColor = Web.fg
        if !mood.emotions.isEmpty {
            var emotions = AttributedString("  · \(mood.emotions.joined(separator: "、"))")
            emotions.foregroundColor = Web.fgSecondary
            text += emotions
        }
        if let energy = mood.energy {
            var line = AttributedString("  精力\(PourFormat.energyWord(energy))")
            line.foregroundColor = Web.fgTertiary
            text += line
        }
        return text
    }
}
