import PourDesign
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 从别的 App 分享进来（docs/模块/产品优化.md R7）：文字、链接就像说了一段话，交给电脑上的 Pour 整理；
/// 发之前可以补一句（「这篇讲睡眠的不错」）。连不上电脑时先存在手机上，Pour 打开时再发
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = extensionContext
        Task { @MainActor in
            let shared = await Self.sharedText(from: context)
            let sheet = ShareSheet(text: shared) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
            let host = UIHostingController(rootView: sheet)
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }

    /// 分享过来的字：链接优先，其次是文字
    static func sharedText(from context: NSExtensionContext?) async -> String {
        for item in context?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                    let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
                {
                    return url.absoluteString
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                    let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
                {
                    return text
                }
            }
            if let text = item.attributedContentText?.string, !text.isEmpty { return text }
        }
        return ""
    }
}

/// 分享的那一页：分享过来的字可以改、可以补一句；「发给 Pour」
private struct ShareSheet: View {
    @State var text: String
    let close: () -> Void
    @State private var sending = false
    @State private var result: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                TextEditor(text: $text).font(Theme.Typeface.body)
                    .frame(minHeight: Theme.Size.touch * 3)
                    .padding(Theme.Space.small)
                    .background(Theme.Palette.fill, in: Theme.rounded(Theme.Corner.card))
                Text("可以补一句为什么存它，Pour 会一起整理").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                if let result {
                    Text(result).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Space.screen)
            .background(Theme.Palette.background)
            .navigationTitle("发给 Pour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: close) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发") { send() }
                        .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func send() {
        sending = true
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            result = await SharedClient.say(words)
            try? await Task.sleep(for: .seconds(1.2))
            close()
        }
    }
}
