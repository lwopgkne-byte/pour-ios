import PourAPI
import PourCore
import PourDesign
import SwiftUI
import UIKit

/// 按住的那一件：哪一行、这一行在屏幕上的位置（浮起来的预览画在原地）
struct TodoPress: Equatable {
    let row: API.TodoRow
    let frame: CGRect
}

/// 按住一行的菜单（待办 2.0 第 6 步，docs/todo-2.0 design/after-05-menu）：整页模糊，这一行原样浮起来（和列表里一模一样）；
/// 旁边一张菜单：最上面一排四个格子（现在在哪格就用那格的底色和描边，点别的就换），再是完成 · 推迟到… · 编辑… · 看原话 ·
/// 复制文字，最下面单独一组删除（红）。系统的菜单做不出带字、带颜色的四个格子，自己画；点外面、读屏的「返回」收起
struct TodoPressMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let press: TodoPress
    @State private var shown = false
    @State private var snoozing = false
    @State private var panelHeight: CGFloat = 0

    private var row: API.TodoRow { press.row }

    var body: some View {
        ZStack {
            // 设计稿：浅色磨砂（不压暗），浮起来的这一行和菜单靠阴影分出来
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Theme.Palette.background.opacity(0.45))
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityHidden(true)
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let width = min(proxy.size.width - Theme.Space.regular * 2, Self.panelWidth)
                let place = Self.place(
                    row: press.frame.offsetBy(dx: -origin.x, dy: -origin.y), panel: panelHeight,
                    height: proxy.size.height)
                preview
                    .frame(width: press.frame.width, height: press.frame.height)
                    .offset(x: press.frame.minX - origin.x, y: place.row)
                panel
                    .frame(width: width)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        panelHeight = $0
                    }
                    .scaleEffect(shown ? 1 : 0.6, anchor: place.below ? .top : .bottom)
                    .opacity(shown && panelHeight > 0 ? 1 : 0)
                    .offset(x: press.frame.maxX - origin.x - width, y: place.panel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .onAppear {
            withAnimation(Theme.Motion.pick(Theme.Motion.spring, reduceMotion: reduceMotion)) { shown = true }
        }
        .sensoryFeedback(Theme.Haptics.voice, trigger: shown) { _, now in now }
    }

    /// 菜单宽 280（设计稿 268–280），窄的屏幕两边各留 16
    static let panelWidth: CGFloat = 280
    private static let gap: CGFloat = 12

    /// 浮起的这一行、菜单的上沿；菜单在这一行下面还是上面（从哪一头弹出来）
    struct Place: Equatable {
        let row: CGFloat
        let panel: CGFloat
        let below: Bool
    }

    /// 摆在哪：下面放得下放下面，不然放上面；两头都不够就把这一行往上挪，菜单接在下面
    static func place(row: CGRect, panel: CGFloat, height: CGFloat) -> Place {
        let top = Theme.Space.small
        let bottom = height - Theme.Space.small
        if row.maxY + gap + panel <= bottom { return Place(row: row.minY, panel: row.maxY + gap, below: true) }
        if row.minY - gap - panel >= top { return Place(row: row.minY, panel: row.minY - gap - panel, below: false) }
        let moved = max(top, bottom - panel - gap - row.height)
        return Place(row: moved, panel: moved + row.height + gap, below: true)
    }

    // MARK: - 浮起的这一行

    /// 和列表里同一套 TodoLine（圈和字不贴、右边的状态不溢出）；点它打开编辑
    private var preview: some View {
        let trailing = TodoBoard.trailing(row, today: model.today, now: TodosPage.clock())
        return Button {
            open(.detail(row))
        } label: {
            TodoLine(Show.spaced(row.content), done: row.done, dim: row.lane == .later, identifier: "todoPress.row") {
                QuadrantRing(quadrant: row.lane.rawValue, done: row.done, label: row.content) {}
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } trailing: {
                if let trailing { TodoTrailing(trailing) }
            }
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.card))
            .shadow(color: Theme.Palette.shadowFar, radius: shown ? 16 : 0, y: shown ? 6 : 0)
            .scaleEffect(shown ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(row.content))
        .accessibilityHint(Text("打开编辑"))
    }

    // MARK: - 菜单

    private var panel: some View {
        VStack(spacing: 0) {
            quadrants
            band
            if snoozing { snoozeLines } else { lines }
        }
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.card))
        .clipShape(Theme.rounded(Theme.Corner.card))
        .shadow(color: Theme.Palette.shadowFar, radius: 24, y: 8)
        .animation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion), value: snoozing)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todoPress.panel")
    }

    /// 最上面一排：马上做 · 排时间 · 快速办 · 放一放
    private var quadrants: some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(TodoQuadrant.sorted, id: \.self) { lane in
                QuadrantPick(quadrant: lane.rawValue, title: lane.title, selected: row.lane == lane) {
                    choose(lane)
                }
                .accessibilityIdentifier("todoPress.quadrant.\(lane.rawValue)")
            }
        }
        .padding(Theme.Space.small + Theme.Space.hairline)
    }

    private var band: some View {
        Theme.Palette.background.frame(height: Theme.Space.small).accessibilityHidden(true)
    }

    @ViewBuilder private var lines: some View {
        MenuLine(row.done ? "改成没完成" : "完成", symbol: row.done ? "arrow.uturn.backward" : "checkmark") {
            close()
            model.setDone(row.id, !row.done)
        }
        .accessibilityIdentifier("todoPress.done")
        if !row.done {
            Divider()
            MenuLine("推迟到…", symbol: Theme.Symbol.snooze, more: true) { snoozing = true }
                .accessibilityIdentifier("todoPress.snooze")
        }
        Divider()
        MenuLine("编辑…", symbol: "pencil") { open(.detail(row)) }
            .accessibilityIdentifier("todoPress.edit")
        if let source = row.source {
            Divider()
            MenuLine("看原话", symbol: "quote.closing") {
                close()
                model.openLink("/library?note=\(source.noteId)")
            }
            .accessibilityIdentifier("todoPress.source")
        }
        Divider()
        MenuLine("复制文字", symbol: "square.on.square") {
            UIPasteboard.general.string = row.content
            close()
            model.toast("复制好了")
        }
        .accessibilityIdentifier("todoPress.copy")
        band
        MenuLine("删除", symbol: Theme.Symbol.delete, destructive: true) {
            close()
            model.deleteTodo(row)
        }
        .accessibilityIdentifier("todoPress.delete")
    }

    /// 推迟到…：1 小时后 · 今晚 8 点 · 明天上午 · 下周一 · 选时间（打开推迟的弹层，里面有日子和钟点）
    @ViewBuilder private var snoozeLines: some View {
        MenuLine("推迟到…", symbol: "chevron.left") { snoozing = false }
            .fontWeight(.semibold)
            .accessibilityLabel(Text("返回"))
            .accessibilityIdentifier("todoPress.back")
        ForEach(Self.presets, id: \.preset) { item in
            Divider()
            MenuLine(item.title, symbol: item.preset.symbol) {
                close()
                model.snooze(row.id, to: item.preset)
            }
        }
        Divider()
        MenuLine("选时间…", symbol: "calendar") { open(.snooze(row)) }
    }

    private static let presets: [(preset: SnoozePreset, title: String)] = [
        (.hour, "1 小时后"), (.tonight, "今晚 8 点"), (.tomorrow, "明天上午"), (.monday, "下周一"),
    ]

    // MARK: - 做

    /// 换一格：先改界面再发；轻提示能撤销
    private func choose(_ lane: TodoQuadrant) {
        close()
        model.file([row], into: lane)
    }

    private func open(_ sheet: TodoSheet) {
        close()
        model.todoSheet = sheet
    }

    private func close() {
        withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) { model.todoPress = nil }
    }
}

extension View {
    /// 按住这一行出待办 2.0 的菜单（TodoPressMenu）：记下这一行在屏幕上的位置，按住 0.4 秒打开；读屏是「更多」
    func todoPress(_ row: API.TodoRow) -> some View { modifier(TodoPressable(row: row)) }
}

private struct TodoPressable: ViewModifier {
    @Environment(AppModel.self) private var model
    let row: API.TodoRow
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: {
                frame = $0
            }
            // 比行里的按钮（圈、打开编辑）先认：按住 0.4 秒是菜单，没到就松手还是点
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in show() })
            .accessibilityAction(named: Text("更多")) { show() }
    }

    private func show() {
        withAnimation(Theme.Motion.standard) { model.todoPress = TodoPress(row: row, frame: frame) }
    }
}
