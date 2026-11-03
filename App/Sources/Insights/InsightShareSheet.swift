import Photos
import PourAPI
import PourCore
import PourDesign
import SwiftUI
import UIKit

/// 分享成图片（01 需求文档 7.4、06 交互细节 5.3）：竖版卡片（引号、宋体那句话、「—— 我，2026年10月11日」、POUR · 倾），
/// 三种样子点着换（暖白、墨色、月白）；存到相册 · 发给朋友（系统分享面板）· 拷贝。
/// 图片只在你点分享时在这台手机上画（ImageRenderer，1080 像素宽），不上传
struct InsightShareSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: API.InsightItem
    @State private var look = InsightShareCard.Look.warm
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("分享成图片") { dismiss() }
            ScrollView {
                VStack(spacing: Theme.Space.large) {
                    preview
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("图片的样子：\(item.quote)，\(Self.signature(item.day))"))
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("share.card")
                    looks
                    actions
                    Text("只在你点分享时在这台手机上画出来，不上传").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .padding(.vertical, Theme.Space.regular)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: look) { image = Self.render(item, look: look) }
    }

    /// 图片的样子：就是画出来、要分享出去的那一张（还没画好时先空出那么大的地方）
    private var preview: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: InsightShareCard.width)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            } else {
                InsightShareCard(quote: item.quote, signature: Self.signature(item.day), look: look).hidden()
            }
        }
        .themeEdge(radius: 0)
        .animation(Theme.Motion.standard, value: image.map(ObjectIdentifier.init))
    }

    /// 三种样子：一个色点 + 名字
    private var looks: some View {
        HStack(spacing: Theme.Space.small) {
            ForEach(InsightShareCard.Look.allCases) { one in
                Button {
                    look = one
                } label: {
                    HStack(spacing: Theme.Space.snug) {
                        Circle().fill(one.background)
                            .frame(width: Theme.Size.dot + Theme.Space.snug, height: Theme.Size.dot + Theme.Space.snug)
                            .overlay { Circle().stroke(Theme.Palette.separator) }
                        Text(one.name).font(Theme.Typeface.footnoteSemibold)
                    }
                    .foregroundStyle(look == one ? Theme.Palette.onAccent : Theme.Palette.label)
                    .padding(.horizontal, Theme.Space.medium)
                    .frame(minHeight: Theme.Size.capsule)
                    .background(look == one ? Theme.Palette.accentFill : Theme.Palette.fill, in: Capsule())
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityAddTraits(look == one ? .isSelected : [])
                .accessibilityIdentifier("share.look.\(one.rawValue)")
                .themeSelectionFeedback(trigger: look == one)
            }
        }
    }

    /// 存到相册 · 发给朋友 · 拷贝
    private var actions: some View {
        HStack(alignment: .top, spacing: Theme.Space.xLarge) {
            ShareAction("存到相册", symbol: "photo.on.rectangle") { save() }
                .accessibilityIdentifier("share.save")
            if let image {
                ShareLink(
                    item: Image(uiImage: image), preview: SharePreview(item.quote, image: Image(uiImage: image))
                ) {
                    ShareActionLabel("发给朋友", symbol: "paperplane")
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("share.send")
            }
            ShareAction("拷贝", symbol: "doc.on.doc") {
                guard let image else { return }
                UIPasteboard.general.image = image
                dismiss()
                model.toast("拷贝好了，去微信里粘贴")
            }
            .accessibilityIdentifier("share.copy")
        }
    }

    /// 存到相册：只要「添加照片」的权限（第一次系统会问）
    private func save() {
        guard let image else { return }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                model.toast("存不了：到「设置 → Pour → 照片」里允许添加照片")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                dismiss()
                model.toast("存到相册了")
            } catch {
                model.toast("没存上，再试一次")
            }
        }
    }

    /// 「—— 我，2026年10月11日」
    static func signature(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return "—— 我" }
        return "—— 我，\(parts[0])年\(parts[1])月\(parts[2])日"
    }

    /// 画成图片：300 点宽 × 3.6 = 1080 像素，长的句子往下长、不截断
    static func render(_ item: API.InsightItem, look: InsightShareCard.Look) -> UIImage? {
        let renderer = ImageRenderer(
            content: InsightShareCard(quote: item.quote, signature: signature(item.day), look: look))
        renderer.scale = 1080 / InsightShareCard.width
        return renderer.uiImage
    }
}

/// 分享的一个大按钮：白色圆里一个图标，下面写名字
private struct ShareAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    init(_ title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) { ShareActionLabel(title, symbol: symbol) }
            .buttonStyle(PressScale())
    }
}

private struct ShareActionLabel: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        VStack(spacing: Theme.Space.snug) {
            Image(systemName: symbol).font(Theme.Typeface.quickIcon).foregroundStyle(Theme.Palette.label)
                .frame(width: Theme.Size.quickIcon, height: Theme.Size.quickIcon)
                .background(Theme.Palette.card, in: Circle())
                .themeEdge(radius: Theme.Size.quickIcon / 2)
            Text(title).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
        }
        .frame(minWidth: Theme.Size.quickIcon + Theme.Space.large)
        .contentShape(Rectangle())
    }
}
