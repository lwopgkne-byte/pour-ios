import PourAPI
import PourDesign
import SwiftUI

/// 你的说法（主页）：最近记住的先列 10 条，多的收在「看全部」里；「添加一个说法」在列表最上面原地多一行
struct KnownSayings: View {
    @Environment(AppModel.self) private var model
    let store: KnownStore
    @State private var all = false
    @State private var adding = false
    @State private var phrase = ""
    @State private var meaning = ""

    var body: some View {
        let sayings = store.about?.sayings ?? []
        KnownBlock(title: "你的说法") {
            if adding {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    TextField("说法（老路线）", text: $phrase).textFieldStyle(.roundedBorder).accessibilityLabel(Text("说法"))
                    TextField("意思（小区绕圈 5 公里）", text: $meaning).textFieldStyle(.roundedBorder).accessibilityLabel(
                        Text("意思"))
                    HStack(spacing: Theme.Space.regular) {
                        Button("记住") { save() }.buttonStyle(.borderedProminent).disabled(
                            phrase.isBlank || meaning.isBlank)
                        Button("取消") { cancel() }.buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, Theme.Space.small)
            }
            ForEach(all ? sayings : Array(sayings.prefix(10)), id: \.key) { saying in
                KnownRow(
                    title: AttributedString("\(saying.phrase) = \(saying.meaning)"),
                    meta: "\(KnownStore.isoDay(saying.updatedAt))记住"
                ) { store.open(saying.key) }
            }
            if !all && sayings.count > 10 {
                LinkButton("看全部 \(sayings.count) 个") { all = true }
            }
        } foot: {
            LinkButton("＋ 添加一个说法", font: Theme.Typeface.body, identifier: "known.saying.add") { adding = true }
            Text("· 也可以直接说「168 就是 16:8 轻断食」")
        }
    }

    private func cancel() {
        adding = false
        phrase = ""
        meaning = ""
    }

    private func save() {
        let client = model.client
        let saying = (phrase.trimmingCharacters(in: .whitespaces), meaning.trimmingCharacters(in: .whitespaces))
        Task {
            do {
                try await client.addSaying(saying.0, meaning: saying.1)
                cancel()
                await store.load(client)
                model.dataChanged()
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

extension String {
    /// 只有空白
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
