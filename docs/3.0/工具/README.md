# 工具

- `TourShotsUITests.swift`：把每一页从上到下一屏一屏截下来（2026-10-27 验收账号写方案时用的）。用法：拷进 `AppUITests/`，`xcodegen generate`，起一个演示数据的服务器，然后
  `xcodebuild test -project Pour.xcodeproj -scheme Pour -destination 'id=<模拟器>' -only-testing:PourUITests/TourShotsUITests -resultBundlePath <结果>.xcresult -collect-test-diagnostics never`，
  再 `xcrun xcresulttool export attachments --path <结果>.xcresult --output-path <目录>`（`manifest.json` 里有每张图的名字）。
  里面写死了 `http://127.0.0.1:5199` 和 2026-10 的几个日子，正式化时改成参数（03 开发计划第 0 步）。
