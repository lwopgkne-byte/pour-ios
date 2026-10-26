import PourAPI
import PourDesign
import SwiftUI

/// 我的语录（docs/模块/产品优化.md R4）：说「记一句：……」让记下的，和感悟里原话的那一句，新的在前。
/// 只用你说过的话；不想放进来的点「不放进语录」（记录不动）。每日回顾的最后一句「你说过」从这里轮着挑
struct KnownQuotes: View {
    @Environment(AppModel.self) private var model
    @State private var quotes: [API.MyQuote] = []
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !quotes.isEmpty {
                ReviewSection(title: "我的语录") {
                    VStack(alignment: .leading, spacing: Web.space3) {
                        ForEach(all ? quotes : Array(quotes.prefix(5))) { quote in row(quote) }
                        if !all && quotes.count > 5 {
                            WebTextButton("看全部 \(quotes.count) 句", font: Web.caption) { all = true }
                        }
                        Text("说「记一句：……」就记进来；只放你说过的话")
                            .font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                }
            }
        }
        .task(id: model.dataVersion) {
            if let fresh = try? await model.client.quotes() { quotes = fresh }
        }
    }

    private func row(_ quote: API.MyQuote) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(Show.spaced("「\(quote.text)」")).font(Web.body).foregroundStyle(Web.fg).lineSpacing(
                Web.quoteLineSpacing)
            HStack(spacing: Web.space2) {
                Text("\(Show.dayTitle(quote.day, today: model.today))\(quote.asked ? " · 让记下的" : " · 感悟里的")")
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
                Spacer(minLength: 0)
                WebTextButton("不放进语录", font: Web.caption, color: Web.fgSecondary) { hide(quote) }
                    .accessibilityLabel(Text("不放进语录：\(quote.text)"))
            }
        }
    }

    private func hide(_ quote: API.MyQuote) {
        let client = model.client
        Task {
            do {
                quotes = try await client.hideQuote(quote.entryId)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}
