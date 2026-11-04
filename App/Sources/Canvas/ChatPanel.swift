import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 说一句（对话）弹层的上面和中间：照可交互原型 1:1（产品主人 2026-11-03：「请参考原型 1 比 1 复刻」，原型的 ChatSheet）——
/// 弹层的底、圆角、影子在 Composer；这里是小横条、「说一句」、右上角灰圆的关闭；按天分隔（居中一行小字）；
/// 你的话在右边蓝底白字的气泡里，Pour 的在左边白气泡里（收据一条一张：彩色小方块 + 粗体 + 灰字 + 撤销；ChatMessages）；
/// 话少时从上往下排；往下拖上面那一条收起；往上翻自动拿更早的，离开底部时下面正中「回到最新」。
/// 还没交给服务器的话（没网时）排在最后，下面一行小字「没网，先存在手机上 · 连上自动发」
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
                    LazyVStack(spacing: Theme.Space.small) {
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
                    .padding(.horizontal, Theme.Space.inset)
                    .padding(.top, Theme.Space.tight)
                    .padding(.bottom, Theme.Space.medium)
                }
                // 一滑就收起键盘：边滑边收的话面板跟着键盘一帧一帧变高，下面会闪
                .scrollDismissesKeyboard(.immediately)
                // 话少时从上往下排（原型）；打开时在最下面；内容长短变了不跟着挪（跟着挪的话往上翻时下面会跳）
                .defaultScrollAnchor(.bottom, for: .initialOffset)
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
                        .themeTransition(.opacity)
                    }
                }
                .animation(Theme.Motion.pick(Theme.Motion.quick, reduceMotion: reduceMotion), value: atBottom)
                // 键盘起来、面板变矮：原来停在最下面就还停在最下面。点底下的输入框打开时键盘晚一步起来，
                // 不跟着的话最新的几条被挤到键盘后面、出来「回到最新」（2026-11-05 当成真的用户走一遍时看到的）
                .onScrollGeometryChange(for: Fit.self) { geometry in
                    Fit(
                        height: geometry.containerSize.height,
                        gap: geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height)
                } action: { old, new in
                    guard new.height < old.height, old.gap < old.height / 4 else { return }
                    reader.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 面板有多高、离最下面还差多少（键盘起来时看原来是不是停在最下面）
    private struct Fit: Equatable {
        let height: CGFloat
        let gap: CGFloat
    }

    /// 上面一条（原型 .grab + .shead）：小横条、「说一句」、右上角灰圆的关闭；整条都能往下拖收起
    private var header: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.Palette.grabber)
                .frame(width: Theme.Space.section + Theme.Space.snug, height: Theme.Space.tight + 1)
                .padding(.top, Theme.Space.small).padding(.bottom, Theme.Space.tight)
                .accessibilityHidden(true)
            HStack(spacing: Theme.Space.small) {
                Text("说一句").font(Theme.Typeface.sheetTitle).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        model.chatOpen = false
                    }
                } label: {
                    Image(systemName: "xmark").font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.label)
                        .frame(width: Theme.Size.smallRing, height: Theme.Size.smallRing)
                        .background(Theme.Palette.fillStrong, in: Circle())
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("关闭对话"))
                .accessibilityIdentifier("chat.close")
            }
            .padding(.leading, Theme.Space.large)
            .padding(.trailing, Theme.Space.medium - Theme.Space.tight / 2)
            .padding(.bottom, Theme.Space.hairline)
        }
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

/// 按天分隔：居中一行小字（原型 12.5 号、第三层字色，上下 8 / 2）
private struct DaySeparator: View {
    let label: String

    var body: some View {
        Text(label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Space.small).padding(.bottom, Theme.Space.hairline)
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
