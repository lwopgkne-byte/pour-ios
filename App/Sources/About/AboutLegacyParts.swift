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
            .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
    }
}

extension View {
    /// 一行下面的细线
    func moneyRule() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
    }
}

/// 能点的一行：内容在左，右边一个小箭头，下面一条细线；按下去底色变深
struct MoneyLinkRow<Label: View>: View {
    var minHeight = Web.space16
    var chevron = true
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: Web.space2) {
                label().frame(maxWidth: .infinity, alignment: .leading)
                if chevron {
                    Image(systemName: "chevron.right").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Web.space2)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
    }
}

/// 名字和钱一行、下面一句灰色小字（留意的一行、人情的一行）
struct MoneyMainSub: View {
    let main: Text
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            main.font(Web.body).foregroundStyle(Web.fg)
            if let sub, !sub.isEmpty {
                Text(sub).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 灰色的小标签（「固定的」「等报销」「人情」）
struct MoneyTag: View {
    let text: String

    var body: some View {
        Text(text).font(Web.caption).foregroundStyle(Web.tag("gray").fg).fixedSize()
            .padding(.horizontal, Web.space2)
            .background(Capsule().fill(Web.tag("gray").bg))
    }
}

/// 一句话里的一段：字体、颜色（「一共送出 **¥4,066**」这种半粗的钱）
struct Segment {
    let text: String
    var font: Font = Web.body
    var color: Color = Web.fg

    init(_ text: String, font: Font = Web.body, color: Color = Web.fg) {
        self.text = text
        self.font = font
        self.color = color
    }

    /// 半粗的一段
    static func bold(_ text: String, color: Color = Web.fg) -> Segment {
        .init(text, font: Web.bodySemibold, color: color)
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
        VStack(alignment: .leading, spacing: Web.space4) {
            WebSkeleton(width: Web.space16)
            WebSkeleton(height: Web.space8).containerRelativeFrame(.horizontal) { width, _ in width / 2 }
            WebSkeleton(height: Web.space6).containerRelativeFrame(.horizontal) { width, _ in width * 3 / 4 }
            WebSkeleton(height: Web.space16)
        }
    }
}

/// 一部分：大留白 + 一个安静的小标题（原来回顾里的样子；回顾 3.0 第 6 步换成了卡片，「关于我」那几页第 8 步再换）
struct LegacySection<Content: View>: View {
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

extension View {
    /// 原来回顾一页的外框（「关于我」那几页还在用）：能上下滚，左右滑翻上一页（往右滑）、下一页（往左滑）
    func legacyPage(prev: (() -> Void)?, next: (() -> Void)?) -> some View {
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
