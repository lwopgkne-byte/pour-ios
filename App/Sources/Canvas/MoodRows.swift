import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一条心情（回顾页用；画布 2.0 的心情卡在 CardBodies3）：五个小圆点 + 说法 + 情绪词 + 说到时的精力，下面一行是那一刻
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
