import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天：每一刻一行（几点 · 表情 · 说法 · 情绪词），下面是那一刻（宋体原话）；点一行打开那一条心情。
/// 刚记下还在整理的那一刻先显示（「整理中」）
struct MoodTodayCard: View {
    @Environment(AppModel.self) private var model
    let page: API.MoodPage

    var body: some View {
        let pending = model.mood.pending.filter { $0.day == page.today }
        PageSection(title: "今天", meta: page.todaySummary) { moments(pending) }
    }

    @ViewBuilder private func moments(_ pending: [PendingMood]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if page.todayMoments.isEmpty && pending.isEmpty {
                Text("今天还没说心情。点上面一个表情就记下了，想说为什么再说。").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            ForEach(page.todayMoments) { moment in
                Button {
                    model.mood.detail = moment
                } label: {
                    MoodMomentRow(moment: moment).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mood.moment")
            }
            ForEach(pending) { MoodPendingRow(pending: $0) }
        }
    }
}

/// 一刻心情：几点、表情、说法、情绪词、说到时的精力；下面那一刻（宋体，左边一条线）
struct MoodMomentRow: View {
    let moment: API.MoodMoment
    var showTime = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .center, spacing: Theme.Space.small) {
                if showTime {
                    Text(moment.time ?? "").font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(minWidth: Theme.Size.touch, alignment: .leading)
                }
                MoodBadge(level: moment.level, size: Theme.Size.tile)
                Text(moment.word).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                if let detail {
                    Text(detail).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
            }
            if let said = moment.moment {
                Text(said).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Theme.Space.small)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.Palette.separator).frame(width: Theme.Space.hairline)
                    }
                    .padding(.leading, showTime ? Theme.Size.touch + Theme.Space.small : 0)
            }
        }
        .padding(.vertical, Theme.Space.tight)
        .accessibilityElement(children: .combine)
    }

    /// 「开心、放松 · 精力有点累」
    private var detail: String? {
        let emotions: String? = moment.emotions.isEmpty ? nil : moment.emotions.joined(separator: "、")
        let energy: String? = moment.energy.map { "精力\(Show.energyWord($0))" }
        let text = [emotions, energy].compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}

/// 刚记下、还在整理的一刻：右边小字「整理中」
struct MoodPendingRow: View {
    let pending: PendingMood

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(spacing: Theme.Space.small) {
                Text(pending.time).font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.touch, alignment: .leading)
                MoodBadge(level: pending.level, size: Theme.Size.tile)
                Text(MoodText.names[pending.level - 1]).font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(Theme.Palette.label)
                if !pending.emotions.isEmpty {
                    Text(pending.emotions.joined(separator: "、")).font(Theme.Typeface.subheadline)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
                Text("整理中").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            if let because = pending.because {
                Text(because).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.leading, Theme.Size.touch + Theme.Space.small)
            }
        }
        .padding(.vertical, Theme.Space.tight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mood.pending")
    }
}

/// 这个月：上面一行平均和几天；心情月历（每一格那天的表情，没说的「—」），左右滑或 ‹ › 换月；
/// 点一天下面出现那天的每一刻（再点一次收起）
struct MoodMonthCard: View {
    @Environment(AppModel.self) private var model
    let page: API.MoodPage
    @Binding var picked: String?
    let changeMonth: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(Show.monthName(page.month)).font(Theme.Typeface.pageSection).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                arrow("chevron.left", label: "上个月", to: page.prevMonth)
                arrow("chevron.right", label: "下个月", to: page.nextMonth)
            }
            .padding(.leading, Theme.Space.tight)
            .padding(.top, Theme.Space.medium)
            grid
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(page.monthLine ?? "\(Show.monthName(page.month))还没说到心情。").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel)
            MoodMonthGrid(blanks: blanks, days: days, today: page.current ? page.today : nil, selected: picked) { day in
                withAnimation(Theme.Motion.standard) { picked = picked == day ? nil : day }
            }
            .gesture(
                DragGesture(minimumDistance: Theme.Size.touch).onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                    if drag.translation.width < 0, let next = page.nextMonth { changeMonth(next) }
                    if drag.translation.width > 0, let prev = page.prevMonth { changeMonth(prev) }
                })
            if let picked { dayMoments(picked) }
        }
        .themeCard(radius: Theme.Corner.smallCard)
    }

    private func arrow(_ symbol: String, label: String, to month: String?) -> some View {
        Button {
            if let month { changeMonth(month) }
        } label: {
            Image(systemName: symbol).font(Theme.Typeface.footnoteSemibold)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(month == nil ? Theme.Palette.tertiaryLabel : Theme.Palette.accent)
        .disabled(month == nil)
        .accessibilityLabel(Text(label))
    }

    private var blanks: Int { PourDate.weekdayMon0("\(page.month)-01") }

    private var days: [MoodMonthGrid.Day] {
        let count = (28...31).last { PourDate.isValid("\(page.month)-\(String(format: "%02d", $0))") } ?? 30
        let byDay = Dictionary(page.days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        return (1...count).map { number in
            let day = "\(page.month)-\(String(format: "%02d", number))"
            let found = byDay[day]
            let spoken = "\(Show.monthDay(day))，\(found?.word ?? "没说心情")"
            return MoodMonthGrid.Day(day: day, number: number, level: found?.level, spoken: spoken)
        }
    }

    /// 点的那一天：那天的每一刻；没说心情写清楚
    @ViewBuilder private func dayMoments(_ day: String) -> some View {
        let found = page.days.first { $0.day == day }
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Divider()
            Text("\(Show.monthDay(day)) \(Show.weekday(day))\(found.map { " · \($0.word)" } ?? "")")
                .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .frame(minHeight: Theme.Size.touch)
                .accessibilityIdentifier("mood.pickedDay")
            if let found {
                ForEach(found.moments) { moment in
                    Button {
                        model.mood.detail = moment
                    } label: {
                        MoodMomentRow(moment: moment).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("那天没说心情").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.bottom, Theme.Space.small)
            }
        }
        .transition(.opacity)
    }
}
