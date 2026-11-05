import PourAPI
import PourDesign
import SwiftUI

/// 目标首页的卡片怎么排（照可交互原型 goalBlocks）：一块「我在乎的」只有一个目标（又不是落后要调的）算「单个」，
/// 两个单个挨着时左右并排；一块有好几个目标时两列，落后要调的、最后落单的那一张占一整行
enum GoalBlock: Identifiable {
    case single(API.GoalGroup, API.GoalCard)
    case pair(API.GoalGroup, API.GoalCard, API.GoalGroup, API.GoalCard)
    case group(API.GoalGroup)

    var id: String {
        switch self {
        case .single(let group, _): "single-\(group.name)"
        case .pair(let left, _, let right, _): "pair-\(left.name)-\(right.name)"
        case .group(let group): "group-\(group.name)"
        }
    }

    static func blocks(_ groups: [API.GoalGroup]) -> [GoalBlock] {
        var out: [GoalBlock] = []
        for group in groups where !group.cards.isEmpty {
            let single = group.cards.count == 1 && !group.cards[0].lagging
            if single, case .single(let previous, let card)? = out.last {
                out[out.count - 1] = .pair(previous, card, group, group.cards[0])
            } else if single {
                out.append(.single(group, group.cards[0]))
            } else {
                out.append(.group(group))
            }
        }
        return out
    }

    /// 一块好几个时，一行一行：占一整行的（落后要调的、最后落单的半张）单独一行，别的两个一行
    static func rows(_ cards: [API.GoalCard]) -> [[API.GoalCard]] {
        let halves = cards.filter { !$0.lagging }
        let lastOdd = halves.count % 2 == 1 ? halves.last?.id : nil
        var rows: [[API.GoalCard]] = []
        var pending: [API.GoalCard] = []
        for card in cards {
            if card.lagging || card.id == lastOdd {
                rows.append([card])
            } else {
                pending.append(card)
                if pending.count == 2 {
                    rows.append(pending)
                    pending = []
                }
            }
        }
        if !pending.isEmpty { rows.append(pending) }
        return rows
    }
}

/// 一块「我在乎的」的小标题（原型 GLabel）：彩色小图标 + 名字
struct GoalGroupLabel: View {
    let group: API.GoalGroup

    var body: some View {
        Label {
            Text(group.name)
        } icon: {
            Image(systemName: CareIcon.symbol(group.icon)).foregroundStyle(Theme.careColor(group.icon))
        }
        .font(Theme.Typeface.footnoteSemibold)
        .foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.tight)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 一个目标一张白卡（原型 GoalCard）：半张是环在上、名字、一句人话（落后琥珀色）、第二行链接；
/// 一整行的是环在左边。点了推进那个目标，按住出菜单，左滑露出暂停（GoalSwipe）
struct GoalCardView: View {
    @Environment(AppModel.self) private var model
    let card: API.GoalCard
    var wide = false

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .center, spacing: Theme.Space.medium) {
                    ring
                    text
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    ring
                    text
                }
            }
        }
        .padding(Theme.Space.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .themeEdge(radius: Theme.Corner.smallCard)
        .opacity(card.paused ? 0.62 : 1)
        .contentShape(Theme.rounded(Theme.Corner.smallCard))
        .onTapGesture { model.openGoal(card.id) }
        .contextMenu { GoalMenu(card: card) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.openGoal(card.id) }
        .accessibilityAction(named: Text(card.paused ? "继续" : "暂停")) {
            model.goalAct(card.id, card.paused ? "resume" : "pause")
        }
        .accessibilityIdentifier("goal.row.\(card.id)")
        // 左滑露出的按钮在卡片外面（不和卡片合成一个读屏的元素）
        .modifier(GoalSwipe(card: card))
    }

    private var ring: some View {
        GoalRing(
            state: card.ringState, progress: card.pct, label: card.ring ?? "", size: Theme.Size.rowRing,
            spinIn: model.goals.fresh == card.id)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            Text(card.title).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.line).font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(card.state == "behind" ? Theme.Palette.warn : Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            if let second = card.second {
                Button {
                    if card.lagging { model.goals.sheet = .grow(card.id) } else { model.openGoal(card.id) }
                } label: {
                    // 服务器给的有时已经带「›」，不再多加一个
                    Text(card.lagging || second.hasSuffix("›") ? second : "\(second) ›").font(
                        Theme.Typeface.footnoteMedium
                    )
                    .foregroundStyle(Theme.Palette.accent)
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(card.lagging ? "goal.grow.\(card.id)" : "goal.ask.\(card.id)")
            }
        }
    }
}

/// 左滑露出「暂停」（「继续」）：卡片往左挪，后面一个灰色的按钮，点了暂停、轻提示能撤销；往右滑、点别处收回。
/// 竖着划照样是翻页（只认横着的）
struct GoalSwipe: ViewModifier {
    @Environment(AppModel.self) private var model
    let card: API.GoalCard
    @State private var offset: CGFloat = 0

    private static let reveal = Theme.Size.touch * 2

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    model.goalAct(card.id, card.paused ? "resume" : "pause")
                    withAnimation(Theme.Motion.quick) { offset = 0 }
                } label: {
                    Label(card.paused ? "继续" : "暂停", systemImage: card.paused ? "play.fill" : "pause.fill")
                        .labelStyle(.iconOnly).font(Theme.Typeface.bodySemibold)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .frame(width: Self.reveal - Theme.Space.small)
                        .frame(maxHeight: .infinity)
                        .background(Theme.Palette.secondaryLabel, in: Theme.rounded(Theme.Corner.smallCard))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(card.paused ? "继续" : "暂停"))
                .transition(.opacity)
            }
            content.offset(x: offset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: Theme.Space.large)
                .onChanged { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    let base: CGFloat = offset <= -Self.reveal ? -Self.reveal : 0
                    offset = min(0, max(-Self.reveal, base + drag.translation.width))
                }
                .onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    withAnimation(Theme.Motion.quick) {
                        offset = drag.translation.width < -Theme.Space.section ? -Self.reveal : 0
                    }
                })
    }
}
