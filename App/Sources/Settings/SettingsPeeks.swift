import PourAPI
import PourDesign
import SwiftUI

/// 没答对的句子
struct FailuresPeek: View {
    let run: API.Evals.Run?

    var body: some View {
        DetailPeek(title: "没答对的句子") {
            if let run {
                Text(
                    Show.spaced(
                        "\(EvalNames.when(run.at)) · \(EvalNames.shortModel(run.model)) 模型 · "
                            + "\(run.cases) 句里错了 \(run.failures.count) 句。"
                            + "同一类错反复出现，就说明整理规则里少了一条，先改它。")
                )
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                if let run, !run.failures.isEmpty {
                    ForEach(run.failures, id: \.id) { failure in
                        VStack(alignment: .leading, spacing: Theme.Space.small) {
                            QuoteText(text: failure.text)
                            ForEach(Array(failure.problems.enumerated()), id: \.offset) { _, problem in
                                Text(
                                    spans([
                                        (EvalNames.dim(problem.dim), Theme.Palette.label),
                                        (" · \(problem.what)", Theme.Palette.secondaryLabel),
                                    ])
                                )
                                .font(Theme.Typeface.footnote)
                            }
                        }
                    }
                } else {
                    Text("这次全部都对。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(.top, Theme.Space.xLarge)
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
        DetailPeek(title: "你改过的地方") {
            Text("整理错了你改一下，这里就多一条：原话，和改过之后的正确结果。看一眼觉得对，就收进检查清单，以后每次检查都会看它还会不会错。")
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(intro).font(Theme.Typeface.body).padding(.top, Theme.Space.medium)
            VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                if let list {
                    if list.candidates.isEmpty {
                        Text("还没有纠正过。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    ForEach(list.candidates) { item(item: $0, classifying: list.classifying) }
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    Dots(label: "加载中").foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(.top, Theme.Space.xLarge)
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
            ("AI 会分一下：", Theme.Palette.secondaryLabel), ("通用的", Theme.Palette.label),
            ("是换谁这么说都可能被理解错，收进去以后所有人都受益；", Theme.Palette.secondaryLabel), ("你个人的", Theme.Palette.label),
            ("是只有你知道的说法（某个人是谁、你的简称），会顺便记进个人词典。", Theme.Palette.secondaryLabel),
        ])
    }

    private func item(item: API.Candidate, classifying: Bool) -> some View {
        let remember = item.scope == "personal" && item.phrase != nil && item.meaning != nil
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            QuoteText(text: item.text)
            Text(Show.spaced("\(EvalNames.when(item.createdAt)) · 正确结果：\(expected(item))"))
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            if let scope = item.scope {
                let why = item.scopeWhy.map { " · \($0)" } ?? (item.scopeBy == "me" ? " · 你改的" : "")
                let learn = remember ? " · 会记住「\(item.phrase ?? "")」= \(item.meaning ?? "")" : ""
                Text(
                    spans([
                        (Self.scopeNames[scope] ?? scope, Theme.Palette.label),
                        (why + learn, Theme.Palette.secondaryLabel),
                    ])
                )
                .font(Theme.Typeface.footnote)
            } else if classifying {
                HStack(spacing: Theme.Space.small) {
                    Dots()
                    Text("正在看是通用的还是你个人的")
                }
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            HStack(spacing: Theme.Space.medium) {
                ThemeTextButton(remember ? "记住，并收进检查清单" : "收进检查清单", font: Theme.Typeface.bodyMedium) {
                    let done = remember ? "已记住「\(item.phrase ?? "")」，并收进检查清单" : "已收进检查清单"
                    act(done) { try await $0.addCandidate(item.id) }
                }
                if let scope = item.scope {
                    let other = scope == "general" ? "personal" : "general"
                    ThemeButton(scope == "general" ? "其实是我个人的" : "其实是通用的", variant: .ghost) {
                        act("改成了\(Self.scopeNames[other] ?? other)") { try await $0.setCandidateScope(item.id, other) }
                    }
                }
                ThemeButton("忽略", variant: .ghost) { act("已忽略") { try await $0.ignoreCandidate(item.id) } }
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
        DetailPeek(title: "处理日志") {
            Text("最近 50 次整理。点开一条，可以看到每一步发给大模型的内容和它的回答。")
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            VStack(alignment: .leading, spacing: 0) {
                if let runs {
                    if runs.isEmpty {
                        Text("还没有整理过。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    ForEach(runs) { RunItem(run: $0) }
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    Dots(label: "加载中").foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(.top, Theme.Space.regular)
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
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                if let error = run.error { Text(error).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.bad) }
                if let steps {
                    ForEach(steps) { StepItem(step: $0) }
                } else {
                    Dots(label: "加载中").foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(.leading, Theme.Space.regular)
            .padding(.bottom, Theme.Space.regular)
            .task { steps = try? await model.client.runSteps(run.id) }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(run.noteText).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(1)
                Text(summary).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .frame(minHeight: Theme.Size.touch)
        }
        .tint(Theme.Palette.secondaryLabel)
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
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(
                spans(
                    [
                        (Self.names[step.step] ?? step.step, Theme.Palette.label),
                        (detail, Theme.Palette.secondaryLabel),
                    ], bold: 1)
            )
            .font(Theme.Typeface.footnote)
            if let error = step.error { Text(error).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.bad) }
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
            Text(label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).frame(
                minHeight: Theme.Size.touch)
        }
        .tint(Theme.Palette.secondaryLabel)
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
            Text(text).font(Theme.Typeface.mono).foregroundStyle(Theme.Palette.secondaryLabel).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Space.small).padding(.horizontal, Theme.Space.medium)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    height = $0
                }
        }
        .frame(height: min(max(height, Theme.Space.section), (Theme.Space.section * 2) * 5))
        .background(RoundedRectangle(cornerRadius: Theme.Corner.tile).fill(Theme.Palette.fill))
        .padding(.top, Theme.Space.tight)
    }
}
