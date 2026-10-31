import Foundation
import PourAPI

/// 斜杠命令里不发给 AI、在手机上直接做的几件事
extension AppModel {
    func run(_ command: SlashCommand, _ rest: String) async {
        switch command.action {
        case "search":
            search = rest
        case "today":
            chatOpen = false
            goHome()
            show(today)
        case "report":
            await openLatestWeekly()
        case "undo":
            await undoLatest()
        default:
            break
        }
    }

    /// /周报：打开最近的那一份
    private func openLatestWeekly() async {
        do {
            let reports = try await client.reports()
            guard let report = reports.first(where: { $0.kind == "weekly" && $0.report != nil })?.report else {
                toast("还没有周报。每周一早上会生成上周的（那一周有记录的话）。")
                return
            }
            open(Show.reportPath("weekly", from: report.period.from))
        } catch {
            toast(error.message)
        }
    }

    /// /撤销：撤销最近一段整理出了东西、还没撤销过的话
    private func undoLatest() async {
        do {
            let notes = try await client.recentNotes(limit: 30).notes
            let last = notes.reversed().first { note in
                guard let result = note.result, result.undone != true else { return false }
                return !result.receipt.isEmpty || !(result.goals ?? []).isEmpty
            }
            guard let last else {
                toast("最近没有可以撤销的记录。")
                return
            }
            try await client.undo(note: last.id)
            await refreshAll()
            toast("已撤销「\(last.text.prefix(20))」整理出的记录，原话还在")
        } catch {
            toast(error.message)
        }
    }
}
