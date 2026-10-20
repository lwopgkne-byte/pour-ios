import PourAPI
import PourDesign
import SwiftUI

/*
 * 「Pour 认识的」（网页版 about/known.tsx，docs/prd-about-me.md、prd-about-me-2.md 第 9 节）：作息、常做的事、
 * 常提到的人和关系、常去的地方、你的说法。全部由程序算，每条两行、整行能点；点开看依据，说得不对点一下它就不再这么说。
 * 每一页拿同一份数据（KnownStore），只摆和这一页有关的那几块
 */

/// 一页里「Pour 认识的」的数据和开着的那一条
@MainActor @Observable
final class KnownStore {
    private(set) var about: API.Known?
    /// 开着的那一条（sleep、habit:…、person:…、place:…、saying:…）
    var opened: KnownKey?

    struct KnownKey: Identifiable, Hashable {
        let id: String
    }

    func load(_ client: APIClient) async {
        if let fresh = try? await client.known() { about = fresh }
    }

    func has(_ key: String) -> Bool {
        guard let about else { return false }
        if key == "sleep" { return about.sleep != nil }
        return about.habits.contains { $0.key == key } || (about.people + about.former).contains { $0.key == key }
            || about.places.contains { $0.key == key } || about.sayings.contains { $0.key == key }
    }

    func open(_ key: String) { opened = KnownKey(id: key) }
}

/// 一块：小标题、每条两行、块底一行灰字（根据什么，加上「你说不对的 1 条已经不显示 · 看看」）
struct KnownBlock<Content: View, Foot: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var hidden: [API.HiddenItem] = []
    var hiddenWord = "你说不对的"
    /// 恢复说不对的那几条用
    var store: KnownStore?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let foot: () -> Foot
    @State private var showHidden = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(Web.captionMedium).foregroundStyle(Web.fgSecondary).padding(.bottom, Web.space1)
                .accessibilityAddTraits(.isHeader)
            content()
            HStack(spacing: Web.space1) {
                foot()
                if !hidden.isEmpty {
                    Text("\(hiddenWord) \(hidden.count) \(hiddenWord == "你说不对的" ? "条" : "个")已经不显示 ·")
                    WebTextButton(showHidden ? "收起" : "看看", font: Web.caption) { showHidden.toggle() }
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            .padding(.top, Web.space2)
            if showHidden {
                ForEach(hidden, id: \.key) { item in
                    HStack(spacing: Web.space3) {
                        Text(item.text).frame(maxWidth: .infinity, alignment: .leading)
                        WebTextButton("恢复", font: Web.caption) { store?.restore(item, model) }
                    }
                    .font(Web.caption).foregroundStyle(Web.fgSecondary)
                    .frame(minHeight: Web.touch)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 一条：上面一句话，下面一行灰字；整行能点。确认过的句子后面跟一个淡淡的 ✓
struct KnownRow: View {
    let title: AttributedString
    var meta: String?
    var confirmed = false
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text(title + (confirmed ? AttributedString(" ✓") : AttributedString())).font(Web.body).foregroundStyle(
                    Web.fg)
                if let meta, !meta.isEmpty {
                    Text(meta).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                }
            }
            .padding(Web.space2)
            .frame(maxWidth: .infinity, minHeight: Web.touch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
        .padding(.horizontal, -Web.space2)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(confirmed ? "你确认过" : ""))
    }
}

/// 列表和块要的几样：恢复说不对的、标对错
extension KnownStore {
    func restore(_ item: API.HiddenItem, _ model: AppModel) {
        mark(item.key, nil, basis: "", sentence: item.text, model)
    }

    func mark(_ key: String, _ value: String?, basis: String, sentence: String, _ model: AppModel) {
        let client = model.client
        Task {
            do {
                try await client.mark(key, value, basis: basis, sentence: sentence)
                await load(client)
                model.dataChanged()
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 作息（「睡眠」那一页）
struct KnownSleep: View {
    @Environment(AppModel.self) private var model
    let store: KnownStore

    var body: some View {
        let hidden = store.about?.hidden.filter { $0.block == "sleep" } ?? []
        if let about = store.about, about.sleep != nil || !hidden.isEmpty {
            KnownBlock(title: "作息", hidden: hidden, store: store) {
                if let sleep = about.sleep {
                    KnownRow(
                        title: AttributedString(Show.sleepSentence(sleep)), meta: Show.sleepMeta(sleep),
                        confirmed: sleep.mark == "right"
                    ) { store.open("sleep") }
                }
            } foot: {
                if let sleep = about.sleep { Text("根据最近 4 周的 \(sleep.nights.count) 个晚上") }
            }
        }
    }
}

/// 常做的事（它所在的领域那一页）
struct KnownHabits: View {
    @Environment(AppModel.self) private var model
    let store: KnownStore
    let domain: String

    var body: some View {
        let habits = store.about?.habits.filter { $0.domain == domain } ?? []
        let hidden = store.about?.hidden.filter { $0.block == "habits" && $0.domain == domain } ?? []
        if !habits.isEmpty || !hidden.isEmpty {
            KnownBlock(title: "常做的事", hidden: hidden, store: store) {
                ForEach(habits, id: \.key) { habit in
                    KnownRow(
                        title: AttributedString(habit.name), meta: Show.habitMeta(habit),
                        confirmed: habit.mark == "right"
                    ) {
                        store.open(habit.key)
                    }
                }
            } foot: {
                Text("最近 4 周每周都做过的才列")
            }
        }
    }
}

/// 人和关系（「人」那一页、主页）：你说过的关系，没说过的写「添加关系」；只写你说过的，不猜
struct KnownPeople: View {
    @Environment(AppModel.self) private var model
    let store: KnownStore
    var names: [String]?
    var onlyRelations = false

    var body: some View {
        let people =
            store.about?.people.filter {
                (names?.contains($0.name) ?? true) && !$0.titled && ($0.relation != nil || !onlyRelations)
            } ?? []
        let hidden = onlyRelations ? [] : store.about?.hidden.filter { $0.block == "people" } ?? []
        if !people.isEmpty || !hidden.isEmpty {
            KnownBlock(title: "人和关系", hidden: hidden, hiddenWord: "不用列出的", store: store) {
                ForEach(people, id: \.key) { person in
                    KnownRow(title: name(person), meta: meta(person), confirmed: person.mark == "right") {
                        store.open(person.key)
                    }
                }
            } foot: {
                if !onlyRelations { Text("只写你说过的。也可以直接说「小李是我同事」") }
            }
        }
    }

    /// 「小王 · 同事」：关系用次要文字色
    private func name(_ person: API.KnownPerson) -> AttributedString {
        var text = AttributedString(person.name)
        if let relation = person.relation, !person.titled {
            var rest = AttributedString(" · \(Show.relationShort(relation.meaning))")
            rest.foregroundColor = Web.fgSecondary
            text += rest
        }
        return text
    }

    /// 关系是从哪学来的：「你 8月13日说的「小王是我同事」」
    private func meta(_ person: API.KnownPerson) -> String {
        guard let relation = person.relation else { return "\(Show.personMeta(person)) · 添加关系" }
        if let note = relation.note {
            let clause = Show.saidClause(note.text, name: person.name, meaning: relation.meaning)
            return "你 \(KnownStore.isoDay(note.at))说的「\(clause)」"
        }
        return "你 \(KnownStore.isoDay(relation.updatedAt))在这里写的"
    }
}

/// 常去的地方（主页）：整理时用它认出「又去面馆了」说的是哪儿
struct KnownPlaces: View {
    @Environment(AppModel.self) private var model
    let store: KnownStore

    var body: some View {
        let places = store.about?.places ?? []
        let hidden = store.about?.hidden.filter { $0.block == "places" } ?? []
        if !places.isEmpty || !hidden.isEmpty {
            KnownBlock(title: "常去的地方", hidden: hidden, hiddenWord: "不用列出的", store: store) {
                ForEach(places, id: \.key) { place in
                    KnownRow(
                        title: AttributedString(place.name), meta: Show.placeMeta(place),
                        confirmed: place.mark == "right"
                    ) {
                        store.open(place.key)
                    }
                }
            } foot: {
                Text("最近 90 天去过 3 天以上的")
            }
        }
    }
}

extension KnownStore {
    /// ISO 时刻 →「9月12日」（这台手机的时区）
    static func isoDay(_ iso: String) -> String {
        guard let date = Show.instant(iso) else { return "" }
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日"
    }

    /// ISO 时刻 →「7:10」
    static func isoClock(_ iso: String) -> String {
        let clock = Show.formatClock(iso)
        return clock.hasPrefix("0") ? String(clock.dropFirst()) : clock
    }
}
