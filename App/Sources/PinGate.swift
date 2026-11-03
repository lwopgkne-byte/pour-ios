import PourAPI
import PourDesign
import SwiftUI

/// 输入 PIN：电脑上的 Pour 开了局域网 PIN、这台手机还没输过时整个 App 先显示这一页；
/// 输对了这台手机记住 30 天（令牌在 cookie 里）
struct PinGate: View {
    @Environment(AppModel.self) private var model
    @State private var pin = ""
    @State private var problem: String?
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.regular) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("Pour").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label).accessibilityAddTraits(
                    .isHeader)
                Text("输入电脑上设置的 PIN。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                TextField("4-6 位数字", text: $pin)
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focused)
                    .padding(.horizontal, Theme.Space.small)
                    .frame(minHeight: Theme.Size.touch)
                    .background(RoundedRectangle(cornerRadius: Theme.Corner.tile).fill(Theme.Palette.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Corner.tile).strokeBorder(
                            problem == nil
                                ? (focused ? Theme.Palette.accent : Theme.Palette.separator) : Theme.Palette.bad,
                            lineWidth: 1)
                    )
                    .accessibilityLabel(Text("PIN"))
                    .onChange(of: pin) { _, now in
                        pin = String(now.filter(\.isNumber).prefix(6))
                        problem = nil
                    }
                Text(problem ?? "输入后，这台设备会记住 30 天。").font(Theme.Typeface.footnote)
                    .foregroundStyle(problem == nil ? Theme.Palette.secondaryLabel : Theme.Palette.bad)
            }
            ThemeButton("进入", variant: .primary, loading: busy, disabled: pin.count < 4, block: true) { enter() }
        }
        .padding(.horizontal, Theme.Space.regular)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.card)
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
                let pairing = try await client.login(pin: code)
                // 设备登录：新服务器给这台设备一把钥匙，以后每个请求带上（旧服务器没有，照旧靠 cookie）
                ServerConfiguration.remember(deviceKey: pairing.token)
                pin = ""
                await model.refreshAll()
                await model.flushOutbox()
            } catch {
                problem = error.readable
            }
        }
    }
}
