import PourAPI
import PourDesign
import SwiftUI

/// 回答（规格第九章）：文字（加粗、短列表），[#12] 变成能点的来源编号；
/// 下面是图表、「查看完整报告」、来源（原话片段和日期，点一下在笔记库里看）
struct AnswerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let answer: API.Answer

    private var sources: [API.AnswerSource] { answer.sources ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            ForEach(Array(Self.blocks(answer.text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let line): Text(inline(line))
                case .list(let lines):
                    VStack(alignment: .leading, spacing: Web.space1) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                                Text("•").accessibilityHidden(true)
                                Text(inline(line))
                            }
                        }
                    }
                }
            }
            .font(Web.body).foregroundStyle(Web.fg)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if let id = Int(url.lastPathComponent) { openNote(id) }
                    return .handled
                })
            ForEach(Array((answer.charts ?? []).enumerated()), id: \.offset) { _, chart in ChartCard(spec: chart) }
            ForEach(answer.reports ?? [], id: \.id) { report in
                WebTextButton("查看完整报告：\(report.title)") { openReport(report.id) }
            }
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, item in sourceRow(index, item) }
                }
                .padding(.top, Web.space1)
            }
        }
    }

    private func sourceRow(_ index: Int, _ source: API.AnswerSource) -> some View {
        Button {
            openNote(source.noteId)
        } label: {
            HStack(spacing: Web.space2) {
                Text("\(index + 1)").font(Web.caption).foregroundStyle(Web.fgSecondary).monospacedDigit()
                    .frame(minWidth: Web.space4 + Web.space1, minHeight: Web.space4 + Web.space1)
                    .background(Circle().fill(Web.bgSubtle))
                Text(source.text).font(Web.caption).foregroundStyle(Web.fgSecondary)
                    .lineLimit(typeSize > .large ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Show.dayTitle(source.day, today: model.today)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .fixedSize()
            }
            .frame(minHeight: Web.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
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
                part.font = Web.bodySemibold
                out += part
            } else if let cited = match.output.2, let id = Int(cited), let number = order.firstIndex(of: id) {
                var part = AttributedString(" \(number + 1) ")
                part.font = Web.captionMedium
                part.foregroundColor = Web.accent
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
