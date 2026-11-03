import PourAPI
import PourDesign
import SwiftUI

/// 我的语录（docs/模块/产品优化.md R4）：说「记一句：……」让记下的、感悟里收藏的（3.0 的「语录 ★」），和感悟里原话的那一句，
/// 新的在前。只用你说过的话；不想放进来的点「不放进语录」（记录不动）。每日回顾的最后一句「你说过」从这里轮着挑。
/// 3.0 感悟页的「语录 ★」是同一份（第 8 步重做关于我时这一块收进感悟页）
struct KnownQuotes: View {
    @Environment(AppModel.self) private var model
    @State private var quotes: [API.MyQuote] = []
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !quotes.isEmpty {
                LegacySection(title: "我的语录") {
                    VStack(alignment: .leading, spacing: Theme.Space.medium) {
                        ForEach(all ? quotes : Array(quotes.prefix(5))) { quote in row(quote) }
                        if !all && quotes.count > 5 {
                            LinkButton("看全部 \(quotes.count) 句") { all = true }
                        }
                        Text("说「记一句：……」、在感悟里点 ★ 就记进来；只放你说过的话")
                            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
        }
        .task(id: model.dataVersion) {
            if let fresh = try? await model.client.quotes() { quotes = fresh }
        }
    }

    private func row(_ quote: API.MyQuote) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(Show.spaced("「\(quote.text)」")).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.quote)
            HStack(spacing: Theme.Space.small) {
                Text("\(Show.dayTitle(quote.day, today: model.today))\(quote.asked ? " · 语录 ★" : " · 感悟里的")")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer(minLength: 0)
                LinkButton("不放进语录") { hide(quote) }
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
