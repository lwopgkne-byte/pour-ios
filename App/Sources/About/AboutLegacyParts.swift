import PourAPI
import PourDesign
import SwiftUI

/*
 * 「关于我」那几页（第 8 步重做以前）还在用的几样，原来是钱的旧页面的部件（第 3 步钱重做以后搬到这里）：
 * 能点的一行、一列（上面一条细线、每行下面一条细线）、名字和一句小字、灰色小标签（笔记库、搜索也用）、
 * 几段拼成一句、一页的外框。第 8 步重做「关于我」时一起换掉
 */

/// 一列：上面一条细线，每一行自己在下面画线
struct MoneyList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .overlay(alignment: .top) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
    }
}

extension View {
    /// 一行下面的细线
    func moneyRule() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
    }
}

/// 能点的一行：内容在左，右边一个小箭头，下面一条细线；按下去底色变深
struct MoneyLinkRow<Label: View>: View {
    var minHeight = (Theme.Space.section * 2)
    var chevron = true
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.small) {
                label().frame(maxWidth: .infinity, alignment: .leading)
                if chevron {
                    Image(systemName: "chevron.right").font(Theme.Typeface.footnote).foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Theme.Space.small)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .moneyRule()
    }
}

/// 名字和钱一行、下面一句灰色小字（留意的一行、人情的一行）
struct MoneyMainSub: View {
    let main: Text
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            main.font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            if let sub, !sub.isEmpty {
                Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 灰色的小标签（「固定的」「等报销」「人情」）
struct MoneyTag: View {
    let text: String

    var body: some View {
        // 字用第二层字色、底是浅灰（和笔记库「意思相近」一样）：标签色的 solid 是画点和条的，写字对比度不够（3.0 收尾查出来的）
        Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
            .padding(.horizontal, Theme.Space.small)
            .background(Capsule().fill(Theme.Palette.fill))
    }
}

/// 一句话里的一段：字体、颜色（「一共送出 **¥4,066**」这种半粗的钱）
struct Segment {
    let text: String
    var font: Font = Theme.Typeface.body
    var color: Color = Theme.Palette.label

    init(_ text: String, font: Font = Theme.Typeface.body, color: Color = Theme.Palette.label) {
        self.text = text
        self.font = font
        self.color = color
    }

    /// 半粗的一段
    static func bold(_ text: String, color: Color = Theme.Palette.label) -> Segment {
        .init(text, font: Theme.Typeface.bodySemibold, color: color)
    }
}

/// 几段拼成一句
func rich(_ parts: [Segment]) -> AttributedString {
    parts.reduce(into: AttributedString()) { text, part in
        var piece = AttributedString(part.text)
        piece.font = part.font
        piece.foregroundColor = part.color
        text += piece
    }
}

extension View {
    /// 一页的外框（「关于我」那几页）：能上下滚，左右滑翻上一页（往右滑）、下一页（往左滑）；和回顾一样
    func moneyPage(prev: (() -> Void)? = nil, next: (() -> Void)? = nil) -> some View {
        legacyPage(prev: prev, next: next)
    }
}

/// 加载中的样子（关于我的几页还在用；回顾 3.0 第 6 步换成了新组件，这几页第 8 步一起换）
struct ReviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.regular) {
            SkeletonBlock(height: Theme.Space.regular).frame(width: Theme.Space.section * 2)
            SkeletonBlock(height: Theme.Space.section).containerRelativeFrame(.horizontal) { width, _ in width / 2 }
            SkeletonBlock(height: Theme.Space.xLarge).containerRelativeFrame(.horizontal) { width, _ in width * 3 / 4 }
            SkeletonBlock(height: Theme.Space.section * 2)
        }
    }
}

extension View {
    /// 原来回顾一页的外框（「关于我」那几页还在用）：能上下滚，左右滑翻上一页（往右滑）、下一页（往左滑）
    func legacyPage(prev: (() -> Void)?, next: (() -> Void)?) -> some View {
        ScrollView {
            self.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.regular)
                .padding(.top, Theme.Space.regular)
                .padding(.bottom, (Theme.Size.touch + Theme.Space.tight))
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: Theme.Space.xLarge).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > (Theme.Size.touch + Theme.Space.tight) + Theme.Space.medium,
                    abs(across) > abs(drag.translation.height) * 2
                else {
                    return
                }
                if across > 0 { prev?() } else { next?() }
            }
        )
    }
}
