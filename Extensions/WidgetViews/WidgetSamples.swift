import PourAPI

/// 小组件的样子用的样例（小组件库里的预览、App 开发版的「小组件样张」）
enum WidgetSamples {
    static let glance = API.Glance(
        today: "2026-10-26",
        open: [
            .init(id: 1, content: "喝水", remindAt: "14:00", overdue: false),
            .init(id: 2, content: "送车去保养", remindAt: "19:00", overdue: false),
            .init(id: 3, content: "买牛奶", remindAt: nil, overdue: false),
        ],
        done: 1, total: 4,
        next: .init(id: 2, content: "送车去保养", remindAt: "19:00", overdue: false),
        quote: .init(text: "付出不亚于任何人的努力", day: "2026-10-20", asked: true))
}
