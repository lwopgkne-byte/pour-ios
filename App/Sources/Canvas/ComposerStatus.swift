import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 输入框上面的一条玻璃小条（docs/模块/生活画布2.0.md 第 6 节）：刚才那段话到哪了——没网先存在手机上、正在整理、
/// 没整理成（能重试）。整理好了小条就收起来（画布上长出来了）。对话开着时不出现（对话里看得到）。
/// 整理好了、没整理成的触感在 ComposerHaptics（对话开着也要震）
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
                    .themeTransition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion), value: state)
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
}

/// 输入框这一块的触感（docs/模块/生活画布2.0.md 8.6）。挂在一直都在的输入框上：对话开着、用说的发出去也震
struct ComposerHaptics: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(VoiceSession.self) private var voice

    /// 最后一段话：哪一段、整理到哪了
    struct LastNote: Equatable {
        let id: Int
        let status: String
    }

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(Theme.Haptics.send, trigger: model.outbox.count) { old, new in new > old }
            .sensoryFeedback(trigger: model.chat.last.map { LastNote(id: $0.id, status: $0.status) }, Self.feedback)
            // 开始、停下说话（没听成的另有一震，在 VoiceFailure）
            .sensoryFeedback(Theme.Haptics.voice, trigger: voice.active) { _, now in now || voice.phase == .idle }
    }

    /// 看着的那一段整理好了、没整理成才震。只认同一段话的变化：刚打开 App、拿到以前的记录时不震
    static func feedback(_ old: LastNote?, _ new: LastNote?) -> SensoryFeedback? {
        guard let old, let new, old.id == new.id, old.status != new.status else { return nil }
        switch new.status {
        case "done": return Theme.Haptics.done
        case "failed": return Theme.Haptics.failed
        default: return nil
        }
    }
}
