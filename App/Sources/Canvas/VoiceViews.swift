import PourDesign
import SwiftUI
import UIKit

/// 点一下说：输入框长成录音卡（docs/模块/生活画布2.0.md 第 6 节）——红点「正在听」、计时、声波、
/// 说的字一边说一边出（还没定下来的字浅一点）；✕ 不要了、✓ 转成字再改、↑ 直接发
struct VoiceCard: View {
    @Environment(VoiceSession.self) private var voice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// ✓：字放进输入框；↑：发出去
    let useText: (String, _ send: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            header
            Waveform(levels: voice.levels).frame(height: Theme.Size.waveform)
            words
            HStack(spacing: Theme.Space.medium) {
                round("xmark", label: "不要了", id: "voice.cancel", filled: false) { voice.cancel() }
                Spacer(minLength: 0)
                round("checkmark", label: "转成字再改", id: "voice.text", filled: false) { finish(send: false) }
                round("arrow.up", label: "发送", id: "voice.send", filled: true) { finish(send: true) }
            }
            .disabled(voice.phase != .listening)
        }
        .padding(Theme.Space.regular)
        .themeGlass(radius: Theme.Corner.composer)
        .sensoryFeedback(Theme.Haptics.warning, trigger: voice.nearLimit) { _, near in near }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("正在听你说"))
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: Theme.Space.small) {
            switch voice.phase {
            case .preparing(let progress):
                ProgressRing(progress: progress, color: Theme.Palette.accent, lineWidth: 3)
                    .frame(width: Theme.Size.miniRing, height: Theme.Size.miniRing)
                Text("第一次用，正在准备中文的听写 · \(Int(progress * 100))%")
            default:
                Image(systemName: "circle.fill").font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.bad)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text("正在听")
                Spacer(minLength: 0)
                if let start = voice.startedAt {
                    Text(timerInterval: start...start.addingTimeInterval(VoiceSession.limit), countsDown: false)
                        .monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
        }
        .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
    }

    /// 说的字：定下来的主字色，还没定下来的次要色；还没说时一句提示
    private var words: some View {
        Group {
            if voice.text.isEmpty {
                Text("说吧，我在听").foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                let settled = Text(voice.settled).foregroundStyle(Theme.Palette.label)
                let pending = Text(voice.pending).foregroundStyle(Theme.Palette.secondaryLabel)
                Text("\(settled)\(pending)")
            }
        }
        .font(Theme.Typeface.body).lineSpacing(Theme.Leading.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("voice.words")
    }

    private func finish(send: Bool) {
        Task {
            if let words = await voice.finish() { useText(words, send) }
        }
    }

    private func round(
        _ symbol: String, label: String, id: String, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // 圆是固定大小：图标封顶，不出圆；字号很大的人长按看大图标
            Image(systemName: symbol).font(Theme.Typeface.bodySemibold)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(filled ? Theme.Palette.onAccent : Theme.Palette.label)
                .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
                .background(filled ? Theme.Palette.accentFill : Theme.Palette.fill, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(label))
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
        .accessibilityIdentifier(id)
    }
}

/// 按住说：输入框上面一张玻璃卡「松开发送 / 手指往上滑，取消」，往上滑过了变成「松开取消」
struct HoldCard: View {
    @Environment(VoiceSession.self) private var voice
    let cancelling: Bool

    var body: some View {
        VStack(spacing: Theme.Space.small) {
            Waveform(levels: voice.levels).frame(height: Theme.Size.waveform)
            Text(voice.text.isEmpty ? "说吧，我在听" : voice.text).font(Theme.Typeface.body)
                .foregroundStyle(voice.text.isEmpty ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                .lineLimit(3)
            Text(cancelling ? "松开取消" : "松开发送 · 手指往上滑，取消").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(cancelling ? Theme.Palette.bad : Theme.Palette.secondaryLabel)
        }
        .padding(Theme.Space.regular)
        .frame(maxWidth: .infinity)
        .themeGlass(radius: Theme.Corner.card)
        .sensoryFeedback(Theme.Haptics.select, trigger: cancelling)
        .accessibilityElement(children: .combine)
    }
}

/// 声波：一排竖条，越新的越靠右；不说话时是平的
struct Waveform: View {
    let levels: [Double]

    var body: some View {
        Canvas { context, size in
            let count = CGFloat(levels.count)
            let gap: CGFloat = 2
            let width = max(1, (size.width - gap * (count - 1)) / count)
            for (index, level) in levels.enumerated() {
                let height = max(width, size.height * min(1, max(0.06, level)))
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                context.fill(Capsule().path(in: rect), with: .color(Theme.Palette.accent.opacity(0.35 + level * 0.65)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// 第一次点麦克风：先说清楚（只在手机上转字，录音不存不传），再请系统权限。
/// 字号很大时：说明放不下就能上下滑（两个按钮一直在下面），两个按钮上下排
struct VoiceIntro: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let start: () -> Void
    let later: () -> Void

    var body: some View {
        let buttons =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.small))
            : AnyLayout(HStackLayout(spacing: Theme.Space.small))
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ViewThatFits(in: .vertical) {
                message
                // 放不下：说明能上下滑，滚动条先闪一下告诉你下面还有
                ScrollView { message }.scrollBounceBehavior(.basedOnSize).scrollIndicatorsFlash(onAppear: true)
            }
            buttons {
                Button("好，开始说", action: start).buttonStyle(.borderedProminent).tint(Theme.Palette.accentFill)
                Button("先不用", action: later).buttonStyle(.bordered).tint(Theme.Palette.accent)
            }
            .font(Theme.Typeface.footnoteSemibold).buttonBorderShape(.capsule)
        }
        .padding(Theme.Space.regular)
        .themeGlass(radius: Theme.Corner.card)
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Label("用说的", systemImage: "mic").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            Text("说的话在这台手机上转成字，录音不存、不传。点「好，开始说」以后，系统会问能不能用麦克风。")
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .lineSpacing(Theme.Leading.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 听不了、没听清：一行说清楚；要去设置里打开麦克风的带一个按钮（字号很大时放在下面一行，字用满一行）
struct VoiceFailure: View {
    @Environment(VoiceSession.self) private var voice
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    let message: String
    let settings: Bool

    var body: some View {
        let below = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.small) {
                Image(systemName: "mic.slash").foregroundStyle(Theme.Palette.bad)
                Text(message).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: Theme.Space.tight)
                if !below { settingsButton }
                dismissButton
            }
            if below { settingsButton.frame(minHeight: Theme.Size.touch) }
        }
        .font(Theme.Typeface.footnoteMedium)
        .buttonStyle(.plain)
        .padding(.leading, Theme.Space.inset)
        .frame(minHeight: Theme.Size.touch)
        .themeGlass(radius: Theme.Corner.composer)
        .sensoryFeedback(Theme.Haptics.failed, trigger: message)
    }

    @ViewBuilder private var settingsButton: some View {
        if settings, let url = URL(string: UIApplication.openSettingsURLString) {
            Button("去设置") { openURL(url) }.foregroundStyle(Theme.Palette.accent)
        }
    }

    private var dismissButton: some View {
        Button {
            voice.dismissFailure()
        } label: {
            Image(systemName: "xmark").foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
        }
        .accessibilityLabel(Text("知道了"))
    }
}
