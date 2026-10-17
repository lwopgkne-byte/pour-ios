# 对拍的标准答案（冻结数据）

网页版的规则在一批输入上的输出。Swift 版的同一条规则必须和它一模一样（`Packages/PourKit/Tests/PourCoreTests/GoldenTests.swift` 逐份比较）。

- **出处**：网页版仓库 [lwopgkne-byte/pour](https://github.com/lwopgkne-byte/pour) 的 `scripts/export-golden.ts`，2026-10-17 导出（M0，网页版提交 `0286834`）。网页版已经冻结，这些文件不会再变
- **不要手改**。以后的模块要更多标准答案（M2 心情说法和时间推断、M7 目标计算……）：在网页版仓库加导出、跑一次 `npm run golden`，把新文件拷进来，在这里记一行出处和网页版的提交号

| 文件 | 内容 | 样例 |
|---|---|---|
| `date.json` | 日期的 4 个函数：addDays、diffDays、weekdayMon0、isValidDateStr | 133 |
| `time.json` | 时间的 6 个函数：parseTime、formatTime、parseDuration、formatDuration、formatDurationCn、circularDiff | 266 |
| `math.json` | `Math.round`（Swift 的 `jsRound` 对拍用） | 314 |
