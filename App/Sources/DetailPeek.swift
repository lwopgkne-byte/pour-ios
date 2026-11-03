import PourAPI
import PourDesign
import SwiftUI

/// 详情层：从底部滑出的一层，上面是标题和右上角的关闭，下面能滚。
/// 设置里的类别、没答对的句子、你改过的地方、处理日志都用它（记录详情 EntryPeek 是同一个样子）
struct DetailPeek<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.small) {
                Text(Show.spaced(title)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label).lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(Theme.Typeface.section).foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("关闭"))
            }
            .padding(.leading, Theme.Space.regular)
            .padding([.trailing, .vertical], Theme.Space.small)
            .frame(minHeight: Theme.Size.touch + Theme.Space.tight)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.regular)
                    .padding(.bottom, Theme.Space.xLarge)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.Palette.card)
        .presentationDetents([.fraction(0.6), .large])
        .presentationCornerRadius(Theme.Corner.chip)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        .tint(Theme.Palette.accent)
    }
}
