import PourAPI
import PourDesign
import SwiftUI

/// 详情层：从底部滑出的一层，上面是标题和右上角的关闭，下面能滚。
/// 设置里的类别、没答对的句子、你改过的地方、处理日志都用它（记录详情 EntryPeek 是同一个样子）
struct WebPeek<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Web.space2) {
                Text(Show.spaced(title)).font(Web.sectionSemibold).foregroundStyle(Web.fg).lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(Web.section).foregroundStyle(Web.fgSecondary)
                        .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("关闭"))
            }
            .padding(.leading, Web.space4)
            .padding([.trailing, .vertical], Web.space2)
            .frame(minHeight: Web.header)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Web.space4)
                    .padding(.bottom, Web.space6)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Web.bg)
        .presentationDetents([.fraction(0.6), .large])
        .presentationCornerRadius(Web.radiusPanel)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        .tint(Web.accent)
    }
}
