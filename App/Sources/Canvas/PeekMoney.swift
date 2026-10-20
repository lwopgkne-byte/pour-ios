import PourAPI
import PourDesign
import SwiftUI

/// 详情里一笔钱下面的几行（docs/prd-money.md 5.13）：给谁、回来的钱、谁给的、报销了没 / 还了没、
/// 固定的。事情办完了不是整理错了：不算「你改过的地方」
struct MetricMoneyRows: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let event: API.EventData
    let metric: API.Metric
    let index: Int

    var body: some View {
        let spent = metric.unit == "元" && metric.name == "花费"
        // 收到的人情：是谁给的
        let received = metric.unit == "元" && metric.name == "收入" && event.renqing != nil && metric.flag == nil
        if spent {
            PeekRow(label: "给谁") {
                InlineEdit(label: "给谁", value: metric.forWhom ?? "", placeholder: "没说") { text in
                    var changed = metric
                    changed.forWhom = text.trimmingCharacters(in: .whitespaces).nilIfEmpty
                    save(changed)
                }
            }
        }
        // 退款到了、AA 转回来了：撤销说回来的那段话就恢复
        if spent, let returned = metric.returned {
            let actual = max(0, ((metric.value - returned.amount) * 100).rounded() / 100)
            PeekRow(label: "回来的钱") { Text("\(Show.returnedNote(returned)) · 实际花 \(Show.yuan(actual))") }
        }
        if received {
            PeekRow(label: "谁给的") {
                InlineEdit(label: "谁给的", value: metric.from ?? "", placeholder: event.people?.first ?? "没说") { text in
                    var changed = metric
                    changed.from = text.trimmingCharacters(in: .whitespaces).nilIfEmpty
                    save(changed)
                }
            }
        }
        if metric.flag == "reimburse" || metric.flag == "lend" { settleRow }
        if let fixed = model.detail?.fixed, fixed.index == index {
            PeekRow(label: "固定的") {
                HStack(spacing: Web.space2) {
                    Text("每个月 \(fixed.dayOfMonth) 日")
                    WebTextButton(metric.ended == true ? "已不再算 · 改回来" : "不再算固定的") {
                        model.endFixed(
                            .init(entryId: entry.id, index: index), ended: metric.ended != true,
                            said: metric.ended == true ? nil : "不再算固定的了")
                    }
                }
            }
        }
    }

    private var settleRow: some View {
        let reimburse = metric.flag == "reimburse"
        let settled = metric.settled == true
        let title =
            reimburse
            ? (settled ? "已报销 · 改为还没报" : "还没报 · 标记为已报销") : (settled ? "已还 · 改为还没还" : "还没还 · 标记为已还")
        return PeekRow(label: reimburse ? "报销" : "还了没") {
            WebTextButton(title) {
                model.settle([.init(entryId: entry.id, index: index)], settled: !settled, said: nil)
            }
        }
    }

    private func save(_ changed: API.Metric) {
        model.update(entry.id, ["metrics": .array([changed.json(value: changed.value)])])
    }
}

/// 详情里整件事的两行：人情（什么事、送出还是收到、和谁的来往、「不算人情」）；买的东西（用了几次、每次多少钱）
struct EventMoneyRows: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let event: API.EventData

    var body: some View {
        if let renqing = event.renqing {
            PeekRow(label: "人情") {
                PourFlowLayout(spacing: Web.space2, lineSpacing: 0) {
                    Text(words(renqing))
                    ForEach(counterparts, id: \.self) { name in
                        WebTextButton("和\(name)的来往 ›", font: Web.body, color: Web.fgSecondary) {
                            navigate("/money/renqing/\(name)")
                        }
                    }
                    WebTextButton("不算人情", font: Web.body, color: Web.fgSecondary) {
                        model.update(entry.id, ["renqing": .null])
                    }
                }
            }
        }
        let bought = (event.metrics ?? []).contains { $0.unit == "元" && $0.name == "花费" }
        if !(event.things ?? []).isEmpty && bought {
            PeekRow(label: "这样东西") {
                WebTextButton("用了几次、每次多少钱 ›", font: Web.body, color: Web.fgSecondary) {
                    navigate("/money/thing/\(entry.id)")
                }
            }
        }
    }

    /// 「结婚 · 你送的」「你请的」
    private func words(_ renqing: API.Renqing) -> String {
        let what =
            renqing.treat == true
            ? (renqing.dir == "out" ? "你请的" : "请你的") : (renqing.dir == "out" ? "你送的" : "收到的")
        return renqing.occasion == "请客" || renqing.occasion == "其他" ? what : "\(renqing.occasion) · \(what)"
    }

    /// 来往的人（shared counterparts）：去掉家里人、公司这类；「同事小王」记成「小王」；最多 3 个
    private var counterparts: [String] {
        let names = (event.metrics ?? []).flatMap { [$0.forWhom ?? "", $0.from ?? ""] } + (event.people ?? [])
        var out: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.wholeMatch(of: Self.household) == nil, name.firstMatch(of: Self.org) == nil else {
                continue
            }
            let person = name.wholeMatch(of: Self.relationName).map { String($0.output.2) } ?? name
            if !out.contains(person) { out.append(person) }
        }
        return Array(out.prefix(3))
    }

    private nonisolated(unsafe) static let org = /公司|单位|老板|平台|银行|商家|店家|群/
    /// 家里人（自己、老婆老公、孩子、爸妈、公婆岳父母、爷爷奶奶外公外婆）：家里人之间的钱不算人情往来（shared HOUSEHOLD）
    private nonisolated(unsafe) static let household =
        #/
        我 | 自己 | 本人 | 一家人 | 全家 | 家里 | 家人 | 我们 | 我们家
        | (?:我的?)? (?: 老婆 | 老公 | 妻子 | 丈夫 | 爱人 | 媳妇 | 儿子 | 女儿 | 孩子 | 宝宝 | 大宝 | 小宝 | 老大 | 老二
          | 爸爸? | 妈妈? | 父亲 | 母亲 | 爸妈 | 父母 | 爷爷 | 奶奶 | 外公 | 外婆 | 姥姥 | 姥爷
          | 公公 | 婆婆 | 岳父 | 岳母 | 丈母娘 | 老丈人 )
        /#

    private nonisolated(unsafe) static let relationName =
        /(同事|朋友|老同学|同学|邻居|领导|客户|发小|闺蜜|哥们|兄弟)((?:小|老|大|阿).{1,2})/

    /// 关掉详情，去「钱」里的那一页
    private func navigate(_ path: String) {
        model.detail = nil
        model.open(path)
    }
}

extension String {
    /// 空字符串当作没写
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
