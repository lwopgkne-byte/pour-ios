#!/bin/bash
# 全部页面截图（docs/3.0/03-开发计划.md 2.1 第 5 条）：连一台演示数据的服务器，在「iPhone 15 · iOS 27」模拟器上
# 把每一页从上往下一屏一屏截下来，再拼成每页一张长图。每一步做之前、做之后各跑一次，并排对照。
# 用法：scripts/tour-shots.sh <服务器地址> <输出目录>
#   例：scripts/tour-shots.sh http://127.0.0.1:5288 docs/3.0/验收/第1步/改之后
#   输出：<输出目录>/每一屏/*.png（一屏一张）、<输出目录>/*.jpg（每页一张长图）
# 只连演示数据：真实数据是产品主人的个人数据，不截图、不进仓库（服务器不是演示数据就停下）。
# 日子按服务器的「今天」算；「一样东西」「和一个人的来往」挑演示数据里的第一个。
set -euo pipefail

cd "$(dirname "$0")/.."
usage="用法：scripts/tour-shots.sh <服务器地址> <输出目录>"
SERVER="${1:?${usage}}"
OUT="${2:?${usage}}"
SERVER="${SERVER%/}"
fail() { printf '\n✗ %s\n' "$1"; exit 1; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

META="$(curl -fsS -m 5 "${SERVER}/api/meta")" || fail "连不上 ${SERVER}：先把服务器起来"
MODE="$(json 'd.get("mode","")' <<<"${META}")"
TODAY="$(json 'd["today"]' <<<"${META}")"
[[ "${MODE}" == "demo" ]] || fail "${SERVER} 现在不是演示数据（mode=${MODE}）：只截演示数据"
MONTH="${TODAY:0:7}"
THING="$(curl -fsS -m 10 "${SERVER}/api/money/${MONTH}" \
  | json 'next((str(i["entryId"]) for i in d.get("items",[]) if i.get("things")), "")')"
PERSON="$(curl -fsS -m 10 "${SERVER}/api/money/renqing" | json '(d.get("people") or [{}])[0].get("name","")')"
echo "服务器 ${SERVER}（演示数据，今天 ${TODAY}）；一样东西：记录 ${THING:-没有}；人情：${PERSON:-没有}"

xcodegen generate --spec project.yml --quiet
IFS=$'\t' read -r SIM_ID SIM_NAME < <(python3 scripts/simulator.py "Pour 截图" "iPhone 15" 27) \
  || fail "没有 iOS 27 的模拟器：在 Xcode → 设置 → Components 里装上"
xcrun simctl boot "${SIM_ID}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${SIM_ID}" -b >/dev/null
echo "模拟器：${SIM_NAME}"

mkdir -p build
RESULT="build/tour-$(date +%Y%m%d-%H%M%S).xcresult"
LOG="build/tour.log"
echo "截图中（十分钟左右）……"
if ! TEST_RUNNER_POUR_TOUR_SERVER="${SERVER}" TEST_RUNNER_POUR_TOUR_TODAY="${TODAY}" \
  TEST_RUNNER_POUR_TOUR_THING="${THING}" TEST_RUNNER_POUR_TOUR_PERSON="${PERSON}" \
  xcodebuild test -project Pour.xcodeproj -scheme Pour -destination "platform=iOS Simulator,id=${SIM_ID}" \
  -derivedDataPath build/DerivedData -resultBundlePath "${RESULT}" -collect-test-diagnostics never \
  -only-testing:PourUITests/TourShotsUITests/testTour >"${LOG}" 2>&1; then
  grep -E "error:|failed" "${LOG}" | head -10
  echo "（没跑完也把截到的导出来）"
fi
[[ -d "${RESULT}" ]] || fail "没有测试结果（完整输出：${LOG}）"

rm -rf "${OUT}/每一屏"
python3 scripts/export-screenshots.py "${RESULT}" "${OUT}/每一屏"
swift scripts/stitch-shots.swift "${OUT}/每一屏" "${OUT}"
printf '\n✓ 截图好了：%s\n' "${OUT}"
