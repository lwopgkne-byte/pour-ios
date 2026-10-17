#!/bin/bash
# iOS 一键检查（M0）：推送前自动跑（.githooks/pre-push，改了 ios/ 才跑），合并前 GitHub Actions 再跑一遍。
#   ① 生成工程 ② 代码格式 ③ SwiftLint（含令牌检查）④ 依赖方向 ⑤ 隐私清单
#   ⑥ 规则和设计系统的单元测试（Mac 上直接跑）⑦ App 的单元测试和界面测试（模拟器）
# 用法：ios/scripts/check.sh            全部
#       ios/scripts/check.sh --no-ui    跳过界面测试（快）
# 用一台专用的检查模拟器「Pour 检查」（没有就建），每次先关掉再跑，不受平时手动开的模拟器影响。
# 机型默认 iPhone 17 Pro，可以用 POUR_SIMULATOR="iPhone 13" 换；这台电脑没有这个机型就用第一个能用的 iPhone
set -euo pipefail

cd "$(dirname "$0")/.."
IOS_DIR="$(pwd)"
SIMULATOR="${POUR_SIMULATOR:-iPhone 17 Pro}"
SKIP_UI=0
[[ "${1:-}" == "--no-ui" ]] && SKIP_UI=1

START=${SECONDS}
step() { printf '\n▸ %s\n' "$1"; }
fail() { printf '\n✗ %s\n' "$1"; exit 1; }

step "工具版本"
xcodebuild -version | awk 'NR==1'
echo "XcodeGen $(xcodegen --version | awk '{print $2}') · SwiftLint $(swiftlint version)"

step "① 生成工程"
xcodegen generate --spec project.yml --quiet || fail "工程生成失败"

step "② 代码格式（swift-format）"
xcrun swift-format lint --strict --recursive --configuration .swift-format \
  App AppTests AppUITests Packages/PourKit/Sources Packages/PourKit/Tests Packages/PourKit/Package.swift \
  || fail "格式不对：运行 xcrun swift-format format -i -r --configuration ios/.swift-format <文件> 自动改好"

step "③ SwiftLint（含不许硬编码颜色和字号）"
swiftlint lint --strict --quiet || fail "SwiftLint 没通过"

step "④ 依赖方向"
python3 scripts/check-deps.py || fail "依赖方向不对"

step "⑤ 隐私清单"
plutil -lint App/Resources/PrivacyInfo.xcprivacy || fail "隐私清单格式不对"

step "⑥ 规则和设计系统的单元测试（Mac）"
(cd Packages/PourKit && swift test --quiet 2>&1 | tail -3) || fail "单元测试没通过"

step "⑦ App 的测试"
RUNTIME="$(xcrun simctl list runtimes available | awk '/^iOS /{id=$NF} END{print id}')"
[[ -n "${RUNTIME}" ]] || fail "没有可用的 iOS 模拟器系统：在 Xcode → 设置 → Components 里装一个"
DEVICE_TYPE="$(xcrun simctl list devicetypes | grep -F "${SIMULATOR} (" | head -1 | sed -E 's/.*\((com\.apple[^)]*)\)$/\1/' || true)"
if [[ -z "${DEVICE_TYPE}" ]]; then
  DEVICE_TYPE="$(xcrun simctl list devicetypes | grep -m1 -E '^iPhone ' | sed -E 's/.*\((com\.apple[^)]*)\)$/\1/')"
  echo "这台电脑没有 ${SIMULATOR}，改用 ${DEVICE_TYPE##*.}"
fi
SIM_NAME="Pour 检查（${DEVICE_TYPE##*.}）"
SIM_ID="$(xcrun simctl list devices available | grep -F "${SIM_NAME} (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
[[ -n "${SIM_ID}" ]] || SIM_ID="$(xcrun simctl create "${SIM_NAME}" "${DEVICE_TYPE}" "${RUNTIME}")"
# 关掉重开，并等它完全开好再测：刚开机时系统桌面还在准备，这时启动 App 会被拒（「Busy」）
xcrun simctl shutdown "${SIM_ID}" >/dev/null 2>&1 || true
xcrun simctl boot "${SIM_ID}"
xcrun simctl bootstatus "${SIM_ID}" -b >/dev/null
echo "模拟器：${SIM_NAME} · ${RUNTIME##*.}（已开好）"
EXTRA=()
[[ ${SKIP_UI} == 1 ]] && EXTRA=(-skip-testing:PourUITests) && echo "（跳过界面测试）"
RESULT="build/check-$(date +%Y%m%d-%H%M%S).xcresult"
LOG="build/check-xcodebuild.log"
mkdir -p build
if ! xcodebuild test -project Pour.xcodeproj -scheme Pour \
  -destination "platform=iOS Simulator,id=${SIM_ID}" \
  -derivedDataPath build/DerivedData -resultBundlePath "${RESULT}" \
  ${EXTRA[@]+"${EXTRA[@]}"} >"${LOG}" 2>&1; then
  grep -E "error:|✘|failed" "${LOG}" | grep -v "known issue" | head -20
  fail "App 的测试没通过（完整输出：ios/${LOG}，结果：ios/${RESULT}）"
fi
grep -E "Executed [0-9]+ tests|Test run with" "${LOG}" | tail -2

printf '\n✓ iOS 检查全部通过（%d 秒）。测试结果：ios/%s\n' $((SECONDS - START)) "${RESULT}"
