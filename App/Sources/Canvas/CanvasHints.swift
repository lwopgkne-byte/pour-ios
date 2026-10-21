import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 首次使用（规格 3 / 5.1）：说明原话会发送到大模型整理。手机上填不了密钥（只能在电脑上用「Pour 设置」），
/// 只说一声；.env 里已经有密钥的，确认一下就开始整理。确认过或者跳过就不再出现
struct SetupCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let llm = model.llm, llm.showSetup == true {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                HStack(spacing: Theme.Space.small) {
                    IconTile(symbol: "sparkles", emoji: "", color: Theme.tag("blue"))
                    Text("连接大模型").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(Show.spaced("你说的话会发送到 DeepSeek 服务器整理成记录。原话始终先存在这台电脑上，不会因为连不上而丢失。"))
                    .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineSpacing(Theme.Leading.body)
                if llm.configured {
                    HStack(spacing: Theme.Space.small) {
                        Button("知道了，开始整理") { model.acceptConsent() }.buttonStyle(.borderedProminent)
                        Button("跳过") { model.dismissSetup() }.buttonStyle(.bordered)
                    }
                    .font(Theme.Typeface.footnoteSemibold).buttonBorderShape(.capsule).tint(Theme.Palette.accentFill)
                } else {
                    Text("密钥请在电脑上双击「Pour 设置」填写。").font(Theme.Typeface.subheadline)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    Button("跳过") { model.dismissSetup() }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .font(Theme.Typeface.footnoteSemibold).tint(Theme.Palette.accent)
                }
            }
            .themeCard()
            .padding(.top, Theme.Space.large)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("连接大模型"))
        }
    }
}

/// 早上的一行提示：「昨天的回顾好了」（docs/prd-review.md 6.1）。
/// 看过了、或者过了中午就不显示；不是弹窗，也没有红点。画布上是标题下面的一个小胶囊
enum ReviewHint {
    /// 要显示时是昨天那份回顾的地址
    @MainActor static func path(_ model: AppModel) -> String? {
        guard model.shownDay == model.today else { return nil }
        let yesterday = PourDate.addDays(model.today, -1)
        let unread = model.reviews.contains { $0.kind == "daily" && $0.day == yesterday && !$0.read }
        guard unread, Calendar.current.component(.hour, from: Date()) < 12 else { return nil }
        return "/review/\(yesterday)"
    }
}
