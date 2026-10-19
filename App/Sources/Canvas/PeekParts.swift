import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 详情的一行（网页版 setting-row）：左边名称，右边现在的值和操作，至少 44 点高
struct PeekRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Web.space4) {
            Text(label).font(Web.body).foregroundStyle(Web.fg)
            Spacer(minLength: Web.space2)
            content().font(Web.body).foregroundStyle(Web.fgSecondary).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Web.space2)
        .frame(minHeight: Web.touch)
    }
}

/// 原地编辑（网页版 InlineEdit）：平时是一段能点的字；点一下变成输入框，按「完成」或者点别处就保存。不需要「编辑」「保存」按钮
struct InlineEdit: View {
    let label: String
    let value: String
    var display: String?
    var placeholder = "添加"
    var keyboard: UIKeyboardType = .default
    /// 返回错误的说法表示不合法
    var validate: ((String) -> String?)?
    var startEditing = false
    let onSave: (String) -> Void

    @State private var editing = false
    @State private var text = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            VStack(alignment: .trailing, spacing: Web.space1) {
                TextField(label, text: $text)
                    .font(Web.body).foregroundStyle(Web.fg)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    // 地址不要自动大写、不要自动改
                    .textInputAutocapitalization(keyboard == .URL ? .never : nil)
                    .autocorrectionDisabled(keyboard == .URL)
                    .submitLabel(.done)
                    .focused($focused)
                    .padding(.horizontal, Web.space2)
                    .frame(minHeight: Web.control)
                    .overlay(
                        RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                            problem == nil ? Web.lineStrong : Web.danger, lineWidth: 1)
                    )
                    .onSubmit(commit)
                    .onChange(of: focused) { _, now in if !now { commit() } }
                if let problem { Text(problem).font(Web.caption).foregroundStyle(Web.danger) }
            }
            .onAppear { focused = true }
        } else {
            Button {
                text = value
                problem = nil
                editing = true
            } label: {
                Text(Show.spaced(display ?? (value.isEmpty ? placeholder : value)))
                    .foregroundStyle(value.isEmpty && display == nil ? Web.fgTertiary : Web.fgSecondary)
                    .frame(minHeight: Web.touch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("修改\(label)"))
            .accessibilityValue(Text(display ?? (value.isEmpty ? placeholder : value)))
            .onAppear { if startEditing && !editing { editing = true } }
        }
    }

    private func commit() {
        guard editing else { return }
        if text == value {
            editing = false
            return
        }
        if let message = validate?(text) {
            problem = message
            return
        }
        onSave(text)
        editing = false
    }
}

/// 一小节：标题是灰色的小字（网页版 Section）
struct PeekSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            Text(title).font(Web.captionMedium).foregroundStyle(Web.fgSecondary).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// 最近 7 天（网页版 Sparkline / MoodDots）：7 根细柱，这一天深一些；心情每条一个点，越高越好
struct Sparkline: View {
    let trend: API.Trend
    let color: Color
    let today: String

    var body: some View {
        let max = Swift.max(trend.points.compactMap(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: Web.space2) {
            ForEach(trend.points, id: \.day) { point in
                VStack(spacing: Web.space1) {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            if trend.unit == "mood" {
                                ForEach(Array((point.values ?? []).enumerated()), id: \.offset) { index, level in
                                    Circle().fill(Web.tag("pink").solid)
                                        .frame(width: Web.space2, height: Web.space2)
                                        .opacity(point.day == today ? 1 : 0.45)
                                        .offset(
                                            x: (CGFloat(index) - CGFloat((point.values ?? []).count - 1) / 2)
                                                * Web.space2,
                                            y: -(proxy.size.height - Web.space2) * (level - 1) / 4)
                                }
                            } else if let value = point.value {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: Web.radiusControl, topTrailingRadius: Web.radiusControl
                                )
                                .fill(color)
                                .frame(height: Swift.max(proxy.size.height * 0.06, proxy.size.height * value / max))
                                .opacity(point.day == today ? 1 : 0.45)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
                    }
                    Text("\(Int(point.day.suffix(2)) ?? 0)").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
        }
        .frame(height: Web.space16 + Web.space4)
        .accessibilityElement()
        .accessibilityLabel(Text("最近 7 天的\(trend.label)"))
    }
}
