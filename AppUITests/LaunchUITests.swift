import XCTest

/// 真的把 App 打开：亮色、暗色、最大字号（AX5）各走一遍，并跑系统的无障碍审计。
/// 截图作为附件留在测试结果里，自验收时导出来看。
final class LaunchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        // 放回亮色（模拟器不接受「未指定」）。XCTest 在主线程上调用同步的 tearDown；用 async 版本再等主线程会互相等死
        MainActor.assumeIsolated { XCUIDevice.shared.appearance = .light }
    }

    @MainActor
    func testLaunchLight() throws {
        try launchAndCheck(appearance: .light, name: "启动页-亮色")
    }

    @MainActor
    func testLaunchDark() throws {
        try launchAndCheck(appearance: .dark, name: "启动页-暗色")
    }

    @MainActor
    func testLaunchLargestText() throws {
        try launchAndCheck(
            appearance: .light, name: "启动页-最大字号",
            arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    @MainActor
    private func launchAndCheck(
        appearance: XCUIDevice.Appearance, name: String, arguments: [String] = []
    ) throws {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()

        let brand = app.descendants(matching: .any)["launch.brand"].firstMatch
        XCTAssertTrue(brand.waitForExistence(timeout: 5), "看不到字标")
        XCTAssertEqual(brand.label, "Pour 倾")

        let version = app.descendants(matching: .any)["launch.version"].firstMatch
        XCTAssertTrue(version.exists, "看不到版本号")
        XCTAssertTrue(
            version.label.range(of: #"^版本 \d+\.\d+\.\d+ · 构建 \d+$"#, options: .regularExpression) != nil,
            "版本号的写法不对：\(version.label)")

        // 系统的无障碍审计：对比度、元素说明、动态字体截断、可点范围……有问题直接失败
        try app.performAccessibilityAudit()

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
