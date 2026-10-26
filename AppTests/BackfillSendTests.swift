import Foundation
import PourCore
import Testing

@testable import Pour

/// 看以前的某一天时说的话补记到那一天（docs/模块/产品优化.md R1.1）：待发里带着那一天，画布留在那一天；
/// 今天说的照旧不带
@Suite("补记", .serialized)
@MainActor
struct BackfillSendTests {
    @Test func backfillKeepsTheDay() {
        // 手机上存的待发，测试完原样放回：测试的话不能留下来
        let keys = [OutboxStore.serverKey, "pour.outbox.uiTest"]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) } }
        let model = AppModel(client: StubServer.client())
        let yesterday = PourDate.addDays(model.today, -1)
        model.show(yesterday)
        model.draft = "晚上吃了火锅"
        model.send()
        #expect(model.outbox.last?.day == yesterday)
        #expect(model.shownDay == yesterday, "补记完跳走了")
        model.show(model.today)
        model.draft = "跑了步"
        model.send()
        #expect(model.outbox.last?.day == nil)
    }

    /// 以前存在手机上的待发没有 day 这一项：照样读得出来，算今天的
    @Test func oldOutboxStillLoads() {
        let key = "pour.outbox.test-old"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.set(Data(#"[{"clientId":"a1","text":"以前的","createdAt":0}]"#.utf8), forKey: key)
        let items = OutboxStore.load(from: key)
        #expect(items.first?.text == "以前的")
        #expect(items.first?.day == nil)
    }
}
