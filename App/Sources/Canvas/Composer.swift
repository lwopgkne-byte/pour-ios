import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 底部的「说一句」（docs/模块/生活画布2.0.md 第 6 节；样子照可交互原型 1:1，产品主人 2026-11-03）。
/// 收着时是浮在页面上的玻璃条（离两边 16、离底 10，50 高）：左边「对话」、中间输入（最多长到 6 行）、右边蓝色的圆
/// （没字时是麦克风；有字时是发送，麦克风缩进输入框里）；上面一条玻璃小条说刚才那段话整理到哪了（ComposerStatus）。
/// 点一下、发出去：从下面拉上来一张几乎满屏的弹层（原型 ChatSheet）——上面两个大圆角、暖白底、往上一层影子，后面的页面压暗；
/// 最下面九成白的一块放快捷和输入框，上面一条细线，一直铺到屏幕底边
struct Composer: View {
    @Environment(AppModel.self) private var model
    @Environment(VoiceSession.self) private var voice
    @Environment(\.visibleHeight) private var visibleHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Bool
    @State private var drag: CGFloat = 0
    /// 第一次点麦克风：先看一张说明
    @State private var intro = false
    /// 按住说的时候往上滑过了（松开就不要了）
    @State private var cancelling = false
    /// 最下面那一块（说明、命令、快捷、输入框或听写）有多高：对话让出这么多。量的是整块，
    /// 打「/」时快捷收起、命令出来也是一个数（分开量的话快捷消失那一下会把命令的高度清成 0，2026-10-31 界面测试查出来的）
    @State private var dockHeight: CGFloat = 0

    var body: some View {
        @Bindable var model = model
        let open = model.chatOpen
        VStack(spacing: open ? 0 : Theme.Space.small) {
            let commands = Show.slashMenu(model.draft)
            // 快捷一直在（原型：打了字也在），只有列出斜杠命令、正在听的时候让开
            let chips = open && commands.isEmpty && !voice.active
            // 弹层上沿离顶上安全区 10 点（原型 calc(100% - top - 10px)）；键盘弹着时照看得见的那一截算
            let chatHeight = visibleHeight - Theme.Space.small - Theme.Space.hairline - dockHeight
            if open, chatHeight >= Theme.Size.touch {
                ChatPanel(drag: $drag)
                    .frame(height: chatHeight)
                    .themeTransition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !open { ComposerStatus() }
            // 最下面那一块（原型 padding 8 12 bot+12）：收着时什么都不垫，输入条自己是玻璃
            VStack(spacing: Theme.Space.small) {
                voiceExtras(open: open)
                if !commands.isEmpty {
                    SlashMenu(commands: commands, open: open) { command in
                        model.draft = "\(command.cmd) "
                        focused = true
                    }
                }
                if chips {
                    SayChips { prefix in
                        model.draft = prefix
                        focused = true
                    }
                }
                if voice.active, voice.mode == .tap {
                    VoiceCard(before: model.draft, open: open) { words, send in use(words, send: send) }
                        .themeTransition(.opacity)
                } else {
                    ComposerBar(
                        focused: $focused, open: open, cancelling: $cancelling, tapMic: tapMic,
                        sendWords: { use($0, send: true) })
                }
            }
            .padding(.top, open ? Theme.Space.small : 0)
            .padding(.horizontal, open ? Theme.Space.medium : 0)
            .padding(.bottom, open ? Theme.Space.medium : 0)
            .background {
                if open { DockBackground() }
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                dockHeight = $0
            }
        }
        // 开着：上面两个大圆角的暖白底，往上一层影子，铺到屏幕底边（原型 .sheet）。
        // 只画底、不裁：裁了的话收着时玻璃边上那圈柔光会被切掉，输入框换了样子键盘的焦点也会丢
        .background {
            if open {
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Corner.sheet, topTrailingRadius: Theme.Corner.sheet, style: .continuous
                )
                .fill(Theme.Palette.sheet)
                .shadow(color: Theme.Palette.sheetShadow, radius: Theme.Space.large, y: -Theme.Space.small)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .offset(y: max(0, drag))
        // 收着：离两边 16、离底 10（原型 .say 的 margin）
        .padding(.horizontal, open ? 0 : Theme.Space.regular)
        .padding(.bottom, open ? 0 : Theme.Space.small + Theme.Space.hairline)
        // 收起对话是要看画布：键盘一起收起来
        .onChange(of: model.chatOpen) { _, open in
            if !open { focused = false }
        }
        // 点「说一句」：展开成对话，上面一排快捷（docs/3.0/01-需求文档.md 2.2）
        .onChange(of: focused) { _, isFocused in
            if isFocused, !model.chatOpen { model.chatOpen = true }
        }
        // 别处先填好了一段（时间轴上点空当补记）：弹出键盘接着说
        .onChange(of: model.composeFocus) { focused = true }
        // 小组件、控制中心的「说一句」（pour://voice）：打开就开始听
        .onAppear(perform: startPendingVoice)
        .onChange(of: model.voicePending) { startPendingVoice() }
        .animation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion), value: open)
        .animation(Theme.Motion.pick(Theme.Motion.emphasized, reduceMotion: reduceMotion), value: voice.active)
        .onAppear {
            voice.onLimit = finishAtLimit
            voice.onInterrupted = keepWords
        }
        // 说着话切到别的 App、锁屏：系统会关掉麦克风——说到的字放进输入框
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, voice.active { keepWords() }
        }
        .modifier(ComposerHaptics())
    }

    /// 输入框上面跟说话有关的：第一次的说明、按住说的卡、听不了的那句话
    @ViewBuilder private func voiceExtras(open: Bool) -> some View {
        if intro {
            VoiceIntro(open: open) {
                intro = false
                voice.explained = true
                voice.start(.tap)
            } later: {
                intro = false
            }
            .themeTransition(.move(edge: .bottom).combined(with: .opacity))
        }
        if voice.active, voice.mode == .hold {
            HoldCard(cancelling: cancelling, open: open)
                .themeTransition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
        }
        if case .failed(let message, let settings) = voice.phase {
            VoiceFailure(message: message, settings: settings, open: open).transition(.opacity)
        }
    }

    /// 小组件、控制中心叫起来的：和点麦克风一样
    private func startPendingVoice() {
        guard model.voicePending, !voice.active else { return }
        model.voicePending = false
        tapMic()
    }

    /// 点麦克风：和原型一样拉上来对话，在最下面听（第一次先看说明）
    private func tapMic() {
        focused = false
        voice.dismissFailure()
        if !model.chatOpen { model.chatOpen = true }
        if voice.explained {
            voice.start(.tap)
        } else {
            intro = true
        }
    }

    /// 说完的字：✓ 放进输入框再改，↑ 和松开就发出去。输入框里已经有字的（说了一半停了、又接着说），接在后面
    private func use(_ words: String, send: Bool) {
        model.draft = Self.joined(model.draft, words)
        if send {
            withAnimation(Theme.Motion.pick(Theme.Motion.emphasized, reduceMotion: reduceMotion)) { model.send() }
        } else {
            focused = true
        }
    }

    /// 被打断了（来电话、闹钟、换耳机、锁屏）：说到的字放进输入框，不发；什么都没说就安静地收起
    private func keepWords() {
        Task {
            guard let words = await voice.finish(quiet: true) else { return }
            model.draft = Self.joined(model.draft, words)
            model.toast("录音停了，说到的字放在输入框里")
        }
    }

    /// 接着说：输入框里已经有字、末尾没有标点的，先加一个逗号再接（「早上跑了五公里，中午和小王吃面」）
    static func joined(_ draft: String, _ words: String) -> String {
        let head = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = head.last else { return tail }
        guard !tail.isEmpty else { return head }
        let ends = last.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
        return ends ? head + tail : head + "，" + tail
    }

    /// 说到 2 分钟：点一下说的转成字留着再改，按住说的发出去
    private func finishAtLimit() {
        let send = voice.mode == .hold
        Task { if let words = await voice.finish() { use(words, send: send) } }
    }
}

/// 输入的那一行。收着（原型 .say）：左边「对话」、中间输入、右边蓝色的圆；开着（原型 ChatSheet 的 form）：
/// 42 高的输入框（暖白底、一圈细线、两头圆）+ 右边蓝色的圆。蓝色的圆没字时是麦克风，有字时是发送——
/// 有字时麦克风缩进输入框右边，说了一半停了也能接着说（产品主人 2026-11-03：「语音不能连续说」）
private struct ComposerBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    /// 输入框换过几次；字号变过、还没换
    @State private var fieldID = 0
    @State private var resized = false
    var focused: FocusState<Bool>.Binding
    let open: Bool
    @Binding var cancelling: Bool
    let tapMic: () -> Void
    let sendWords: (String) -> Void

    var body: some View {
        @Bindable var model = model
        let empty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack(alignment: .bottom, spacing: Theme.Space.small) {
            if !open { chatButton }
            HStack(alignment: .bottom, spacing: 0) {
                TextField(Show.spaced(placeholder), text: $model.draft, axis: .vertical)
                    .font(Theme.Typeface.message)
                    .foregroundStyle(Theme.Palette.label)
                    .lineLimit(1...6)
                    .padding(.vertical, Theme.Space.small)
                    .frame(minHeight: open ? Theme.Size.field : Theme.Size.touch)
                    .padding(.leading, open ? Theme.Space.regular : 0)
                    .padding(.trailing, open && empty ? Theme.Space.regular : 0)
                    .focused(focused)
                    .accessibilityLabel(Text(backfilling ? "补记 \(Show.monthDay(model.shownDay))" : "说一句"))
                    .accessibilityIdentifier("pourbar.input")
                    // 字号调小以后（控制中心、设置里调），多行的输入框不会自己缩回去：回到 App 时换一个新的。
                    // 不在字号一变就换：审计正看着它时换掉，后面的审计会一直等那个旧的、超时
                    .id(fieldID)
                    .onChange(of: typeSize) { resized = true }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active, resized else { return }
                        resized = false
                        fieldID += 1
                    }
                if !empty {
                    MicButton(tap: tapMic, send: sendWords, cancelling: $cancelling, style: .inline)
                        .frame(height: open ? Theme.Size.field : Theme.Size.touch)
                        .themeTransition(.opacity)
                }
            }
            .background {
                if open {
                    Theme.rounded(Theme.Size.field / 2).fill(Theme.Palette.sheet)
                        .overlay(Theme.rounded(Theme.Size.field / 2).strokeBorder(Theme.Palette.separator))
                }
            }
            // 蓝色的圆：排的时候 40 宽（和原型一样贴着），点的地方 44
            Group {
                if empty {
                    MicButton(tap: tapMic, send: sendWords, cancelling: $cancelling)
                } else {
                    sendButton
                }
            }
            .padding(.horizontal, -(Theme.Size.touch - Theme.Size.micButton) / 2)
            .padding(.vertical, open ? -(Theme.Size.touch - Theme.Size.field) / 2 : 0)
            .themeTransition(.scale.combined(with: .opacity))
        }
        .padding(.leading, open ? 0 : (Theme.Size.sayBar - Theme.Size.sayIcon) / 2)
        .padding(.trailing, open ? 0 : (Theme.Size.sayBar - Theme.Size.micButton) / 2)
        .padding(.vertical, open ? 0 : (Theme.Size.sayBar - Theme.Size.touch) / 2)
        .animation(Theme.Motion.quick, value: empty)
        .modifier(GlassWhenFloating(floating: !open))
    }

    /// 收着时左边的「对话」（原型 forum 图标，38 的方块）：点了拉上来对话
    private var chatButton: some View {
        Button {
            withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                model.chatOpen = true
            }
        } label: {
            // 输入框上的按钮和系统的栏一样：图标封顶，字号很大的人长按看大图标（输入的字照样跟着变大）
            Image(systemName: "bubble.left.and.bubble.right")
                .font(Theme.Typeface.toolbarIcon).foregroundStyle(Theme.Palette.secondaryLabel)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -(Theme.Size.touch - Theme.Size.sayIcon) / 2)
        .accessibilityLabel(Text("展开对话"))
        .accessibilityShowsLargeContentViewer { Label("展开对话", systemImage: "bubble.left.and.bubble.right") }
        .accessibilityIdentifier("pourbar.chat")
    }

    /// 发送（有字的时候）：蓝色的圆里一个纸飞机（原型 send）
    private var sendButton: some View {
        Button {
            withAnimation(Theme.Motion.pick(Theme.Motion.emphasized, reduceMotion: reduceMotion)) { model.send() }
        } label: {
            Image(systemName: "paperplane.fill").font(Theme.Typeface.sendIcon)
                .rotationEffect(.degrees(45))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: Theme.Size.micButton, height: Theme.Size.micButton)
                .background(Theme.Palette.accentFill, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text("发送"))
        .accessibilityShowsLargeContentViewer { Label("发送", systemImage: "paperplane.fill") }
        .accessibilityIdentifier("pourbar.send")
    }

    /// 在画布上看以前的某一天：说的话补记到那一天（docs/模块/产品优化.md R1.1）
    private var backfilling: Bool { model.stack.isEmpty && model.shownDay < model.today }

    /// 提示跟着页面变（docs/3.0/01-需求文档.md 2.2；字照原型）：收着时在待办、钱、目标、心情、感悟那一页说什么，
    /// 画布上早上问吃了什么、白天问做了什么、晚上（6 点到日界线）问哪一刻觉得挺好，别的页「说一句……」；
    /// 对话开着时「说点什么，比如：晚饭 35」；在画布上看以前的日子时「补记 10月25日：那天做了什么？」
    private var placeholder: String {
        if backfilling { return "补记 \(Show.monthDay(model.shownDay))：那天做了什么？" }
        if open { return "说点什么，比如：晚饭 35" }
        switch model.sayContext {
        case "money": return "记一笔，比如：午饭 25"
        case "goals": return "定个目标，比如：每周跑 3 次"
        case "mood": return "现在心情怎么样？说一句"
        case "insights": return "想明白了什么？说一句"
        case "todos": return "说一句待办：明天三点取快递"
        default: break
        }
        guard model.stack.isEmpty else { return "说一句……" }
        let now = Date()
        if Show.isEvening(now, boundary: model.dayBoundary) { return "今天哪一刻觉得挺好？" }
        let hour = Calendar.current.component(.hour, from: now)
        return (5..<10).contains(hour) ? "早上吃了什么？" : "今天做了什么？比如：跑步 1 小时"
    }
}

/// 弹层最下面那一块的底（原型 rgba(255,255,255,.9) + 上面一条细线）：一直铺到屏幕底边
private struct DockBackground: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: 0) {
            Theme.Palette.separator.frame(height: 1 / displayScale)
            Theme.Palette.dock
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// 收着对话时，输入框是浮着的玻璃
private struct GlassWhenFloating: ViewModifier {
    let floating: Bool

    func body(content: Content) -> some View {
        content.themeGlass(radius: Theme.Size.sayBar / 2, active: floating)
    }
}
