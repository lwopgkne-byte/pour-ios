import PourAPI
import PourCore
import PourDesign
import SwiftUI
import UIKit

/// 一行待办（待办页、画布的待办卡同一套，06 交互细节 2.1）：左边圆圈（点了勾上、划线留在原地），
/// 点别处打开详情；时间胶囊、第二行（和谁 · 东西 · 地方、↻ 重复）
struct TodoRowView: View {
    @Environment(AppModel.self) private var model
    let row: API.TodoRow
    let today: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            TodoCircle(done: row.done, label: row.content) { model.setDone(row.id, !row.done) }
                .padding(.leading, -Theme.Space.medium + Theme.Space.hairline)
            Button {
                model.todoSheet = .detail(row)
            } label: {
                TodoLabel(
                    Show.spaced(row.content), done: row.done, capsule: capsule, detail: TodoBoard.detail(row),
                    repeatText: row.repeatText
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(spoken))
            .accessibilityHint(Text("打开详情"))
            .accessibilityIdentifier("todo.row")
        }
    }

    private var capsule: (text: String, tone: TimeCapsule.Tone)? {
        TodoBoard.capsule(row, today: today, now: PourDate.localDateTime(Date(), in: .current))
    }

    /// 读屏念的：事、做完没有、什么时候、重复
    private var spoken: String {
        var parts = [row.content]
        if row.done { parts.append("已完成") }
        if let capsule { parts.append(capsule.text) }
        if let repeatText = row.repeatText { parts.append(repeatText) }
        if let detail = TodoBoard.detail(row) { parts.append(detail) }
        return parts.joined(separator: "，")
    }
}

/// 按住一行的菜单（06 交互细节 2.2）：完成、推迟到…、改时间、复制、看原话、删除；以前没做完的多一个「带到今天」
struct TodoMenu: View {
    @Environment(AppModel.self) private var model
    let row: API.TodoRow

    var body: some View {
        Button {
            model.setDone(row.id, !row.done)
        } label: {
            Label(row.done ? "改成没完成" : "完成", systemImage: row.done ? "arrow.uturn.backward" : Theme.Symbol.done)
        }
        if !row.done {
            if row.overdue {
                Button {
                    model.carryToToday([row])
                } label: {
                    Label("带到今天", systemImage: "arrow.down.to.line")
                }
            }
            Button {
                model.todoSheet = .snooze(row)
            } label: {
                Label("推迟到…", systemImage: Theme.Symbol.snooze)
            }
        }
        Button {
            model.todoSheet = .detail(row)
        } label: {
            Label("改时间", systemImage: "calendar.badge.clock")
        }
        Button {
            UIPasteboard.general.string = row.content
            model.toast("复制好了")
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
        if let source = row.source {
            Button {
                model.openLink("/library?note=\(source.noteId)")
            } label: {
                Label("看原话", systemImage: "text.quote")
            }
        }
        Divider()
        Button(role: .destructive) {
            model.deleteTodo(row)
        } label: {
            Label("删除", systemImage: Theme.Symbol.delete)
        }
    }
}

extension API.TodoRow {
    /// 画布的待办卡（拿的是这一天的记录）：换成待办页的一行，打开同一个详情、同一套菜单
    init?(entry: API.Entry, today: String) {
        guard case .todo(let todo) = entry.data else { return nil }
        let day = todo.due ?? entry.day
        self.init(
            id: entry.id, content: todo.content, day: day, remindAt: todo.remindAt.map { String($0.suffix(5)) },
            done: todo.done, repeat: todo.repeat, repeatText: todo.repeat?.text, overdue: !todo.done && day < today,
            people: todo.people ?? [], things: todo.things ?? [], places: todo.places ?? [],
            source: entry.sources.first.map { Source(noteId: $0.noteId, text: $0.text, at: $0.createdAt) })
    }
}
