import PourAPI
import PourDesign
import SwiftUI

/// 没答对的句子
struct FailuresPeek: View {
    let run: API.Evals.Run?

    var body: some View {
        WebPeek(title: "没答对的句子") {
            if let run {
                Text(
                    Show.spaced(
                        "\(EvalNames.when(run.at)) · \(EvalNames.shortModel(run.model)) 模型 · "
                            + "\(run.cases) 句里错了 \(run.failures.count) 句。"
                            + "同一类错反复出现，就说明整理规则里少了一条，先改它。")
                )
                .font(Web.body).foregroundStyle(Web.fgSecondary)
            }
            VStack(alignment: .leading, spacing: Web.space6) {
                if let run, !run.failures.isEmpty {
                    ForEach(run.failures, id: \.id) { failure in
                        VStack(alignment: .leading, spacing: Web.space2) {
                            QuoteText(text: failure.text)
                            ForEach(Array(failure.problems.enumerated()), id: \.offset) { _, problem in
                                Text(
                                    spans([
                                        (EvalNames.dim(problem.dim), Web.fg), (" · \(problem.what)", Web.fgSecondary),
                                    ])
                                )
                                .font(Web.caption)
                            }
                        }
                    }
                } else {
                    Text("这次全部都对。").font(Web.body).foregroundStyle(Web.fgTertiary)
                }
            }
            .padding(.top, Web.space6)
        }
    }
}

/// 你改过的地方：原话和改过之后的正确结果；收进检查清单、改通用 / 个人、忽略
struct CandidatesPeek: View {
    @Environment(AppModel.self) private var model
    @State private var list: API.Candidates?
    @State private var problem: String?

    private static let scopeNames = ["general": "通用的", "personal": "你个人的"]

    var body: some View {
        WebPeek(title: "你改过的地方") {
            Text("整理错了你改一下，这里就多一条：原话，和改过之后的正确结果。看一眼觉得对，就收进检查清单，以后每次检查都会看它还会不会错。")
                .font(Web.body).foregroundStyle(Web.fgSecondary)
            Text(intro).font(Web.body).padding(.top, Web.space3)
            VStack(alignment: .leading, spacing: Web.space6) {
                if let list {
                    if list.candidates.isEmpty {
                        Text("还没有纠正过。").font(Web.body).foregroundStyle(Web.fgTertiary)
                    }
                    ForEach(list.candidates) { item(item: $0, classifying: list.classifying) }
                } else if let problem {
                    WebErrorState(problem) { Task { await load() } }
                } else {
                    Dots(label: "加载中").foregroundStyle(Web.fgTertiary)
                }
            }
            .padding(.top, Web.space6)
        }
        .task { await load() }
        .task(id: list?.classifying) {
            // AI 正在分通用的 / 个人的：每 2 秒看一次
            guard list?.classifying == true else { return }
            try? await Task.sleep(for: .seconds(2))
            await load()
        }
    }

    private var intro: AttributedString {
        spans([
            ("AI 会分一下：", Web.fgSecondary), ("通用的", Web.fg),
            ("是换谁这么说都可能被理解错，收进去以后所有人都受益；", Web.fgSecondary), ("你个人的", Web.fg),
            ("是只有你知道的说法（某个人是谁、你的简称），会顺便记进个人词典。", Web.fgSecondary),
        ])
    }

    private func item(item: API.Candidate, classifying: Bool) -> some View {
        let remember = item.scope == "personal" && item.phrase != nil && item.meaning != nil
        return VStack(alignment: .leading, spacing: Web.space2) {
            QuoteText(text: item.text)
            Text(Show.spaced("\(EvalNames.when(item.createdAt)) · 正确结果：\(expected(item))"))
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
            if let scope = item.scope {
                let why = item.scopeWhy.map { " · \($0)" } ?? (item.scopeBy == "me" ? " · 你改的" : "")
                let learn = remember ? " · 会记住「\(item.phrase ?? "")」= \(item.meaning ?? "")" : ""
                Text(spans([(Self.scopeNames[scope] ?? scope, Web.fg), (why + learn, Web.fgSecondary)]))
                    .font(Web.caption)
            } else if classifying {
                HStack(spacing: Web.space2) {
                    Dots()
                    Text("正在看是通用的还是你个人的")
                }
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            HStack(spacing: Web.space3) {
                WebTextButton(remember ? "记住，并收进检查清单" : "收进检查清单") {
                    let done = remember ? "已记住「\(item.phrase ?? "")」，并收进检查清单" : "已收进检查清单"
                    act(done) { try await $0.addCandidate(item.id) }
                }
                if let scope = item.scope {
                    let other = scope == "general" ? "personal" : "general"
                    WebButton(scope == "general" ? "其实是我个人的" : "其实是通用的", variant: .ghost) {
                        act("改成了\(Self.scopeNames[other] ?? other)") { try await $0.setCandidateScope(item.id, other) }
                    }
                }
                WebButton("忽略", variant: .ghost) { act("已忽略") { try await $0.ignoreCandidate(item.id) } }
            }
        }
    }

    /// 正确结果写成一行给人看的字
    private func expected(_ item: API.Candidate) -> String {
        guard !item.expected.isEmpty else { return "不应该有记录" }
        return item.expected.map { entry in
            if entry.kind != "event" {
                let meta = Show.meta(entry.kind, model.categories)
                return "\(meta.emoji) \(meta.name)" + (entry.due.map { " · \($0)" } ?? "")
                    + (entry.done == true ? " · 已完成" : "")
            }
            let meta = Show.meta(entry.category ?? "other", model.categories)
            var parts = ["\(meta.emoji) \(entry.label ?? meta.name)"]
            if let start = entry.start {
                parts.append(String(start.dropFirst(11)) + (entry.end.map { "–\($0.dropFirst(11))" } ?? ""))
            }
            if let minutes = entry.durationMin { parts.append("\(minutes) 分钟") }
            parts += (entry.values ?? []).map { Show.amount($0) }
            return parts.joined(separator: " · ")
        }
        .joined(separator: "；")
    }

    private func load() async {
        do {
            list = try await model.client.candidateList()
            problem = nil
        } catch {
            problem = error.readable
        }
    }

    private func act(_ done: String, _ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = model.client
        Task {
            do {
                try await work(client)
                await load()
                model.toast(done)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 处理日志（规格 5.7）：每次整理的每一步发了什么、收到什么、用了多久和多少 token
struct RunLogPeek: View {
    @Environment(AppModel.self) private var model
    @State private var runs: [API.RunSummary]?
    @State private var problem: String?

    var body: some View {
        WebPeek(title: "处理日志") {
            Text("最近 50 次整理。点开一条，可以看到每一步发给大模型的内容和它的回答。")
                .font(Web.body).foregroundStyle(Web.fgSecondary)
            VStack(alignment: .leading, spacing: 0) {
                if let runs {
                    if runs.isEmpty { Text("还没有整理过。").font(Web.body).foregroundStyle(Web.fgTertiary) }
                    ForEach(runs) { RunItem(run: $0) }
                } else if let problem {
                    WebErrorState(problem) { Task { await load() } }
                } else {
                    Dots(label: "加载中").foregroundStyle(Web.fgTertiary)
                }
            }
            .padding(.top, Web.space4)
        }
        .task { await load() }
    }

    private func load() async {
        do {
            runs = try await model.client.runs()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 一次整理：点开看每一步
private struct RunItem: View {
    @Environment(AppModel.self) private var model
    let run: API.RunSummary
    @State private var open = false
    @State private var steps: [API.StepDetail]?

    private static let outcomes = ["done": "已记录", "confirm": "待确认", "pending": "暂停", "failed": "失败"]

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: Web.space3) {
                if let error = run.error { Text(error).font(Web.body).foregroundStyle(Web.danger) }
                if let steps {
                    ForEach(steps) { StepItem(step: $0) }
                } else {
                    Dots(label: "加载中").foregroundStyle(Web.fgTertiary)
                }
            }
            .padding(.leading, Web.space4)
            .padding(.bottom, Web.space4)
            .task { steps = try? await model.client.runSteps(run.id) }
        } label: {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text(run.noteText).font(Web.body).foregroundStyle(Web.fg).lineLimit(1)
                Text(summary).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            .frame(minHeight: Web.touch)
        }
        .tint(Web.fgTertiary)
    }

    private var summary: String {
        var text =
            "\(EvalNames.when(run.startedAt).replacing("月", with: "/").replacing("日", with: "")) · "
            + "\(Self.outcomes[run.outcome ?? ""] ?? "进行中") · "
            + "\(String(format: "%.1f", Double(run.durationMs) / 1000)) 秒"
            + " · 约 \(Self.cny(run.costCny))"
        if run.promptTokens > 0 {
            let cached = Int((Double(run.cacheHitTokens) / Double(run.promptTokens) * 100).rounded())
            text += "（\(run.totalTokens) token，\(cached)% 走缓存\(run.peak ? "，高峰价" : "")）"
        }
        return text
    }

    /// 一次整理的花费很少：多保留几位小数
    private static func cny(_ value: Double) -> String {
        if value <= 0 { return "¥0" }
        return String(format: value < 0.01 ? "¥%.4f" : "¥%.3f", value)
    }
}

/// 一步：名字、版本、用时、token；点开看原始内容
private struct StepItem: View {
    let step: API.StepDetail

    private static let names = ["route": "意图识别", "parse": "解析", "merge": "合并入库", "compose": "组装回复"]

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text(spans([(Self.names[step.step] ?? step.step, Web.fg), (detail, Web.fgTertiary)], bold: 1))
                .font(Web.caption)
            if let error = step.error { Text(error).font(Web.caption).foregroundStyle(Web.danger) }
            if let input = step.input { raw("发给大模型的内容", input) }
            if let output = step.output { raw("大模型的回答", output) }
            if let result = step.result, step.output == nil { raw("结果", result) }
        }
    }

    private var detail: String {
        var text = (step.skillVersion.map { " · \($0)" } ?? "") + " · \(step.durationMs) ms"
        if step.promptTokens > 0 {
            let cached = step.cacheHitTokens > 0 ? "（缓存命中 \(step.cacheHitTokens)）" : ""
            text += " · 输入 \(step.promptTokens)\(cached) / 输出 \(step.completionTokens) token"
        }
        return text
    }

    private func raw(_ label: String, _ text: String) -> some View {
        DisclosureGroup {
            LogBlock(text: Self.pretty(text))
        } label: {
            Text(label).font(Web.caption).foregroundStyle(Web.fgSecondary).frame(minHeight: Web.touch)
        }
        .tint(Web.fgTertiary)
    }

    /// JSON 排版得好读一些；发给大模型的消息把每条的内容直接展开
    static func pretty(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data) else {
            return raw
        }
        if let messages = value as? [[String: Any]],
            messages.allSatisfy({ $0["role"] is String && $0["content"] is String })
        {
            return messages.map { "【\($0["role"] as? String ?? "")】\n\($0["content"] as? String ?? "")" }
                .joined(separator: "\n\n")
        }
        guard
            let pretty = try? JSONSerialization.data(
                withJSONObject: value, options: [.prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed])
        else { return raw }
        return String(bytes: pretty, encoding: .utf8) ?? raw
    }
}

/// 原始内容：浅灰底、等宽字、自动换行，最高 320 点，再长就在里面滚
private struct LogBlock: View {
    let text: String
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            Text(text).font(Web.mono).foregroundStyle(Web.fgSecondary).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Web.space2).padding(.horizontal, Web.space3)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    height = $0
                }
        }
        .frame(height: min(max(height, Web.space8), Web.space16 * 5))
        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bgSubtle))
        .padding(.top, Web.space1)
    }
}
