# 01 现在的 App（2026-10-20；2026-10-31 3.0 第 0 步清理后更新）

> 给接手的 Claude：App 现在是怎么搭起来的、每样东西在哪、怎么改一页、怎么测。要做成什么样看 [00 提示词](00-提示词.md)；为什么这么搭看 [ADR A22](ADR/A22-路线B.md)、[A23](ADR/A23-只留服务器.md)。

## 1. 一张图

```
iPhone 上的 Pour App  ──接口（HTTP）、推送（/api/events）──▶  Mac 上的 Pour 服务器（~/Developer/pour）──▶ DeepSeek
     界面和交互                                                 数据、业务规则、AI、统计、回顾、提醒、搜索
```

- **App 只做界面**：读写服务器的接口；一直听服务器的推送，哪样变了就重新拿哪样；没网时说的话先存在手机上（发件箱），连上自动发；看到的待办里要提醒的，由手机自己排系统通知
- **服务器做其余一切**：整理（意图识别 → 解析 → 程序把关 → 收据）、钱、目标、心情、关于我、回顾和周报月报、按意思搜索（电脑上的本地模型）、提醒和推送（Bark / Server酱）、夜里自动体检
- **只能在电脑上做的**（密钥、PIN、从备份导入、评测、审核员考试）：App 里只看得到现在的样子，改要双击 `~/Developer/pour/Pour 设置.command`
- **链接**：服务器和对话里的链接是页面地址（`/review/2026-10-18`、`/money/watch`、`/library?note=12`、`/about?find=老地方`），`model.open(地址)` 打开；从 App 外面是 `pour://open?path=地址`，Bark 的推送是 `pour://`（打开 App）

## 2. 代码在哪

| 位置 | 是什么 |
|---|---|
| `App/Sources/PourApp.swift` | 入口；`pour://` 链接在这里接 |
| `App/Sources/AppModel*.swift` | App 的状态：连哪台服务器、拿数据、听推送、发件箱、轻提示、打开哪一页（`open(地址)`、`pagePath`）、对话面板（`chatOpen`）、搜索（`search`）、打开记录或目标的详情 |
| `App/Sources/RootView.swift`、`Pages.swift` | 外壳：左上角菜单、右上角搜索、八页、演示数据的横幅、轻提示 |
| `App/Sources/Canvas/` | 生活画布、输入框（斜杠命令）、对话面板、记录详情（原地改、最近 7 天、相关目标、来源原话）、时间轴、类别卡片 |
| `App/Sources/Review/`、`Money/`、`About/`、`Goals/`、`Library/`、`Search/`、`Settings/` | 各页 |
| `App/Sources/PinGate.swift`、`ServerConfiguration.swift` | 要 PIN 时整个 App 先显示的那一页；服务器地址（设置里改过的存在钥匙串，没有就用 Info.plist 的 `PourServerURL`） |
| `App/Sources/WebPeek.swift` | 从底部滑出的详情层 |
| `App/Sources/StubServer*.swift` | 界面测试用的假服务器（启动参数 `-uiTest`）：照服务器的接口回话，数据是从演示服务器拿的 |
| `Packages/PourKit/Sources/PourAPI/` | 服务器接口的数据类型（字段名一字不差）、客户端 `APIClient`、推送 `Events`、写法 `Show`（日期、钱、心情、时长……和服务器说的一字不差） |
| `PourDesign/Theme/` | **唯一的设计系统**（[ADR A26](ADR/A26-一套设计系统.md)）：生活画布 2.0 起的令牌（`Theme.Palette`、`Theme.Space`、`Theme.Corner`、`Theme.Motion`……）和组件；`ColorToken.swift` 是颜色值和对比度计算 |
| `PourDesign/Web.swift`、`WebControls.swift`、`WebParts.swift` | 还没重做的页面暂时用的令牌 `Web.*` 和组件（`WebButton`、`WebSwitch`、`WebSegmented`……）：3.0 每重做一块就换掉那一块的，全部做完删掉 |
| `PourCore/` | 日期、钟点、`Math.round` 的规则（和服务器对拍：`fixtures/golden/`）、中文和数字之间的空 |
| `PourPlatform/` | 待办的系统通知（`Reminder`、`Reminders`）、钥匙串、和扩展共用的存储、健康、日历、语音 |
| `AppUITests/` | 每一页的界面测试；`AppAudit.swift` 是无障碍审计和它的例外 |
| `scripts/` | `bootstrap.sh` 准备环境、`check.sh` 检查、`install-device.sh` 装到手机、`simulator.py` 选模拟器、`tour-shots.sh` 全部页面截图（每页拼一张长图）、几个检查脚本 |

第一阶段手机自己存数据、自己调 AI 的那一套（`PourData`、`PourAI`、`gateway/`）、旧设计系统 `Pour*` 和设计画廊，3.0 第 0 步（2026-10-31）删掉了，要找去 Git 标签 `ios-2.8`。以前的工作目录里可能还留着 `gateway/.env`（产品主人的密钥）：不读、不改、不删，`.gitignore` 整个忽略 `gateway/`。

## 3. 改一页、加一页

1. **接口先在服务器做好**：`~/Developer/pour` 里改 `server/src/routes/`、`shared/src/`，`npm run check` 过；字段名定下来
2. **数据类型**：`PourAPI/` 里照服务器的类型一字不差地写，`APIClient` 加方法；从 5288（开发用的演示服务器）拿一份真的回复存进 `Packages/PourKit/Tests/PourAPITests/Fixtures/`（`curl -s 127.0.0.1:5288/api/... | python3 -m json.tool --no-ensure-ascii`），写解码测试
3. **界面**：`App/Sources/<页面>/` 写 SwiftUI，只用设计系统的令牌和组件（SwiftLint 会拦硬编码的颜色、字号、间距、圆角）；数字和说法用服务器给的、用 `Show` 写，手机不自己算
4. **界面测试**：假服务器里加这一页的接口（`StubServer+<页面>.swift`），`AppUITests/` 里点进去、截图、跑审计
5. **检查**：`swiftlint lint --strict`、`xcrun swift-format lint --strict -r …`、`python3 scripts/check-wording.py`、`swift test`（在 `Packages/PourKit` 里）、这一页的界面测试；交出去前 `scripts/check.sh`（全部界面测试和审计）

## 4. 测试和检查

- **单元测试**：`cd Packages/PourKit && swift test`（约 80 项：接口解码、写法、对拍、提醒）
- **界面测试**：连假服务器、不花钱。每页一个测试类，都跑系统的无障碍审计（对比度、字被截、点按区域、动态字体），截图存进测试结果
- **一键检查**：`scripts/check.sh` 是全部（界面测试和审计，半个小时左右），改得多或者改了大家都用的（外壳、审计、设计系统）时跑；推送前自动跑的是 `--no-ui`（几分钟；不要用 `--no-verify` 跳过）；平时只跑改到的那一页的界面测试（`-only-testing:PourUITests/MoneyUITests`）
- **审计的坑**（踩过的）：长页面的审计偶尔超时（AppAudit 会重试、再按类型分开审）；检查跑着的时候别跑别的重活、别改仓库里的文件；审计报「字被截」常是一行字放不下用了省略号——字大时换成多行；对比度报错常是对话面板或搜索盖着的页面——盖着时把下面的页面对读屏藏起来
- **截图对照**：`scripts/tour-shots.sh http://127.0.0.1:5288 <输出目录>` 一条命令把每一页截下来、每页拼一张长图（只连演示数据的服务器）；单看一页：启动参数 `-serverURL http://127.0.0.1:5288` 连演示服务器，`-day 2026-10-15` 直接打开那一天

## 5. 跑起来

- **服务器**（在 `~/Developer/pour` 里，用 Node 24）：5188 给产品主人的手机（`POUR_DATA_DIR=~/Developer/pour-phone-data`）；**5288 是开发用的演示数据**（`POUR_DATA_DIR=~/Developer/pour-dev-data`，里面的 `mode.json` 写着演示数据，3.0 第 0 步建的，日志在同一个目录的 `server-5288.log`）；命令和重启的规矩在服务器仓库的 CLAUDE.md。重启 5188 前先备份数据库
- **模拟器**：「iPhone 15 · iOS 27」（和产品主人的手机一样）；`scripts/simulator.py` 选
- **装到产品主人的 iPhone**：数据线连上、手机解锁，`scripts/install-device.sh`（免费签名，7 天要重装；它把服务器地址写成这台 Mac 的局域网名字 `http://<名字>.local:5188`）
- **App 里改连哪台**：「设置 → 这台手机 → 电脑上的 Pour」

## 6. 现在的局限（第二阶段要解决的，见 00 提示词第 2、9 节）

- 手感是网页的：左上角菜单、半屏详情层、网页式按钮和列表；只有亮色；动效和触感少
- 还没重做的页面用 `Web*`（名字是从网页版搬来的痕迹）：3.0 第 1–10 步一块一块换成 `Theme`
- 输入只有打字和输入法的语音键；没有拍照、分享、小组件、Siri
- 只在家里的 WiFi 下能用；推送靠 Bark / Server酱
- 第一阶段用真 AI 走一遍的界面测试（`RealAIUITests`）2026-10-20 删掉了：标识对不上，而且会连到产品主人的服务器；以后要用真的 AI 测，先起一个隔离的服务器（临时数据目录）再连它
- 第二阶段、产品优化八步、演示数据都在 2026-10-31 合进了 `main`（标签 `ios-2.8`）；3.0 从这里开始
