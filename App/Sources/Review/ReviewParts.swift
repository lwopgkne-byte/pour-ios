import PourAPI
import PourDesign
import SwiftUI

/*
 * 每日回顾、周报、月报共用的几样（docs/prd-report.md：同样的东西在所有地方一样）：
 * 一页的开头、关键数字、一个部分、目标一行、加载中的样子、左右滑翻上一页下一页
 */

/// 一页的开头：小字的「每日回顾」（点了回到列表）、「· 已更新」，大标题和后面灰色的「昨天」「上周」，一句话概括
struct ReviewHead: View {
    let kicker: String
    let updated: Bool
    let title: String
    let relative: String?
    let overview: String
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            HStack(spacing: Web.space2) {
                // 看起来是一行小字，能点的范围撑到 44 点
                Text(kicker).font(Web.caption).foregroundStyle(Web.fgTertiary).tracking(Web.kickerTracking)
                    .accessibilityHidden(true)
                    .overlay {
                        Button(action: back) {
                            Color.clear.frame(minWidth: Web.touch, minHeight: Web.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(kicker))
                        .accessibilityHint(Text("回到回顾列表"))
                    }
                if updated {
                    Text("· 已更新").font(Web.caption).foregroundStyle(Web.fgTertiary).tracking(Web.kickerTracking)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
                Text(Show.spaced(title)).font(Web.title).foregroundStyle(Web.fg)
                if let relative { Text(relative).font(Web.section).foregroundStyle(Web.fgTertiary) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            // 每日回顾的总结写在下面「这一天的样子」里（传空的），周报月报照旧写在这里
            if !overview.isEmpty {
                Text(Show.spaced(overview)).font(Web.section).foregroundStyle(Web.fg)
                    .lineSpacing(Web.overviewLineSpacing)
                    .padding(.top, Web.space2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 关键数字：全页唯一的焦点（浅灰底的一块，手机上两列）
struct KeyNumbers: View {
    let numbers: [API.KeyNumber]

    var body: some View {
        if !numbers.isEmpty {
            // 手机上两列（普通的格子，不用懒加载：字号变了不重建）
            Grid(alignment: .topLeading, horizontalSpacing: Web.space4, verticalSpacing: Web.space4) {
                ForEach(Array(stride(from: 0, to: numbers.count, by: 2)), id: \.self) { start in
                    GridRow {
                        cell(numbers[start])
                        if start + 1 < numbers.count {
                            cell(numbers[start + 1])
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Web.space4)
            .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
            .padding(.top, Web.space8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("关键数字"))
        }
    }

    private func cell(_ number: API.KeyNumber) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(value(number))
            Text(Show.spaced(number.label)).font(Web.caption).foregroundStyle(Web.fgSecondary)
                .padding(.top, Web.space1)
            if let compare = number.compare {
                Text(Show.spaced(compare)).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// 大号的数字（半粗）、小号的单位
    private func value(_ number: API.KeyNumber) -> AttributedString {
        number.parts.reduce(into: AttributedString()) { text, part in
            var digits = AttributedString(part.number)
            digits.font = Web.displaySemibold
            digits.foregroundColor = Web.fg
            text += digits
            if !part.unit.isEmpty {
                var unit = AttributedString("\u{2006}\(part.unit)\u{2006}")
                unit.font = Web.caption
                unit.foregroundColor = Web.fgSecondary
                text += unit
            }
        }
    }
}

/// 一部分：大留白 + 一个安静的小标题
struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            Text(title).font(Web.captionMedium).foregroundStyle(Web.fgTertiary).tracking(Web.kickerTracking)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Web.space12)
    }
}

/// 目标一行：状态色小圆点、名称、这一天 / 这一期推进了多少，细进度条，一句话；点了打开目标详情
struct ReviewGoalRow: View {
    @Environment(AppModel.self) private var model
    let goal: API.DayGoal

    var body: some View {
        Button {
            model.openGoal(goal.id)
        } label: {
            VStack(alignment: .leading, spacing: Web.space2) {
                HStack(spacing: Web.space2) {
                    ToneDot(tone: goal.tone)
                    Text(Show.spaced(goal.title)).foregroundStyle(Web.fg).frame(
                        maxWidth: .infinity, alignment: .leading)
                    if let delta = goal.delta {
                        Text(Show.spaced(delta)).font(Web.bodySemibold).foregroundStyle(Web.fg).monospacedDigit()
                    }
                }
                .font(Web.body)
                GoalBar(pct: goal.pct, tone: goal.tone)
                Text(Show.spaced(goal.headline)).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            .padding(Web.space2)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
        .padding(.horizontal, -Web.space2)
        .accessibilityElement(children: .combine)
    }
}

/// 能点的一行：按下去底色变深，往两边伸出 8 点
struct ReviewLine<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        // 往两边伸出 8 点放在外面一层：按钮自己的大小和里面的字一样，审计不会以为字被截了
        VStack(spacing: 0) {
            Button(action: action) {
                label().padding(.vertical, Web.space1).padding(.horizontal, Web.space2)
                    .frame(maxWidth: .infinity, minHeight: Web.touch, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(WebPressStyle(radius: Web.radiusControl))
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, -Web.space2)
    }
}

/// 一页最下面的小字：来自几段话、去画布、这一周的周报
struct ReviewFoot<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) { content() }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Web.space4)
            .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
            .padding(.top, Web.space12)
    }
}

/// 加载中的样子
struct ReviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Web.space4) {
            WebSkeleton(width: Web.space16)
            WebSkeleton(height: Web.space8).containerRelativeFrame(.horizontal) { width, _ in width / 2 }
            WebSkeleton(height: Web.space6).containerRelativeFrame(.horizontal) { width, _ in width * 3 / 4 }
            WebSkeleton(height: Web.space16)
        }
    }
}

extension View {
    /// 回顾一页的外框：能上下滚，左右滑翻上一页（往右滑）、下一页（往左滑）
    func reviewPage(prev: (() -> Void)?, next: (() -> Void)?) -> some View {
        ScrollView {
            self.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Web.space4)
                .padding(.top, Web.space4)
                .padding(.bottom, Web.space12)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: Web.space6).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > Web.space12 + Web.space3, abs(across) > abs(drag.translation.height) * 2 else {
                    return
                }
                if across > 0 { prev?() } else { next?() }
            }
        )
    }
}
