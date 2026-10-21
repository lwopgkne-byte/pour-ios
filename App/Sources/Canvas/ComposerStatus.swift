import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 输入框上面的一条玻璃小条（docs/模块/生活画布2.0.md 第 6 节）：刚才那段话到哪了——没网先存在手机上、正在整理、
/// 没整理成（能重试）。整理好了小条就收起来（画布上长出来了），轻轻一震。对话开着时不出现（对话里看得到）
struct ComposerStatus: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 小条说什么
    enum Stage: Equatable {
        case offline
        case processing(String)
        case failed(noteId: Int, reason: String)
    }

    var body: some View {
        Group {
            if let state {
                content(state)
                    .padding(.horizontal, Theme.Space.inset)
                    .frame(minHeight: Theme.Size.touch)
                    .themeGlass(radius: Theme.Corner.composer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion), value: state)
        .sensoryFeedback(Theme.Haptics.done, trigger: doneCount) { old, new in new > old }
        .sensoryFeedback(Theme.Haptics.failed, trigger: state) { _, new in
            if case .failed = new { true } else { false }
        }
    }

    @ViewBuilder private func content(_ state: Stage) -> some View {
        switch state {
        case .offline:
            row(symbol: "icloud.slash", text: "没网，先存在手机上 · 连上自动发", tint: Theme.Palette.secondaryLabel) {
                Button("重试") { Task { await model.flushOutbox() } }
            }
        case .processing(let text):
            Button {
                withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                    model.chatOpen = true
                }
            } label: {
                row(symbol: "sparkles", text: "正在整理：\(text)", tint: Theme.Palette.accent, breathing: true) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("打开对话"))
        case .failed(let noteId, let reason):
            let said = reason.hasPrefix("没整理成") ? reason : "没整理成：\(reason)"
            row(symbol: "exclamationmark.circle", text: said, tint: Theme.Palette.bad) {
                Button("重试") { model.retry(note: noteId) }
            }
        }
    }

    private func row<Action: View>(
        symbol: String, text: String, tint: Color, breathing: Bool = false, @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: Theme.Space.small) {
            Image(systemName: symbol).foregroundStyle(tint)
                .symbolEffect(.breathe, options: .repeating, isActive: breathing && !reduceMotion)
            Text(Show.spaced(text)).foregroundStyle(Theme.Palette.label).lineLimit(1)
            Spacer(minLength: Theme.Space.tight)
            action().font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent).buttonStyle(.plain)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
        }
        .font(Theme.Typeface.footnoteMedium)
    }

    /// 现在该说什么：没网（手机上存着没发出去的）最要紧；然后看最后一段话（今天的）
    private var state: Stage? {
        if model.outbox.contains(where: { $0.failed != nil }) { return .offline }
        guard let last = model.chat.last, last.day == model.today else { return nil }
        switch last.status {
        case "processing", "pending":
            return .processing(String(last.text.prefix(14)) + (last.text.count > 14 ? "…" : ""))
        case "failed":
            return .failed(noteId: last.id, reason: last.error ?? "原因不明")
        default:
            return nil
        }
    }

    /// 今天整理好了几段：多了一段就轻轻一震
    private var doneCount: Int {
        model.chat.filter { $0.day == model.today && $0.status == "done" }.count
    }
}
