# 对拍的标准答案

服务器（仓库 [lwopgkne-byte/pour](https://github.com/lwopgkne-byte/pour)）的规则在一批输入上的输出。Swift 版的同一条规则必须和它一模一样（`Packages/PourKit/Tests/PourCoreTests/GoldenTests.swift` 逐份比较）。

- **出处**：服务器仓库的 `scripts/export-golden.ts`，2026-10-17 导出（提交 `0286834`）；2026-10-20 服务器 2.0.0 删掉网页时重新导出了一次，只有文件开头「说明」那一句变了，样例一份没变
- **不要手改**。服务器改了这些函数（它的 `npm run check` 会说标准答案不是最新的），或者要更多标准答案：在服务器仓库跑 `npm run golden`，把新文件拷进来，在这里记一行出处和提交号

| 文件 | 内容 | 样例 |
|---|---|---|
| `date.json` | 日期的 4 个函数：addDays、diffDays、weekdayMon0、isValidDateStr | 133 |
| `time.json` | 时间的 6 个函数：parseTime、formatTime、parseDuration、formatDuration、formatDurationCn、circularDiff | 266 |
| `math.json` | `Math.round`（Swift 的 `jsRound` 对拍用） | 314 |
