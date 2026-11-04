import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 健康（可交互原型「健康」；「我的 → 记录 → 健康」进来；要服务器 2.20.0）：健康 App 来的（手表或手机）和你说的放在一起，
/// 你说的为准、同一次只算一次——步数（圆环、目标）、昨晚那一觉（几点到几点、21:00–9:00 上的一段）、最近 7 天的锻炼
/// （右边小标签「你说过」「来自健康」）；最下面一句只读这三样、一行去设置里的健康和日历
struct HealthHomePage: View {
    @Environment(AppModel.self) private var model
    @State private var page: API.HealthPage?
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("来自健康 App（手表或手机）；你说过的为准，同一次只算一次").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.tight).padding(.bottom, Theme.Space.medium)
                if let page {
                    content(page)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.section)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.section)
        }
        .background(Theme.Palette.background)
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.HealthPage) -> some View {
        if !page.connected { notConnected }
        if let steps = page.steps { StepsCard(steps: steps, today: page.today) }
        if let sleep = page.sleep {
            header(sleep.day == page.today ? "昨晚" : "前一晚 · \(Show.monthDay(sleep.day))")
            SleepCard(sleep: sleep)
        }
        header("最近 7 天的锻炼")
        workouts(page.workouts)
        Text("健康 App 记的（手表或手机），你没说过。要改、要删，在健康 App 里；你说一句同一件事，就用你说的。只读这三样，不往健康里写。")
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Space.tight).padding(.top, Theme.Space.small)
        settingsRow.padding(.top, Theme.Space.medium)
    }

    /// 还没接上健康：说清楚接上了会有什么，下面一行去设置
    private var notConnected: some View {
        Text("还没接上健康 App。接上以后，手表或手机记的步数、睡眠、锻炼会出现在这里；现在只有你说过的。")
            .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard(radius: Theme.Corner.smallCard)
            .padding(.bottom, Theme.Space.medium)
    }

    /// 区块标题（原型 .sh：卡片外面、左边粗字）
    private func header(_ title: String) -> some View {
        PageSectionHeader(title: title)
            .padding(.top, Theme.Space.xLarge).padding(.bottom, Theme.Space.small)
    }

    /// 锻炼：一组白底的行（原型 .grp），右边小标签分清是你说的还是健康 App 记的
    @ViewBuilder private func workouts(_ items: [API.HealthItem]) -> some View {
        if items.isEmpty {
            Text("最近 7 天没有锻炼。说一句「跑了 5 公里」，或者戴着手表练，这里就会有。")
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard(radius: Theme.Corner.smallCard)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider().padding(.leading, Theme.Space.regular) }
                    WorkoutRow(item: item)
                }
            }
            .themeCard(radius: Theme.Corner.smallCard, padding: 0)
        }
    }

    private var settingsRow: some View {
        Button {
            model.open("/settings#health")
        } label: {
            HStack {
                Text("设置 → 健康、日历").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .padding(.horizontal, Theme.Space.regular)
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
            .themeCard(radius: Theme.Corner.smallCard, padding: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityIdentifier("health.settings")
    }

    private func load() async {
        if page == nil, let saved: API.HealthPage = model.client.cached("/api/health/page") { page = saved }
        do throws(APIError) {
            page = try await model.client.healthPage()
            problem = nil
        } catch {
            // 服务器还是旧的（没有这一页）：说清楚要更新
            guard page == nil else { return }
            if case .server(404, _, _) = error {
                problem = "电脑上的 Pour 要更新到 2.20.0 才有这一页。"
            } else {
                problem = error.message
            }
        }
    }
}

/// 步数：左边圆环（走到目标的几成，中间写百分比），右边大字「6,039 步」和「今天 · 目标每天 8,000 步 · 来自健康」
private struct StepsCard: View {
    let steps: API.HealthPage.Steps
    let today: String

    var body: some View {
        HStack(spacing: Theme.Space.regular) {
            if let goal = steps.goal, goal > 0 {
                let share = steps.count / goal
                ZStack {
                    ProgressRing(progress: min(1, share), color: Theme.Palette.bad, lineWidth: Theme.Space.small + 1)
                    Text("\(Int((share * 100).rounded()))%").font(Theme.Typeface.rowNumber).monospacedDigit()
                        .foregroundStyle(Theme.Palette.label)
                }
                .frame(width: Theme.Size.ring * 1.65, height: Theme.Size.ring * 1.65)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("\(steps.count.formatted(.number.grouping(.automatic))) 步").font(Theme.Typeface.metric)
                    .monospacedDigit().foregroundStyle(Theme.Palette.label)
                Text(line).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .themeCard(radius: Theme.Corner.smallCard)
        .accessibilityElement(children: .combine)
    }

    /// 「今天 · 目标每天 8,000 步 · 来自健康」
    private var line: String {
        var parts = [steps.day == today ? "今天" : (Show.relative(steps.day, today: today) ?? Show.monthDay(steps.day))]
        if let goal = steps.goal { parts.append("目标每天 \(goal.formatted(.number.grouping(.automatic))) 步") }
        parts.append(steps.said ? "你说的" : "来自健康")
        return parts.joined(separator: " · ")
    }
}

/// 那一觉：「0:10 – 7:00 · 6 小时 50 分」，下面 21:00 到 9:00 的一条，睡着的那一段紫色；再一行说哪几样是健康 App 记的
private struct SleepCard: View {
    let sleep: API.HealthItem

    /// 21:00 起算，12 个小时
    private static let axisStart = 21 * 60
    private static let axisLength = 12 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.heroMetric).monospacedDigit().foregroundStyle(Theme.Palette.label)
            if let span {
                GeometryReader { geometry in
                    Capsule().fill(Theme.Palette.fill)
                    Capsule().fill(Theme.tag("purple").solid)
                        .frame(width: max(Theme.Space.small, geometry.size.width * span.width))
                        .offset(x: geometry.size.width * span.left)
                }
                .frame(height: Theme.Size.bar + Theme.Space.hairline)
                .accessibilityHidden(true)
                HStack {
                    Text("21:00")
                    Spacer()
                    Text("3:00")
                    Spacer()
                    Text("9:00")
                }
                .font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                .accessibilityHidden(true)
            }
            Text(note).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(radius: Theme.Corner.smallCard)
        .accessibilityElement(children: .combine)
    }

    /// 「0:10 – 7:00 · 6 小时 50 分」；没说几点的只写多久
    private var title: String {
        var parts: [String] = []
        if let start = sleep.start, let end = sleep.end { parts.append("\(Self.clock(start)) – \(Self.clock(end))") }
        if let minutes = sleep.minutes { parts.append(Self.duration(minutes)) }
        return parts.isEmpty ? sleep.label : parts.joined(separator: " · ")
    }

    /// 哪几样是谁记的
    private var note: String {
        if !sleep.said { return "健康 App 记的，你没说过" }
        if sleep.fromHealth.isEmpty { return "你说的" }
        return "你说的；\(sleep.fromHealth.joined(separator: "、"))是健康 App 补上的"
    }

    /// 在 21:00–9:00 上的哪一段（0–1）
    private var span: (left: Double, width: Double)? {
        guard let start = sleep.start.flatMap(Self.minutes), let end = sleep.end.flatMap(Self.minutes) else {
            return nil
        }
        let from = Double((start - Self.axisStart + 1440) % 1440)
        let until = Double((end - Self.axisStart + 1440) % 1440)
        let axis = Double(Self.axisLength)
        let left = min(axis, from) / axis
        return (left, max(0, min(axis, until) / axis - left))
    }

    private static func minutes(_ local: String) -> Int? { PourDate.minutesOfDay(local) }

    /// 「2026-11-02T07:00」→「7:00」
    static func clock(_ local: String) -> String {
        guard let minutes = minutes(local) else { return "" }
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// 410 →「6 小时 50 分」
    static func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest) 分钟" }
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }
}

/// 一次锻炼：名字、「10月31日 · 8.4 公里 · 50 分钟」，右边「你说过」（蓝）或「来自健康」（灰）
private struct WorkoutRow: View {
    let item: API.HealthItem

    var body: some View {
        HStack(spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(Show.spaced(item.label)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Text(sub).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            }
            Spacer(minLength: 0)
            Text(item.said ? "你说过" : "来自健康").font(Theme.Typeface.caption)
                .foregroundStyle(item.said ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.snug + 1).frame(minHeight: Theme.Size.badge - Theme.Space.hairline)
                .background(
                    item.said ? Theme.Palette.bubble : Theme.Palette.fillStrong, in: Theme.rounded(Theme.Corner.tail))
        }
        .padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.medium)
        .accessibilityElement(children: .combine)
    }

    /// 「10月31日 · 8.4 公里 · 50 分钟」
    private var sub: String {
        var parts = [Show.monthDay(item.day)]
        if let distance = item.kilometers {
            parts.append("\(distance.formatted(.number.precision(.fractionLength(0...1)))) 公里")
        }
        if let minutes = item.minutes { parts.append(SleepCard.duration(minutes)) }
        return parts.joined(separator: " · ")
    }
}
