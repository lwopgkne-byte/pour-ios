#!/bin/bash
# iOS 一键检查（M0）：推送前自动跑（.githooks/pre-push，改了 ios/ 才跑），合并前 GitHub Actions 再跑一遍。
#   ① 生成工程 ② 代码格式 ③ SwiftLint（含令牌检查）④ 依赖方向、原始色板是最新的 ⑤ 隐私清单
#   ⑥ 规则和设计系统的单元测试（Mac 上直接跑）
#   ⑦ App 和设计画廊的测试：iOS 26（最低系统，iPhone 17 Pro）和 iOS 27（最新系统）各一台模拟器
# 用法：ios/scripts/check.sh            全部
#       ios/scripts/check.sh --no-ui    跳过界面测试（快）
# 用专用的检查模拟器「Pour 检查」（没有就建，ios/scripts/simulator.py），每次先关掉再开好再跑。
# 机型默认 iPhone 17 Pro，可以用 POUR_SIMULATOR="iPhone 13" 换；某个系统不支持这个机型就用它支持的第一个 iPhone
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
  App AppTests AppUITests Gallery/Sources GalleryUITests \
  Packages/PourKit/Sources Packages/PourKit/Tests Packages/PourKit/Package.swift \
  || fail "格式不对：运行 xcrun swift-format format -i -r --configuration ios/.swift-format <文件> 自动改好"

step "③ SwiftLint（含不许硬编码颜色和字号）"
swiftlint lint --strict --quiet || fail "SwiftLint 没通过"

step "④ 依赖方向"
python3 scripts/check-deps.py || fail "依赖方向不对"
python3 scripts/palette.py --swift --check || fail "原始色板不是最新的"

step "⑤ 隐私清单"
plutil -lint App/Resources/PrivacyInfo.xcprivacy || fail "隐私清单格式不对"

step "⑥ 规则和设计系统的单元测试（Mac）"
(cd Packages/PourKit && swift test --quiet 2>&1 | tail -3) || fail "单元测试没通过"

step "⑦ App 和设计画廊的测试"
EXTRA=()
[[ ${SKIP_UI} == 1 ]] && EXTRA=(-skip-testing:PourUITests -skip-testing:GalleryUITests) && echo "（跳过界面测试）"
mkdir -p build
for MAJOR in 26 27; do
  IFS=$'\t' read -r SIM_ID SIM_NAME < <(python3 scripts/simulator.py "Pour 检查" "${SIMULATOR}" "${MAJOR}") \
    || fail "没有 iOS ${MAJOR} 的模拟器：在 Xcode → 设置 → Components 里装上"
  # 关掉重开，并等它完全开好再测：刚开机时系统桌面还在准备，这时启动 App 会被拒（「Busy」）
  xcrun simctl shutdown "${SIM_ID}" >/dev/null 2>&1 || true
  xcrun simctl boot "${SIM_ID}"
  xcrun simctl bootstatus "${SIM_ID}" -b >/dev/null
  echo "模拟器：${SIM_NAME}（已开好）"
  for SCHEME in Pour PourGallery; do
    RESULT="build/check-ios${MAJOR}-${SCHEME}-$(date +%Y%m%d-%H%M%S).xcresult"
    LOG="build/check-ios${MAJOR}-${SCHEME}.log"
    if ! xcodebuild test -project Pour.xcodeproj -scheme "${SCHEME}" \
      -destination "platform=iOS Simulator,id=${SIM_ID}" \
      -derivedDataPath build/DerivedData -resultBundlePath "${RESULT}" \
      ${EXTRA[@]+"${EXTRA[@]}"} >"${LOG}" 2>&1; then
      grep -E "error:|✘|failed" "${LOG}" | grep -v "known issue" | head -20
      fail "${SCHEME} 在 iOS ${MAJOR} 上的测试没通过（完整输出：ios/${LOG}，结果：ios/${RESULT}）"
    fi
    echo "  ${SCHEME}：$(grep -E "Executed [0-9]+ tests|Test run with" "${LOG}" | tail -1 | sed -E 's/^[[:space:]]+//')"
  done
  xcrun simctl shutdown "${SIM_ID}" >/dev/null 2>&1 || true
done

printf '\n✓ iOS 检查全部通过（%d 秒）。测试结果在 ios/build/\n' $((SECONDS - START))
