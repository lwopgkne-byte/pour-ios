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

/// 感悟：引用原话，下面是标签；意思相近的旧笔记收成一行「以前也说过类似的 3 条」，点开才看到
struct InsightRows: View {
    let items: [API.Entry]

    var body: some View {
        ForEach(items) { entry in
            if case .insight(let insight) = entry.data {
                DayRow(entry: entry) {
                    VStack(alignment: .leading, spacing: Web.space2) {
                        QuoteText(text: insight.quote)
                        if !insight.tags.isEmpty {
                            PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
                                ForEach(insight.tags, id: \.self) { YellowTag(text: $0) }
                            }
                        }
                        if let related = entry.related, !related.isEmpty { RelatedNotes(related: related) }
                    }
                }
            }
        }
    }
}

/// 以前也说过类似的（网页版 RelatedNotes）
private struct RelatedNotes: View {
    @Environment(AppModel.self) private var model
    let related: [API.Related]
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Web.line).frame(height: 1).padding(.bottom, Web.space1)
            Button {
                open.toggle()
            } label: {
                HStack(spacing: Web.space1) {
                    Text(Show.spaced("以前也说过类似的 \(related.count) 条"))
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                }
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
                .frame(minHeight: Web.touch)
            }
            .buttonStyle(.plain)
            if open {
                ForEach(related, id: \.self) { item in
                    Button {
                        model.show(item.day)
                    } label: {
                        HStack(spacing: Web.space3) {
                            Text(Show.spaced(Show.dayTitle(item.day, today: model.today))).foregroundStyle(
                                Web.fgTertiary)
                            Text(Show.spaced(item.text)).foregroundStyle(Web.fgSecondary).lineLimit(1)
                        }
                        .font(Web.caption)
                        .frame(minHeight: Web.touch)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, Web.space2)
    }
}
