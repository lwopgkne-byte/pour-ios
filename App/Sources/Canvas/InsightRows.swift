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
