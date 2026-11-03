import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话面板（docs/模块/生活画布2.0.md 第 7 节；2026-11-03 产品主人说「太粗糙了」重做样子）：
/// 上面小横条 + 「对话」+ 关闭；暖灰底，按天分隔（居中一行小字），你的话在右边蓝底白字的气泡里，
/// 整理的结果在左边白卡片上（收据、回复、追问；ChatMessages）；话少时贴着输入框往上排（像「信息」）；
/// 往下拖上面那一条收起；往上翻自动拿更早的，离开底部时下面正中「回到最新」。
/// 还没交给服务器的话（没网时）排在最后，写「正在保存」或者「没有保存上 · 重试」
struct ChatPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var drag: CGFloat
    @State private var atBottom = true

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: Theme.Space.regular) {
                        // 翻到最上面自动拿更早的一页，拿完停在原来看的地方（看见「加载更早的记录」就拿）
                        if model.chatHasMore {
                            Dots(label: "加载更早的记录").foregroundStyle(Theme.Palette.tertiaryLabel)
                                .padding(.top, Theme.Space.small)
                                .onScrollVisibilityChange { visible in
                                    guard visible, let first = rows.first?.id else { return }
                                    Task {
                                        await model.loadEarlierChat()
                                        reader.scrollTo(first, anchor: .top)
                                    }
                                }
                        }
                        if rows.isEmpty { ChatEmpty() }
                        ForEach(rows, id: \.id) { row in
                            switch row {
                            case .day(_, let label): DaySeparator(label: label)
                            case .note(let note): NoteMessage(note: note)
                            case .message(let message): MessageCard(message: message)
                            case .outbox(let item): OutboxMessage(item: item)
                            }
                        }
                        footer
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, Theme.Space.regular)
                    .padding(.bottom, Theme.Space.regular)
                }
                .scrollDismissesKeyboard(.interactively)
                // 话少时贴着下面（输入框）排，不在上面留一大片空
                .defaultScrollAnchor(.bottom)
                // 界面测试认对话面板用（AppAudit：面板里滚到上沿后面、只露出一截的字不量）
                .accessibilityIdentifier("chat.scroll")
                .onAppear { reader.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: bottomKey) { _, _ in
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        reader.scrollTo("bottom", anchor: .bottom)
                    }
                }
                // 离开底部半屏以上：右下角「回到最新」
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.containerSize.height
                        >= geometry.contentSize.height - geometry.containerSize.height / 2
                } action: { _, now in
                    atBottom = now
                }
                // 下面正中：不压在右边你的气泡、左边的收据上
                .overlay(alignment: .bottom) {
                    if !atBottom {
                        GlassCircleButton("arrow.down", label: "回到最新") {
                            withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                                reader.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .padding(.bottom, Theme.Space.small)
                        .themeTransition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .animation(Theme.Motion.pick(Theme.Motion.quick, reduceMotion: reduceMotion), value: atBottom)
            }
        }
        .background(Theme.Palette.background)
    }

    /// 上面一条：小横条、「对话」、右边关闭；整条都能往下拖收起
    private var header: some View {
        VStack(spacing: Theme.Space.tight) {
            Capsule().fill(Theme.Palette.separator)
                .frame(width: Theme.Space.section + Theme.Space.tight, height: Theme.Space.tight + 1)
                .accessibilityHidden(true)
            HStack(spacing: Theme.Space.small) {
                Text("对话").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        model.chatOpen = false
                    }
                } label: {
                    Image(systemName: "xmark").font(Theme.Typeface.glyph).foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(width: Theme.Size.sendButton, height: Theme.Size.sendButton)
                        .background(Theme.Palette.fill, in: Circle())
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("关闭对话"))
                .accessibilityIdentifier("chat.close")
            }
            .padding(.leading, Theme.Space.regular)
            .padding(.trailing, Theme.Space.tight)
        }
        .padding(.top, Theme.Space.small)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { end in
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        if end.translation.height > Theme.Size.touch + Theme.Space.regular {
                            model.chatOpen = false
                        }
                        drag = 0
                    }
                }
        )
    }

    /// 最下面：排队的话共用一个暂停原因（比如还没填大模型的密钥），只说一次；没保存上的说会自动重发
    @ViewBuilder private var footer: some View {
        if let blocker {
            Text(Show.spaced("\(waiting) 段话在排队：\(blocker)")).font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.center)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.85 }
                .padding(.top, Theme.Space.small)
        }
        if let failed = model.outbox.first(where: { $0.failed != nil })?.failed {
            Text("\(failed)这段话先存在这台设备上，恢复后会自动重发。")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private enum Row {
        case day(String, String)
        case note(API.Note)
        case message(API.SystemMessage)
        case outbox(AppModel.Outbox)

        var id: String {
            switch self {
            case .day(let day, _): "day-\(day)"
            case .note(let note): "note-\(note.id)"
            case .message(let message): "msg-\(message.id)"
            case .outbox(let item): "out-\(item.clientId)"
            }
        }
    }

    /// 原话和系统消息按时间排，每天前面插一个分隔；还没交给服务器的放在最后（算今天）
    private var rows: [Row] {
        var out: [Row] = []
        var lastDay: String?
        func day(_ value: String) {
            guard value != lastDay else { return }
            lastDay = value
            out.append(.day(value, Self.separator(value, today: model.today)))
        }
        // 补记的按说的那天分（它的 day 是补记到的那天，气泡下面写着）
        let notes = model.chat.map { note in
            let said = note.backfill == true ? Show.logicalDay(note.createdAt, boundary: model.dayBoundary) : nil
            return (at: note.createdAt, day: said ?? note.day, row: Row.note(note))
        }
        let messages = model.messages.map { message in
            let day = Show.logicalDay(message.createdAt, boundary: model.dayBoundary) ?? model.today
            return (at: message.createdAt, day: day, row: Row.message(message))
        }
        for item in (notes + messages).sorted(by: { $0.at < $1.at }) {
            day(item.day)
            out.append(item.row)
        }
        for item in model.outbox {
            day(model.today)
            out.append(.outbox(item))
        }
        return out
    }

    /// 按天分隔：「今天 · 10月21日」「10月18日 周六」
    static func separator(_ day: String, today: String) -> String {
        if let relative = Show.relative(day, today: today) { return "\(relative) · \(Show.monthDay(day))" }
        return "\(Show.monthDay(day)) \(Show.weekday(day))"
    }

    private var waiting: Int { model.chat.filter { $0.status == "pending" }.count }
    private var blocker: String? { model.chat.first { $0.status == "pending" && $0.error != nil }?.error }

    /// 有新的话、最后一段整理完长出结果时滚到底
    private var bottomKey: String { "\(rows.last?.id ?? "")-\(model.chat.last?.status ?? "")" }
}

/// 按天分隔：居中一行小字（像「信息」，不加底色）
private struct DaySeparator: View {
    let label: String

    var body: some View {
        Text(label).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Space.small)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 还没说过话：一句说明 + 三个例子，点一下填进输入框
private struct ChatEmpty: View {
    @Environment(AppModel.self) private var model
    static let examples = ["8点跑了5公里", "午饭花了35", "这周睡得怎么样"]

    var body: some View {
        VStack(spacing: Theme.Space.medium) {
            Text("说说今天").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            Text("说过的话会出现在这里，整理好的记录长在画布上。").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.center)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) {
                ForEach(Self.examples, id: \.self) { example in
                    Button {
                        model.draft = example
                    } label: {
                        Text(Show.spaced(example)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                            .background(Theme.Palette.fill, in: Capsule())
                            .frame(minHeight: Theme.Size.touch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale())
                    .accessibilityHint(Text("填进输入框"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.section)
    }
}
