#!/bin/bash
# 自验收的截图矩阵（设计审查清单：亮色、暗色、最大字号 × 小屏 375 点、大屏 440 点）。
# 在 iPhone SE（375 点宽）和 iPhone 17 Pro Max（440 点宽）上跑画廊的一屏一屏审计（GalleryUITests，每一屏都截图），
# 跑完把截图导出到 <输出目录>/375、<输出目录>/440，文件名如「样张-today-暗色-第2屏.png」。顺带在这两种宽度上也审计一遍。
# 都用 iOS 26：这台 Mac 上 iOS 27.1 的模拟器只支持 iPhone Duo。
# 用法：scripts/screenshots.sh <输出目录> [测试名…]（默认三个样张测试；画廊页面加 testGalleryPagesLight 等）
set -euo pipefail

OUT="${1:?用法：scripts/screenshots.sh <输出目录> [测试名…]}"
shift
TESTS=("$@")
[[ ${#TESTS[@]} -gt 0 ]] || TESTS=(testSamplesLight testSamplesDark testSamplesLargestText)
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)" # 换成完整路径：下面要切到仓库根目录
cd "$(dirname "$0")/.."
mkdir -p build
ONLY=()
for TEST in "${TESTS[@]}"; do ONLY+=("-only-testing:GalleryUITests/GalleryUITests/${TEST}"); done

STATUS=0
for SPEC in "375|iPhone SE (3rd generation)" "440|iPhone 17 Pro Max"; do
  WIDTH="${SPEC%%|*}"
  TYPE="${SPEC#*|}"
  IFS=$'\t' read -r SIM_ID SIM_NAME < <(python3 scripts/simulator.py "Pour 截图" "${TYPE}" 26)
  xcrun simctl shutdown "${SIM_ID}" >/dev/null 2>&1 || true
  xcrun simctl boot "${SIM_ID}"
  xcrun simctl bootstatus "${SIM_ID}" -b >/dev/null
  # 状态栏固定成 9:41、满格，截图之间好比较
  xcrun simctl status_bar "${SIM_ID}" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3
  echo "模拟器：${SIM_NAME}（${WIDTH} 点宽）"
  RESULT="build/screenshots-${WIDTH}-$(date +%Y%m%d-%H%M%S).xcresult"
  LOG="build/screenshots-${WIDTH}.log"
  if ! xcodebuild test -project Pour.xcodeproj -scheme PourGallery \
    -destination "platform=iOS Simulator,id=${SIM_ID}" \
    -derivedDataPath build/DerivedData -resultBundlePath "${RESULT}" "${ONLY[@]}" >"${LOG}" 2>&1; then
    STATUS=1
    echo "  有审计问题或测试没过（完整输出：${LOG}）："
    grep -E "^审计问题|error:" "${LOG}" | head -20 | sed 's/^/    /' || true
  fi
  echo "  $(grep -E "Executed [0-9]+ tests" "${LOG}" | tail -1 | sed -E 's/^[[:space:]]+//')"
  python3 scripts/export-screenshots.py "${RESULT}" "${OUT}/${WIDTH}"
  xcrun simctl status_bar "${SIM_ID}" clear
  xcrun simctl shutdown "${SIM_ID}"
done
exit "${STATUS}"
