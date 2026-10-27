import PourAPI
import PourDesign
import SwiftUI

/// 今天推进的目标（规格 7.1）：一排进度环小卡，左右滑；点了打开目标详情
struct GoalRings: View {
    @Environment(AppModel.self) private var model
    let goals: [API.DayGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            SectionHeader(title: "今天推进的目标", trailing: "\(goals.count) 个")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Theme.Space.medium) {
                    ForEach(goals) { goal in
                        Button {
                            model.openGoal(goal.id)
                        } label: {
                            GoalRingCard(goal: goal)
                        }
                        .buttonStyle(PressScale())
                        .accessibilityElement(children: .combine)
                        // 先念目标是什么，再念今天推进了多少、进度
                        .accessibilityLabel(
                            Text(
                                Show.spoken(
                                    [goal.title, goal.delta, goal.headline].compactMap(\.self).joined(separator: " · "))
                            ))
                    }
                }
                .padding(.vertical, Theme.Space.small)
            }
            // 滑到屏幕两边：列表本身撑满屏宽，内容两边留出和页面一样的边
            .contentMargins(.horizontal, Theme.Space.screen, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Theme.Space.screen)
        }
    }
}

/// 一个目标的小卡：进度环、右上角今天推进了多少、目标名、一行进度
private struct GoalRingCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 小卡的宽跟着字号变：字大了「连续第 4 天」也放得下一行
    @ScaledMetric(relativeTo: .body) private var width = Theme.Size.goalCard
    let goal: API.DayGoal

    var body: some View {
        let color = Theme.Palette.status(goal.tone)
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(alignment: .top) {
                ProgressRing(progress: goal.pct, color: color).frame(width: Theme.Size.ring, height: Theme.Size.ring)
                Spacer(minLength: Theme.Space.small)
                if let delta = goal.delta {
                    // 放不下一行时字缩小一点，不截成「今天 3946…」（步数这种四位数，2026-10-27 演示数据里看到的）
                    Text(Show.spaced(delta)).font(Theme.Typeface.rowNumber).foregroundStyle(color)
                        .lineLimit(typeSize > .large ? nil : 1).minimumScaleFactor(0.7)
                        .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                        .background(color.opacity(0.1), in: Theme.rounded(Theme.Corner.tile))
                }
            }
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(Show.spaced(goal.title)).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
                    .lineLimit(typeSize > .large ? nil : 2)
                Text(Show.spaced(goal.headline)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel).lineLimit(typeSize > .large ? nil : 2)
            }
        }
        .frame(width: width, alignment: .leading)
        .themeCard(radius: Theme.Corner.smallCard, padding: Theme.Space.inset)
    }
}

/// 卡片底部的相关目标：小环 + 名字 + 进度，点了打开目标详情；半宽的卡里只写名字（进度在上面「今天推进的目标」里）
struct GoalFooter: View {
    @Environment(AppModel.self) private var model
    let goal: API.DayGoal
    var compact = false

    var body: some View {
        Button {
            model.openGoal(goal.id)
        } label: {
            HStack(spacing: Theme.Space.small) {
                ProgressRing(progress: goal.pct, color: Theme.Palette.status(goal.tone), lineWidth: 3)
                    .frame(width: Theme.Size.miniRing, height: Theme.Size.miniRing)
                Text(Show.spaced(compact ? goal.title : "\(goal.title) · \(goal.headline)")).font(
                    Theme.Typeface.footnote
                )
                .foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(Show.spoken(compact ? goal.title : "\(goal.title) · \(goal.headline)")))
    }
}
