import PourAPI
import PourDesign
import SwiftUI

/// 关于我一节的标题（docs/3.0/01-需求文档.md 第 10 章）：左边名字，旁边 ⓘ 点了说怎么算的（方法说明收在这里）；
/// 右边一行小字（「最近 30 天 · 点一行进去」「2 条」）
struct AboutSection: View {
    let title: String
    var meta: String?
    var info: String?
    @State private var showing = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader).layoutPriority(1)
            if let info {
                Button {
                    showing = true
                } label: {
                    Image(systemName: "info.circle").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(title)是怎么算的"))
                .popover(isPresented: $showing) {
                    Text(info).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.Space.regular)
                        .frame(width: Theme.Size.popover)
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer(minLength: Theme.Space.small)
            if let meta {
                Text(meta).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: Theme.Size.touch)
        .padding(.top, Theme.Space.small)
    }
}

/// 卡片里一行能点的：名字、下面一行小字、右边一个值和 ›（Pour 认识的、你的 2026、在笔记库看原话）
struct AboutLinkRow: View {
    let title: String
    var sub: String?
    var value: String?
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.medium) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    if let sub, !sub.isEmpty {
                        Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Theme.Space.small)
                if let value {
                    Text(value).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .multilineTextAlignment(.trailing)
                }
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .padding(.vertical, Theme.Space.medium)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier ?? "about.link")
    }
}

/// 一行一个领域：名字、条（和最多的那块比）、百分比、›（你的生活由什么组成、你的一年说得最多的）
struct DomainShareRow: View {
    let name: String
    let color: String
    /// 0–100
    let share: Int
    /// 最多的那块的百分比（条按它画满）
    let most: Int
    var action: (() -> Void)?

    var body: some View {
        let row = HStack(spacing: Theme.Space.medium) {
            Text(name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .frame(minWidth: Theme.Size.label, alignment: .leading)
            GeometryReader { geo in
                Capsule().fill(Theme.Palette.fill).overlay(alignment: .leading) {
                    Capsule().fill(Theme.tag(color).solid)
                        .frame(width: max(Theme.Size.bar, geo.size.width * Double(share) / Double(max(most, 1))))
                }
            }
            .frame(height: Theme.Size.bar)
            Text("\(share)%").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                .foregroundStyle(Theme.Palette.label).frame(minWidth: Theme.Size.touch, alignment: .trailing)
            if action != nil {
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
        }
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(name) \(share)%"))
                .accessibilityAddTraits(.isButton)
        } else {
            row.accessibilityElement(children: .ignore).accessibilityLabel(Text("\(name) \(share)%"))
        }
    }
}

/// 页面最下面一行：「全部由你说过的话算出来，只在你的电脑上」
struct AboutFoot: View {
    var body: some View {
        Text("全部由你说过的话算出来，只在你的电脑上").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.small)
    }
}

/// 关于我一节：标题 + 一张卡片装着内容（card: false 是内容自己就是一张张卡片，比如连锁反应）
struct AboutCardSection<Content: View>: View {
    let title: String
    var card = true
    var info: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            AboutSection(title: title, info: info)
            if card {
                VStack(alignment: .leading, spacing: Theme.Space.small) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themeCard()
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// 关于我的一页：上下滚，左右留出屏幕边，下面留出「说一句」
    func aboutPage() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) { self }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.screen)
                .padding(.bottom, Theme.Space.xLarge)
        }
    }
}
