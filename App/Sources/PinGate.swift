import PourAPI
import PourDesign
import SwiftUI

/// 输入 PIN（网页版 PinGate）：电脑上的 Pour 开了局域网 PIN、这台手机还没输过时整个 App 先显示这一页；
/// 输对了这台手机记住 30 天（令牌在 cookie 里）
struct PinGate: View {
    @Environment(AppModel.self) private var model
    @State private var pin = ""
    @State private var problem: String?
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space4) {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text("Pour").font(Web.sectionSemibold).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                Text("输入电脑上设置的 PIN。").font(Web.body).foregroundStyle(Web.fgSecondary)
            }
            VStack(alignment: .leading, spacing: Web.space1) {
                TextField("4-6 位数字", text: $pin)
                    .font(Web.body).foregroundStyle(Web.fg)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focused)
                    .padding(.horizontal, Web.space2)
                    .frame(minHeight: Web.touch)
                    .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                            problem == nil ? (focused ? Web.accent : Web.line) : Web.danger, lineWidth: 1)
                    )
                    .accessibilityLabel(Text("PIN"))
                    .onChange(of: pin) { _, now in
                        pin = String(now.filter(\.isNumber).prefix(6))
                        problem = nil
                    }
                Text(problem ?? "输入后，这台设备会记住 30 天。").font(Web.caption)
                    .foregroundStyle(problem == nil ? Web.fgTertiary : Web.danger)
            }
            WebButton("进入", variant: .primary, loading: busy, disabled: pin.count < 4, block: true) { enter() }
        }
        .frame(maxWidth: Web.toastWidth)
        .padding(.horizontal, Web.space4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Web.bg)
        .onAppear { focused = true }
    }

    private func enter() {
        busy = true
        problem = nil
        let client = model.client
        let code = pin
        Task {
            defer { busy = false }
            do {
                try await client.login(pin: code)
                pin = ""
                await model.refreshAll()
                await model.flushOutbox()
            } catch {
                problem = error.readable
            }
        }
    }
}
