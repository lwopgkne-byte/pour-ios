#!/bin/bash
# 用数据线把 App 装到产品主人的 iPhone 上（没有 TestFlight 时的验收方式，M0 小方案第 2 节）。
# 免费的个人签名：装上的 App 7 天后打不开，插上线重新运行本脚本即可。
# 构建号 = 这个分支的提交数，启动页底部会显示，验收时对得上。
# 用法：scripts/install-device.sh        （手机用数据线连着 Mac，已经点过「信任」）
set -euo pipefail

cd "$(dirname "$0")/.."
step() { printf '\n▸ %s\n' "$1"; }
fail() { printf '\n✗ %s\n' "$1"; exit 1; }

[[ -f Config/Local.xcconfig ]] || fail "还没有签名团队：在 Xcode → 设置 → Accounts 登录 Apple ID，再运行 scripts/bootstrap.sh"

step "找连着的 iPhone"
JSON="$(mktemp)"
xcrun devicectl list devices --json-output "${JSON}" >/dev/null
DEVICE="$(python3 - "${JSON}" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
# 只要真机：新的 Xcode 把模拟器也列在这里（reality 是 simulated）
phones = [d for d in devices if d.get("hardwareProperties", {}).get("deviceType") == "iPhone"
          and d.get("hardwareProperties", {}).get("reality") == "physical"]
# 以前配对过的手机拔了线也会列出来（tunnelState 是 unavailable）：只要现在连着的
connected = [d for d in phones if d.get("connectionProperties", {}).get("tunnelState") != "unavailable"]
if connected:
    d = connected[0]
    c = d.get("connectionProperties", {})
    print(d["identifier"], d["hardwareProperties"].get("udid", ""), d["deviceProperties"].get("osVersionNumber", "?"),
          d["deviceProperties"].get("name", "iPhone"), c.get("pairingState", ""), sep="|")
PY
)"
rm -f "${JSON}"
[[ -n "${DEVICE}" ]] || fail "Mac 现在没认到 iPhone：解锁手机、重新插线；在「访达」左侧看到 iPhone 才算连上。还不行就换一根能传数据的线"
IFS='|' read -r DEVICE_ID UDID IOS_VERSION DEVICE_NAME PAIRING <<<"${DEVICE}"
echo "${DEVICE_NAME} · iOS ${IOS_VERSION}"
[[ "${PAIRING}" == "paired" ]] || fail "手机还没信任这台 Mac：看手机屏幕上的「要信任此电脑吗」，点「信任」并输入锁屏密码，再运行一次"

BUILD="$(git rev-list --count HEAD)"
# 手机在局域网里找这台 Mac 上的 Pour 服务器（网页版的服务器，产品主人 2026-10-19 选 B）：用 Mac 的局域网名字
SERVER="http://$(scutil --get LocalHostName).local:5188"
step "构建（版本 $(awk -F' = ' '/^MARKETING_VERSION/{print $2}' Config/Base.xcconfig) · 构建 ${BUILD}）"
xcodegen generate --spec project.yml --quiet
xcodebuild build -project Pour.xcodeproj -scheme Pour -configuration Debug \
  -destination "id=${UDID}" -derivedDataPath build/DeviceData -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="${BUILD}" POUR_SERVER_URL="${SERVER}" >build/install-device.log 2>&1 \
  || { grep -E "error:" build/install-device.log | head -10; fail "构建没成功（完整输出：build/install-device.log）"; }

step "装到手机上"
APP="build/DeviceData/Build/Products/Debug-iphoneos/Pour.app"
xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" >/dev/null
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "${APP}/Info.plist")"
if xcrun devicectl device process launch --device "${DEVICE_ID}" "${BUNDLE_ID}" >/dev/null 2>&1; then
  echo "已经在手机上打开了 Pour。"
else
  echo "装好了，但没能自动打开：第一次装要在手机上 设置 → 通用 → VPN 与设备管理 里信任开发者，再点开 Pour。"
fi
printf '\n✓ 装好了（构建 %s）。手机连的是这台 Mac 上的 Pour 服务器：%s\n' "${BUILD}" "${SERVER}"
