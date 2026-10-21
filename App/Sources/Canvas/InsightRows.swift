import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 原话的摘录：左边一条细线表示「这是引用」，行高 1.8
struct QuoteText: View {
    let text: String

    var body: some View {
        Text(Show.spaced(text)).font(Web.body).foregroundStyle(Web.fg).lineSpacing(Web.quoteLineSpacing)
            .padding(.leading, Web.space3)
            .overlay(alignment: .leading) { Rectangle().fill(Web.lineStrong).frame(width: Web.space1 / 2) }
    }
}

/// 黄色的小标签（感悟的标签）
struct YellowTag: View {
    let text: String

    var body: some View {
        Text(text).font(Web.caption).foregroundStyle(Web.tag("yellow").fg)
            .padding(.horizontal, Web.space2)
            .background(Capsule().fill(Web.tag("yellow").bg))
    }
}
