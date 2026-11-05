import PourDesign
import SwiftUI

/// 没网时整页只出这一条（待办 2.0 第 2 步，docs/todo-2.0 spec「没网」）：导航下面一条胶囊
/// 「没网，先存在手机上 · 内容停在 11:08」+「重试」。不压日期（以前在顶上和日期叠在一起），底部输入框上面不再出第二条。
/// 页面显示的是上次存的（staleSince），或者有话存在手机上还没发出去，就出
struct OfflinePill: View {
    @Environment(AppModel.self) private var model
    @State private var retrying = false

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Image(systemName: "icloud.slash").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.secondaryLabel).accessibilityHidden(true)
            Text(Self.text(since: model.staleSince, now: Date())).font(Theme.Typeface.footnoteMedium)
                .foregroundStyle(Theme.Palette.secondaryLabel).lineLimit(2)
            Spacer(minLength: Theme.Space.tight)
            Button {
                guard !retrying else { return }
                retrying = true
                Task {
                    await model.flushOutbox()
                    await model.refreshAll()
                    if model.offline == nil { model.dataChanged() }
                    retrying = false
                }
            } label: {
                Text(retrying ? "在连…" : "重试").font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                    Theme.Palette.accent
                )
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                .background(Theme.Palette.card, in: Capsule())
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("offline.retry")
        }
        .padding(.leading, Theme.Space.medium).padding(.trailing, Theme.Space.tight)
        .background(Theme.Palette.statFill, in: Capsule())
        .padding(.horizontal, Theme.Space.screen).padding(.bottom, Theme.Space.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stale")
    }

    /// 「没网，先存在手机上 · 内容停在 11:08」（不是今天存的写日子）；内容是新的、只是有话没发出去：「· 连上自动发」
    static func text(since: Date?, now: Date) -> String {
        guard let since else { return "没网，先存在手机上 · 连上自动发" }
        let clock = since.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        guard !Calendar.current.isDate(since, inSameDayAs: now) else { return "没网，先存在手机上 · 内容停在 \(clock)" }
        let day = since.formatted(.dateTime.month(.defaultDigits).day())
        return "没网，先存在手机上 · 内容停在 \(day) \(clock)"
    }
}

extension View {
    /// 页面顶上（导航下面）没网时的那一条：画布和推进来的每一页都挂这个
    func offlinePill() -> some View {
        modifier(OfflinePillSpace())
    }
}

private struct OfflinePillSpace: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        let show = model.staleSince != nil || model.outbox.contains { $0.failed != nil }
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if show { OfflinePill().transition(.move(edge: .top).combined(with: .opacity)) }
            }
            .animation(Theme.Motion.standard, value: show)
    }
}
