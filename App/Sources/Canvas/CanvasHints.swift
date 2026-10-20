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
            VStack(alignment: .leading, spacing: Web.space3) {
                VStack(alignment: .leading, spacing: Web.space1) {
                    Text("连接大模型").font(Web.bodySemibold).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                    Text(Show.spaced("你说的话会发送到 DeepSeek 服务器整理成记录。原话始终先存在这台电脑上，不会因为连不上而丢失。"))
                        .font(Web.body).foregroundStyle(Web.fgSecondary)
                }
                if llm.configured {
                    HStack(spacing: Web.space3) {
                        WebButton("知道了，开始整理", variant: .primary) { model.acceptConsent() }
                        WebButton("跳过", variant: .ghost) { model.dismissSetup() }
                    }
                } else {
                    HStack(spacing: Web.space3) {
                        Text("密钥请在电脑上双击「Pour 设置」填写。").font(Web.body).foregroundStyle(Web.fgSecondary)
                        WebButton("跳过", variant: .ghost) { model.dismissSetup() }
                    }
                }
            }
            .padding(Web.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bgSubtle))
            .padding(.top, Web.space6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("连接大模型"))
        }
    }
}

/// 早上的一行提示：「昨天的回顾好了 →」（docs/prd-review.md 6.1）。
/// 看过了、或者过了中午就不显示；不是弹窗，也没有红点
struct ReviewHint: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let yesterday = PourDate.addDays(model.today, -1)
        let unread = model.reviews.contains { $0.kind == "daily" && $0.day == yesterday && !$0.read }
        if unread, Calendar.current.component(.hour, from: Date()) < 12 {
            Button {
                model.open("/review/\(yesterday)")
            } label: {
                Text("昨天的回顾好了 →").font(Web.body).foregroundStyle(Web.fgSecondary)
                    .frame(minHeight: Web.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, Web.space2)
        }
    }
}
