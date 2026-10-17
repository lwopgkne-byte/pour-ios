#!/bin/bash
# 自验收的截图矩阵（设计审查清单：亮色、暗色、最大字号 × 小屏 375 点、大屏 440 点）。
# 用 scripts/check.sh 刚构建好的 App；截图存到指定目录。
# 用法：scripts/screenshots.sh <输出目录>
set -euo pipefail

OUT="${1:?用法：scripts/screenshots.sh <输出目录>}"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)" # 换成完整路径：下面要切到仓库根目录
cd "$(dirname "$0")/.."
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/Pour.app"
[[ -d "${APP}" ]] || { echo "先运行 scripts/check.sh 构建 App"; exit 1; }
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "${APP}/Info.plist")"
RUNTIME="$(xcrun simctl list runtimes available | awk '/^iOS /{id=$NF} END{print id}')"

# 小屏：iPhone SE（375 点宽）；大屏：iPhone 17 Pro Max（440 点宽）
for TYPE in iPhone-SE-3rd-generation iPhone-17-Pro-Max; do
  NAME="Pour 截图（${TYPE}）"
  ID="$(xcrun simctl list devices available | grep -F "${NAME} (" | grep -oE '[0-9A-F-]{36}' | awk 'NR==1' || true)"
  [[ -n "${ID}" ]] || ID="$(xcrun simctl create "${NAME}" "com.apple.CoreSimulator.SimDeviceType.${TYPE}" "${RUNTIME}")"
  xcrun simctl boot "${ID}" 2>/dev/null || true
  xcrun simctl bootstatus "${ID}" -b >/dev/null
  # 状态栏固定成 9:41、满格，截图之间好比较
  xcrun simctl status_bar "${ID}" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install "${ID}" "${APP}"
  for MODE in light dark ax5; do
    case "${MODE}" in
      light) xcrun simctl ui "${ID}" appearance light; xcrun simctl ui "${ID}" content_size large ;;
      dark) xcrun simctl ui "${ID}" appearance dark; xcrun simctl ui "${ID}" content_size large ;;
      ax5) xcrun simctl ui "${ID}" appearance light; xcrun simctl ui "${ID}" content_size accessibility-extra-extra-extra-large ;;
    esac
    xcrun simctl terminate "${ID}" "${BUNDLE_ID}" 2>/dev/null || true
    xcrun simctl launch "${ID}" "${BUNDLE_ID}" >/dev/null
    sleep 2
    xcrun simctl io "${ID}" screenshot --type=png "${OUT}/${TYPE}-${MODE}.png" >/dev/null 2>&1
    echo "${OUT}/${TYPE}-${MODE}.png"
  done
  xcrun simctl ui "${ID}" content_size large
  xcrun simctl shutdown "${ID}"
done
