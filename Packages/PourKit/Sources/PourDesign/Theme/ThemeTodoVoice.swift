public import SwiftUI

// 待办 2.0「说一句」的结果卡片（docs/todo-2.0 第 10 步，design/after-07-voice）：哪一格 · 哪天 · 几点三个小标签、
// 只说了时间段时下面问几点的一排小按钮。只管样子，点了改什么由用的地方给（菜单）

/// 结果卡片上的一个小标签：哪一格是象限底色 + 实心小图标 + 名字（AI 猜的用象限色虚线边、后面写「· 猜的」）；
/// 哪天、几点是灰底。看得见的高 30，点的地方 44
public struct ReceiptTag: View {
    public enum Kind: Equatable, Sendable {
        /// 哪一格（0 是还没分）、是不是猜的
        case quadrant(Int, guessed: Bool)
        case plain
    }

    let text: String
    let symbol: String?
    let kind: Kind

    public init(_ text: String, symbol: String? = nil, kind: Kind = .plain) {
        self.text = text
        self.symbol = symbol
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: Theme.Space.tight - 1) {
            if let symbol { Image(systemName: symbol).font(Theme.Typeface.caption) }
            Text(label).font(lit ? Theme.Typeface.footnoteSemibold : Theme.Typeface.footnote).monospacedDigit()
        }
        // 一个标签不折行（放不下整个挪到下一行，见 ChipFlow）
        .fixedSize()
        .foregroundStyle(lit ? Theme.Quadrant.text(quadrant) : Theme.Palette.secondaryLabel)
        .padding(.horizontal, Theme.Space.small + Theme.Space.hairline)
        .frame(minHeight: Theme.Size.editChip - Theme.Space.small + Theme.Space.hairline)
        .background(lit ? Theme.Quadrant.tint(quadrant) : Theme.Palette.fill, in: Capsule())
        .overlay {
            if guessed {
                Capsule().strokeBorder(Theme.Quadrant.ring(quadrant), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
    }

    private var quadrant: Int {
        if case .quadrant(let value, _) = kind { return value }
        return 0
    }

    /// 放进了四格之一（还没分的和哪天、几点一样是灰的）
    private var lit: Bool { quadrant > 0 }

    private var guessed: Bool {
        if case .quadrant(let value, let guessed) = kind { return guessed && value > 0 }
        return false
    }

    private var label: String { guessed ? "\(text) · 猜的" : text }
}

/// 只说了上午、下午、晚上：「下午几点提醒你？」下面一排小按钮（13:00 · 15:00 · 16:00 · 下午就行）
public struct WindowAsk: View {
    let question: String
    let choices: [String]
    let keep: String
    let pick: (String?) -> Void

    /// pick：点了钟点给钟点，点「下午就行」给 nil
    public init(_ question: String, choices: [String], keep: String, pick: @escaping (String?) -> Void) {
        self.question = question
        self.choices = choices
        self.keep = keep
        self.pick = pick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(question).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.label)
            ChipFlow {
                ForEach(choices, id: \.self) { clock in
                    EditChip(clock, selected: false) { pick(clock) }.fixedSize()
                }
                EditChip(keep, selected: false) { pick(nil) }.fixedSize()
            }
        }
        .accessibilityElement(children: .contain)
    }
}
