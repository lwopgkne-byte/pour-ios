import PourDesign
import SwiftUI

/// 一页里的一块（照可交互原型的 .sh + .card）：标题在白卡片外面（粗字，右边一句小字或一个链接），下面一张白卡。
/// 钱、健康、值不值这些页都用它，一页里的块长得一样
struct PageSection<Content: View>: View {
    let title: String
    var meta: String?
    var link: String?
    var open: (() -> Void)?
    /// 卡片里留不留边（一行一行的列表自己留边，传 false）
    var padded = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            PageSectionHeader(title: title, meta: meta, link: link, open: open)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard(radius: Theme.Corner.smallCard, padding: padded ? Theme.Space.regular : 0)
        }
        .padding(.top, Theme.Space.medium)
    }
}

/// 一块的标题（原型 .sh：18 号粗，右边 13 号的灰字或者一个蓝色链接）
struct PageSectionHeader: View {
    let title: String
    var meta: String?
    var link: String?
    var open: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.pageSection).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let link, let open {
                ThemeTextButton(link, action: open)
            } else if let meta {
                Text(meta).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, Theme.Space.tight)
    }
}
