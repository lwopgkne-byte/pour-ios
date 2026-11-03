import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 好时刻（全部，06 交互细节 10.1）：心情 4 级以上、说了那一刻的每一刻，按月分组；每一刻一个小表情 + 宋体那一刻 +
/// 「日期 · 心情 · 情绪词」；点开是一条心情（能改）
struct MoodMomentsPage: View {
    @Environment(AppModel.self) private var model
    @State private var moments: [API.MoodMoment]?
    @State private var problem: String?

    var body: some View {
        List {
            if let moments {
                if moments.isEmpty {
                    Text("还没有好时刻。心情不错的时候顺口说一句为什么（「晚上楼下飘上来烤红薯的香味」），这里就会有。")
                        .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                        .listRowBackground(Color.clear)
                }
                ForEach(months(moments), id: \.self) { month in
                    Section {
                        ForEach(moments.filter { $0.day.hasPrefix(month) }) { moment in
                            Button {
                                model.mood.detail = moment
                            } label: {
                                MoodGoodRow(moment: moment).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        let title = "\(Int(month.prefix(4)) ?? 0)年\(Show.monthName(month))"
                        MoodListHeader(title: title, count: count(moments, month))
                    }
                }
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Space.medium)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    /// 有好时刻的月份，新的在前
    private func months(_ list: [API.MoodMoment]) -> [String] {
        Set(list.map { String($0.day.prefix(7)) }).sorted(by: >)
    }

    private func count(_ list: [API.MoodMoment], _ month: String) -> Int {
        list.filter { $0.day.hasPrefix(month) }.count
    }

    private func load() async {
        do throws(APIError) {
            moments = try await model.client.moments().compactMap(API.MoodMoment.init(moment:))
            problem = nil
        } catch {
            if moments == nil { problem = error.message }
        }
    }
}

/// 分组列表的组头：左边名字，右边几个
struct MoodListHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            Spacer()
            Text("\(count) 个").font(Theme.Typeface.subheadline).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
