import PourAPI
import PourDesign
import SwiftUI

/// 设置页「大模型」：模型、密钥（只显示打码）、测试连接、排队、本月用量和花费、
/// 每月上限、自动入库的把握程度。手机上不是在电脑上打开的：密钥只能在电脑上用「Pour 设置」填
struct LlmSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        Loaded(
            load: { () async throws(APIError) in try await client.llmStatus() },
            content: { status, reload in
                LlmRows(status: status, reload: reload)
            })
    }
}

private struct LlmRows: View {
    @Environment(AppModel.self) private var model
    let status: API.LlmStatus
    let reload: () -> Void

    @State private var testing = false
    /// 测试连接的结果：成没成、说了什么
    @State private var testResult: (ok: Bool, message: String)?
    @State private var logOpen = false

    private static let models = [
        (key: "deepseek-flash", label: "flash · 便宜"), (key: "deepseek-v4-pro", label: "pro · 最强"),
    ]

    private var deepseek: Bool { status.baseUrl.contains("deepseek.com") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(
                label: "模型", hint: status.baseUrl.replacing(/^https?:\/\//, with: ""),
                spokenHint: deepseek ? "DeepSeek 的服务" : nil
            ) {
                if deepseek {
                    WebSegmented("模型", options: Self.models, selected: status.model) { choose($0) }
                } else {
                    Text(status.model).lineLimit(1)
                }
            }
            if deepseek {
                FieldMessage(
                    text: "评测里两个准确率相当（flash 99.7%–100%，pro 100%），写周报、回答问题的质量也差不多；"
                        + "flash 花费约为 pro 的三成，也更快。"
                        + (status.modelSource == "env" ? "现在用的是 .env 里设置的模型，在这里选了以后以这里为准。" : ""))
            }
            SettingRow(label: "密钥", hint: status.local ? nil : "在电脑上用「Pour 设置」填") {
                Text(status.keyMasked ?? "还没有填写")
                if status.keySource == "env" { Text("来自 .env").foregroundStyle(Web.fgTertiary) }
            }
            if status.keySource == "env" {
                FieldMessage(text: "当前使用 .env 中的密钥，此处修改不会生效。").padding(.bottom, Web.space2)
            }
            if status.configured && !status.consentAccepted {
                SettingRow(label: "发送说明") {
                    Text("你说的话会发送到大模型服务器整理")
                    WebTextButton("确认") { post("好的，开始整理") { try await $0.acceptConsent() } }
                }
            }
            SettingRow(label: "连接") {
                if let testResult {
                    Text(Show.spaced(testResult.message)).foregroundStyle(testResult.ok ? Web.fgSecondary : Web.danger)
                }
                WebButton("测试连接", loading: testing, disabled: !status.configured) { test() }
            }
            if status.queue.pending > 0 {
                SettingRow(label: "排队中") {
                    Text(
                        Show.spaced(
                            "\(status.queue.pending) 段话" + (status.queue.blocker.map { "：\($0)" } ?? "，正在整理")))
                }
            }
            usage
            SettingRow(label: "每月上限") {
                NumberEdit(
                    label: "每月上限", value: Double(status.monthlyTokenLimit),
                    format: { $0 == 0 ? "不限" : "\(Numbers.grouped($0)) token" },
                    parse: { text in Int(text.trimmingCharacters(in: .whitespaces)).map(Double.init) },
                    hint: "填 0 表示不限",
                    onSave: { value in
                        post("每月上限已更新") { try await $0.llmSettings(["monthlyTokenLimit": .number(value)]) }
                    })
            }
            SettingRow(label: "自动入库的把握程度") {
                NumberEdit(
                    label: "自动入库的把握程度", value: status.confidenceThreshold,
                    format: { "\(Int(($0 * 100).rounded()))% 以上" },
                    parse: { text in
                        let number = Double(text.replacing("%", with: "").trimmingCharacters(in: .whitespaces))
                        return number.flatMap { (0...100).contains($0) ? $0 / 100 : nil }
                    },
                    toInput: { String(Int(($0 * 100).rounded())) },
                    hint: "0 到 100，低于它的记录会标为待确认",
                    onSave: { value in
                        post("已更新") { try await $0.llmSettings(["confidenceThreshold": .number(value)]) }
                    })
            }
            SettingRow(label: "处理日志") { WebTextButton("查看") { logOpen = true } }
        }
        .sheet(isPresented: $logOpen) { RunLogPeek() }
    }

    /// 本月用量、估算花费、每个功能各用了多少
    @ViewBuilder private var usage: some View {
        let usage = status.usage
        SettingRow(label: "本月用量（\(Int(usage.month.suffix(2)) ?? 0) 月）") {
            Text("\(Numbers.grouped(Double(usage.totalTokens))) token · \(usage.calls) 次调用")
        }
        SettingRow(label: "估算花费") {
            let hit =
                usage.promptTokens > 0
                ? " · 缓存命中 \(Int((Double(usage.cacheHitTokens) / Double(usage.promptTokens) * 100).rounded()))%" : ""
            Text("约 \(Numbers.cny(usage.costCny))\(hit)")
        }
        VStack(alignment: .trailing, spacing: Web.space1) {
            Text("按 DeepSeek 官方价格估算，实际以账单为准" + (usage.costPartial ? "；有些调用用的模型不在价格表里，没算进去" : ""))
            ForEach(usage.byFeature.filter { $0.totalTokens > 0 || $0.calls > 0 }, id: \.feature) { item in
                let name = Self.featureNames[item.feature] ?? item.feature
                Text(
                    "\(name)：\(Numbers.grouped(Double(item.totalTokens))) token"
                        + " · \(item.calls) 次 · 约 \(Numbers.cny(item.costCny))")
            }
        }
        .font(Web.caption).foregroundStyle(Web.fgTertiary).multilineTextAlignment(.trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.bottom, Web.space2)
    }

    private func choose(_ name: String) {
        guard name != status.model else { return }
        post("已换成 \(name)，下一段话开始生效") { try await $0.llmSettings(["model": .string(name)]) }
    }

    private func test() {
        testing = true
        testResult = nil
        let client = model.client
        Task {
            do {
                let result = try await client.testLLM()
                testResult = (result.ok, result.message)
                reload()
            } catch {
                testResult = (false, error.readable)
            }
            testing = false
        }
    }

    /// 改一样东西：成了重新拿、说一声；没成说为什么
    private func post(_ done: String, _ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = model.client
        Task {
            do {
                try await work(client)
                reload()
                model.toast(done)
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 用量统计里各功能的中文名
    static let featureNames = [
        "router": "意图识别", "parse-note": "解析记录", "canvas-summary": "一句话总结", "goal": "理解目标",
        "answer": "回答问题", "morning-brief": "早上提醒", "evening-nudge": "晚上提醒", "warning": "预警",
        "weekly-report": "周报", "monthly-report": "月报", "test": "测试连接", "eval": "评测",
    ]

}

/// 原地改一个数：平时是一段能点的字；点一下变成输入框，按「完成」或者点别处保存
struct NumberEdit: View {
    let label: String
    let value: Double
    let format: (Double) -> String
    let parse: (String) -> Double?
    var toInput: ((Double) -> String)?
    let hint: String
    let onSave: (Double) -> Void

    var body: some View {
        InlineEdit(
            label: label, value: toInput?(value) ?? Self.plain(value), display: format(value), keyboard: .numberPad,
            validate: { parse($0) == nil ? hint : nil },
            onSave: { text in
                if let number = parse(text), number != value { onSave(number) }
            })
    }

    private static func plain(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
