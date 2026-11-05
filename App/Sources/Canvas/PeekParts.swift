import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 详情的一行：左边名称，右边现在的值和操作，至少 44 点高
struct PeekRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.regular) {
            Text(label).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            Spacer(minLength: Theme.Space.small)
            content().font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(
                .trailing)
        }
        .padding(.vertical, Theme.Space.small)
        .frame(minHeight: Theme.Size.touch)
    }
}

/// 原地编辑：平时是一段能点的字；点一下变成输入框，按「完成」或者点别处就保存。不需要「编辑」「保存」按钮
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
            VStack(alignment: .trailing, spacing: Theme.Space.tight) {
                TextField(label, text: $text)
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    // 地址不要自动大写、不要自动改
                    .textInputAutocapitalization(keyboard == .URL ? .never : nil)
                    .autocorrectionDisabled(keyboard == .URL)
                    .submitLabel(.done)
                    .focused($focused)
                    .padding(.horizontal, Theme.Space.small)
                    .frame(minHeight: Theme.Size.capsule)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Corner.tile).strokeBorder(
                            problem == nil ? Theme.Palette.separator : Theme.Palette.bad, lineWidth: 1)
                    )
                    .onSubmit(commit)
                    .onChange(of: focused) { _, now in if !now { commit() } }
                if let problem { Text(problem).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.bad) }
            }
            .onAppear { focused = true }
        } else {
            // 看起来是一段字；能点的范围至少 44×44，不另占地方
            Text(Show.spaced(display ?? (value.isEmpty ? placeholder : value)))
                .foregroundStyle(
                    value.isEmpty && display == nil ? Theme.Palette.secondaryLabel : Theme.Palette.secondaryLabel
                )
                .frame(minHeight: Theme.Size.touch)
                .accessibilityHidden(true)
                .overlay {
                    Button {
                        text = value
                        problem = nil
                        editing = true
                    } label: {
                        Color.clear.frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch).contentShape(
                            Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("修改\(label)"))
                    .accessibilityValue(Text(display ?? (value.isEmpty ? placeholder : value)))
                }
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

/// 一小节：标题是灰色的小字
struct PeekSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// 最近 7 天：7 根细柱，这一天深一些；心情每条一个点，越高越好
struct Sparkline: View {
    let trend: API.Trend
    let color: Color
    let today: String

    var body: some View {
        let max = Swift.max(trend.points.compactMap(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: Theme.Space.small) {
            ForEach(trend.points, id: \.day) { point in
                VStack(spacing: Theme.Space.tight) {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            if trend.unit == "mood" {
                                ForEach(Array((point.values ?? []).enumerated()), id: \.offset) { index, level in
                                    Circle().fill(Theme.tag("pink").solid)
                                        .frame(width: Theme.Space.small, height: Theme.Space.small)
                                        .opacity(point.day == today ? 1 : 0.45)
                                        .offset(
                                            x: (CGFloat(index) - CGFloat((point.values ?? []).count - 1) / 2)
                                                * Theme.Space.small,
                                            y: -(proxy.size.height - Theme.Space.small) * (level - 1) / 4)
                                }
                            } else if let value = point.value {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: Theme.Corner.tile, topTrailingRadius: Theme.Corner.tile
                                )
                                .fill(color)
                                .frame(height: Swift.max(proxy.size.height * 0.06, proxy.size.height * value / max))
                                .opacity(point.day == today ? 1 : 0.45)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
                    }
                    Text("\(Int(point.day.suffix(2)) ?? 0)").font(Theme.Typeface.footnote).foregroundStyle(
                        Theme.Palette.secondaryLabel)
                }
            }
        }
        .frame(height: (Theme.Space.section * 2) + Theme.Space.regular)
        .accessibilityElement()
        .accessibilityLabel(Text("最近 7 天的\(trend.label)"))
    }
}

extension View {
    /// 记录详情里的一块白卡（照原型 RecordSheet 的 .grp：暖灰底上的白色圆角卡）
    func peekCard(vertical: CGFloat = 0) -> some View {
        padding(.horizontal, Theme.Space.regular).padding(.vertical, vertical)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.stat))
    }
}
