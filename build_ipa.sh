#!/usr/bin/env bash
#
# build_ipa.sh — 无签名构建 Flutter iOS App 并打包为 IPA
#
# 适用场景:
#   本机只有开发证书(或完全没有发布证书 / Provisioning Profile)时,
#   生成"未签名"的 .ipa。该包不能直接安装到设备,
#   需后续用 fastlane/sigh、Xcode 或 `codesign` 重新签名后方可安装 / 上架。
#
# 用法:
#   ./build_ipa.sh                  # 默认输出到 build/ios/ipa/Runner.ipa
#   ./build_ipa.sh -o out/app.ipa   # 指定输出文件(目录会自动创建)
#   ./build_ipa.sh --no-pod         # 跳过 pod install(已装过依赖时加速)
#   ./build_ipa.sh -h               # 查看帮助
#
set -euo pipefail

# ---------- 可配置变量 ----------
OUT_IPA=""
SKIP_POD=0
FLUTTER="${FLUTTER:-flutter}"

# ---------- 解析参数 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output) OUT_IPA="$2"; shift 2 ;;
    --no-pod)    SKIP_POD=1;  shift   ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

# ---------- 定位项目根目录(脚本所在目录) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/4] flutter pub get"
"$FLUTTER" pub get

if [[ $SKIP_POD -eq 0 ]]; then
  echo "==> [2/4] pod install"
  ( cd ios && pod install )
else
  echo "==> [2/4] 跳过 pod install (--no-pod)"
fi

echo "==> [3/4] flutter build ios --release --no-codesign"
"$FLUTTER" build ios --release --no-codesign

APP_PATH="$SCRIPT_DIR/build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "错误: 未找到 $APP_PATH, 构建可能失败" >&2
  exit 1
fi

# ---------- 输出路径处理 ----------
if [[ -z "$OUT_IPA" ]]; then
  OUT_DIR="$SCRIPT_DIR/build/ios/ipa"
  mkdir -p "$OUT_DIR"
  OUT_IPA="$OUT_DIR/Runner.ipa"
else
  mkdir -p "$(dirname "$OUT_IPA")"
fi

echo "==> [4/4] 打包 IPA -> $OUT_IPA"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"
cp -R "$APP_PATH" "$WORK/Payload/Runner.app"
( cd "$WORK" && zip -r -y -q "$OUT_IPA" Payload )

echo "完成! IPA 已生成:"
ls -lh "$OUT_IPA"

# ---------- 重新签名提示 ----------
cat <<'NOTE'

提示: 该 IPA 未签名。要安装到真机 / 上架, 任选其一重新签名:
  1) Xcode: 双击 .xcworkspace, 选 Runner target 配置 Signing, Product > Archive。
  2) fastlane: 准备分发证书 + Provisioning Profile 后 `fastlane gym` / `fastlane sigh`。
  3) 命令: 用 `codesign --force --sign "iPhone Distribution: ..." Payload/Runner.app`
           再 `zip -r` 重新打包。
NOTE
