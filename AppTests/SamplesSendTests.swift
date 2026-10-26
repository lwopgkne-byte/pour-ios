import Foundation
import Testing

@testable import Pour

/// 画布样张里说一句（产品主人 2026-10-26：用语音说了今天做了什么，样张里的假服务器只回「好的，听到了」）：
/// 这句话交给真的服务器——放进真的待发、回到服务器的数据、打开对话；样张里的假服务器收不到
@Suite("样张里说的话交给真的服务器", .serialized)
@MainActor
struct SamplesSendTests {
    @Test func sentenceGoesToTheRealServer() {
        // 手机上存的待发、样张的开关，测试完原样放回：测试的话不能留下来、平时打开时发给真的服务器
        let keys = [OutboxStore.serverKey, "pour.outbox.uiTest", CanvasSamples.key]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) }
            AppModel.openChatOnLaunch = false
        }
        CanvasSamples.set(true)
        let model = AppModel(client: StubServer.client(), health: .forTests(), calendar: .forTests())
        let waiting = model.outbox.count
        model.draft = "今天早上跑了五公里 中午和同事吃火锅"
        model.send()
        #expect(OutboxStore.load(from: OutboxStore.serverKey).last?.text == "今天早上跑了五公里 中午和同事吃火锅")
        #expect(model.replaced, "没换回服务器的数据")
        #expect(!CanvasSamples.isOn, "样张没关")
        #expect(AppModel.openChatOnLaunch, "回来以后不打开对话")
        #expect(model.outbox.count == waiting, "不该交给样张里的假服务器")
    }
}
