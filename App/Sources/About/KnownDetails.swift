import PourAPI
import PourDesign
import SwiftUI

/// 一个人：关系（就是个人词典里这个名字的那一条：改了就改词典，清空就是删掉）、最近 90 天、最近的记录、不用列出
struct PersonDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let person: API.KnownPerson
    let store: KnownStore
    let openEntry: (String, Int) -> Void
    let leave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            if !person.titled { relation }
            PeekSection(title: "最近 90 天") {
                Text(Show.spaced(Show.personSummary(person))).font(Web.body).foregroundStyle(Web.fg)
            }
            if !person.recent.isEmpty {
                PeekSection(title: "最近的记录") {
                    KnownEvidence(
                        items: person.recent.map {
                            .init(
                                day: $0.day, text: "\(Show.monthDay($0.day)) · \($0.label)", side: $0.domain,
                                entryId: $0.entryId)
                        }, first: 5, unit: "条", open: openEntry)
                    WebTextButton("在笔记库看和\(person.name)有关的原话", font: Web.caption) {
                        let tag = person.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
                        leave("/library?tag=\(tag)")
                    }
                    .padding(.top, Web.space2)
                }
            }
            WebTextButton("不用列出\(person.name)", color: Web.fgSecondary) { wrong() }
        }
    }

    private var relation: some View {
        VStack(alignment: .leading, spacing: 0) {
            PeekRow(label: "关系") {
                InlineEdit(label: "关系", value: person.relation?.meaning ?? "", placeholder: "添加") { save($0) }
            }
            if let relation = person.relation, let note = relation.note {
                HStack(spacing: Web.space1) {
                    let clause = Show.saidClause(note.text, name: person.name, meaning: relation.meaning)
                    MeNote("你在 \(KnownStore.isoDay(note.at))说「\(clause)」 ·")
                    if let noteId = relation.noteId {
                        WebTextButton("原话", font: Web.caption) { leave("/library?note=\(noteId)") }
                    }
                }
            } else if let relation = person.relation {
                MeNote("你 \(KnownStore.isoDay(relation.updatedAt))在这里写的")
            } else {
                MeNote("只写你说过的。也可以直接说「\(person.name)是我……」")
            }
        }
    }

    private func save(_ text: String) {
        let meaning = text.trimmingCharacters(in: .whitespaces)
        let client = model.client
        let relation = person.relation
        let name = person.name
        Task {
            do {
                if let relation, meaning.isEmpty {
                    try await client.deleteSaying(relation.id)
                } else if let relation {
                    try await client.editSaying(relation.id, meaning: meaning)
                } else if !meaning.isEmpty {
                    try await client.addSaying(name, meaning: meaning)
                }
                await store.load(client)
                model.dataChanged()
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func wrong() {
        dismiss()
        store.mark(person.key, "wrong", basis: person.basis, sentence: person.name, model)
        model.toast("不再显示「\(person.name)」", action: "撤销") {
            store.mark(person.key, nil, basis: person.basis, sentence: person.name, model)
        }
    }
}

/// 一个地方：去过几天、多是做什么、最近那几次；说得不对能「不用列出」
struct PlaceDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let place: API.KnownPlace
    let store: KnownStore
    let openEntry: (String, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            Text(
                Show.spaced(
                    "\(place.name)：最近 90 天去过 \(place.days) 天"
                        + (place.doing.isEmpty ? "" : "，多是\(place.doing.joined(separator: "、"))") + "。")
            )
            .font(Web.body).foregroundStyle(Web.fg)
            PeekSection(title: "最近的 \(place.recent.count) 次") {
                KnownEvidence(
                    items: place.recent.map {
                        .init(
                            day: $0.day, text: "\(Show.monthDay($0.day))\($0.at.map { " \($0)" } ?? "") · \($0.label)",
                            side: nil, entryId: $0.entryId)
                    }, first: 5, unit: "次", open: openEntry)
            }
            MeNote("整理你的话时，Pour 用它认出「又去面馆了」说的是哪儿。")
            WebTextButton("不用列出\(place.name)", color: Web.fgSecondary) {
                dismiss()
                store.mark(place.key, "wrong", basis: place.basis, sentence: place.name, model)
                model.toast("不再显示「\(place.name)」", action: "撤销") {
                    store.mark(place.key, nil, basis: place.basis, sentence: place.name, model)
                }
            }
        }
    }
}

/// 一个说法：说法、意思能原地改；从哪学来的（原话里那个词标出来）；删除（能撤销）
struct SayingDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let saying: API.Saying
    let store: KnownStore
    let leave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space6) {
            VStack(alignment: .leading, spacing: 0) {
                PeekRow(label: "说法") {
                    InlineEdit(
                        label: "说法", value: saying.phrase, validate: { $0.isBlank ? "说法不能是空的" : nil },
                        onSave: { edit(phrase: $0.trimmingCharacters(in: .whitespaces)) })
                }
                PeekRow(label: "意思") {
                    InlineEdit(
                        label: "意思", value: saying.meaning, validate: { $0.isBlank ? "意思不能是空的" : nil },
                        onSave: { edit(meaning: $0.trimmingCharacters(in: .whitespaces)) })
                }
                MeNote("点一下就能改。整理你的话时会按这个意思理解")
            }
            PeekSection(title: "从哪学来的") {
                if let note = saying.note {
                    QuoteText(text: note.text)
                    HStack(spacing: Web.space1) {
                        MeNote("\(KnownStore.isoDay(note.at)) \(KnownStore.isoClock(note.at)) ·")
                        if let noteId = saying.noteId {
                            WebTextButton("原话", font: Web.caption) { leave("/library?note=\(noteId)") }
                        }
                    }
                } else {
                    MeNote("你 \(KnownStore.isoDay(saying.updatedAt))自己加的")
                }
            }
            WebTextButton("删除这个说法", color: Web.danger) { remove() }
        }
    }

    private func edit(phrase: String? = nil, meaning: String? = nil) {
        let client = model.client
        let id = saying.id
        Task {
            do {
                try await client.editSaying(id, phrase: phrase, meaning: meaning)
                if let phrase { store.open("saying:\(phrase)") }
                await store.load(client)
                model.dataChanged()
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func remove() {
        let client = model.client
        let saying = saying
        dismiss()
        Task {
            do {
                try await client.deleteSaying(saying.id)
                await store.load(client)
                model.dataChanged()
                model.toast("删掉了「\(saying.phrase)」", action: "撤销") {
                    Task {
                        try? await client.addSaying(saying.phrase, meaning: saying.meaning, noteId: saying.noteId)
                        await store.load(client)
                        model.dataChanged()
                    }
                }
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 一列依据：先列几条，多的收在「看全部」里；点一条打开那条记录
struct KnownEvidence: View {
    struct Item {
        let day: String
        let text: String
        let side: String?
        let entryId: Int
    }

    let items: [Item]
    let first: Int
    let unit: String
    let open: (String, Int) -> Void
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array((all ? items : Array(items.prefix(first))).enumerated()), id: \.offset) { _, item in
                Button {
                    open(item.day, item.entryId)
                } label: {
                    HStack(spacing: Web.space3) {
                        Text(Show.spaced(item.text)).font(Web.body).foregroundStyle(Web.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let side = item.side { Text(side).font(Web.caption).foregroundStyle(Web.fgTertiary) }
                    }
                    .padding(.vertical, Web.space2)
                    .frame(minHeight: Web.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(WebPressStyle(radius: 0))
                .moneyRule()
                .accessibilityElement(children: .combine)
            }
            if !all && items.count > first {
                WebTextButton("看全部 \(items.count) \(unit)", font: Web.caption) { all = true }.padding(.top, Web.space2)
            }
        }
    }
}
