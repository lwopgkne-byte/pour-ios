import PourDesign
import SwiftUI

/// 麦克风：点一下说（下面换成听写的那一块，有字的接着说），按住说（松开就发，往上滑取消）。读屏点两下是「点一下说」。
/// 没字时是输入框右边蓝色的圆（原型 .mic）；有字时那个圆换成发送，麦克风缩成输入框里右边一个灰的小图标，好接着说
struct MicButton: View {
    enum Style {
        /// 蓝色的圆
        case circle
        /// 输入框里的灰色小图标
        case inline
    }

    @Environment(VoiceSession.self) private var voice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 点一下：要不要先看说明（第一次用）由外面决定
    let tap: () -> Void
    /// 按住说完松开：发出去
    let send: (String) -> Void
    /// 按住时往上滑过了：松开就不要了
    @Binding var cancelling: Bool
    var style = Style.circle
    @State private var pressedAt: Date?
    @State private var holding = false
    @State private var waiting: Task<Void, Never>?

    /// 按多久算「按住」
    static let holdAfter: Duration = .milliseconds(350)
    /// 往上滑多少算「取消」
    static let cancelDistance: CGFloat = 60

    var body: some View {
        // 图标封顶，不出圆（不加长按看大图标：长按是「按住说」）
        Group {
            switch style {
            case .circle:
                Image(systemName: "mic.fill").font(Theme.Typeface.micIcon)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: Theme.Size.micButton, height: Theme.Size.micButton)
                    .background(Theme.Palette.accentFill, in: Circle())
            case .inline:
                Image(systemName: holding ? "mic.fill" : "mic").font(Theme.Typeface.toolbarIcon)
                    .foregroundStyle(holding ? Theme.Palette.onAccent : Theme.Palette.secondaryLabel)
                    .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
                    .background(holding ? Theme.Palette.accentFill : .clear, in: Circle())
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .scaleEffect(holding && !reduceMotion ? 1.15 : 1)
        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
        .contentShape(Circle())
        .gesture(press)
            .animation(Theme.Motion.quick, value: holding)
            .accessibilityElement()
            .accessibilityLabel(Text("说话"))
            .accessibilityHint(Text("点一下说，说完了可以改；也可以按住说，松开就发"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tap() }
            .accessibilityIdentifier("pourbar.mic")
    }

    /// 一个手势管两种：按下 0.35 秒还没松开就是「按住说」，在那之前松开是「点一下」
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if pressedAt == nil {
                    pressedAt = Date()
                    // 还没看过「用说的」那张说明：按住也先看说明（松开时当成点了一下）
                    waiting = Task {
                        try? await Task.sleep(for: Self.holdAfter)
                        guard !Task.isCancelled, pressedAt != nil, voice.explained else { return }
                        holding = true
                        voice.start(.hold)
                    }
                }
                if holding { cancelling = drag.translation.height < -Self.cancelDistance }
            }
            .onEnded { _ in
                waiting?.cancel()
                pressedAt = nil
                if holding {
                    holding = false
                    let cancelled = cancelling
                    cancelling = false
                    if cancelled {
                        voice.cancel()
                    } else {
                        Task { if let words = await voice.finish() { send(words) } }
                    }
                } else {
                    tap()
                }
            }
    }
}
