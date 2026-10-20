# 01 现在的 App（2026-10-20）

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
| `App/Sources/StubServer*.swift` | 界面测试用的假服务器（启动参数 `-uiTest`）：照服务器的接口回话，数据是从 5199 演示服务器拿的 |
| `Packages/PourKit/Sources/PourAPI/` | 服务器接口的数据类型（字段名一字不差）、客户端 `APIClient`、推送 `Events`、写法 `Show`（日期、钱、心情、时长……和服务器说的一字不差） |
| `PourDesign/Web.swift`、`WebControls.swift`、`WebParts.swift` | **现在用的设计系统**：令牌 `Web.*`（颜色、字号、间距、圆角、动效）和组件（`WebButton`、`WebSwitch`、`WebSegmented`、`WebChip`、`WebTextField`、`WebSkeleton`、`WebErrorState`、`WebTextButton`、`WebPressStyle`、`Dots`） |
| `PourDesign/Pour*.swift`、`Components/` | 第一阶段「纸·墨·青」的旧设计系统，只剩设计画廊在用（有和现在同名的，如 `PourSkeleton`） |
| `PourCore/` | 日期、钟点、`Math.round` 的规则（和服务器对拍：`fixtures/golden/`），几样写法 |
| `PourPlatform/` | 待办的系统通知、钥匙串 |
| `PourData/`、`PourAI/` | 第一阶段手机自己存数据、自己调 AI 的那一套，不用了；只有 `PourData` 里的 `Reminder` 类型还被提醒用着 |
| `gateway/` | 第一阶段手机自己的 AI 网关，不用了。**`gateway/.env` 里有产品主人的密钥：不读、不改，删之前先问他** |
| `Gallery/`、`GalleryUITests/` | 设计画廊 App（第一阶段的样张），不上架 |
| `AppUITests/` | 每一页的界面测试；`AppAudit.swift` 是无障碍审计和它的例外 |
| `scripts/` | `bootstrap.sh` 准备环境、`check.sh` 检查、`install-device.sh` 装到手机、`simulator.py` 选模拟器、几个检查脚本 |

## 3. 改一页、加一页

1. **接口先在服务器做好**：`~/Developer/pour` 里改 `server/src/routes/`、`shared/src/`，`npm run check` 过；字段名定下来
2. **数据类型**：`PourAPI/` 里照服务器的类型一字不差地写，`APIClient` 加方法；从 5199 拿一份真的回复存进 `Packages/PourKit/Tests/PourAPITests/Fixtures/`（`curl -s 127.0.0.1:5199/api/... | python3 -m json.tool --no-ensure-ascii`），写解码测试
3. **界面**：`App/Sources/<页面>/` 写 SwiftUI，只用设计系统的令牌和组件（SwiftLint 会拦硬编码的颜色、字号、间距、圆角）；数字和说法用服务器给的、用 `Show` 写，手机不自己算
4. **界面测试**：假服务器里加这一页的接口（`StubServer+<页面>.swift`），`AppUITests/` 里点进去、截图、跑审计
5. **检查**：`swiftlint lint --strict`、`xcrun swift-format lint --strict -r …`、`python3 scripts/check-wording.py`、`swift test`（在 `Packages/PourKit` 里）、这一页的界面测试；交出去前 `scripts/check.sh --full`

## 4. 测试和检查

- **单元测试**：`cd Packages/PourKit && swift test`（约 90 项：接口解码、写法、对拍、提醒）
- **界面测试**：连假服务器、不花钱。每页一个测试类，都跑系统的无障碍审计（对比度、字被截、点按区域、动态字体），截图存进测试结果
- **一键检查**：`scripts/check.sh`（推送前自动跑，约 10–20 分钟；不要用 `--no-verify` 跳过）；`--full` 是全部审计（亮暗 × 最大字号 × 一屏一屏），每一块自验收前跑；`--no-ui` 只跑最快的
- **审计的坑**（踩过的）：长页面的审计偶尔超时（AppAudit 会重试、再按类型分开审）；检查跑着的时候别跑别的重活、别改仓库里的文件；审计报「字被截」常是一行字放不下用了省略号——字大时换成多行；对比度报错常是对话面板或搜索盖着的页面——盖着时把下面的页面对读屏藏起来
- **截图对照**：启动参数 `-serverURL http://127.0.0.1:5199` 连演示服务器（演示数据），`-day 2026-10-15` 直接打开那一天

## 5. 跑起来

- **服务器**（在 `~/Developer/pour` 里，用 Node 24）：5188 给产品主人的手机（`POUR_DATA_DIR=~/Developer/pour-phone-data`），5199 是演示数据；命令和重启的规矩在服务器仓库的 CLAUDE.md。重启前先备份数据库
- **模拟器**：「iPhone 15 · iOS 27」（和产品主人的手机一样）；`scripts/simulator.py` 选
- **装到产品主人的 iPhone**：数据线连上、手机解锁，`scripts/install-device.sh`（免费签名，7 天要重装；它把服务器地址写成这台 Mac 的局域网名字 `http://<名字>.local:5188`）
- **App 里改连哪台**：「设置 → 这台手机 → 电脑上的 Pour」

## 6. 现在的局限（第二阶段要解决的，见 00 提示词第 2、9 节）

- 手感是网页的：左上角菜单、半屏详情层、网页式按钮和列表；只有亮色；动效和触感少
- 两套设计系统并存（`Web*` 和旧的 `Pour*`）；名字里的 `Web` 是从网页版搬来的痕迹
- 输入只有打字和输入法的语音键；没有拍照、分享、小组件、Siri
- 只在家里的 WiFi 下能用；推送靠 Bark / Server酱
- 旧东西还在：`PourData`、`PourAI`、`gateway/`、设计画廊。第一阶段用真 AI 走一遍的界面测试（`RealAIUITests`）2026-10-20 删掉了：标识对不上，而且会连到产品主人的服务器；以后要用真的 AI 测，先起一个隔离的服务器（临时数据目录）再连它
- M2 分支（`feature/ios-m2-say-to-today`）还没合进 main
