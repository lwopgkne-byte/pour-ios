import XCTest

/// 性能预算（docs/3.0/02-技术方案.md「性能预算」、04 验收标准：真机或同型号模拟器）：推进一页的转场、画布滚动的卡顿。
/// 真机上的冷启动和内存用 xctrace 量（写在 docs/3.0/验收/收尾.md）；真机上跑不了界面测试（免费签名只能装 3 个 App）。
/// 平时的检查不跑（每样要量 5 遍）：`TEST_RUNNER_POUR_PERF=1 xcodebuild test-without-building … -only-testing:PourUITests/PerformanceUITests`
final class PerformanceUITests: XCTestCase {
    private func skipUnlessAsked() throws {
        guard ProcessInfo.processInfo.environment["POUR_PERF"] == "1" else {
            throw XCTSkip("只在量性能时跑（TEST_RUNNER_POUR_PERF=1）")
        }
    }

    /// 推进一页：我 → 待办，再回到画布；系统记的导航转场
    @MainActor func testPushPage() throws {
        try skipUnlessAsked()
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric], options: options) {
            app.openTile("todos")
            app.goBackToCanvas()
        }
    }

    /// 滚动：画布样张（上班族，一天的卡片最多）往上快速划，系统记的滚动减速卡顿
    @MainActor func testScrollCanvas() throws {
        try skipUnlessAsked()
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }
}
