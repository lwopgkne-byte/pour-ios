import PourAPI
import PourCore
import PourDesign
import SwiftUI

// MARK: - 健康 App 的步数、睡眠、锻炼（docs/模块/产品优化.md R5）

/// 接上健康的小卡：只在看今天、这台设备有健康 App、还没接、没点掉时出现。
/// 点「接上」才问系统要权限；「不用」点掉，以后在设置里也能接
struct HealthHint: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.shownDay == model.today, model.showHealthHint {
            ConnectHint(
                key: "health", symbol: "heart.fill", color: "pink", title: "接上健康：步数、睡眠、锻炼自动出现",
                text: "只读这三样，不往健康里写。送到电脑上的 Pour，算进目标、回顾和问答；你说过的为准，同一次只算一次。",
                connect: model.connectHealth
            ) {
                model.health.closeHint()
                model.toast("以后在「设置 → 健康」里也能接上")
            }
        }
    }
}

/// 接上一样系统里的东西（健康、日历）的那张安静的小卡：图标和一句话、为什么要、「接上」「不用」
struct ConnectHint: View {
    /// 界面测试找按钮用：health.connect、calendar.dismiss……
    let key: String
    let symbol: String
    let color: String
    let title: String
    let text: String
    let connect: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.small) {
                IconTile(symbol: symbol, emoji: "", color: Theme.tag(color))
                Text(Show.spaced(title)).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(Show.spaced(text)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .lineSpacing(Theme.Leading.body)
            HStack(spacing: Theme.Space.small) {
                Button("接上", action: connect).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("\(key).connect")
                Button("不用", action: dismiss).buttonStyle(.bordered).accessibilityIdentifier("\(key).dismiss")
            }
            .font(Theme.Typeface.footnoteSemibold).buttonBorderShape(.capsule).tint(Theme.Palette.accentFill)
        }
        .themeCard()
        .accessibilityElement(children: .contain)
    }
}

/// 运动卡上的步数：这张卡只有步数时写大字，还有别的运动时写一小行
struct StepsLine: View {
    let steps: Int
    let alone: Bool

    var body: some View {
        Group {
            if alone {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    FigureText([(steps.formatted(), "步")])
                    ThemeBadge(HealthTag.fromApp)
                }
            } else {
                HStack(spacing: Theme.Space.small) {
                    Label("\(steps.formatted()) 步", systemImage: "figure.walk").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    ThemeBadge(HealthTag.fromApp)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("canvas.steps")
    }
}

/// 名字和小标签（「来自健康」）：放得下排一行，放不下（半宽的卡）标签换到下一行，名字不被挤得截断
struct TaggedLabel<Label: View>: View {
    let tag: String?
    @ViewBuilder let label: () -> Label

    var body: some View {
        if let tag {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                    label()
                    ThemeBadge(tag)
                }
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    label()
                    ThemeBadge(tag)
                }
            }
        } else {
            label()
        }
    }
}

/// 一条记录旁边的小标签：健康 App 记的写「来自健康」；你说的、补上了手表的时间距离的写补了哪几样
enum HealthTag {
    static let fromApp = "来自健康"

    static func text(_ entry: API.Entry) -> String? {
        if entry.fromHealthApp { return fromApp }
        guard let filled = entry.fromHealth, !filled.isEmpty else { return nil }
        return "\(filled.joined(separator: "、"))来自健康"
    }
}

/// 健康 App 记的那条的详情：只能看。要改、要删在健康 App 里；你说一句同一件事，就用你说的
struct HealthPeek: View {
    let entry: API.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space4) {
            if let event = CanvasPlan.event(entry) {
                VStack(spacing: 0) {
                    if let start = event.start, let end = event.end {
                        PeekRow(label: "时间") { Text("\(Show.clock(start))–\(Show.clock(end))").monospacedDigit() }
                    }
                    let minutes = CanvasPlan.minutes(event)
                    if minutes > 0 { PeekRow(label: "时长") { Text(Show.spaced(Show.minutes(minutes))) } }
                    ForEach(event.metrics ?? [], id: \.self) { metric in
                        PeekRow(label: metric.name) { Text(Show.spaced("\(Show.amount(metric.value)) \(metric.unit)")) }
                    }
                }
            }
            Text(Show.spaced("健康 App 记的（手表或手机），你没说过。要改、要删，在健康 App 里；你说一句同一件事，就用你说的。"))
                .font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: "x-apple-health://") {
                Link("打开健康", destination: url).font(Web.bodyMedium).foregroundStyle(Web.accent)
                    .frame(minHeight: Web.touch)
            }
        }
        .accessibilityIdentifier("detail.health")
    }
}
