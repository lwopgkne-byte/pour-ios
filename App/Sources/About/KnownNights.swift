import PourAPI
import PourDesign
import SwiftUI

/// 作息那张图（照可交互原型「Pour 认识的 · 作息」）：最近几周一晚一条细线，横着是晚上 9 点到第二天 11 点，
/// 紫色一段是那晚从睡到起；和平时差得多的那几晚是琥珀色。下面一行刻度，再下面一句「和平时差得多的 N 晚」点进去看是哪几晚
struct KnownNights: View {
    let sleep: API.SleepPattern
    let open: () -> Void

    /// 横轴从晚上 9 点开始，一共 14 个小时
    private static let startHour = 21.0
    private static let span = 14.0
    private static let ticks = ["21:00", "0:00", "3:00", "6:00", "9:00", "11:00"]

    var body: some View {
        let odd = Set(sleep.outliers.map(\.entryId))
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            VStack(spacing: Theme.Space.hairline) {
                ForEach(sleep.nights.reversed(), id: \.entryId) { night in
                    line(night, odd: odd.contains(night.entryId))
                }
            }
            HStack {
                ForEach(Self.ticks, id: \.self) { tick in
                    Text(tick)
                    if tick != Self.ticks.last { Spacer(minLength: 0) }
                }
            }
            .font(Theme.Typeface.tick).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            .accessibilityHidden(true)
            if let first = sleep.outliers.first {
                Button(action: open) {
                    Text(Show.spaced(outlierLine(first))).font(Theme.Typeface.footnoteMedium)
                        .foregroundStyle(Theme.Palette.accent).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: Theme.Size.touch, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("known.sleep.outliers")
            }
        }
        .padding(.bottom, Theme.Space.small)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("最近 \(sleep.nights.count) 个晚上几点睡几点起"))
    }

    private func line(_ night: API.Night, odd: Bool) -> some View {
        let from = Self.offset(night.start)
        let to = max(from, Self.offset(night.end))
        return Capsule().fill(Theme.Palette.fill).frame(height: Theme.Space.tight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(odd ? Theme.Palette.ringWarn : Theme.tag("purple").solid)
                        .frame(width: max(Theme.Space.tight, proxy.size.width * (to - from) / Self.span))
                        .offset(x: proxy.size.width * from / Self.span)
                }
            }
            .accessibilityHidden(true)
    }

    /// 「2026-10-19T00:20」→ 从晚上 9 点算起过了几个小时（3.33），夹在图里
    static func offset(_ local: String) -> Double {
        let time = local.dropFirst(11)
        let hour = Double(time.prefix(2)) ?? 0
        let minute = Double(time.dropFirst(3).prefix(2)) ?? 0
        let since = (hour + minute / 60 - startHour + 24).truncatingRemainder(dividingBy: 24)
        return min(span, max(0, since))
    }

    /// 一晚：「和平时差得多的 1 晚：10月19日 2:10 睡 · 记错了就点这一晚改 ›」；好几晚：「和平时差得多的 3 晚 · 记错了就点进去改 ›」
    private func outlierLine(_ first: API.Night) -> String {
        if sleep.outliers.count == 1 {
            return "和平时差得多的 1 晚：\(Show.monthDay(first.day)) \(Show.clock(first.start)) 睡 · 记错了就点这一晚改 ›"
        }
        return "和平时差得多的 \(sleep.outliers.count) 晚 · 记错了就点进去改 ›"
    }
}
