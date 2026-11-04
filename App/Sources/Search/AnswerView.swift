import PourAPI
import PourDesign
import SwiftUI

/// 回答（规格第九章）：文字（加粗、短列表），[#12] 变成能点的来源编号；
/// 下面是图表、「查看完整报告」、来源（原话片段和日期，点一下在笔记库里看）
struct AnswerView: View {
    @Environment(AppModel.self) private var model
    let answer: API.Answer
    /// 正文的字：搜索里 17，说一句的白气泡里 16（原型）
    var font = Theme.Typeface.body

    private var sources: [API.AnswerSource] { answer.sources ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ForEach(Array(Self.blocks(answer.text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let line): Text(inline(line))
                case .list(let lines):
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                                Text("•").accessibilityHidden(true)
                                Text(inline(line))
                            }
                        }
                    }
                }
            }
            .font(font).foregroundStyle(Theme.Palette.label)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if let id = Int(url.lastPathComponent) { openNote(id) }
                    return .handled
                })
            ForEach(Array((answer.charts ?? []).enumerated()), id: \.offset) { _, chart in ChartCard(spec: chart) }
            ForEach(answer.reports ?? [], id: \.id) { report in
                LinkButton("查看完整报告：\(report.title) ›", font: Theme.Typeface.body) { openReport(report.id) }
            }
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, item in sourceRow(index, item) }
                }
                .padding(.top, Theme.Space.tight)
            }
        }
    }

    private func sourceRow(_ index: Int, _ source: API.AnswerSource) -> some View {
        Button {
            openNote(source.noteId)
        } label: {
            HStack(spacing: Theme.Space.small) {
                Text("\(index + 1)").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .monospacedDigit()
                    .frame(
                        minWidth: Theme.Space.regular + Theme.Space.tight,
                        minHeight: Theme.Space.regular + Theme.Space.tight
                    )
                    .background(Circle().fill(Theme.Palette.fill))
                // 3.0.1 的气泡窄了（最宽八成）：原话放不下就折行，不截成「…」
                Text(source.text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Show.dayTitle(source.day, today: model.today)).font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.secondaryLabel
                )
                .fixedSize()
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("在笔记库里看这段原话"))
    }

    /// 查看完整报告：问一下服务器是哪一期，收起对话，打开那一期的周报 / 月报
    private func openReport(_ id: Int) {
        let client = model.client
        Task {
            do {
                guard let report = try await client.report(id).report else {
                    model.toast("这份报告找不到了。")
                    return
                }
                model.chatOpen = false
                model.open(Show.reportPath(report.kind, from: report.period.from))
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 看那段原话：收起对话，到笔记库
    private func openNote(_ id: Int) {
        model.chatOpen = false
        model.open("/library?note=\(id)")
    }

    /// 一行里的**加粗**和 [#12]（来源编号，按在来源里的顺序写成 1、2……，点了看那段原话）
    private func inline(_ line: String) -> AttributedString {
        let order = sources.map(\.noteId)
        var out = AttributedString()
        var rest = Substring(line)
        while let match = rest.firstMatch(of: /\*\*([^*]+)\*\*|\[#(\d+)\]/) {
            out += AttributedString(Show.spaced(String(rest[..<match.range.lowerBound])))
            if let bold = match.output.1 {
                var part = AttributedString(Show.spaced(String(bold)))
                part.font = Theme.Typeface.bodySemibold
                out += part
            } else if let cited = match.output.2, let id = Int(cited), let number = order.firstIndex(of: id) {
                var part = AttributedString(" \(number + 1) ")
                part.font = Theme.Typeface.footnoteSemibold
                part.foregroundColor = Theme.Palette.accent
                part.link = URL(string: "pour://note/\(id)")
                out += part
            }
            rest = rest[match.range.upperBound...]
        }
        out += AttributedString(Show.spaced(String(rest)))
        return out
    }

    enum Block {
        case paragraph(String)
        case list([String])
    }

    /// 很小的一套格式：空行分段，「- 」开头是列表，开头的 # 去掉
    static func blocks(_ text: String) -> [Block] {
        var out: [Block] = []
        var list: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let item = line.wholeMatch(of: /\s*[-•*]\s+(.*)/) {
                list.append(String(item.output.1))
                continue
            }
            if !list.isEmpty {
                out.append(.list(list))
                list = []
            }
            let plain = line.replacing(/^#+\s*/, with: "").trimmingCharacters(in: .whitespaces)
            if !plain.isEmpty { out.append(.paragraph(plain)) }
        }
        if !list.isEmpty { out.append(.list(list)) }
        return out
    }
}
