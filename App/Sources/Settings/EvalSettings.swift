import PourAPI
import PourDesign
import SwiftUI

/// 设置页「AI 准不准」（网页版 EvalSettings.tsx 1 比 1）：越来越懂你（每周要你改几次、AI 追问几次、记住了多少说法）、
/// 自动检查、最近一次检查的准确率、分开看、没答对的句子、你改过的地方。跑检查只能在电脑上点
struct EvalSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        VStack(alignment: .leading, spacing: 0) {
            Loaded(
                load: { () async throws(APIError) in try await client.growth() },
                content: { growth, _ in
                    GrowthRows(growth: growth)
                })
            Loaded(
                load: { () async throws(APIError) in try await client.auditStatus() },
                content: { audit, _ in
                    AuditRow(status: audit)
                })
            Loaded(
                load: { () async throws(APIError) in try await client.evals() },
                content: { evals, reload in
                    EvalRows(evals: evals, reload: reload)
                })
        }
    }
}

/// 维度的中文名
enum EvalNames {
    static let dims = [
        "category": "分类", "time": "时间", "value": "数字", "intent": "听懂要做什么", "goal": "目标",
        "answer": "回答问题", "scope": "分清通用和个人",
    ]

    static func dim(_ key: String) -> String { dims[key] ?? key }

    /// 排在第几（和服务器给的顺序一样：分类、时间、数字……）
    static func order(_ key: String) -> Int {
        ["category", "time", "value", "intent", "goal", "answer", "scope"].firstIndex(of: key) ?? Int.max
    }

    /// 0.983 →「98.3%」
    static func pct(_ rate: Double) -> String {
        let value = (rate * 1000).rounded() / 10
        return value == value.rounded() ? "\(Int(value))%" : "\(value)%"
    }

    /// 「deepseek-v4-flash」→「flash」
    static func shortModel(_ name: String) -> String {
        name.replacing(/^deepseek-/, with: "").replacing(/^v4-/, with: "")
    }

    /// 「10月18日 18:00」
    static func when(_ iso: String) -> String {
        guard let date = Show.instant(iso) else { return "" }
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日 \(Show.formatClock(iso))"
    }
}

private struct EvalRows: View {
    @Environment(AppModel.self) private var model
    let evals: API.Evals
    let reload: () -> Void
    @State private var failuresOpen = false
    @State private var candidatesOpen = false
    @State private var candidates: Int?

    var body: some View {
        let last = evals.runs.first
        let sameModel = evals.runs.filter { $0.model == last?.model }
        let dims = (last?.summary ?? [:]).filter { $0.value.checks > 0 }
            .sorted { EvalNames.order($0.key) < EvalNames.order($1.key) }
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "最近一次检查", hint: lastHint(last)) {
                Text(last.map { "\(EvalNames.pct($0.overall)) 正确" } ?? "还没有检查过").foregroundStyle(Web.fg)
            }
            if let last, !dims.isEmpty {
                let weakest = dims.min { $0.value.rate < $1.value.rate }
                SettingRow(
                    label: "分开看",
                    hint: weakest.map { $0.value.rate < 1 ? "最弱的是「\(EvalNames.dim($0.key))」" : "每一方面都对" }
                ) {
                    PourFlowLayout(spacing: Web.space3, lineSpacing: Web.space1) {
                        ForEach(dims, id: \.key) { key, value in
                            Text("\(EvalNames.dim(key)) \(EvalNames.pct(value.rate))")
                                .foregroundStyle(value.rate < 1 ? Web.fg : Web.fgSecondary)
                        }
                    }
                    .font(Web.caption)
                }
                .id(last.file)
            }
            if sameModel.count > 1 {
                SettingRow(label: "最近几次", hint: "同一个模型，从早到晚：变高是变准了") {
                    Text(sameModel.prefix(6).reversed().map { EvalNames.pct($0.overall) }.joined(separator: " → "))
                        .font(Web.caption).monospacedDigit()
                }
            }
            if let last {
                SettingRow(label: "没答对的句子", hint: problemsHint(last)) {
                    Text(last.failures.isEmpty ? "没有" : "\(last.failures.count) 条")
                    if !last.failures.isEmpty { WebTextButton("查看") { failuresOpen = true } }
                }
            }
            SettingRow(label: "你改过的地方", hint: "整理错了你改一下，这里就多一条；收进检查清单后，以后每次检查都会看它还会不会错") {
                Text(candidates.map { $0 > 0 ? "\($0) 条" : "还没有" } ?? "还没有")
                WebTextButton("查看") { candidatesOpen = true }
            }
            SettingRow(label: "再检查一次", hint: rerunHint(sameModel)) {
                if evals.progress.running {
                    HStack(spacing: Web.space2) {
                        Dots()
                        Text(evals.progress.total.map { "\(evals.progress.done) / \($0)" } ?? "准备中")
                    }
                } else {
                    Text("只能在电脑上点").foregroundStyle(Web.fgTertiary)
                }
            }
            if let error = evals.progress.error, !evals.progress.running {
                FieldMessage(text: error, tone: Web.danger)
            }
        }
        .task { await countCandidates() }
        .task(id: evals.progress.running) {
            // 跑检查时每 2 秒看一次进度（网页版 refetchInterval）
            guard evals.progress.running else { return }
            try? await Task.sleep(for: .seconds(2))
            reload()
        }
        .sheet(isPresented: $failuresOpen) { FailuresPeek(run: last) }
        .sheet(isPresented: $candidatesOpen, onDismiss: recount, content: { CandidatesPeek() })
    }

    private func recount() { Task { await countCandidates() } }

    private func countCandidates() async {
        candidates = try? await model.client.candidates().candidates.count
    }

    private func lastHint(_ last: API.Evals.Run?) -> String {
        guard let last else { return "用一批说好了正确答案的话，检查 AI 整理得准不准" }
        var hint = "用 \(last.cases) 句话检查 · \(EvalNames.shortModel(last.model)) 模型 · \(EvalNames.when(last.at))"
        if let scopes = last.scopes, scopes.personal.cases > 0 {
            hint += " · 通用的 \(EvalNames.pct(scopes.general.rate))，你个人的 \(EvalNames.pct(scopes.personal.rate))"
        }
        return hint
    }

    /// 按出错的方面数一数：哪一类错最多，就先修哪一类
    private func problemsHint(_ run: API.Evals.Run) -> String? {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for failure in run.failures {
            for problem in failure.problems {
                if counts[problem.dim] == nil { order.append(problem.dim) }
                counts[problem.dim, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return nil }
        return order.enumerated().sorted { lhs, rhs in
            let left = counts[lhs.element] ?? 0
            let right = counts[rhs.element] ?? 0
            return left != right ? left > right : lhs.offset < rhs.offset
        }
        .map { "\(EvalNames.dim($0.element)) \(counts[$0.element] ?? 0) 处" }
        .joined(separator: " · ")
    }

    private func rerunHint(_ runs: [API.Evals.Run]) -> String {
        let cost = runs.first { $0.costCny != nil }?.costCny
        let price = cost.map { "，约 ¥" + String(format: $0 < 0.1 ? "%.2f" : "%.1f", $0) } ?? ""
        return "改了整理规则、换了模型之后检查一次\(price)，一两分钟"
    }
}

/// 越来越懂你（docs/prd-grow.md）：数字全部是程序数出来的
private struct GrowthRows: View {
    @Environment(AppModel.self) private var model
    let growth: API.Growth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let week = growth.weeks.last {
                SettingRow(label: "这周要你改", hint: trend(\.corrections) ?? "这周说了 \(week.notes) 段话") {
                    Text("\(week.corrections) 次").foregroundStyle(Web.fg).monospacedDigit()
                }
                SettingRow(label: "这周 AI 追问", hint: trend(\.asks) ?? "拿不准的时候先问你，不瞎猜") {
                    Text("\(week.asks) 次").foregroundStyle(Web.fg).monospacedDigit()
                }
            }
            link(label: "记住你的说法", hint: "在「关于我」里可以看、可以改") {
                let learned = growth.dictionary
                Text(
                    learned.total > 0
                        ? "\(learned.total) 条" + (learned.thisWeek > 0 ? " · 这周新学 \(learned.thisWeek) 条" : "") : "还没有")
            }
            let knows = growth.knows
            if knows.people + knows.habits + knows.places > 0 {
                link(label: "整理时认得出", hint: "你说得简略时，Pour 用这些认出你说的是谁、是哪儿、哪件事") {
                    Text(
                        [
                            knows.people > 0 ? "\(knows.people) 个人" : nil,
                            knows.habits > 0 ? "\(knows.habits) 件常做的事" : nil,
                            knows.places > 0 ? "\(knows.places) 个地方" : nil,
                        ]
                        .compactMap { $0 }.joined(separator: " · "))
                }
            }
            if growth.about.right + growth.about.wrong > 0 {
                link(label: "关于我", hint: nil) {
                    Text("你确认了 \(growth.about.right) 条 · 说不对 \(growth.about.wrong) 条")
                }
            }
            if let checklist = growth.checklist {
                SettingRow(label: "检查清单", hint: "通用的越多，将来给别人用也越准；你个人的只用来检查你自己") {
                    Text("通用 \(checklist.general) 句 · 你个人的 \(checklist.personal) 句").monospacedDigit()
                }
            }
        }
    }

    /// 能点的一行：去「关于我」（网页版 setting-link）
    private func link<Content: View>(label: String, hint: String?, @ViewBuilder content: @escaping () -> Content)
        -> some View
    {
        Button {
            model.open("/about")
        } label: {
            SettingRow(label: label, hint: hint, content: content).padding(.horizontal, Web.space2)
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
        .padding(.horizontal, -Web.space2)
    }

    /// 最近几周每 100 段话里有几次：从早到晚，变小是更懂你了；不到两周、或者一直是 0 不说
    private func trend(_ pick: KeyPath<API.Growth.Week, Int>) -> String? {
        let values = growth.weeks.compactMap { week -> Int? in
            week.notes > 0 ? Int((Double(week[keyPath: pick]) / Double(week.notes) * 100).rounded()) : nil
        }
        guard values.count >= 2, values.contains(where: { $0 != 0 }) else { return nil }
        return "每 100 段话几次，最近几周：" + values.suffix(6).map(String.init).joined(separator: " → ")
    }
}

/// 自动检查（docs/prd-auto-improve.md 第 ① 步）：夜里体检这周发现了几处、审核员准不准、这个月花了多少
private struct AuditRow: View {
    let status: API.AuditStatus

    var body: some View {
        SettingRow(label: "自动检查", hint: hint) {
            if status.examRunning {
                HStack(spacing: Web.space2) {
                    Dots()
                    Text("审核员在考试")
                }
            } else if let exam = status.exam {
                if exam.passed {
                    Text("这周 \(status.week.found) 处").foregroundStyle(Web.fg).monospacedDigit()
                } else {
                    Text("审核员没考过")
                }
            } else {
                Text("还没开始")
            }
        }
    }

    private var hint: String {
        guard let exam = status.exam else {
            return "每天夜里用更强的模型把前一天的整理复查一遍，查出来的第二天在回顾里告诉你；审核员先考试，及格才上岗"
        }
        let result =
            "真错抓出 \(exam.caught)/\(exam.wrongTotal)（要 7 成），误报 \(exam.falseAlarms)/\(exam.rightTotal)（最多 1 成）"
        guard exam.passed else { return "审核员考试：\(result)。没考过就先不查" }
        let decided = status.decided.confirmed + status.decided.dismissed
        let accuracy = Int((Double(status.decided.confirmed) / Double(max(decided, 1)) * 100).rounded())
        let budget =
            status.lastRun?.outcome == "budget"
            ? "这个月的 ¥\(Self.money(status.capCny)) 用完了，下个月自动继续"
            : "这个月 \(Self.yuan(status.monthCostCny))，最多 ¥\(Self.money(status.capCny))"
        let parts = [
            status.week.confirmed > 0 ? "你确认是真错的 \(status.week.confirmed) 处" : "",
            decided > 0 ? "审核员看准了 \(accuracy)%（你看过 \(decided) 处）" : "审核员考试：\(result)",
            budget,
            status.lastRun?.outcome == "failed" ? "上次没查成：\(status.lastRun?.detail ?? "")" : "",
            exam.current ? "" : "审核规则或模型换过了，下次检查前会重考",
        ]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func yuan(_ value: Double) -> String {
        "¥" + String(format: value < 10 ? "%.2f" : "%.0f", value)
    }

    private static func money(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
