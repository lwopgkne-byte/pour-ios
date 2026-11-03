import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 加待办（01 需求文档 4.5、06 交互细节 2.3）：键盘马上出来；边打边认——认出来的字变蓝底，下面「📅 明天」「🔔 15:00 提醒」
/// 「↻ 每周五」三个胶囊（程序认，不等 AI，打字停 150 毫秒就认）；没输入时四个例子点一下填进去；
/// 回车或「加上」：弹层关掉，新的一行出现在对的组、亮一下。打的这句话照样存成原话
struct TodoAddSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var when: API.When?
    /// 输入框旁边的麦克风：说话也能加（和「说一句」同一套听写，在手机上转成字）
    @State private var voice = VoiceSession(input: VoiceSession.makeInput())
    @FocusState private var focused: Bool

    static let examples = ["明天下午三点取快递", "下周一上午十点交方案", "半小时后给妈妈打电话", "每周五晚上八点给爸妈打视频"]

    init(text: String) {
        _text = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    field
                    if trimmed.isEmpty { examples } else { recognized }
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
            .scrollDismissesKeyboard(.never)
        }
        .background(Theme.Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        // 打字停 150 毫秒再认（06 交互细节 2.3：程序认，100 毫秒内回来）
        .task(id: trimmed) {
            guard !trimmed.isEmpty else {
                when = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            if let found = try? await model.client.parseWhen(trimmed), !Task.isCancelled { when = found }
        }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var header: some View {
        HStack {
            // 能点的范围撑在按钮里面（外面加的尺寸不算）
            ThemeTextButton("取消", font: Theme.Typeface.body) { dismiss() }
            Spacer()
            Text("加待办").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: add) {
                Text("加上").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(trimmed.isEmpty ? Theme.Palette.tertiaryLabel : Theme.Palette.onAccent)
                    .padding(.horizontal, Theme.Space.regular)
                    .frame(minHeight: Theme.Size.capsule)
                    .background(trimmed.isEmpty ? Theme.Palette.fill : Theme.Palette.accentFill, in: Capsule())
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .disabled(trimmed.isEmpty)
            .accessibilityIdentifier("todoAdd.add")
        }
        .padding(.horizontal, Theme.Space.small)
        .padding(.top, Theme.Space.small)
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .center, spacing: Theme.Space.small) {
                TextField("比如：明天下午三点取快递", text: $text, axis: .vertical)
                    .font(Theme.Typeface.summary)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("todoAdd.field")
                    // 竖着能长的输入框里回车是换行：拦下来当「加上」
                    .onChange(of: text) { _, now in
                        guard now.contains("\n") else { return }
                        text = now.replacingOccurrences(of: "\n", with: "")
                        add()
                    }
                mic
            }
            .padding(.leading, Theme.Space.regular)
            .padding(.trailing, Theme.Space.tight)
            .padding(.vertical, Theme.Space.tight)
            .frame(minHeight: Theme.Size.composer)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
            if case .failed(let message, _) = voice.phase {
                Text(message).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.warn)
            }
        }
        // 说着话：字一边出来一边填进输入框
        .onChange(of: voice.text) { _, now in
            if voice.active, !now.isEmpty { text = now }
        }
    }

    /// 点一下开始听，再点一下停下、说的字填进输入框（下面马上认时间）
    private var mic: some View {
        Button {
            Task {
                if voice.active {
                    if let words = await voice.finish() { text = words }
                    focused = true
                } else {
                    focused = false
                    voice.start(.tap)
                }
            }
        } label: {
            Image(systemName: voice.active ? "stop.fill" : Theme.Symbol.mic)
                .font(Theme.Typeface.bodySemibold)
                .foregroundStyle(voice.active ? Theme.Palette.onAccent : Theme.Palette.accent)
                .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
                .background(voice.active ? Theme.Palette.accentFill : Theme.Palette.bubble, in: Circle())
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(voice.active ? "说完了" : "说话"))
        .accessibilityIdentifier("todoAdd.mic")
    }

    /// 没输入时：四个例子，点一下填进去
    private var examples: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("试试这样说（点一下填进去）").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            ForEach(Self.examples, id: \.self) { example in
                Button {
                    text = example
                } label: {
                    Text(example).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                        .padding(.horizontal, Theme.Space.regular)
                        .background(Theme.Palette.card, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScale())
            }
        }
    }

    /// 认出来的：原话里认出的字蓝底；日子、提醒、重复三个胶囊；会记成什么
    @ViewBuilder private var recognized: some View {
        if let when {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                Text(highlighted(when)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityIdentifier("todoAdd.preview")
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    chip(dayLabel(when), symbol: "calendar", lit: when.day != nil)
                    if let time = when.time {
                        chip("\(time) 提醒", symbol: Theme.Symbol.remind, lit: true)
                    } else {
                        chip("不提醒", symbol: "bell.slash", lit: false)
                    }
                    if let repeatText = when.repeatText { chip(repeatText, symbol: Theme.Symbol.repeats, lit: true) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("todoAdd.when")
                Text("会记成：\(Text(when.title).foregroundStyle(Theme.Palette.label).bold()) · 打的这句话照样存成原话")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }

    private func chip(_ title: String, symbol: String, lit: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(Theme.Typeface.subheadline).monospacedDigit()
            .foregroundStyle(lit ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.medium)
            .frame(minHeight: Theme.Size.capsule)
            .background(lit ? Theme.Palette.bubble : Theme.Palette.card, in: Capsule())
    }

    /// 「明天」「10月30日 周五」；没说哪天是今天
    private func dayLabel(_ when: API.When) -> String {
        guard let day = when.day else { return "今天" }
        return TodoBoard.when(day: day, time: nil, today: model.today)
    }

    /// 认出来的字变蓝底（服务器给的位置是 JS 的下标，就是 UTF-16 的位置）
    private func highlighted(_ when: API.When) -> AttributedString {
        let source = trimmed
        var result = AttributedString(source)
        for span in when.spans where span.count == 2 {
            let utf16 = source.utf16
            guard span[0] >= 0, span[1] <= utf16.count, span[0] < span[1],
                let start = utf16.index(utf16.startIndex, offsetBy: span[0], limitedBy: utf16.endIndex),
                let end = utf16.index(utf16.startIndex, offsetBy: span[1], limitedBy: utf16.endIndex),
                let range = Range(start..<end, in: result)
            else { continue }
            result[range].backgroundColor = Theme.Palette.bubble
            result[range].foregroundColor = Theme.Palette.accent
        }
        return result
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        if voice.active { voice.cancel() }
        model.addTodo(trimmed)
        dismiss()
    }
}
