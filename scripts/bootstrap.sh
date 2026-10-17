#!/bin/bash
# 在 Mac 上一键准备好 iOS 开发环境（M0）。可以重复运行，已经装好的会跳过。
#   1. 检查 Xcode   2. 装工具（ios/Brewfile）   3. Node（版本看 .nvmrc）和网页版的依赖、推送前检查
#   4. 这台电脑的签名团队   5. 生成 Xcode 工程
# 用法：在仓库根目录运行 ios/scripts/bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
REQUIRED_XCODE_MAJOR=27 # 2026-10-17 回到方案一：Xcode 27（ADR A03）
START=${SECONDS}
step() { printf '\n▸ %s\n' "$1"; }
fail() { printf '\n✗ %s\n' "$1"; exit 1; }

step "1/5 检查 Xcode"
[[ "$(uname -m)" == "arm64" ]] || fail "需要 M 系列芯片的 Mac"
command -v xcodebuild >/dev/null || fail "没找到 Xcode：先从 App Store 装 Xcode，打开一次"
XCODE_VERSION="$(xcodebuild -version | awk 'NR==1{print $2}')"
[[ "${XCODE_VERSION%%.*}" == "${REQUIRED_XCODE_MAJOR}" ]] \
  || fail "现在的 Xcode 是 ${XCODE_VERSION}，项目要 ${REQUIRED_XCODE_MAJOR}.x（xcode-select -p 看用的是哪个）"
xcodebuild -checkFirstLaunchStatus || fail "Xcode 还没完成第一次启动：打开一次 Xcode，等它装完组件"
echo "Xcode ${XCODE_VERSION} ✓"

step "2/5 装工具（XcodeGen、SwiftLint、fnm）"
command -v brew >/dev/null || fail "没找到 Homebrew：先按 https://brew.sh 的一行命令装上"
brew bundle --file ios/Brewfile --quiet
echo "XcodeGen $(xcodegen --version | awk '{print $2}') · SwiftLint $(swiftlint version) ✓"

step "3/5 Node $(cat .nvmrc) 和网页版的依赖（也会启用推送前检查）"
eval "$(fnm env --shell bash)"
fnm install --log-level=quiet "$(cat .nvmrc)"
fnm use --log-level=quiet "$(cat .nvmrc)"
echo "Node $(node -v)"
npm ci --silent --no-fund --no-audit
[[ "$(git config core.hooksPath)" == ".githooks" ]] || fail "推送前检查没启用"
echo "推送前检查已启用 ✓"

step "4/5 这台电脑的签名团队"
LOCAL_CONFIG="ios/Config/Local.xcconfig"
if [[ -f "${LOCAL_CONFIG}" ]]; then
  echo "已有 ${LOCAL_CONFIG} ✓"
else
  TEAM="$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | grep -m1 -E '^ *teamID = ' | sed -E 's/.*teamID = "?([A-Z0-9]+)"?;/\1/' || true)"
  if [[ -n "${TEAM}" ]]; then
    printf '// 这台电脑自己的签名团队。bootstrap.sh 生成，不提交。\nDEVELOPMENT_TEAM = %s\n' "${TEAM}" >"${LOCAL_CONFIG}"
    echo "用 Xcode 里登录的团队 ${TEAM} ✓"
  else
    echo "Xcode 里还没登录 Apple ID：模拟器照样能用；要装到 iPhone 上，先在 Xcode → 设置 → Accounts 登录，再运行一次本脚本"
  fi
fi

step "5/5 生成 Xcode 工程"
(cd ios && xcodegen generate --spec project.yml --quiet)
echo "ios/Pour.xcodeproj ✓"

printf '\n✓ 环境准备好了（%d 秒）。\n  检查：ios/scripts/check.sh\n  打开工程：open ios/Pour.xcodeproj\n' $((SECONDS - START))
