import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 原话的摘录：左边一条细线表示「这是引用」，行高 1.8
struct QuoteText: View {
    let text: String

    var body: some View {
        Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineSpacing(
            Theme.Leading.quote
        )
        .padding(.leading, Theme.Space.medium)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.Palette.separator).frame(width: Theme.Space.tight / 2) }
    }
}

/// 黄色的小标签（感悟的标签）
struct YellowTag: View {
    let text: String

    var body: some View {
        Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.tag("yellow").solid)
            .padding(.horizontal, Theme.Space.small)
            .background(Capsule().fill(Theme.tag("yellow").tint))
    }
}
