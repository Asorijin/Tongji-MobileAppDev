#!/usr/bin/env bash
# 本地（macOS）与 CI 一致的测试入口：make test / make verify。
#
# 前置条件：macOS + Xcode 16.4 + XcodeGen（`brew install xcodegen` 或把
# .tools/xcodegen/bin 加入 PATH）。已在本地生成过 CamCardClone.xcodeproj 时可跳过 xcodegen。
#
# 用法：
#   bash scripts/run-tests.sh            # 增量构建并运行全部测试
#   bash scripts/run-tests.sh --clean    # 删除 build/ 后从零构建（等价 CI）
#
# 与 CI 一致：同样执行 build-for-testing → test-without-building，并输出 build/*.log。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.5}"
DERIVED_DATA="build/DerivedData"
RESULT_BUNDLE="build/TestResults.xcresult"

for arg in "$@"; do
  case "$arg" in
    --clean)
      echo "==> 清理 build/"
      rm -rf build
      ;;
    *)
      echo "未知参数：$arg" >&2
      exit 2
      ;;
  esac
done

if command -v python3 >/dev/null 2>&1; then
  echo "==> 校验合成名片数据集"
  python3 scripts/verify_test_cards.py
fi

if [ ! -d CamCardClone.xcodeproj ]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "==> 生成 Xcode 工程"
    xcodegen generate
  else
    echo "缺少 CamCardClone.xcodeproj，且未找到 xcodegen。请安装 XcodeGen 后重试。" >&2
    exit 1
  fi
fi

mkdir -p build
rm -rf "$RESULT_BUNDLE"

echo "==> build-for-testing（$DESTINATION）"
xcodebuild build-for-testing \
  -project CamCardClone.xcodeproj \
  -scheme CamCardClone \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  | tee build/build.log

echo "==> test-without-building"
set +e
xcodebuild test-without-building \
  -project CamCardClone.xcodeproj \
  -scheme CamCardClone \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  | tee build/test.log
status=${PIPESTATUS[0]}
set -e

echo "==> 摘要"
grep -E "Test Suite '.*' (passed|failed)|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" build/test.log | tail -n 30 || true

exit "$status"
