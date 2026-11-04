import PourDesign
import SwiftUI
import UIKit

/// 点一下说（docs/模块/生活画布2.0.md 第 6 节；样子照原型「说一句」的听写）：弹层最下面那一块换成听写——
/// 红点「正在听」和计时、说的字居中一边说一边出（还没定下来的字浅一点）、一小排蓝色的声波；
/// 下面三个胶囊：不要了、转成字（放进输入框再改）、发送。接着说的时候上面浅浅地写着前面说过的
struct VoiceCard: View {
    @Environment(VoiceSession.self) private var voice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 输入框里已经有的字：接着说的时候浅浅地写在上面，说的接在后面
    var before = ""
    /// 在说一句的弹层里（白底那一块）；不在的话是一张玻璃卡
    var open = true
    /// 转成字：字放进输入框；发送：发出去
    let useText: (String, _ send: Bool) -> Void

    var body: some View {
        VStack(spacing: Theme.Space.small + Theme.Space.hairline) {
            header
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("接着说 · \(before)").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(2).truncationMode(.head).multilineTextAlignment(.center)
                    .accessibilityIdentifier("voice.before")
            }
            words
            VoiceBars(levels: voice.levels)
            HStack(spacing: Theme.Space.small) {
                chip("xmark", "不要了", id: "voice.cancel", filled: false) { voice.cancel() }
                chip("character.cursor.ibeam", "转成字", id: "voice.text", filled: false) { finish(send: false) }
                chip("arrow.up", "发送", id: "voice.send", filled: true) { finish(send: true) }
            }
            .disabled(voice.phase != .listening)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, open ? Theme.Space.snug : Theme.Space.regular)
        .padding(.horizontal, open ? 0 : Theme.Space.regular)
        .themeGlass(radius: Theme.Corner.card, active: !open)
        .sensoryFeedback(Theme.Haptics.warning, trigger: voice.nearLimit) { _, near in near }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("正在听你说"))
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: Theme.Space.snug) {
            switch voice.phase {
            case .preparing(let progress):
                ProgressRing(progress: progress, color: Theme.Palette.accent, lineWidth: 3)
                    .frame(width: Theme.Size.miniRing, height: Theme.Size.miniRing)
                Text("第一次用，正在准备中文的听写 · \(Int(progress * 100))%")
            default:
                Image(systemName: "circle.fill").font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.bad)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text("正在听")
                if let start = voice.startedAt {
                    Text(timerInterval: start...start.addingTimeInterval(VoiceSession.limit), countsDown: false)
                        .monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
        }
        .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
    }

    /// 说的字（原型 18 号、居中）：定下来的主字色，还没定下来的次要色；还没说时「在听……」。
    /// 一直没听到声音、说完停了一会儿：下面一行小字提示（VoiceSession.hint）
    private var words: some View {
        VStack(spacing: Theme.Space.tight) {
            Group {
                if voice.text.isEmpty {
                    Text(voice.hint ?? "在听……").foregroundStyle(Theme.Palette.secondaryLabel)
                } else {
                    let settled = Text(voice.settled).foregroundStyle(Theme.Palette.label)
                    let pending = Text(voice.pending).foregroundStyle(Theme.Palette.secondaryLabel)
                    Text("\(settled)\(pending)")
                }
            }
            .font(Theme.Typeface.body).lineSpacing(Theme.Leading.body).multilineTextAlignment(.center)
            .accessibilityIdentifier("voice.words")
            if !voice.text.isEmpty, let hint = voice.hint {
                Text(hint).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(Theme.Motion.quick, value: voice.hint)
    }

    private func finish(send: Bool) {
        Task {
            if let words = await voice.finish() { useText(words, send) }
        }
    }

    /// 下面的胶囊（原型 .chip：32 高、浅墨底；发送是蓝底白字），点的地方 44 高
    private func chip(
        _ symbol: String, _ title: String, id: String, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                Image(systemName: symbol).font(Theme.Typeface.footnoteSemibold)
                Text(title).font(filled ? Theme.Typeface.cardTitle : Theme.Typeface.subheadline)
            }
            .foregroundStyle(filled ? Theme.Palette.onAccent : Theme.Palette.label)
            .padding(.horizontal, Theme.Space.medium + Theme.Space.tight)
            .frame(minHeight: Theme.Size.capsule)
            .background(filled ? Theme.Palette.accentFill : Theme.Palette.fill, in: Capsule())
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(id)
    }
}

/// 按住说（原型的听写）：说的字居中、一小排蓝色的声波、下面一个胶囊「松开发送 · 手指往上滑，取消」，往上滑过了变成红的「松开取消」
struct HoldCard: View {
    @Environment(VoiceSession.self) private var voice
    let cancelling: Bool
    /// 在说一句的弹层里；不在的话是一张玻璃卡
    var open = true

    var body: some View {
        VStack(spacing: Theme.Space.small + Theme.Space.hairline) {
            Text(voice.text.isEmpty ? (voice.hint ?? "在听……") : voice.text).font(Theme.Typeface.body)
                .foregroundStyle(voice.text.isEmpty ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            VoiceBars(levels: voice.levels)
            Text(cancelling ? "松开取消" : "松开发送 · 手指往上滑，取消").font(Theme.Typeface.subheadline)
                .foregroundStyle(cancelling ? Theme.Palette.badInk : Theme.Palette.label)
                .padding(.horizontal, Theme.Space.medium + Theme.Space.tight)
                .frame(minHeight: Theme.Size.capsule)
                .background(cancelling ? Theme.Palette.badFill : Theme.Palette.fill, in: Capsule())
        }
        .padding(.vertical, open ? Theme.Space.snug : Theme.Space.regular)
        .padding(.horizontal, open ? 0 : Theme.Space.regular)
        .frame(maxWidth: .infinity)
        .themeGlass(radius: Theme.Corner.card, active: !open)
        .sensoryFeedback(Theme.Haptics.select, trigger: cancelling)
        .accessibilityElement(children: .combine)
    }
}

/// 听写时的声波（原型 .wave）：七根 4 点宽的蓝条，跟着最近的声音高低（8 到 36 点）；不说话时是一排短短的。
/// 音量扣掉了底噪（LevelMeter）；小声也看得出来（高度按音量的 0.8 次方）
struct VoiceBars: View {
    let levels: [Double]
    static let count = 7

    var body: some View {
        let recent = Array(levels.suffix(Self.count))
        let shown = [Double](repeating: 0, count: max(0, Self.count - recent.count)) + recent
        HStack(spacing: Theme.Space.tight) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, level in
                Capsule().fill(Theme.Palette.accent)
                    .frame(width: Theme.Space.tight, height: Self.height(level))
            }
        }
        .frame(height: Theme.Size.touch)
        .animation(Theme.Motion.quick, value: levels)
        .accessibilityHidden(true)
    }

    static func height(_ level: Double) -> CGFloat {
        let low = Theme.Space.small
        let high = Theme.Size.capsule + Theme.Space.tight
        return low + (high - low) * pow(min(1, max(0, level)), 0.8)
    }
}

/// 第一次点麦克风：先说清楚（只在手机上转字，录音不存不传），再请系统权限。
/// 说明放不下（屏幕小、字大）就能上下滑，两个按钮一直在下面
struct VoiceIntro: View {
    /// 在说一句的弹层里：暖白底的一块；不在的话是一张玻璃卡
    var open = true
    let start: () -> Void
    let later: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ViewThatFits(in: .vertical) {
                message
                // 放不下：说明能上下滑，滚动条先闪一下告诉你下面还有
                ScrollView { message }.scrollBounceBehavior(.basedOnSize).scrollIndicatorsFlash(onAppear: true)
            }
            HStack(spacing: Theme.Space.small) {
                Button("好，开始说", action: start).buttonStyle(.borderedProminent).tint(Theme.Palette.accentFill)
                Button("先不用", action: later).buttonStyle(.bordered).tint(Theme.Palette.accent)
            }
            .font(Theme.Typeface.footnoteSemibold).buttonBorderShape(.capsule)
        }
        .padding(Theme.Space.regular)
        .background {
            if open { Theme.rounded(Theme.Corner.card).fill(Theme.Palette.sheet) }
        }
        .themeGlass(radius: Theme.Corner.card, active: !open)
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

/// 听不了、没听清：一行说清楚；要去设置里打开麦克风的带一个按钮
struct VoiceFailure: View {
    @Environment(VoiceSession.self) private var voice
    @Environment(\.openURL) private var openURL
    let message: String
    let settings: Bool
    /// 在说一句的弹层里：暖白底的一条；不在的话是玻璃
    var open = true

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Image(systemName: "mic.slash").foregroundStyle(Theme.Palette.bad)
            Text(message).foregroundStyle(Theme.Palette.label)
            Spacer(minLength: Theme.Space.tight)
            settingsButton
            dismissButton
        }
        .font(Theme.Typeface.footnoteMedium)
        .buttonStyle(.plain)
        .padding(.leading, Theme.Space.inset)
        .frame(minHeight: Theme.Size.touch)
        .background {
            if open { Theme.rounded(Theme.Corner.composer).fill(Theme.Palette.sheet) }
        }
        .themeGlass(radius: Theme.Corner.composer, active: !open)
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
