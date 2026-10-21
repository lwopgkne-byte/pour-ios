import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话面板（docs/模块/生活画布2.0.md 第 7 节）：按天分隔的历史（居中的小胶囊），你的话在右边浅蓝的气泡里，
/// 整理的结果在左边（收据小卡、回复、追问；ChatMessages）；拖上面的小横条往下收起；往上翻自动拿更早的，
/// 离开底部时右下角「回到最新」。还没交给服务器的话（没网时）排在最后，写「正在保存」或者「没有保存上 · 重试」
struct ChatPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var drag: CGFloat
    @State private var atBottom = true

    var body: some View {
        VStack(spacing: 0) {
            handle
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: Theme.Space.medium) {
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
                            case .day(_, let label): DayCapsule(label: label)
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
                .overlay(alignment: .bottomTrailing) {
                    if !atBottom {
                        GlassCircleButton("arrow.down", label: "回到最新") {
                            withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                                reader.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .padding(Theme.Space.medium)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .animation(Theme.Motion.pick(Theme.Motion.quick, reduceMotion: reduceMotion), value: atBottom)
            }
        }
        .background(Theme.Palette.card)
    }

    /// 上面的小横条：往下拖收起（读屏用输入框旁边的「收起对话」，这条不再读一遍）
    private var handle: some View {
        Capsule().fill(Theme.Palette.separator)
            .frame(width: Theme.Space.section + Theme.Space.tight, height: Theme.Space.tight + 1)
            .padding(.vertical, Theme.Space.small)
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
            .accessibilityHidden(true)
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
        let notes = model.chat.map { (at: $0.createdAt, day: $0.day, row: Row.note($0)) }
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

/// 按天分隔：居中的小胶囊
private struct DayCapsule: View {
    let label: String

    var body: some View {
        Text(label).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
            .background(Theme.Palette.fill, in: Capsule())
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
