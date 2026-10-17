public import SwiftUI

// 组织级组件（docs/ios/设计规范/08-组件.md「组织」）

/// 时间轴的一行：左边时间列（等宽、右对齐）、中间竖线和领域色点、右边内容
public struct PourTimelineRow<Content: View>: View {
    let time: String?
    let domain: PourDomain?
    let isLast: Bool
    let content: Content

    public init(time: String?, domain: PourDomain?, isLast: Bool = false, @ViewBuilder content: () -> Content) {
        self.time = time
        self.domain = domain
        self.isLast = isLast
        self.content = content()
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // 大字号：时间列移到内容上方（规范 11 第 2 节），色点跟着时间
            VStack(alignment: .leading, spacing: PourSpace.tight) {
                HStack(spacing: PourSpace.related) {
                    if let domain { PourDomainDot(domain, size: PourSize.timelineDot) }
                    if let time {
                        Text(time).pourText(.caption).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : PourSpace.card)
        } else {
            HStack(alignment: .top, spacing: PourSpace.element) {
                Text(time ?? "")
                    .pourText(.caption).monospacedDigit()
                    .foregroundStyle(PourColor.inkSecondary.color)
                    .frame(width: PourSize.timelineTimeColumn - PourSpace.element, alignment: .trailing)
                    .padding(.top, 3)
                ZStack(alignment: .top) {
                    if !isLast { Rectangle().fill(PourColor.line.color).frame(width: 1).padding(.top, 14) }
                    if let domain {
                        PourDomainDot(domain, size: PourSize.timelineDot).padding(.top, 6)
                    } else {
                        Circle().strokeBorder(PourColor.lineStrong.color, lineWidth: 1)
                            .frame(width: PourSize.timelineDot, height: PourSize.timelineDot).padding(.top, 6)
                    }
                }
                .frame(width: PourSize.timelineDot)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, isLast ? 0 : PourSpace.card)
            }
        }
    }
}

/// 日子头：大标题（今天 / 昨天 / 10月14日）+ 副标题（周几 · 一句话总结，带 AI 标识）
public struct PourDayHeader: View {
    let title: String
    let weekday: String
    let summary: String

    public init(title: String, weekday: String, summary: String) {
        self.title = title
        self.weekday = weekday
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            Text(title).pourText(.titlePage).foregroundStyle(PourColor.ink.color).accessibilityAddTraits(.isHeader)
            PourAIText("\(weekday) · \(summary)", style: .meta, color: PourColor.inkSecondary)
        }
    }
}

/// 目标进度的一行（「今天」顶部最多 3 条）：名字、进度条、右侧一句；落后用琥珀色文字说，不变色
public struct PourGoalRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let name: String
    let fraction: Double
    let headline: String
    let behind: Bool
    let domain: PourDomain

    public init(name: String, fraction: Double, headline: String, behind: Bool, domain: PourDomain) {
        self.name = name
        self.fraction = fraction
        self.headline = headline
        self.behind = behind
        self.domain = domain
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 大字号时名字和那一句上下两行，不挤成两条窄列
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: PourSpace.tight))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: PourSpace.related))
            layout {
                Text(name).pourText(.callout).foregroundStyle(PourColor.ink.color)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: PourSpace.related) }
                Text(headline).pourText(.caption).monospacedDigit()
                    .foregroundStyle((behind ? PourColor.attention : PourColor.inkSecondary).color)
            }
            PourProgressBar(fraction, domain: domain)
        }
        .accessibilityElement(children: .combine)
    }
}
