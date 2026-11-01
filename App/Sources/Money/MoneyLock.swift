import LocalAuthentication
import PourDesign
import SwiftUI

/// 打开钱要面容 ID（01 需求文档 5.6；设置 → 隐私）：只记在这台手机上。开了以后，这次打开 App 第一次进钱先验一次
/// （面容 ID，不行就用手机密码）；App 退到后台再回来要重新验。验不过、取消了就停在锁着的这一页，点一下再试
enum MoneyLock {
    static let key = "pour.money.faceID"

    /// 这台手机能不能验（没设手机密码就验不了，锁也就开不了）
    static var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

/// 钱的每一页外面包一层：开了面容 ID 又还没验过，先显示锁着的样子
struct MoneyLockGate<Content: View>: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyLock.key) private var locked = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if !locked || model.moneyUnlocked {
            content()
        } else {
            VStack(spacing: Theme.Space.regular) {
                Image(systemName: "faceid").font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.accent)
                    .accessibilityHidden(true)
                Text("钱锁上了").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Text("设置里开了「打开钱要面容 ID」：确认是你就打开").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.center)
                Button {
                    Task { await model.unlockMoney() }
                } label: {
                    Text("用面容 ID 打开").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, Theme.Space.large).frame(minHeight: Theme.Size.touch)
                        .background(Theme.Palette.accentFill, in: Capsule())
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("moneyLock.open")
            }
            .padding(Theme.Space.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.background)
            .task { await model.unlockMoney() }
        }
    }
}

extension AppModel {
    /// 验一下是不是本人：面容 ID，不行就用手机密码。这台手机没设密码时锁不了，直接打开。
    /// 界面测试里用启动参数 -moneyAuth pass / fail 代替（模拟器上没有面容 ID）
    func unlockMoney() async {
        if let fake = UserDefaults.standard.string(forKey: "moneyAuth") {
            moneyUnlocked = fake == "pass"
            return
        }
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            moneyUnlocked = true
            return
        }
        moneyUnlocked = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "打开钱")) ?? false
    }
}
