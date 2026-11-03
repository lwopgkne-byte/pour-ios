import PourAPI
import PourDesign
import SwiftUI
import UIKit

/// 反馈（docs/3.0/01-需求文档.md 第 13 章）：一句话 + 截图（可以去掉）+ 在哪一页 + 版本 + 最近的出错记录；
/// 发到电脑上的 Pour（填了 GitHub 令牌的再记成一条问题）。原话、金额不自动带
struct FeedbackSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// 打开「我的」以前在哪一页
    let page: String
    let screenshot: UIImage?
    @State private var text = ""
    @State private var attach = true
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    TextField("说一句：哪里不好用、想要什么", text: $text, axis: .vertical).font(Theme.Typeface.body)
                        .lineLimit(3...8).focused($typing)
                        .padding(Theme.Space.medium)
                        .background(
                            Theme.Palette.card,
                            in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous)
                        )
                        .accessibilityIdentifier("feedback.text")
                    if let screenshot {
                        Toggle("带上截图", isOn: $attach).font(Theme.Typeface.body).tint(Theme.Palette.accentFill)
                            .accessibilityIdentifier("feedback.attach")
                        Image(uiImage: screenshot).resizable().scaledToFit().frame(maxHeight: Theme.Size.goalCard * 1.5)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
                            .opacity(attach ? 1 : 0.3)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text(attach ? "会带上的截图" : "不带截图"))
                    }
                    Text("还会带上：在哪一页（\(page)）、App 和电脑上的 Pour 的版本、最近几次出错。原话、金额不会带。")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle("反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") { send() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("feedback.send")
                }
            }
        }
        .onAppear { typing = true }
    }

    private func send() {
        let client = model.client
        let errors = Log.recent
        let sentence =
            text.trimmingCharacters(in: .whitespacesAndNewlines)
            + (errors.isEmpty ? "" : "\n\n最近几次出错：\n" + errors.map { "- \($0)" }.joined(separator: "\n"))
        let image = attach ? screenshot.flatMap(Self.png) : nil
        let page = page
        let app = model.appVersionText
        let server = model.serverVersionText
        dismiss()
        Task {
            do throws(APIError) {
                let out = try await client.sendFeedback(
                    text: sentence, page: page, app: app, server: server, screenshot: image)
                model.toast(out.toast)
            } catch {
                model.toast(error.message)
            }
        }
    }

    /// 截图缩到一倍、存成 PNG（别太大）
    static func png(_ image: UIImage) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }.pngData()
    }

    /// 现在屏幕上的样子
    @MainActor static func snapshot() -> UIImage? {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let window else { return nil }
        return UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

/// 要反馈时截下的：在哪一页、那时的样子
struct FeedbackDraft: Identifiable {
    let id = UUID()
    let page: String
    let screenshot: UIImage?
}
