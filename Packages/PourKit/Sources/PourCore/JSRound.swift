/// 和 JavaScript 的 `Math.round` 一模一样的四舍五入。
///
/// 网页版的规则全部用 `Math.round`：正好在 .5 时**往正无穷**取（`Math.round(-2.5) == -2`），
/// 而 Swift 的 `rounded()` 是**远离零**（`(-2.5).rounded() == -3`）。规则从 TypeScript 搬过来时，
/// 凡是网页版用 `Math.round` 的地方都用它，否则和网页版对拍会差 1（docs/ios/04-AI能力与程序适配方案.md 8.3）。
public func jsRound(_ value: Double) -> Double {
    guard value.isFinite else { return value }
    let floor = value.rounded(.down)
    // 用「和下取整的差」判断，而不是 floor(value + 0.5)：
    // 0.49999999999999994 + 0.5 在双精度里等于 1，会算错；JavaScript 给的是 0
    let result = value - floor >= 0.5 ? floor + 1 : floor
    // JavaScript 里 -0.4、-0.5 四舍五入得到 -0
    if result == 0 && value.sign == .minus { return -0.0 }
    return result
}
